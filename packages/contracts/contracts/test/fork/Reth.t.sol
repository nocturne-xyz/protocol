// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {ForkBase} from "./ForkBase.sol";
import {IWeth} from "../../interfaces/IWeth.sol";
import {IReth} from "../../interfaces/IReth.sol";
import {RethAdapter} from "../../adapters/RethAdapter.sol";
import {IRocketStorage} from "../../interfaces/IRocketStorage.sol";
import {IRocketDepositPool} from "../../interfaces/IRocketDepositPool.sol";
import {IRocketDAOProtocolSettingsDeposit} from "../interfaces/IRocketDAOProtocolSettingsDeposit.sol";
import {IRocketMinipoolQueue} from "../interfaces/IRocketMinipoolQueue.sol";
import "../../libs/Types.sol";
import "../../libs/AssetUtils.sol";
import "../utils/NocturneUtils.sol";

// NOTE: the reth fork test are run against a different date than the other tests because
// Rocket Pool has a stepwise deposit limit that gets filled to max every few months. Must pick
// point in time when deposit limit is not maxed out.
contract RethTest is ForkBase {
    IWeth public constant weth =
        IWeth(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IReth public constant reth =
        IReth(address(0xae78736Cd615f374D3085123A210448E74Fc6393));

    IRocketStorage public constant rocketStorage =
        IRocketStorage(address(0x1d8f8f00cfa6758d7bE78336684788Fb0ee0Fa46));
    uint256 public constant ROCKET_POOL_MIN_DEPOSIT_SIZE = 1 ether / 100;

    RethAdapter rethAdapter;

    function setUp() public {
        baseSetUp();

        rethAdapter = new RethAdapter(address(weth), address(rocketStorage));

        // Whitelist bundler
        teller.setBundlerPermission(BUNDLER, true);

        // Whitelist weth, reth, reth adapter
        handler.setContractPermission(address(weth), true);
        handler.setContractPermission(address(reth), true);
        handler.setContractPermission(address(rethAdapter), true);

        // Whitelist weth approve, reth deposit
        handler.setContractMethodPermission(
            address(weth),
            weth.approve.selector,
            true
        );
        handler.setContractMethodPermission(
            address(rethAdapter),
            rethAdapter.deposit.selector,
            true
        );

        // Prefill tokens
        deal(address(weth), address(handler), 1);
        deal(address(reth), address(handler), 1);
    }

    function testRethSingleDeposit(uint256 wethInAmount) public {
        uint256 maxDepositAmount = _getNewDepositsUpperBound();

        // NOTE: rocket pool minimum amount is 0.01 ETH so higher lower bound than normal
        wethInAmount = bound(
            wethInAmount,
            ROCKET_POOL_MIN_DEPOSIT_SIZE,
            maxDepositAmount
        );
        reserveAndDeposit(address(weth), wethInAmount);

        // TODO: 1% buffer, figure out where actual exchange rate comes from that's used in UI (doesn't match getRethValue)
        uint256 rethExpectedOutAmount = (reth.getRethValue(wethInAmount) * 99) /
            100;

        // Format weth as refund asset
        TrackedAsset[] memory trackedRefundAssets = new TrackedAsset[](1);
        trackedRefundAssets[0] = TrackedAsset({
            encodedAsset: AssetUtils.encodeAsset(
                AssetType.ERC20,
                address(reth),
                ERC20_ID
            ),
            minRefundValue: rethExpectedOutAmount
        });

        // Format actions
        Action[] memory actions = new Action[](2);
        actions[0] = Action({
            contractAddress: address(weth),
            encodedFunction: abi.encodeWithSelector(
                weth.approve.selector,
                address(rethAdapter),
                wethInAmount
            )
        });
        actions[1] = Action({
            contractAddress: address(rethAdapter),
            encodedFunction: abi.encodeWithSelector(
                rethAdapter.deposit.selector,
                wethInAmount
            )
        });

        // Create operation to deposit weth and get reth
        Bundle memory bundle = Bundle({operations: new Operation[](1)});
        bundle.operations[0] = NocturneUtils.formatOperation(
            FormatOperationArgs({
                joinSplitTokens: NocturneUtils._joinSplitTokensArrayOfOneToken(
                    address(weth)
                ),
                joinSplitRefundValues: new uint256[](1),
                gasToken: address(weth),
                root: handler.root(),
                joinSplitsPublicSpends: NocturneUtils
                    ._publicSpendsArrayOfOnePublicSpendArray(
                        NocturneUtils.fillJoinSplitPublicSpends(wethInAmount, 1)
                    ),
                trackedRefundAssets: trackedRefundAssets,
                gasAssetRefundThreshold: 0,
                executionGasLimit: 10_000_000, // large gas limit
                gasPrice: 0,
                actions: actions,
                atomicActions: true,
                operationFailureType: OperationFailureType.NONE
            })
        );

        // Check pre op balances
        assertEq(weth.balanceOf(address(teller)), wethInAmount);
        assertEq(reth.balanceOf(address(teller)), 0);

        // Execute operation
        vm.prank(BUNDLER, BUNDLER);
        teller.processBundle(bundle);

        // Check post op balances
        assertEq(weth.balanceOf(address(teller)), 0);
        assertGe(reth.balanceOf(address(teller)), rethExpectedOutAmount);
    }

    function testRethMultiDeposit(
        uint256 wethInAmount,
        uint256 numDeposits
    ) public {
        uint256 maxDepositAmount = _getNewDepositsUpperBound();
        numDeposits = bound(numDeposits, 1, 10);
        wethInAmount = bound(
            wethInAmount,
            ROCKET_POOL_MIN_DEPOSIT_SIZE * numDeposits,
            maxDepositAmount
        );

        // Adjust weth in amount to be divisible by num deposits
        if (wethInAmount % numDeposits != 0) {
            wethInAmount = wethInAmount - (wethInAmount % numDeposits);
        }
        reserveAndDeposit(address(weth), wethInAmount);

        uint256 rethExpectedOutAmount = (reth.getRethValue(wethInAmount) * 99) /
            100; // TODO: 1% buffer, figure out where actual exchange rate comes from that's used in UI (doesn't match getRethValue)

        // Format weth as refund asset
        TrackedAsset[] memory trackedRefundAssets = new TrackedAsset[](1);
        trackedRefundAssets[0] = TrackedAsset({
            encodedAsset: AssetUtils.encodeAsset(
                AssetType.ERC20,
                address(reth),
                ERC20_ID
            ),
            minRefundValue: rethExpectedOutAmount
        });

        // Format actions
        Action[] memory actions = new Action[](1 + numDeposits);
        actions[0] = Action({
            contractAddress: address(weth),
            encodedFunction: abi.encodeWithSelector(
                weth.approve.selector,
                address(rethAdapter),
                wethInAmount
            )
        });

        // Create multiple weth -> wsteth deposits
        for (uint256 i = 1; i <= numDeposits; i++) {
            actions[i] = Action({
                contractAddress: address(rethAdapter),
                encodedFunction: abi.encodeWithSelector(
                    rethAdapter.deposit.selector,
                    wethInAmount / numDeposits
                )
            });
        }

        // Create operation to deposit weth and get wsteth
        Bundle memory bundle = Bundle({operations: new Operation[](1)});
        bundle.operations[0] = NocturneUtils.formatOperation(
            FormatOperationArgs({
                joinSplitTokens: NocturneUtils._joinSplitTokensArrayOfOneToken(
                    address(weth)
                ),
                joinSplitRefundValues: new uint256[](1),
                gasToken: address(weth),
                root: handler.root(),
                joinSplitsPublicSpends: NocturneUtils
                    ._publicSpendsArrayOfOnePublicSpendArray(
                        NocturneUtils.fillJoinSplitPublicSpends(wethInAmount, 1)
                    ),
                trackedRefundAssets: trackedRefundAssets,
                gasAssetRefundThreshold: 0,
                executionGasLimit: 10_000_000, // large gas limit
                gasPrice: 0,
                actions: actions,
                atomicActions: true,
                operationFailureType: OperationFailureType.NONE
            })
        );

        // Check pre op balances
        assertEq(weth.balanceOf(address(teller)), wethInAmount);
        assertEq(reth.balanceOf(address(teller)), 0);

        // Execute operation
        vm.prank(BUNDLER, BUNDLER);
        teller.processBundle(bundle);

        // Check post op balances
        assertEq(weth.balanceOf(address(teller)), 0);
        assertGe(reth.balanceOf(address(teller)), rethExpectedOutAmount);
    }

    function _getNewDepositsUpperBound() internal view returns (uint256) {
        IRocketDepositPool rocketDepositPool = IRocketDepositPool(
            rocketStorage.getAddress(
                keccak256(
                    abi.encodePacked("contract.address", "rocketDepositPool")
                )
            )
        );
        IRocketDAOProtocolSettingsDeposit rocketDAOProtocolSettingsDeposit = IRocketDAOProtocolSettingsDeposit(
                rocketStorage.getAddress(
                    keccak256(
                        abi.encodePacked(
                            "contract.address",
                            "rocketDAOProtocolSettingsDeposit"
                        )
                    )
                )
            );
        IRocketMinipoolQueue rocketMinipoolQueue = IRocketMinipoolQueue(
            rocketStorage.getAddress(
                keccak256(
                    abi.encodePacked("contract.address", "rocketMinipoolQueue")
                )
            )
        );
        uint256 currentRocketDepositBalance = rocketDepositPool.getBalance();
        uint256 maxDepositLimit = rocketDAOProtocolSettingsDeposit
            .getMaximumDepositPoolSize();
        uint256 minipoolQueueSize = rocketMinipoolQueue.getEffectiveCapacity();

        console.log("currentRocketDepositBalance", currentRocketDepositBalance);
        console.log("maxDepositLimit", maxDepositLimit);
        console.log("minipoolQueueSize", minipoolQueueSize);

        return
            maxDepositLimit + minipoolQueueSize - currentRocketDepositBalance;
    }
}

// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {ForkBase} from "./ForkBase.sol";
import {IWeth} from "../../interfaces/IWeth.sol";
import {IWsteth} from "../../interfaces/IWsteth.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {WstethAdapter} from "../../adapters/WstethAdapter.sol";
import "../../libs/Types.sol";
import "../../libs/AssetUtils.sol";
import "../utils/NocturneUtils.sol";

contract WstethTest is ForkBase {
    IWeth public constant weth =
        IWeth(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IWsteth public constant wsteth =
        IWsteth(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

    WstethAdapter wstethAdapter;

    function setUp() public {
        baseSetUp();

        // Whitelist bundler
        teller.setBundlerPermission(BUNDLER, true);

        wstethAdapter = new WstethAdapter(address(weth), address(wsteth));

        // Whitelist weth, wsteth, wsteth adapter
        handler.setContractPermission(address(weth), true);
        handler.setContractPermission(address(wsteth), true);
        handler.setContractPermission(address(wstethAdapter), true);

        // Whitelist weth approve, wsteth approve, wsteth adapter deposit
        handler.setContractMethodPermission(
            address(weth),
            weth.approve.selector,
            true
        );
        handler.setContractMethodPermission(
            address(wsteth),
            wsteth.approve.selector,
            true
        );
        handler.setContractMethodPermission(
            address(wstethAdapter),
            wstethAdapter.deposit.selector,
            true
        );

        // Prefill tokens
        deal(address(weth), address(handler), 1);
        deal(address(wsteth), address(handler), 1);
    }

    function testWstethSingleDeposit(uint256 wethInAmount) public {
        wethInAmount = bound(wethInAmount, 1000, 10000 ether);
        reserveAndDeposit(address(weth), wethInAmount);

        uint256 wstethExpectedOutAmount = wsteth.getWstETHByStETH(wethInAmount);

        // Format weth as refund asset
        TrackedAsset[] memory trackedRefundAssets = new TrackedAsset[](1);
        trackedRefundAssets[0] = TrackedAsset({
            encodedAsset: AssetUtils.encodeAsset(
                AssetType.ERC20,
                address(wsteth),
                ERC20_ID
            ),
            minRefundValue: wstethExpectedOutAmount
        });

        // Format actions
        Action[] memory actions = new Action[](2);
        actions[0] = Action({
            contractAddress: address(weth),
            encodedFunction: abi.encodeWithSelector(
                weth.approve.selector,
                address(wstethAdapter),
                wethInAmount
            )
        });

        address[] memory outputTokens = new address[](1);
        outputTokens[0] = address(wsteth);
        actions[1] = Action({
            contractAddress: address(wstethAdapter),
            encodedFunction: abi.encodeWithSelector(
                wstethAdapter.deposit.selector,
                wethInAmount
            )
        });

        // Create operation to deposit weth to wsteth
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
                executionGasLimit: 200_000,
                gasPrice: 0,
                actions: actions,
                atomicActions: true,
                operationFailureType: OperationFailureType.NONE
            })
        );

        // Check pre op balances
        assertEq(weth.balanceOf(address(teller)), wethInAmount);
        assertEq(wsteth.balanceOf(address(teller)), 0);

        // Execute operation
        vm.prank(BUNDLER, BUNDLER);
        teller.processBundle(bundle);

        // Check post op balances
        assertEq(weth.balanceOf(address(teller)), 0);
        assertEq(wsteth.balanceOf(address(teller)), wstethExpectedOutAmount);
    }

    function testWstethMultiDeposit(
        uint256 wethInAmount,
        uint256 numDeposits
    ) public {
        numDeposits = bound(numDeposits, 1, 10);
        wethInAmount = bound(wethInAmount, 1000, 10000 ether);

        // Adjust weth in amount to be divisible by num deposits
        if (wethInAmount % numDeposits != 0) {
            wethInAmount = wethInAmount - (wethInAmount % numDeposits);
        }
        reserveAndDeposit(address(weth), wethInAmount);

        // TODO: 1% buffer, figure out where actual exchange rate comes from that's used in UI (doesn't match getRethValue)
        uint256 wstethExpectedOutAmount = (wsteth.getWstETHByStETH(
            wethInAmount
        ) * 99) / 100;

        console.log("wstethExpectedOutAmount:", wstethExpectedOutAmount);

        // Format weth as refund asset
        TrackedAsset[] memory trackedRefundAssets = new TrackedAsset[](1);
        trackedRefundAssets[0] = TrackedAsset({
            encodedAsset: AssetUtils.encodeAsset(
                AssetType.ERC20,
                address(wsteth),
                ERC20_ID
            ),
            minRefundValue: wstethExpectedOutAmount
        });

        // Format actions
        Action[] memory actions = new Action[](1 + numDeposits);
        actions[0] = Action({
            contractAddress: address(weth),
            encodedFunction: abi.encodeWithSelector(
                weth.approve.selector,
                address(wstethAdapter),
                wethInAmount
            )
        });

        // Create multiple weth -> wsteth deposits
        for (uint256 i = 1; i <= numDeposits; i++) {
            actions[i] = Action({
                contractAddress: address(wstethAdapter),
                encodedFunction: abi.encodeWithSelector(
                    wstethAdapter.deposit.selector,
                    wethInAmount / numDeposits
                )
            });
        }

        // Create operation to deposit weth for wsteth
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
        assertEq(wsteth.balanceOf(address(teller)), 0);

        // Execute operation
        vm.prank(BUNDLER, BUNDLER);
        teller.processBundle(bundle);

        // Check post op balances
        assertEq(weth.balanceOf(address(teller)), 0);
        assertGe(wsteth.balanceOf(address(teller)), wstethExpectedOutAmount);
    }
}

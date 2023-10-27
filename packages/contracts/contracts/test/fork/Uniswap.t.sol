// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {ForkBase} from "./ForkBase.sol";
import {IWeth} from "../../interfaces/IWeth.sol";
import {IWsteth} from "../../interfaces/IWsteth.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UniswapV3Adapter} from "../../adapters/UniswapV3Adapter.sol";
import "../../libs/Types.sol";
import "../../libs/AssetUtils.sol";
import "../utils/NocturneUtils.sol";
import "../interfaces/IUniswapV3.sol";

contract UniswapTest is ForkBase {
    IWeth public constant weth =
        IWeth(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IWsteth public constant wsteth =
        IWsteth(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

    IUniswapV3 public constant uniswap =
        IUniswapV3(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    UniswapV3Adapter uniswapAdapter;

    function setUp() public {
        baseSetUp();

        // Deploy uniswap adapter
        uniswapAdapter = new UniswapV3Adapter(address(uniswap));
        uniswapAdapter.setTokenPermission(address(weth), true);
        uniswapAdapter.setTokenPermission(address(wsteth), true);

        // Whitelist bundler
        teller.setBundlerPermission(BUNDLER, true);

        // Whitelist weth, wsteth, wsteth adapter, and uniswap
        handler.setContractPermission(address(weth), true);
        handler.setContractPermission(address(wsteth), true);
        handler.setContractPermission(address(uniswapAdapter), true);

        // Whitelist weth approve, wsteth approve, wsteth adapter deposit, and uniswap input swaps
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
            address(uniswapAdapter),
            uniswapAdapter.exactInputSingle.selector,
            true
        );
        handler.setContractMethodPermission(
            address(uniswapAdapter),
            uniswapAdapter.exactInput.selector,
            true
        );

        // Prefill tokens
        deal(address(weth), address(handler), 1);
        deal(address(wsteth), address(handler), 1);
    }

    function testUniswapSwapSingle(uint256 wstethInAmount) public {
        // Hardcode upper bound to ~$5.1M swap
        wstethInAmount = bound(wstethInAmount, 10000, 3000 ether);
        reserveAndDeposit(address(wsteth), wstethInAmount);

        // Get expected weth out amount, 5% slippage tolerance
        uint256 wethExpectedOutAmount = (wsteth.getStETHByWstETH(
            wstethInAmount
        ) * 95) / 100;

        // Format weth as refund asset
        TrackedAsset[] memory trackedRefundAssets = new TrackedAsset[](1);
        trackedRefundAssets[0] = TrackedAsset({
            encodedAsset: AssetUtils.encodeAsset(
                AssetType.ERC20,
                address(weth),
                ERC20_ID
            ),
            minRefundValue: wethExpectedOutAmount
        });

        // Format swap data
        ExactInputSingleParams
            memory exactInputParams = ExactInputSingleParams({
                tokenIn: address(wsteth),
                tokenOut: address(weth),
                fee: 100,
                recipient: address(handler),
                deadline: block.timestamp + 3600,
                amountIn: wstethInAmount,
                amountOutMinimum: wethExpectedOutAmount,
                sqrtPriceLimitX96: 0
            });

        // Format approve and swap call in actions
        Action[] memory actions = new Action[](2);
        actions[0] = Action({
            contractAddress: address(wsteth),
            encodedFunction: abi.encodeWithSelector(
                wsteth.approve.selector,
                address(uniswapAdapter),
                wstethInAmount
            )
        });
        actions[1] = Action({
            contractAddress: address(uniswapAdapter),
            encodedFunction: abi.encodeWithSelector(
                uniswapAdapter.exactInputSingle.selector,
                exactInputParams
            )
        });

        // Create operation for swap
        Bundle memory bundle = Bundle({operations: new Operation[](1)});
        bundle.operations[0] = NocturneUtils.formatOperation(
            FormatOperationArgs({
                joinSplitTokens: NocturneUtils._joinSplitTokensArrayOfOneToken(
                    address(wsteth)
                ),
                joinSplitRefundValues: new uint256[](1),
                gasToken: address(wsteth),
                root: handler.root(),
                joinSplitsPublicSpends: NocturneUtils
                    ._publicSpendsArrayOfOnePublicSpendArray(
                        NocturneUtils.fillJoinSplitPublicSpends(
                            wstethInAmount,
                            1
                        )
                    ),
                trackedRefundAssets: trackedRefundAssets,
                gasAssetRefundThreshold: 0,
                executionGasLimit: 10_000_000,
                gasPrice: 0,
                actions: actions,
                atomicActions: true,
                operationFailureType: OperationFailureType.NONE
            })
        );

        // Check pre op balances
        assertEq(wsteth.balanceOf(address(teller)), wstethInAmount);
        assertEq(weth.balanceOf(address(teller)), 0);

        // Execute operation
        vm.prank(BUNDLER, BUNDLER);
        teller.processBundle(bundle);

        // Check post op balances
        assertEq(wsteth.balanceOf(address(teller)), 0);
        assertGe(weth.balanceOf(address(teller)), wethExpectedOutAmount);
    }

    function testUniswapSwapMultihop(uint256 wstethInAmount) public {
        // Hardcode upper bound to ~$5.1M swap
        wstethInAmount = bound(wstethInAmount, 10000, 3000 ether);
        reserveAndDeposit(address(wsteth), wstethInAmount);

        // Get expected weth out amount, 5% slippage tolerance
        uint256 wethExpectedOutAmount = (wsteth.getStETHByWstETH(
            wstethInAmount
        ) * 95) / 100;

        // Format weth as refund asset
        TrackedAsset[] memory trackedRefundAssets = new TrackedAsset[](1);
        trackedRefundAssets[0] = TrackedAsset({
            encodedAsset: AssetUtils.encodeAsset(
                AssetType.ERC20,
                address(weth),
                ERC20_ID
            ),
            minRefundValue: wethExpectedOutAmount
        });

        // Format swap data
        // Instructions on formatting inputs: https://docs.uniswap.org/contracts/v3/guides/swaps/multihop-swaps
        ExactInputParams memory exactInputParams = ExactInputParams({
            path: abi.encodePacked(
                address(wsteth),
                uint24(100), // 0.01% pool fee
                address(weth)
            ),
            recipient: address(handler),
            deadline: block.timestamp + 3600,
            amountIn: wstethInAmount,
            amountOutMinimum: wethExpectedOutAmount
        });

        // Format approve and swap call in actions
        Action[] memory actions = new Action[](2);
        actions[0] = Action({
            contractAddress: address(wsteth),
            encodedFunction: abi.encodeWithSelector(
                wsteth.approve.selector,
                address(uniswapAdapter),
                wstethInAmount
            )
        });
        actions[1] = Action({
            contractAddress: address(uniswapAdapter),
            encodedFunction: abi.encodeWithSelector(
                uniswapAdapter.exactInput.selector,
                exactInputParams
            )
        });

        // Create operation for swap
        Bundle memory bundle = Bundle({operations: new Operation[](1)});
        bundle.operations[0] = NocturneUtils.formatOperation(
            FormatOperationArgs({
                joinSplitTokens: NocturneUtils._joinSplitTokensArrayOfOneToken(
                    address(wsteth)
                ),
                joinSplitRefundValues: new uint256[](1),
                gasToken: address(wsteth),
                root: handler.root(),
                joinSplitsPublicSpends: NocturneUtils
                    ._publicSpendsArrayOfOnePublicSpendArray(
                        NocturneUtils.fillJoinSplitPublicSpends(
                            wstethInAmount,
                            1
                        )
                    ),
                trackedRefundAssets: trackedRefundAssets,
                gasAssetRefundThreshold: 0,
                executionGasLimit: 1_000_000,
                gasPrice: 0,
                actions: actions,
                atomicActions: true,
                operationFailureType: OperationFailureType.NONE
            })
        );

        // Check pre op balances
        assertEq(wsteth.balanceOf(address(teller)), wstethInAmount);
        assertEq(weth.balanceOf(address(teller)), 0);

        // Execute operation
        vm.prank(BUNDLER, BUNDLER);
        teller.processBundle(bundle);

        // Check post op balances
        assertEq(wsteth.balanceOf(address(teller)), 0);
        assertGe(weth.balanceOf(address(teller)), wethExpectedOutAmount);
    }
}

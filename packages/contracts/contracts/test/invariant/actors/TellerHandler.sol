// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console} from "forge-std/console.sol";

import {TokenSwapper, SwapRequest} from "../../utils/TokenSwapper.sol";
import {TreeTest, TreeTestLib} from "../../utils/TreeTest.sol";
import {TestBalanceManager} from "../../harnesses/TestBalanceManager.sol";
import "../../utils/NocturneUtils.sol";
import {Teller} from "../../../Teller.sol";
import {Handler} from "../../../Handler.sol";
import {ParseUtils} from "../../utils/ParseUtils.sol";
import {EventParsing} from "../../utils/EventParsing.sol";
import {WETH9} from "../../tokens/WETH9.sol";
import {SimpleERC20Token} from "../../tokens/SimpleERC20Token.sol";
import {OperationGenerator, GenerateOperationArgs, GeneratedOperationMetadata, EthTransferRequest} from "../helpers/OperationGenerator.sol";
import {TokenIdSet, LibTokenIdSet} from "../helpers/TokenIdSet.sol";
import {Utils} from "../../../libs/Utils.sol";
import {AssetUtils} from "../../../libs/AssetUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../libs/Types.sol";

contract TellerHandler is OperationGenerator {
    using LibTokenIdSet for TokenIdSet;
    using OperationLib for Operation;

    // ______PUBLIC______
    Teller public teller;
    Handler public handler;
    TokenSwapper public swapper;

    address public bundlerAddress;

    // First token is always weth (also the gas token)
    address[] public joinSplitTokens;

    SimpleERC20Token public swapErc20;

    bytes32 public lastCall;
    uint256 public ghost_totalBundlerPayout;
    uint256[] public ghost_totalJoinSplitUnwrappedForToken;
    uint256[] public ghost_numberOfTimesPrefillTakenForToken;
    uint256[] public ghost_numberOfTimesPrefillRefilledForToken;

    // ______INTERNAL______
    mapping(bytes32 => uint256) internal _calls;
    uint256 internal _numSuccessfulActions;
    string[] internal _failureReasons;
    TestBalanceManager internal _testBalanceManager;

    EthTransferRequest[] internal _successfulEthTransfers;
    Erc20TransferRequest[] internal _successfulTransfers;
    SwapRequest[] internal _successfulSwaps;

    constructor(
        Teller _teller,
        Handler _handler,
        TokenSwapper _swapper,
        address[] memory _joinSplitTokens,
        SimpleERC20Token _swapErc20,
        address _bundlerAddress,
        address _transferRecipientAddress,
        address _weth,
        address payable _ethTransferAdapter
    )
        OperationGenerator(
            _transferRecipientAddress,
            _weth,
            _ethTransferAdapter
        )
    {
        teller = _teller;
        handler = _handler;
        swapper = _swapper;
        joinSplitTokens = _joinSplitTokens;
        swapErc20 = _swapErc20;
        bundlerAddress = _bundlerAddress;

        // dummy, only for pure fns that only work for calldata
        _testBalanceManager = new TestBalanceManager();

        for (uint256 i = 0; i < joinSplitTokens.length; i++) {
            ghost_totalJoinSplitUnwrappedForToken.push(0);
            ghost_numberOfTimesPrefillTakenForToken.push(0);
            ghost_numberOfTimesPrefillRefilledForToken.push(0);
        }
    }

    // ______EXTERNAL______
    function callSummary() external view {
        console.log("-------------------");
        console.log("TellerHandler call summary:");
        console.log("-------------------");
        console.log("Successful actions", _numSuccessfulActions);
        console.log(
            "Bundler gas token balance",
            IERC20(joinSplitTokens[0]).balanceOf(bundlerAddress)
        );

        for (uint256 i = 0; i < joinSplitTokens.length; i++) {
            console.log(
                "JoinSplit token balance in Handler",
                IERC20(joinSplitTokens[i]).balanceOf(address(handler))
            );
        }

        console.log("swap erc20 received:", ghost_totalSwapErc20Received());

        console.log("Failure reasons:");
        for (uint256 i = 0; i < _failureReasons.length; i++) {
            console.log(_failureReasons[i]);
        }
        console.log("Metadata:");
        for (uint256 i = 0; i < _successfulTransfers.length; i++) {
            console.log(
                "Erc20 transfer amount",
                _successfulTransfers[i].amount,
                ". Token:",
                _successfulTransfers[i].token
            );
        }
        for (uint256 i = 0; i < _successfulEthTransfers.length; i++) {
            console.log(
                "Eth transfer amount",
                _successfulEthTransfers[i].amount
            );
        }
        for (uint256 i = 0; i < _successfulSwaps.length; i++) {
            (, address token, ) = AssetUtils.decodeAsset(
                _successfulSwaps[i].encodedAssetIn
            );
            console.log(
                "Swap in amount",
                _successfulSwaps[i].assetInAmount,
                ". Token in:",
                token
            );
        }
    }

    function processBundle(uint256 seed) external {
        // Ensure swap erc20 always filled so we don't have to bother with prefill logic
        // TODO: remove and allow when we allow teller to transact with swap erc20
        if (swapErc20.balanceOf(address(handler)) == 0) {
            deal(address(swapErc20), address(this), 1);
            swapErc20.transfer(address(handler), 1);
        }

        uint256 _numJoinSplitTokens = numJoinSplitTokens();
        bool[] memory prefillExistsForToken = new bool[](_numJoinSplitTokens);
        for (uint256 i = 0; i < _numJoinSplitTokens; i++) {
            prefillExistsForToken[i] =
                IERC20(joinSplitTokens[i]).balanceOf(address(handler)) > 0;
        }

        (
            Operation memory op,
            GeneratedOperationMetadata memory meta
        ) = _generateRandomOperation(
                GenerateOperationArgs({
                    seed: seed,
                    teller: teller,
                    handler: address(handler),
                    root: handler.root(),
                    exceedJoinSplitsMarginInTokens: 1,
                    swapper: swapper,
                    joinSplitTokens: joinSplitTokens,
                    swapErc20: swapErc20
                })
            );

        Bundle memory bundle;
        bundle.operations = new Operation[](1);
        bundle.operations[0] = op;

        vm.prank(bundlerAddress, bundlerAddress);
        (, OperationResult[] memory opResults) = teller.processBundle(bundle);

        // TODO: enable multiple ops in bundle
        OperationResult memory opResult = opResults[0];

        if (opResult.assetsUnwrapped) {
            uint256 bundlerPayout = _calculateBundlerGasAssetPayout(
                op,
                opResult
            );
            ghost_totalBundlerPayout += bundlerPayout;
        }

        console.log("pushing failure reason");
        if (bytes(opResult.failureReason).length > 0) {
            _failureReasons.push(opResult.failureReason);
        }

        for (uint256 i = 0; i < opResult.callSuccesses.length; i++) {
            if (opResult.callSuccesses[i]) {
                if (meta.isErc20Transfer[i]) {
                    _successfulTransfers.push(meta.transfers[i]);
                } else if (meta.isEthTransfer[i]) {
                    _successfulEthTransfers.push(meta.ethTransfers[i]);
                } else if (meta.isSwap[i]) {
                    _successfulSwaps.push(meta.swaps[i]);
                }
                _numSuccessfulActions += 1;
            }
        }

        for (uint256 i = 0; i < joinSplitTokens.length; i++) {
            ghost_totalJoinSplitUnwrappedForToken[
                i
            ] += _totalJoinSplitTokenAmountInOp(op, i);
        }

        for (uint256 i = 0; i < joinSplitTokens.length; i++) {
            if (
                prefillExistsForToken[i] &&
                IERC20(joinSplitTokens[i]).balanceOf(address(handler)) == 0
            ) {
                ghost_numberOfTimesPrefillTakenForToken[i] += 1;
            } else if (
                !prefillExistsForToken[i] &&
                IERC20(joinSplitTokens[i]).balanceOf(address(handler)) > 0
            ) {
                ghost_numberOfTimesPrefillRefilledForToken[i] += 1;
            }
        }
    }

    // ______VIEW______
    function numJoinSplitTokens() public view returns (uint256) {
        return joinSplitTokens.length;
    }

    function ghost_totalTransferredOutOfTellerForToken(
        uint256 tokenIndex
    ) public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < _successfulTransfers.length; i++) {
            if (
                address(_successfulTransfers[i].token) ==
                address(joinSplitTokens[tokenIndex])
            ) {
                total += _successfulTransfers[i].amount;
            }
        }
        for (uint256 i = 0; i < _successfulSwaps.length; i++) {
            (, address tokenAddr, ) = AssetUtils.decodeAsset(
                _successfulSwaps[i].encodedAssetIn
            );
            if (tokenAddr == address(joinSplitTokens[tokenIndex])) {
                total += _successfulSwaps[i].assetInAmount;
            }
        }
        return total;
    }

    function ghost_totalEthTransferredOutOfTeller()
        public
        view
        returns (uint256)
    {
        uint256 total = 0;
        for (uint256 i = 0; i < _successfulEthTransfers.length; i++) {
            total += _successfulEthTransfers[i].amount;
        }

        return total;
    }

    function ghost_totalSwapErc20Received() public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < _successfulSwaps.length; i++) {
            total += _successfulSwaps[i].erc20OutAmount;
        }
        return total;
    }

    // ______UTILS______
    // Workaround for OperationUtils version not including gasAssetRefundThreshold logic
    function _calculateBundlerGasAssetPayout(
        Operation memory op,
        OperationResult memory opResult
    ) internal view returns (uint256) {
        uint256 payout = _testBalanceManager.calculateBundlerGasAssetPayout(
            op,
            opResult
        );

        uint256 maxGasAssetCost = _testBalanceManager
            .calculateOpMaxGasAssetCost(
                op,
                opResult.verificationGas /
                    (op.pubJoinSplits.length + op.confJoinSplits.length)
            );
        if (maxGasAssetCost - payout < op.gasAssetRefundThreshold) {
            payout = maxGasAssetCost;
        }

        return payout;
    }

    function _totalJoinSplitTokenAmountInOp(
        Operation memory op,
        uint256 tokenIndex
    ) internal view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < op.pubJoinSplits.length; i++) {
            EncodedAsset memory encodedAsset = op
                .trackedAssets[op.pubJoinSplits[i].assetIndex]
                .encodedAsset;
            (, address assetAddr, ) = AssetUtils.decodeAsset(encodedAsset);
            if (assetAddr == joinSplitTokens[tokenIndex]) {
                total += op.pubJoinSplits[i].publicSpend;
            }
        }

        return total;
    }
}

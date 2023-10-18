// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console} from "forge-std/console.sol";

import {TokenSwapper, SwapRequest} from "../../utils/TokenSwapper.sol";
import {TreeTest, TreeTestLib} from "../../utils/TreeTest.sol";
import "../../utils/NocturneUtils.sol";
import {Teller} from "../../../Teller.sol";
import {Handler} from "../../../Handler.sol";
import {ParseUtils} from "../../utils/ParseUtils.sol";
import {EventParsing} from "../../utils/EventParsing.sol";
import {WETH9} from "../../tokens/WETH9.sol";
import {SimpleERC20Token} from "../../tokens/SimpleERC20Token.sol";
import {OperationGenerator, GenerateOperationArgs, GeneratedOperationMetadata} from "../helpers/OperationGenerator.sol";
import {TokenIdSet, LibTokenIdSet} from "../helpers/TokenIdSet.sol";
import {Utils} from "../../../libs/Utils.sol";
import {AssetUtils} from "../../../libs/AssetUtils.sol";
import {TreeUtils} from "../../../libs/TreeUtils.sol";
import "../../../libs/Types.sol";

contract HandlerHandler is CommonBase, StdCheats, StdUtils {
    using LibTokenIdSet for TokenIdSet;

    address constant OWNER = address(0x1);

    Handler public handler;
    address subtreeBatchFiller;

    SimpleERC20Token public depositErc20;

    // ______PUBLIC______
    bytes32 public lastCall;

    // ______INTERNAL______
    mapping(bytes32 => uint256) internal _calls;

    constructor(
        Handler _handler,
        address _subtreeBatchFiller,
        SimpleERC20Token _depositErc20
    ) {
        handler = _handler;
        subtreeBatchFiller = _subtreeBatchFiller;
        depositErc20 = _depositErc20;
    }

    modifier trackCall(bytes32 key) {
        lastCall = key;
        _;
        _calls[lastCall]++;
    }

    function callSummary() external view {
        console.log("-------------------");
        console.log("HandlerHandler call summary:");
        console.log("-------------------");
        console.log("fillBatchWithZeros", _calls["fillBatchWithZeros"]);
        console.log("no-op", _calls["no-op"]);
    }

    // ______EXTERNAL______
    function fillBatchWithZeros() external trackCall("fillBatchWithZeros") {
        if (handler.totalCount() % TreeUtils.BATCH_SIZE != 0) {
            vm.prank(subtreeBatchFiller);
            handler.fillBatchWithZeros();
        } else {
            lastCall = "no-op";
        }
    }
}

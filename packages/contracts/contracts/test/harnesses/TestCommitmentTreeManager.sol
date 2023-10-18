// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "../../libs/Types.sol";
import {CommitmentTreeManager} from "../../CommitmentTreeManager.sol";
import {QueueLib} from "../../libs/Queue.sol";

contract TestCommitmentTreeManager is CommitmentTreeManager {
    using QueueLib for QueueLib.Queue;

    function initialize(address subtreeUpdateVerifier) external initializer {
        __CommitmentTreeManager_init(subtreeUpdateVerifier);
    }

    function handleJoinSplits(Operation calldata op) external {
        _handleJoinSplits(op);
    }

    function handleRefundNote(
        EncodedAsset memory encodedAsset,
        CompressedStealthAddress calldata refundAddr,
        uint256 value
    ) external {
        _handleRefundNote(encodedAsset, refundAddr, value);
    }

    function insertNoteCommitments(uint256[] memory ncs) external {
        _insertNoteCommitments(ncs);
    }

    function insertNote(EncodedNote memory note) external {
        _insertNote(note);
    }

    function currentBatchLen() external view returns (uint256) {
        return _merkle.batchLenPlusOne - 1;
    }

    function accumulatorQueueLen() external view returns (uint256) {
        return _merkle.accumulatorQueue.length();
    }
}

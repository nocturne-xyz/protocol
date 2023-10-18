// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {console} from "forge-std/console.sol";

import {CommitmentTreeManagerHandler} from "./actors/CommitmentTreeManagerHandler.sol";
import {TestCommitmentTreeManager} from "../harnesses/TestCommitmentTreeManager.sol";
import {TestSubtreeUpdateVerifier} from "../harnesses/TestSubtreeUpdateVerifier.sol";
import {TreeUtils} from "../../libs/TreeUtils.sol";
import "../../libs/Types.sol";

contract CommitmentTreeManagerInvariants is Test {
    address constant SUBTREE_BATCH_FILLER = address(0x1);

    CommitmentTreeManagerHandler public commitmentTreeManagerHandler;

    function setUp() public virtual {
        TestSubtreeUpdateVerifier subtreeUpdateVerifier = new TestSubtreeUpdateVerifier();
        TestCommitmentTreeManager commitmentTreeManager = new TestCommitmentTreeManager();
        commitmentTreeManager.initialize(address(subtreeUpdateVerifier));
        commitmentTreeManager.setSubtreeBatchFillerPermission(
            SUBTREE_BATCH_FILLER,
            true
        );

        commitmentTreeManagerHandler = new CommitmentTreeManagerHandler(
            commitmentTreeManager,
            SUBTREE_BATCH_FILLER
        );

        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = commitmentTreeManagerHandler.applySubtreeUpdate.selector;
        selectors[1] = commitmentTreeManagerHandler.handleJoinSplits.selector;
        selectors[2] = commitmentTreeManagerHandler.handleRefundNote.selector;
        selectors[3] = commitmentTreeManagerHandler.fillBatchWithZeros.selector;
        selectors[4] = commitmentTreeManagerHandler.insertNote.selector;
        selectors[5] = commitmentTreeManagerHandler
            .insertNoteCommitments
            .selector;

        targetContract(address(commitmentTreeManagerHandler));
        targetSelector(
            FuzzSelector({
                addr: address(commitmentTreeManagerHandler),
                selectors: selectors
            })
        );
    }

    function invariant_callSummary() public view {
        commitmentTreeManagerHandler.callSummary();
    }

    function invariant_getTotalCountIsConsistent() external {
        assertEq(
            commitmentTreeManagerHandler.ghost_joinSplitLeafCount() +
                commitmentTreeManagerHandler.ghost_refundNotesLeafCount() +
                commitmentTreeManagerHandler
                    .ghostfillBatchWithZerosLeafCount() +
                commitmentTreeManagerHandler.ghost_insertNoteLeafCount() +
                commitmentTreeManagerHandler
                    .ghost_insertNoteCommitmentsLeafCount(),
            commitmentTreeManagerHandler.commitmentTreeManager().totalCount()
        );
    }

    function invariant_handledJoinSplitNullifiersMarkedTrue() external {
        if (commitmentTreeManagerHandler.lastCall() == "handleJoinSplits") {
            (
                ,
                uint256 nullifierA,
                uint256 nullifierB,
                ,
                ,
                ,
                ,
                ,

            ) = commitmentTreeManagerHandler.joinSplitFromLastCall();
            assertEq(
                commitmentTreeManagerHandler
                    .commitmentTreeManager()
                    ._nullifierSet(nullifierA),
                true
            );
            assertEq(
                commitmentTreeManagerHandler
                    .commitmentTreeManager()
                    ._nullifierSet(nullifierB),
                true
            );
        }
    }

    function invariant_totalCountIncreasesByExpected() external {
        if (commitmentTreeManagerHandler.lastCall() == "handleJoinSplits") {
            assertEq(
                commitmentTreeManagerHandler.preCallTotalCount() +
                    2 *
                    commitmentTreeManagerHandler.handleJoinSplitsLength(),
                commitmentTreeManagerHandler
                    .commitmentTreeManager()
                    .totalCount()
            );
        } else if (
            commitmentTreeManagerHandler.lastCall() == "handleRefundNote"
        ) {
            assertEq(
                commitmentTreeManagerHandler.preCallTotalCount() +
                    commitmentTreeManagerHandler.handleRefundNotesLength(),
                commitmentTreeManagerHandler
                    .commitmentTreeManager()
                    .totalCount()
            );
        } else if (
            commitmentTreeManagerHandler.lastCall() == "fillBatchWithZeros"
        ) {
            uint256 amountToFill = TreeUtils.BATCH_SIZE -
                (commitmentTreeManagerHandler.preCallTotalCount() %
                    TreeUtils.BATCH_SIZE);
            assertEq(
                commitmentTreeManagerHandler.preCallTotalCount() + amountToFill,
                commitmentTreeManagerHandler
                    .commitmentTreeManager()
                    .totalCount()
            );
        } else if (commitmentTreeManagerHandler.lastCall() == "insertNote") {
            assertEq(
                commitmentTreeManagerHandler.preCallTotalCount() +
                    commitmentTreeManagerHandler.insertNotesLength(),
                commitmentTreeManagerHandler
                    .commitmentTreeManager()
                    .totalCount()
            );
        } else if (
            commitmentTreeManagerHandler.lastCall() == "insertNoteCommitments"
        ) {
            assertEq(
                commitmentTreeManagerHandler.preCallTotalCount() +
                    commitmentTreeManagerHandler.insertNoteCommitmentsLength(),
                commitmentTreeManagerHandler
                    .commitmentTreeManager()
                    .totalCount()
            );
        } else {
            assertEq(
                commitmentTreeManagerHandler.preCallTotalCount(),
                commitmentTreeManagerHandler
                    .commitmentTreeManager()
                    .totalCount()
            );
        }
    }
}

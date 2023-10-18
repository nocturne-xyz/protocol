// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {console} from "forge-std/console.sol";

import {OffchainMerkleHandler} from "./actors/OffchainMerkleHandler.sol";
import {TreeUtils} from "../../libs/TreeUtils.sol";

contract OffchainMerkleInvariants is Test {
    OffchainMerkleHandler public offchainMerkleHandler;

    function setUp() public virtual {
        offchainMerkleHandler = new OffchainMerkleHandler();
        targetContract(address(offchainMerkleHandler));
    }

    function invariant_callSummary() public view {
        offchainMerkleHandler.callSummary();
    }

    function invariant_insertedNotesPlusInsertedNoteCommitmentsEqualsTotalCount()
        external
    {
        assertEq(
            offchainMerkleHandler.getCount(),
            offchainMerkleHandler.getTotalCount() -
                (offchainMerkleHandler.accumulatorQueueLength() *
                    TreeUtils.BATCH_SIZE) -
                offchainMerkleHandler.batchLen()
        );
    }

    function invariant_getCountAlwaysMultipleOfBatchSize() external {
        assertEq(offchainMerkleHandler.getCount() % TreeUtils.BATCH_SIZE, 0);
    }

    function invariantgetBatchLengthNotExceedingBatchSize() external {
        assertLt(offchainMerkleHandler.batchLen(), TreeUtils.BATCH_SIZE);
    }

    function invariant_rootUpdatedAfterSubtreeUpdate() external {
        if (offchainMerkleHandler.lastCall() == bytes32("applySubtreeUpdate")) {
            assert(
                offchainMerkleHandler.preCallRoot() !=
                    offchainMerkleHandler.root()
            );
        } else {
            assertEq(
                offchainMerkleHandler.preCallRoot(),
                offchainMerkleHandler.root()
            );
        }
    }

    // Because we update in increments of BATCH_SIZE, count % BATCH_SIZE should always = 0, thus
    // the bottom log2(BATCH_SIZE) bits of count should always be 0
    function invariant_bottomLog2BitsOfCountAlwaysZero() external {
        uint128 mask = uint128(TreeUtils.BATCH_SIZE - 1);
        assertEq(offchainMerkleHandler.getCount() & mask, 0);
    }
}

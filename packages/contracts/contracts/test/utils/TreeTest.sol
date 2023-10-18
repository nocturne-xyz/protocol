// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;
import {IPoseidonT3, IPoseidonT5, IPoseidonT6} from "../interfaces/IPoseidon.sol";
import {TreeUtils} from "../../libs/TreeUtils.sol";
import {AlgebraicUtils} from "./AlgebraicUtils.sol";
import "../../libs/Types.sol";
import "forge-std/Test.sol";

struct TreeTest {
    IPoseidonT5 poseidonT5;
    IPoseidonT6 poseidonT6;
}

library TreeTestLib {
    uint256 public constant EMPTY_SUBTREE_ROOT =
        6810774033780416412415162199345403563615586099663557224316660575326988281139;

    function initialize(
        TreeTest storage self,
        IPoseidonT5 _poseidonT5,
        IPoseidonT6 _poseidonT6
    ) internal {
        self.poseidonT5 = _poseidonT5;
        self.poseidonT6 = _poseidonT6;
    }

    function computeSubtreeRoot(
        TreeTest storage self,
        uint256[] memory batch
    ) internal view returns (uint256) {
        require(batch.length <= TreeUtils.BATCH_SIZE, "batch too large");
        uint256[] memory scratch = new uint256[](TreeUtils.BATCH_SIZE);
        for (uint256 i = 0; i < batch.length; i++) {
            scratch[i] = batch[i];
        }
        for (uint256 i = batch.length; i < TreeUtils.BATCH_SIZE; i++) {
            scratch[i] = TreeUtils.ZERO_VALUE;
        }

        for (
            int256 i = int256(TreeUtils.BATCH_SUBTREE_DEPTH - 1);
            i >= 0;
            i--
        ) {
            for (uint256 j = 0; j < 4 ** uint256(i); j++) {
                uint256 one = scratch[4 * j];
                uint256 two = scratch[4 * j + 1];
                uint256 three = scratch[4 * j + 2];
                uint256 four = scratch[4 * j + 3];
                scratch[j] = self.poseidonT5.poseidon([one, two, three, four]);
            }
        }

        return scratch[0];
    }

    // compute the new tree root after inserting a batch to an empty tree
    // returns `lastThreePaths` containing first subtree's path at index 0, 0s elsewhere
    function computeInitialPaths(
        TreeTest storage self,
        uint256[] memory batch
    ) internal view returns (uint256[][3] memory) {
        uint256 subtreeRoot = computeSubtreeRoot(self, batch);
        uint256 zero = EMPTY_SUBTREE_ROOT;

        uint256[][3] memory paths;
        paths[0] = new uint256[](
            TreeUtils.DEPTH - TreeUtils.BATCH_SUBTREE_DEPTH + 1
        );
        paths[1] = new uint256[](
            TreeUtils.DEPTH - TreeUtils.BATCH_SUBTREE_DEPTH + 1
        );
        paths[2] = new uint256[](
            TreeUtils.DEPTH - TreeUtils.BATCH_SUBTREE_DEPTH + 1
        );

        paths[0][0] = subtreeRoot;
        for (
            uint256 i = 0;
            i < TreeUtils.DEPTH - TreeUtils.BATCH_SUBTREE_DEPTH;
            i++
        ) {
            paths[0][i + 1] = self.poseidonT5.poseidon(
                [paths[0][i], zero, zero, zero]
            );
            zero = self.poseidonT5.poseidon([zero, zero, zero, zero]);
        }

        return paths;
    }

    // compute the new tree root after inserting a batch given the paths to the last three subtrees in order of ascending age
    // idx is the index of the leftmost leaf in the subtree
    // returns updated list of last four subtree paths
    function computeNewPaths(
        TreeTest storage self,
        uint256[] memory batch,
        uint256[][3] memory lastThreePaths,
        uint256 idx
    ) internal view returns (uint256[][3] memory) {
        uint256 subtreeRoot = computeSubtreeRoot(self, batch);
        uint256 subtreeIdx = idx >> (2 * TreeUtils.BATCH_SUBTREE_DEPTH);
        uint256 zero = EMPTY_SUBTREE_ROOT;

        uint256[][3] memory newPaths;
        newPaths[0] = new uint256[](
            TreeUtils.DEPTH - TreeUtils.BATCH_SUBTREE_DEPTH + 1
        );
        newPaths[1] = lastThreePaths[0];
        newPaths[2] = lastThreePaths[1];

        newPaths[0][0] = subtreeRoot;
        for (
            uint256 i = 0;
            i < TreeUtils.DEPTH - TreeUtils.BATCH_SUBTREE_DEPTH;
            i++
        ) {
            if (subtreeIdx & 3 == 0) {
                // first child
                newPaths[0][i + 1] = self.poseidonT5.poseidon(
                    [newPaths[0][i], zero, zero, zero]
                );
            } else if (subtreeIdx & 3 == 1) {
                // second child
                newPaths[0][i + 1] = self.poseidonT5.poseidon(
                    [lastThreePaths[0][i], newPaths[0][i], zero, zero]
                );
            } else if (subtreeIdx & 3 == 2) {
                // third child
                newPaths[0][i + 1] = self.poseidonT5.poseidon(
                    [
                        lastThreePaths[1][i],
                        lastThreePaths[0][i],
                        newPaths[0][i],
                        zero
                    ]
                );
            } else {
                // fourth child
                newPaths[0][i + 1] = self.poseidonT5.poseidon(
                    [
                        lastThreePaths[2][i],
                        lastThreePaths[1][i],
                        lastThreePaths[0][i],
                        newPaths[0][i]
                    ]
                );
            }

            zero = self.poseidonT5.poseidon([zero, zero, zero, zero]);
            subtreeIdx >>= 2;
        }

        return newPaths;
    }

    function computeNoteCommitment(
        TreeTest storage self,
        EncodedNote memory note
    ) internal view returns (uint256) {
        (uint256 h1X, uint256 h1Y) = AlgebraicUtils.decompressPoint(
            note.ownerH1
        );
        (uint256 h2X, uint256 h2Y) = AlgebraicUtils.decompressPoint(
            note.ownerH2
        );
        uint256 addrHash = self.poseidonT5.poseidon([h1X, h1Y, h2X, h2Y]);
        return
            self.poseidonT6.poseidon(
                [
                    addrHash,
                    note.nonce,
                    note.encodedAssetAddr,
                    note.encodedAssetId,
                    note.value
                ]
            );
    }
}

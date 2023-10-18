// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import {IPoseidonT3} from "../interfaces/IPoseidon.sol";

//TODO: test new functions added to ensure proper merkle roots are computed

// Each incremental tree has certain properties and data that will
// be used to add new leaves.
struct IncrementalTree {
    uint8 depth; // Depth of the tree (levels - 1).
    uint256 root; // Root hash of the tree.
    uint256 numberOfLeaves; // Number of leaves of the tree.
    IPoseidonT3 poseidonT3; // PoseidonT3 contract
    mapping(uint256 => uint256) zeroes; // Zero hashes used for empty nodes (level -> zero hash).
    // The nodes of the subtrees used in the last addition of a leaf (level -> [left node, right node]).
    mapping(uint256 => uint256[2]) lastSubtrees; // Caching these values is essential to efficient appends.
}

/// @title Incremental binary Merkle tree.
/// @dev The incremental tree allows to calculate the root hash each time a leaf is added, ensuring
/// the integrity of the tree.
library LibIncrementalTree {
    uint8 internal constant MAX_DEPTH = 32;
    uint256 internal constant BN254_SCALAR_FIELD_MODULUS =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    /// @dev Initializes a tree.
    /// @param self: Tree data.
    /// @param depth: Depth of the tree.
    /// @param zero: Zero value to be used.
    function initialize(
        IncrementalTree storage self,
        uint8 depth,
        uint256 zero,
        IPoseidonT3 poseidonT3
    ) internal {
        require(
            zero < BN254_SCALAR_FIELD_MODULUS,
            "Leaf must be < snark field"
        );
        require(
            depth > 0 && depth <= MAX_DEPTH,
            "Depth must be between 1 and 32"
        );

        self.depth = depth;
        self.poseidonT3 = poseidonT3;

        for (uint8 i = 0; i < depth; i++) {
            self.zeroes[i] = zero;
            zero = self.poseidonT3.poseidon([zero, zero]);
        }

        self.root = zero;
    }

    /// @dev Inserts a leaf in the tree.
    /// @param self: Tree data.
    /// @param leaf: Leaf to be inserted.
    function insert(IncrementalTree storage self, uint256 leaf) internal {
        require(
            leaf < BN254_SCALAR_FIELD_MODULUS,
            "Leaf must be < snark field"
        );
        require(
            self.numberOfLeaves < 2 ** self.depth,
            "BinaryTree: tree is full"
        );

        uint256 index = self.numberOfLeaves;
        uint256 hash = leaf;

        for (uint8 i = 0; i < self.depth; i++) {
            if (index % 2 == 0) {
                self.lastSubtrees[i] = [hash, self.zeroes[i]];
            } else {
                self.lastSubtrees[i][1] = hash;
            }

            hash = self.poseidonT3.poseidon(self.lastSubtrees[i]);
            index /= 2;
        }

        self.root = hash;
        self.numberOfLeaves += 1;
    }

    function insert2(
        IncrementalTree storage self,
        uint256[2] memory leaves
    ) internal {
        for (uint256 i = 0; i < 2; i++) {
            require(
                leaves[i] < BN254_SCALAR_FIELD_MODULUS,
                "Leaf must be < snark field"
            );
        }
        require(
            self.numberOfLeaves + 2 <= 2 ** self.depth,
            "BinaryTree: tree is full"
        );

        uint256 index = self.numberOfLeaves / 2;
        uint256 hash = self.poseidonT3.poseidon(leaves);

        for (uint8 i = 1; i < self.depth; i++) {
            if (index % 2 == 0) {
                self.lastSubtrees[i] = [hash, self.zeroes[i]];
            } else {
                self.lastSubtrees[i][1] = hash;
            }

            hash = self.poseidonT3.poseidon(self.lastSubtrees[i]);
            index /= 2;
        }

        self.root = hash;
        self.numberOfLeaves += 2;
    }

    function insert8(
        IncrementalTree storage self,
        uint256[8] memory leaves
    ) internal {
        for (uint256 i = 0; i < 8; i++) {
            require(
                leaves[i] < BN254_SCALAR_FIELD_MODULUS,
                "Leaf must be < snark field"
            );
        }
        require(
            self.numberOfLeaves + 8 <= 2 ** self.depth,
            "BinaryTree: tree is full"
        );

        uint256 index = self.numberOfLeaves / 8;

        uint256 hash = getRootFrom8(self, leaves);

        for (uint8 i = 2; i < self.depth; i++) {
            if (index % 2 == 0) {
                self.lastSubtrees[i] = [hash, self.zeroes[i]];
            } else {
                self.lastSubtrees[i][1] = hash;
            }

            hash = self.poseidonT3.poseidon(self.lastSubtrees[i]);
            index /= 2;
        }

        self.root = hash;
        self.numberOfLeaves += 8;
    }

    // TODO: make sure we can allow both insert16 and insert8, that self.lastSubtrees is properly set
    function insert16(
        IncrementalTree storage self,
        uint256[16] memory leaves
    ) internal {
        for (uint256 i = 0; i < 16; i++) {
            require(
                leaves[i] < BN254_SCALAR_FIELD_MODULUS,
                "Leaf must be < snark field"
            );
        }
        require(
            self.numberOfLeaves + 16 <= 2 ** self.depth,
            "BinaryTree: tree is full"
        );

        uint256 hash = getRootFrom16(self, leaves);
        uint256 index = self.numberOfLeaves / 16;

        for (uint8 i = 3; i < self.depth; i++) {
            if (index % 2 == 0) {
                self.lastSubtrees[i] = [hash, self.zeroes[i]];
            } else {
                self.lastSubtrees[i][1] = hash;
            }

            hash = self.poseidonT3.poseidon(self.lastSubtrees[i]);
            index /= 2;
        }

        self.root = hash;
        self.numberOfLeaves += 16;
    }

    function getRootFrom8(
        IncrementalTree storage self,
        uint256[8] memory leaves
    ) internal view returns (uint256) {
        uint256 leftHash = self.poseidonT3.poseidon(
            [
                self.poseidonT3.poseidon([leaves[0], leaves[1]]),
                self.poseidonT3.poseidon([leaves[2], leaves[3]])
            ]
        );

        uint256 rightHash = self.poseidonT3.poseidon(
            [
                self.poseidonT3.poseidon([leaves[4], leaves[5]]),
                self.poseidonT3.poseidon([leaves[6], leaves[7]])
            ]
        );

        return self.poseidonT3.poseidon([leftHash, rightHash]);
    }

    function getRootFrom16(
        IncrementalTree storage self,
        uint256[16] memory leaves
    ) internal view returns (uint256) {
        uint256[8] memory leftHalf;
        uint256[8] memory rightHalf;
        for (uint256 i = 0; i < 8; i++) {
            leftHalf[i] = leaves[i];
            rightHalf[i] = leaves[i * 2];
        }
        return
            self.poseidonT3.poseidon(
                [getRootFrom8(self, leftHalf), getRootFrom8(self, rightHalf)]
            );
    }
}

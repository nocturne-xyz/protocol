// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;
import {ITeller} from "../interfaces/ITeller.sol";
import "./Types.sol";

// helpers for converting to/from field elems, uint256s, and/or bytes, and hashing them
library TreeUtils {
    uint256 public constant DEPTH = 16;
    uint256 public constant BATCH_SIZE = 16;
    uint256 public constant BATCH_SUBTREE_DEPTH = 2;

    // uint256(keccak256("nocturne")) % BN254_SCALAR_FIELD_MODULUS
    uint256 public constant ZERO_VALUE =
        11826002903343228749062904299844230482823860030613873531382924534593825466831;
    uint256 public constant EMPTY_TREE_ROOT =
        14425423529089750832921210739722026857026797579827942712639385657619324990872;

    // packs a field element for the `encodedPathAndHash` input to the subtree update verifier
    // `subtreeIdx` is the index of the subtree's leftmost element in the tree
    // `accumulatorHashHi` is the top 3 bits of `accumulatorHash` gotten from `uint256ToFieldElemLimbs`
    function encodePathAndHash(
        uint128 subtreeIdx,
        uint256 accumulatorHashHi
    ) internal pure returns (uint256) {
        require(
            subtreeIdx % BATCH_SIZE == 0,
            "subtreeIdx not multiple of BATCH_SIZE"
        );

        // we shift by 2 * depth because the tree is quaternary
        uint256 encodedPathAndHash = uint256(subtreeIdx) >>
            (2 * BATCH_SUBTREE_DEPTH);
        encodedPathAndHash |=
            accumulatorHashHi <<
            (2 * (DEPTH - BATCH_SUBTREE_DEPTH));

        return encodedPathAndHash;
    }

    // hash array of uint256s as big-endian bytes with sha256
    function sha256U256ArrayBE(
        uint256[] memory elems
    ) internal pure returns (bytes32) {
        return sha256(abi.encodePacked(elems));
    }

    function sha256Note(
        EncodedNote memory note
    ) internal pure returns (uint256) {
        uint256[] memory elems = new uint256[](6);
        elems[0] = note.ownerH1;
        elems[1] = note.ownerH2;
        elems[2] = note.nonce;
        elems[3] = note.encodedAssetAddr;
        elems[4] = note.encodedAssetId;
        elems[5] = note.value;
        return uint256(sha256U256ArrayBE(elems));
    }

    // return uint256 as two limbs - one uint256 containing the 3 hi bits, the
    // other containing the lower 253 bits
    function uint256ToFieldElemLimbs(
        uint256 n
    ) internal pure returns (uint256, uint256) {
        return _splitUint256ToLimbs(n, 253);
    }

    // split a uint256 into 2 limbs, one containing the high (256 - lowerBits)
    // bits, the other containing the lower `lowerBits` bits
    function _splitUint256ToLimbs(
        uint256 n,
        uint256 lowerBits
    ) internal pure returns (uint256, uint256) {
        uint256 hi = n >> lowerBits;
        uint256 lo = n & ((1 << lowerBits) - 1);
        return (hi, lo);
    }
}

// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;
import {ITeller} from "../interfaces/ITeller.sol";
import {Groth16} from "../libs/Groth16.sol";
import {Pairing} from "../libs/Pairing.sol";
import "../libs/Types.sol";

// helpers for converting to/from field elems, uint256s, and/or bytes, and hashing them
library Utils {
    uint256 public constant BN254_SCALAR_FIELD_MODULUS =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    uint256 constant COMPRESSED_POINT_SIGN_MASK = 1 << 254;

    // takes a compressed point and extracts the sign bit and y coordinate
    // returns (sign, y)
    function decomposeCompressedPoint(
        uint256 compressedPoint
    ) internal pure returns (uint256 sign, uint256 y) {
        sign = (compressedPoint & COMPRESSED_POINT_SIGN_MASK) >> 254;
        y = compressedPoint & (COMPRESSED_POINT_SIGN_MASK - 1);
        return (sign, y);
    }

    // return the minimum of the two values
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a >= b) ? b : a;
    }

    function sum(uint256[] calldata arr) internal pure returns (uint256) {
        uint256 total = 0;
        uint256 arrLength = arr.length;
        for (uint256 i = 0; i < arrLength; i++) {
            total += arr[i];
        }
        return total;
    }
}

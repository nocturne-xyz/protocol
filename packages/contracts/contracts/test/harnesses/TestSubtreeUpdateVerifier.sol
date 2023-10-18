// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "../utils/Pairing.sol";
import {ISubtreeUpdateVerifier} from "../../interfaces/ISubtreeUpdateVerifier.sol";
import {Groth16} from "../../libs/Groth16.sol";

contract TestSubtreeUpdateVerifier is ISubtreeUpdateVerifier {
    function verifyProof(
        uint256[8] memory, // proof
        uint256[] memory // pis
    ) external pure override returns (bool) {
        return true;
    }

    function batchVerifyProofs(
        uint256[8][] memory, // proofs
        uint256[][] memory // pis
    ) external pure override returns (bool) {
        return true;
    }
}

// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.2;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import {JsonDecodings, CanonAddrSigCheckProofWithPublicSignals} from "../utils/JsonDecodings.sol";
import {ParseUtils} from "../utils/ParseUtils.sol";
import {CanonAddrSigCheckVerifier} from "../../CanonAddrSigCheckVerifier.sol";
import {ICanonAddrSigCheckVerifier} from "../../interfaces/ICanonAddrSigCheckVerifier.sol";
import {Utils} from "../../libs/Utils.sol";

contract TestCanonAddrSigCheckVerifier is Test, JsonDecodings {
    using stdJson for string;

    string constant FIXTURE_PATH = "/fixtures/canonAddrSigCheckProof.json";
    uint256 constant NUM_PIS = 2;

    ICanonAddrSigCheckVerifier canonAddrSigCheckVerifier;

    function setUp() public virtual {
        canonAddrSigCheckVerifier = ICanonAddrSigCheckVerifier(
            new CanonAddrSigCheckVerifier()
        );
    }

    function loadCanonAddrSigCheck(
        string memory path
    ) internal returns (uint256[8] memory proof, uint256[] memory pis) {
        CanonAddrSigCheckProofWithPublicSignals
            memory proofWithPIs = loadCanonAddrSigCheckFromFixture(path);
        proof = baseProofTo8(proofWithPIs.proof);
        pis = new uint256[](NUM_PIS);
        for (uint256 i = 0; i < NUM_PIS; i++) {
            pis[i] = proofWithPIs.publicSignals[i];
        }

        return (proof, pis);
    }

    function verifyFixture(string memory path) public {
        (uint256[8] memory proof, uint256[] memory pis) = loadCanonAddrSigCheck(
            path
        );

        require(
            canonAddrSigCheckVerifier.verifyProof(proof, pis),
            "Invalid proof"
        );
    }

    function batchVerifyFixture(string memory path, uint256 numProofs) public {
        uint256[8][] memory proofs = new uint256[8][](numProofs);
        uint256[][] memory pis = new uint256[][](numProofs);
        for (uint256 i = 0; i < numProofs; i++) {
            (proofs[i], pis[i]) = loadCanonAddrSigCheck(path);
        }

        require(
            canonAddrSigCheckVerifier.batchVerifyProofs(proofs, pis),
            "Invalid proof"
        );
    }

    function testBatchVerifySingle() public {
        (uint256[8] memory proof, uint256[] memory pis) = loadCanonAddrSigCheck(
            FIXTURE_PATH
        );
        uint256[8][] memory proofs = new uint256[8][](1);
        uint256[][] memory allPis = new uint256[][](1);

        proofs[0] = proof;
        allPis[0] = pis;

        require(
            canonAddrSigCheckVerifier.batchVerifyProofs(proofs, allPis),
            "Invalid proof"
        );
    }

    function testBasicVerify() public {
        verifyFixture(FIXTURE_PATH);
    }

    function testBatchVerify() public {
        batchVerifyFixture(FIXTURE_PATH, 8);
        batchVerifyFixture(FIXTURE_PATH, 16);
    }
}

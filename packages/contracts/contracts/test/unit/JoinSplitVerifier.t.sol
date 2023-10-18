// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.2;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import {JsonDecodings, JoinSplitProofWithPublicSignals} from "../utils/JsonDecodings.sol";
import {ParseUtils} from "../utils/ParseUtils.sol";
import {JoinSplitVerifier} from "../../JoinSplitVerifier.sol";
import {IJoinSplitVerifier} from "../../interfaces/IJoinSplitVerifier.sol";
import {Utils} from "../../libs/Utils.sol";

contract TestJoinSplitVerifier is Test, JsonDecodings {
    using stdJson for string;

    string constant FIXTURE_PATH_0_PUBLIC_SPEND =
        "/fixtures/joinsplit_0_publicSpend.json";
    string constant FIXTURE_PATH_100_PUBLIC_SPEND =
        "/fixtures/joinsplit_100_publicSpend.json";
    uint256 constant NUM_PIS = 13;

    IJoinSplitVerifier joinSplitVerifier;

    function setUp() public virtual {
        joinSplitVerifier = IJoinSplitVerifier(new JoinSplitVerifier());
    }

    function loadJoinSplitProof(
        string memory path
    ) internal returns (uint256[8] memory proof, uint256[] memory pis) {
        JoinSplitProofWithPublicSignals
            memory proofWithPIs = loadJoinSplitProofFromFixture(path);
        proof = baseProofTo8(proofWithPIs.proof);
        pis = new uint256[](NUM_PIS);
        for (uint256 i = 0; i < NUM_PIS; i++) {
            pis[i] = proofWithPIs.publicSignals[i];
        }

        return (proof, pis);
    }

    function verifyFixture(string memory path) public {
        (uint256[8] memory proof, uint256[] memory pis) = loadJoinSplitProof(
            path
        );

        require(joinSplitVerifier.verifyProof(proof, pis), "Invalid proof");
    }

    function batchVerifyFixture(string memory path, uint256 numProofs) public {
        uint256[8][] memory proofs = new uint256[8][](numProofs);
        uint256[][] memory pis = new uint256[][](numProofs);
        for (uint256 i = 0; i < numProofs; i++) {
            (proofs[i], pis[i]) = loadJoinSplitProof(path);
        }

        require(
            joinSplitVerifier.batchVerifyProofs(proofs, pis),
            "Invalid proof"
        );
    }

    function testBatchVerifySingle() public {
        (uint256[8] memory proof, uint256[] memory pis) = loadJoinSplitProof(
            FIXTURE_PATH_0_PUBLIC_SPEND
        );
        uint256[8][] memory proofs = new uint256[8][](1);
        uint256[][] memory allPis = new uint256[][](1);

        proofs[0] = proof;
        allPis[0] = pis;

        require(
            joinSplitVerifier.batchVerifyProofs(proofs, allPis),
            "Invalid proof"
        );
    }

    function testBasicVerify0PublicSpend() public {
        verifyFixture(FIXTURE_PATH_0_PUBLIC_SPEND);
    }

    function testBasicVerify100PublicSpend() public {
        verifyFixture(FIXTURE_PATH_100_PUBLIC_SPEND);
    }

    function testBatchVerify() public {
        batchVerifyFixture(FIXTURE_PATH_0_PUBLIC_SPEND, 8);
        batchVerifyFixture(FIXTURE_PATH_0_PUBLIC_SPEND, 16);
        batchVerifyFixture(FIXTURE_PATH_0_PUBLIC_SPEND, 32);
    }
}

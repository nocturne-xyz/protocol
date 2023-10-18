// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../../libs/Types.sol";
import {ParseUtils} from "./ParseUtils.sol";

struct JoinSplitProofWithPublicSignals {
    uint256[13] publicSignals;
    BaseProof proof;
}

struct SubtreeUpdateProofWithPublicSignals {
    uint256[4] publicSignals;
    BaseProof proof;
}

struct CanonAddrSigCheckProofWithPublicSignals {
    uint256[2] publicSignals;
    BaseProof proof;
}

struct SignedDepositRequestFixture {
    address contractAddress;
    string contractName;
    string contractVersion;
    uint256 chainId;
    address screenerAddress;
    DepositRequest depositRequest;
    bytes32 depositRequestHash;
    bytes signature;
}

struct BaseProof {
    string curve;
    string[] pi_a;
    string[][] pi_b;
    string[] pi_c;
    string protocol;
}

contract JsonDecodings is Test {
    using stdJson for string;

    struct SimpleDepositRequestFixtureTypes {
        address contractAddress;
        string contractName;
        string contractVersion;
        uint256 chainId;
        address screenerAddress;
        bytes32 depositRequestHash;
    }

    struct SimpleSignedDepositRequestTypes {
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 gasCompensation;
    }

    function loadFixtureJson(
        string memory path
    ) public returns (string memory) {
        string memory root = vm.projectRoot();
        return vm.readFile(string(abi.encodePacked(bytes(root), bytes(path))));
    }

    function baseProofTo8(
        BaseProof memory proof
    ) public returns (uint256[8] memory) {
        return [
            ParseUtils.parseInt(proof.pi_a[0]),
            ParseUtils.parseInt(proof.pi_a[1]),
            ParseUtils.parseInt(proof.pi_b[0][1]),
            ParseUtils.parseInt(proof.pi_b[0][0]),
            ParseUtils.parseInt(proof.pi_b[1][1]),
            ParseUtils.parseInt(proof.pi_b[1][0]),
            ParseUtils.parseInt(proof.pi_c[0]),
            ParseUtils.parseInt(proof.pi_c[1])
        ];
    }

    function loadSignedDepositRequestFixture(
        string memory path
    ) public returns (SignedDepositRequestFixture memory) {
        string memory json = loadFixtureJson(path);

        // NOTE: helper struct only used to reduce stack usage
        SimpleDepositRequestFixtureTypes
            memory simpleFixtureTypes = extractSimpleDepositRequestFixtureTypes(
                json
            );
        SimpleSignedDepositRequestTypes
            memory simpleDepositRequestTypes = extractSimpleSignedDepositRequestTypes(
                json
            );

        EncodedAsset memory encodedAsset = extractEncodedAsset(json);
        CompressedStealthAddress memory depositAddr = extractDepositAddr(json);
        bytes memory signature = extractSignature(json);

        return
            SignedDepositRequestFixture({
                contractAddress: simpleFixtureTypes.contractAddress,
                contractName: simpleFixtureTypes.contractName,
                contractVersion: simpleFixtureTypes.contractVersion,
                chainId: simpleFixtureTypes.chainId,
                screenerAddress: simpleFixtureTypes.screenerAddress,
                depositRequest: DepositRequest({
                    spender: simpleDepositRequestTypes.spender,
                    encodedAsset: encodedAsset,
                    value: simpleDepositRequestTypes.value,
                    depositAddr: depositAddr,
                    nonce: simpleDepositRequestTypes.nonce,
                    gasCompensation: simpleDepositRequestTypes.gasCompensation
                }),
                depositRequestHash: simpleFixtureTypes.depositRequestHash,
                signature: signature
            });
    }

    function extractSimpleDepositRequestFixtureTypes(
        string memory json
    ) public returns (SimpleDepositRequestFixtureTypes memory) {
        address contractAddress = json.readAddress(".contractAddress");
        string memory contractName = json.readString(".contractName");
        string memory contractVersion = json.readString(".contractVersion");
        uint256 chainId = ParseUtils.parseInt(json.readString(".chainId"));
        address screenerAddress = json.readAddress(".screenerAddress");
        bytes32 depositRequestHash = json.readBytes32(".depositRequestHash");

        return
            SimpleDepositRequestFixtureTypes({
                contractAddress: contractAddress,
                contractName: contractName,
                contractVersion: contractVersion,
                chainId: chainId,
                screenerAddress: screenerAddress,
                depositRequestHash: depositRequestHash
            });
    }

    function extractSimpleSignedDepositRequestTypes(
        string memory json
    ) public returns (SimpleSignedDepositRequestTypes memory) {
        address spender = json.readAddress(".depositRequest.spender");
        uint256 value = ParseUtils.parseInt(
            json.readString(".depositRequest.value")
        );
        uint256 nonce = ParseUtils.parseInt(
            json.readString(".depositRequest.nonce")
        );
        uint256 gasCompensation = ParseUtils.parseInt(
            json.readString(".depositRequest.gasCompensation")
        );

        return
            SimpleSignedDepositRequestTypes({
                spender: spender,
                value: value,
                nonce: nonce,
                gasCompensation: gasCompensation
            });
    }

    function extractEncodedAsset(
        string memory json
    ) public returns (EncodedAsset memory) {
        uint256 encodedAssetAddr = ParseUtils.parseInt(
            json.readString(".depositRequest.encodedAsset.encodedAssetAddr")
        );
        uint256 encodedAssetId = ParseUtils.parseInt(
            json.readString(".depositRequest.encodedAsset.encodedAssetId")
        );

        return
            EncodedAsset({
                encodedAssetAddr: encodedAssetAddr,
                encodedAssetId: encodedAssetId
            });
    }

    function extractDepositAddr(
        string memory json
    ) public returns (CompressedStealthAddress memory) {
        uint256 h1 = ParseUtils.parseInt(
            json.readString(".depositRequest.depositAddr.h1")
        );
        uint256 h2 = ParseUtils.parseInt(
            json.readString(".depositRequest.depositAddr.h2")
        );

        return CompressedStealthAddress({h1: h1, h2: h2});
    }

    // NOTE: we encode to rsv because foundry cannot parse 132 char byte string
    function extractSignature(
        string memory json
    ) public returns (bytes memory) {
        uint256 r = json.readUint(".signature.r");
        uint256 s = json.readUint(".signature.s");
        uint8 v = uint8(json.readUint(".signature.v"));
        bytes memory sig = ParseUtils.rsvToSignatureBytes(r, s, v);
        return sig;
    }

    function loadJoinSplitProofFromFixture(
        string memory path
    ) public returns (JoinSplitProofWithPublicSignals memory) {
        string memory json = loadFixtureJson(path);
        bytes memory proofBytes = json.parseRaw(".proof");
        BaseProof memory proof = abi.decode(proofBytes, (BaseProof));

        uint256[13] memory publicSignals;
        for (uint256 i = 0; i < 13; i++) {
            bytes memory jsonSelector = abi.encodePacked(
                bytes(".publicSignals["),
                Strings.toString(i)
            );
            jsonSelector = abi.encodePacked(jsonSelector, bytes("]"));

            bytes memory signalBytes = json.parseRaw(string(jsonSelector));
            string memory signal = abi.decode(signalBytes, (string));
            publicSignals[i] = ParseUtils.parseInt(signal);
        }

        return
            JoinSplitProofWithPublicSignals({
                publicSignals: publicSignals,
                proof: proof
            });
    }

    function loadSubtreeUpdateProofFromFixture(
        string memory path
    ) public returns (SubtreeUpdateProofWithPublicSignals memory) {
        string memory json = loadFixtureJson(path);
        bytes memory proofBytes = json.parseRaw(".proof");
        BaseProof memory proof = abi.decode(proofBytes, (BaseProof));

        uint256[4] memory publicSignals;
        for (uint256 i = 0; i < 4; i++) {
            bytes memory jsonSelector = abi.encodePacked(
                bytes(".publicSignals["),
                Strings.toString(i)
            );
            jsonSelector = abi.encodePacked(jsonSelector, bytes("]"));

            bytes memory signalBytes = json.parseRaw(string(jsonSelector));
            string memory signal = abi.decode(signalBytes, (string));
            publicSignals[i] = ParseUtils.parseInt(signal);
        }

        return
            SubtreeUpdateProofWithPublicSignals({
                publicSignals: publicSignals,
                proof: proof
            });
    }

    function loadCanonAddrSigCheckFromFixture(
        string memory path
    ) public returns (CanonAddrSigCheckProofWithPublicSignals memory) {
        string memory json = loadFixtureJson(path);
        bytes memory proofBytes = json.parseRaw(".proof");
        BaseProof memory proof = abi.decode(proofBytes, (BaseProof));

        uint256[2] memory publicSignals;
        for (uint256 i = 0; i < 2; i++) {
            bytes memory jsonSelector = abi.encodePacked(
                bytes(".publicSignals["),
                Strings.toString(i)
            );
            jsonSelector = abi.encodePacked(jsonSelector, bytes("]"));

            bytes memory signalBytes = json.parseRaw(string(jsonSelector));
            string memory signal = abi.decode(signalBytes, (string));
            publicSignals[i] = ParseUtils.parseInt(signal);
        }

        return
            CanonAddrSigCheckProofWithPublicSignals({
                publicSignals: publicSignals,
                proof: proof
            });
    }
}

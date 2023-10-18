// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "../../libs/Types.sol";
import {OperationEIP712} from "../../OperationEIP712.sol";

interface ITestOperationEIP712 {
    function computeDigest(
        Operation calldata op
    ) external view returns (uint256);

    function domainSeparatorV4() external view returns (bytes32);

    function nameHash() external view returns (bytes32);

    function versionHash() external view returns (bytes32);
}

contract TestOperationEIP712 is ITestOperationEIP712, OperationEIP712 {
    function initialize(
        string memory contractName,
        string memory contractVersion
    ) external initializer {
        __OperationEIP712_init(contractName, contractVersion);
    }

    function computeDigest(
        Operation calldata op
    ) external view override returns (uint256) {
        return _computeDigest(op);
    }

    function domainSeparatorV4() external view override returns (bytes32) {
        return _domainSeparatorV4();
    }

    function hashOperation(
        Operation calldata op
    ) public pure returns (bytes32) {
        return _hashOperation(op);
    }

    function hashPublicJoinSplits(
        PublicJoinSplit[] calldata publicJoinSplits
    ) public pure returns (bytes32) {
        return _hashPublicJoinSplits(publicJoinSplits);
    }

    function hashPublicJoinSplit(
        PublicJoinSplit calldata publicJoinSplit
    ) public pure returns (bytes32) {
        return _hashPublicJoinSplit(publicJoinSplit);
    }

    function hashJoinSplits(
        JoinSplit[] calldata joinSplits
    ) public pure returns (bytes32) {
        return _hashJoinSplits(joinSplits);
    }

    function hashJoinSplit(
        JoinSplit calldata joinSplit
    ) public pure returns (bytes32) {
        return _hashJoinSplit(joinSplit);
    }

    function hashActions(
        Action[] calldata actions
    ) public pure returns (bytes32) {
        return _hashActions(actions);
    }

    function hashAction(Action calldata action) public pure returns (bytes32) {
        return _hashAction(action);
    }

    function hashCompressedStealthAddress(
        CompressedStealthAddress calldata compressedStealthAddress
    ) public pure returns (bytes32) {
        return _hashCompressedStealthAddress(compressedStealthAddress);
    }

    function hashEncodedFunction(
        bytes calldata encodedFunction
    ) public pure returns (bytes32) {
        return keccak256(encodedFunction);
    }

    function hashTrackedAssets(
        TrackedAsset[] calldata trackedAssets
    ) public pure returns (bytes32) {
        return _hashTrackedAssets(trackedAssets);
    }

    function hashTrackedAsset(
        TrackedAsset calldata trackedAsset
    ) public pure returns (bytes32) {
        return _hashTrackedAsset(trackedAsset);
    }

    function hashEncodedAsset(
        EncodedAsset calldata encodedAsset
    ) public pure returns (bytes32) {
        return _hashEncodedAsset(encodedAsset);
    }

    function nameHash() public view returns (bytes32) {
        return _EIP712NameHash();
    }

    function versionHash() public view returns (bytes32) {
        return _EIP712VersionHash();
    }
}

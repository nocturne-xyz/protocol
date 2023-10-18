// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "../../libs/Types.sol";
import {CanonAddrRegistryEntryEIP712} from "../../CanonAddrRegistryEntryEIP712.sol";

interface ITestCanonAddrRegistryEntryEIP712 {
    function computeDigest(
        CanonAddrRegistryEntry calldata entry
    ) external view returns (uint256);

    function domainSeparatorV4() external view returns (bytes32);

    function nameHash() external view returns (bytes32);

    function versionHash() external view returns (bytes32);
}

contract TestCanonAddrRegistryEntryEIP712 is
    ITestCanonAddrRegistryEntryEIP712,
    CanonAddrRegistryEntryEIP712
{
    function initialize(
        string memory contractName,
        string memory contractVersion
    ) external initializer {
        __CanonAddrRegistryEntryEIP712_init(contractName, contractVersion);
    }

    function computeDigest(
        CanonAddrRegistryEntry calldata entry
    ) external view override returns (uint256) {
        return _computeDigest(entry);
    }

    function domainSeparatorV4() external view override returns (bytes32) {
        return _domainSeparatorV4();
    }

    function hashCanonAddrRegistryEntry(
        CanonAddrRegistryEntry calldata entry
    ) public pure returns (bytes32) {
        return _hashCanonAddrRegistryEntry(entry);
    }

    function nameHash() public view returns (bytes32) {
        return _EIP712NameHash();
    }

    function versionHash() public view returns (bytes32) {
        return _EIP712VersionHash();
    }
}

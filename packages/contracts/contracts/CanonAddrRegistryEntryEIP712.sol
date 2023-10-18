// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

// External
import {ECDSAUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
// Internal
import {Utils} from "./libs/Utils.sol";
import "./libs/Types.sol";

/// @title CanonAddrRegistryEntryEIP712
/// @author Nocturne Labs
/// @notice Base contract for CanonicalAddressRegistry containing EIP712 signing logic for canon
///         addr registry entries
contract CanonAddrRegistryEntryEIP712 is EIP712Upgradeable {
    uint256 constant BOTTOM_252_MASK = (1 << 252) - 1;

    bytes32 public constant CANON_ADDR_REGISTRY_ENTRY_TYPEHASH =
        keccak256(
            bytes(
                "CanonAddrRegistryEntry(address ethAddress,uint256 compressedCanonAddr,uint256 perCanonAddrNonce)"
            )
        );

    uint256 constant MODULUS_252 = 2 ** 252;

    /// @notice Internal initializer
    /// @param contractName Name of the contract
    /// @param contractVersion Version of the contract
    function __CanonAddrRegistryEntryEIP712_init(
        string memory contractName,
        string memory contractVersion
    ) internal onlyInitializing {
        __EIP712_init(contractName, contractVersion);
    }

    /// @notice Computes EIP712 digest of canon addr registry entry
    /// @param entry Canon addr registry entry
    /// @dev The returned uint256 is masked to zero out the top 4 MSBs. The top 3 MSBs
    ///      are 0 because the circuit verifier must take elems <= 253 bits. The 4th MSB is 0 to
    ///      leave space for the sign bit of the compressed canon addr.
    function _computeDigest(
        CanonAddrRegistryEntry memory entry
    ) public view returns (uint256) {
        bytes32 domainSeparator = _domainSeparatorV4();
        bytes32 structHash = _hashCanonAddrRegistryEntry(entry);

        bytes32 digest = ECDSAUpgradeable.toTypedDataHash(
            domainSeparator,
            structHash
        );

        // Only take bottom 252 bits to fit compressed addr sign bit in 253rd PI bit
        return uint256(digest) & BOTTOM_252_MASK;
    }

    /// @notice Hashes canon addr registry entry
    /// @param entry Canon addr registry entry
    function _hashCanonAddrRegistryEntry(
        CanonAddrRegistryEntry memory entry
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    CANON_ADDR_REGISTRY_ENTRY_TYPEHASH,
                    entry.ethAddress,
                    entry.compressedCanonAddr,
                    entry.perCanonAddrNonce
                )
            );
    }
}

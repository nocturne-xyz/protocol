// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

// External
import {ECDSAUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
// Internal
import "./libs/Types.sol";

/// @title DepositRequestEIP712
/// @author Nocturne Labs
/// @notice Base contract for DepositManager containing EIP712 signing logic for deposit requests
abstract contract DepositRequestEIP712 is EIP712Upgradeable {
    bytes32 public constant DEPOSIT_REQUEST_TYPEHASH =
        keccak256(
            bytes(
                // solhint-disable-next-line max-line-length
                "DepositRequest(address spender,EncodedAsset encodedAsset,uint256 value,CompressedStealthAddress depositAddr,uint256 nonce,uint256 gasCompensation)CompressedStealthAddress(uint256 h1,uint256 h2)EncodedAsset(uint256 encodedAssetAddr,uint256 encodedAssetId)"
            )
        );

    bytes32 public constant COMPRESSED_STEALTH_ADDRESS_TYPEHASH =
        keccak256(
            // solhint-disable-next-line max-line-length
            "CompressedStealthAddress(uint256 h1,uint256 h2)"
        );

    bytes32 public constant ENCODED_ASSET_TYPEHASH =
        keccak256(
            // solhint-disable-next-line max-line-length
            "EncodedAsset(uint256 encodedAssetAddr,uint256 encodedAssetId)"
        );

    /// @notice Internal initializer
    /// @param contractName Name of the contract
    /// @param contractVersion Version of the contract
    function __DepositRequestEIP712_init(
        string memory contractName,
        string memory contractVersion
    ) internal onlyInitializing {
        __EIP712_init(contractName, contractVersion);
    }

    /// @notice Recovers signer from signature on deposit request
    /// @param req Deposit request
    /// @param signature Signature on deposit request (hash)
    function _recoverDepositRequestSigner(
        DepositRequest calldata req,
        bytes calldata signature
    ) internal view returns (address) {
        bytes32 digest = _computeDigest(req);
        return ECDSAUpgradeable.recover(digest, signature);
    }

    /// @notice Computes EIP712 digest of deposit request
    /// @dev The inherited EIP712 domain separator includes block.chainid for replay protection.
    /// @param req Deposit request
    function _computeDigest(
        DepositRequest calldata req
    ) public view returns (bytes32) {
        bytes32 domainSeparator = _domainSeparatorV4();
        bytes32 structHash = _hashDepositRequest(req);

        return ECDSAUpgradeable.toTypedDataHash(domainSeparator, structHash);
    }

    /// @notice Hashes deposit request
    /// @param req Deposit request
    function _hashDepositRequest(
        DepositRequest memory req
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    DEPOSIT_REQUEST_TYPEHASH,
                    req.spender,
                    _hashEncodedAsset(req.encodedAsset),
                    req.value,
                    _hashCompressedStealthAddress(req.depositAddr),
                    req.nonce,
                    req.gasCompensation
                )
            );
    }

    /// @notice Hashes stealth address
    /// @param stealthAddress Compressed stealth address
    function _hashCompressedStealthAddress(
        CompressedStealthAddress memory stealthAddress
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    COMPRESSED_STEALTH_ADDRESS_TYPEHASH,
                    stealthAddress.h1,
                    stealthAddress.h2
                )
            );
    }

    /// @notice Hashes encoded asset
    /// @param encodedAsset Encoded asset
    function _hashEncodedAsset(
        EncodedAsset memory encodedAsset
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    ENCODED_ASSET_TYPEHASH,
                    encodedAsset.encodedAssetAddr,
                    encodedAsset.encodedAssetId
                )
            );
    }
}

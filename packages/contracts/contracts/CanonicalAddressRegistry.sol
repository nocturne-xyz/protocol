// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

// Internal
import {CanonAddrRegistryEntryEIP712} from "./CanonAddrRegistryEntryEIP712.sol";
import {ICanonAddrSigCheckVerifier} from "./interfaces/ICanonAddrSigCheckVerifier.sol";
import {Utils} from "./libs/Utils.sol";
import "./libs/Types.sol";

/// @title CanonAddrRegistry
/// @author Nocturne Labs
/// @notice Registry contract for mapping eth addresses to Nocturne canonical addresses. This is a
///         purely UX-related contract that serves a similar purpose as a phone book except instead
///         of mapping names to phone numbers, it maps eth addresses to canon addresses. Someone who
///         wants to privately send funds to another user would look up the recipient's Nocturne
///         canon address in this contract and then deposit funds to that canon address.
/// @dev We use a circuit verifier for the signature check due to prohibitive cost of verifying
///      schnorr sigs over BJJ on-chain.
contract CanonicalAddressRegistry is CanonAddrRegistryEntryEIP712 {
    // Sig check verifier
    ICanonAddrSigCheckVerifier public _sigCheckVerifier;

    // Mapping of canon address to nonce (for replay protection)
    mapping(uint256 => uint256) public _compressedCanonAddrToNonce;

    // Mapping of eth address to canon address where owner of eth address must have
    // proven they own the spend key corresponding to the canon address
    mapping(address => uint256) public _ethAddressToCompressedCanonAddr;

    /// @notice Emitted when a new canon address is set in the eth address to canon address mapping
    event CanonAddressSet(address ethAddress, uint256 compressedCanonAddr);

    /// @notice Initializer function
    /// @param contractName Name of the contract
    /// @param contractVersion Version of the contract
    /// @param sigCheckVerifier Address of the sig check verifier contract
    function initialize(
        string memory contractName,
        string memory contractVersion,
        address sigCheckVerifier
    ) external initializer {
        __CanonAddrRegistryEntryEIP712_init(contractName, contractVersion);
        _sigCheckVerifier = ICanonAddrSigCheckVerifier(sigCheckVerifier);
    }

    /// @notice Attempts to set the canon address for msg.sender in the eth address to canon
    ///         address mapping.
    /// @param compressedCanonAddr Compressed canon address to set
    /// @param proof Proof of knowledge of the spend key corresponding to the canon address
    function setCanonAddr(
        uint256 compressedCanonAddr,
        uint256[8] calldata proof
    ) external {
        // Decompose compressed canon addr point
        (uint256 canonAddrSignBit, uint256 canonAddrYCoordinate) = Utils
            .decomposeCompressedPoint(compressedCanonAddr);

        // Format pis
        uint256[] memory pis = new uint256[](2);
        pis[0] = canonAddrYCoordinate;
        pis[1] =
            (canonAddrSignBit << 252) |
            _computeDigest(
                CanonAddrRegistryEntry({
                    ethAddress: msg.sender,
                    compressedCanonAddr: compressedCanonAddr,
                    perCanonAddrNonce: _compressedCanonAddrToNonce[
                        compressedCanonAddr
                    ]
                })
            );

        // Verify sig proof
        require(_sigCheckVerifier.verifyProof(proof, pis), "!proof");

        // Update state if verification passed
        _ethAddressToCompressedCanonAddr[msg.sender] = compressedCanonAddr;
        _compressedCanonAddrToNonce[compressedCanonAddr]++;

        emit CanonAddressSet(msg.sender, compressedCanonAddr);
    }
}

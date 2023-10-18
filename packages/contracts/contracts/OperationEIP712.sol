// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

// External
import {ECDSAUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
// Internal
import {Utils} from "./libs/Utils.sol";
import "./libs/Types.sol";

/// @title OperationEIP712
/// @author Nocturne Labs
/// @notice Base contract for Teller containing EIP712 signing logic for operation
contract OperationEIP712 is EIP712Upgradeable {
    bytes32 public constant OPERATION_TYPEHASH =
        keccak256(
            bytes(
                // solhint-disable-next-line max-line-length
                "OperationWithoutProofs(PublicJoinSplitWithoutProof[] pubJoinSplits,JoinSplitWithoutProof[] confJoinSplits,CompressedStealthAddress refundAddr,TrackedAsset[] trackedAssets,Action[] actions,EncodedAsset encodedGasAsset,uint256 gasAssetRefundThreshold,uint256 executionGasLimit,uint256 gasPrice,uint256 deadline,bool atomicActions)Action(address contractAddress,bytes encodedFunction)CompressedStealthAddress(uint256 h1,uint256 h2)EncodedAsset(uint256 encodedAssetAddr,uint256 encodedAssetId)EncryptedNote(bytes ciphertextBytes,bytes encapsulatedSecretBytes)JoinSplitWithoutProof(uint256 commitmentTreeRoot,uint256 nullifierA,uint256 nullifierB,uint256 newNoteACommitment,uint256 newNoteBCommitment,uint256 senderCommitment,uint256 joinSplitInfoCommitment,EncryptedNote newNoteAEncrypted,EncryptedNote newNoteBEncrypted)PublicJoinSplitWithoutProof(JoinSplitWithoutProof joinSplit,uint8 assetIndex,uint256 publicSpend)TrackedAsset(EncodedAsset encodedAsset,uint256 minRefundValue)"
            )
        );

    bytes32 public constant ACTION_TYPEHASH =
        keccak256(
            bytes(
                // solhint-disable-next-line max-line-length
                "Action(address contractAddress,bytes encodedFunction)"
            )
        );

    bytes32 public constant COMPRESSED_STEALTH_ADDRESS_TYPEHASH =
        keccak256(
            // solhint-disable-next-line max-line-length
            "CompressedStealthAddress(uint256 h1,uint256 h2)"
        );

    bytes32 public constant PUBLIC_JOINSPLIT_WITHOUT_PROOF_TYPEHASH =
        keccak256(
            bytes(
                // solhint-disable-next-line max-line-length
                "PublicJoinSplitWithoutProof(JoinSplitWithoutProof joinSplit,uint8 assetIndex,uint256 publicSpend)EncryptedNote(bytes ciphertextBytes,bytes encapsulatedSecretBytes)JoinSplitWithoutProof(uint256 commitmentTreeRoot,uint256 nullifierA,uint256 nullifierB,uint256 newNoteACommitment,uint256 newNoteBCommitment,uint256 senderCommitment,uint256 joinSplitInfoCommitment,EncryptedNote newNoteAEncrypted,EncryptedNote newNoteBEncrypted)"
            )
        );

    bytes32 public constant JOINSPLIT_WITHOUT_PROOF_TYPEHASH =
        keccak256(
            bytes(
                // solhint-disable-next-line max-line-length
                "JoinSplitWithoutProof(uint256 commitmentTreeRoot,uint256 nullifierA,uint256 nullifierB,uint256 newNoteACommitment,uint256 newNoteBCommitment,uint256 senderCommitment,uint256 joinSplitInfoCommitment,EncryptedNote newNoteAEncrypted,EncryptedNote newNoteBEncrypted)EncryptedNote(bytes ciphertextBytes,bytes encapsulatedSecretBytes)"
            )
        );

    bytes32 public constant ENCODED_ASSET_TYPEHASH =
        keccak256(
            // solhint-disable-next-line max-line-length
            "EncodedAsset(uint256 encodedAssetAddr,uint256 encodedAssetId)"
        );

    bytes32 public constant ENCRYPTED_NOTE_TYPEHASH =
        keccak256(
            bytes(
                // solhint-disable-next-line max-line-length
                "EncryptedNote(bytes ciphertextBytes,bytes encapsulatedSecretBytes)"
            )
        );

    bytes32 public constant TRACKED_ASSET_TYPEHASH =
        keccak256(
            // solhint-disable-next-line max-line-length
            "TrackedAsset(EncodedAsset encodedAsset,uint256 minRefundValue)EncodedAsset(uint256 encodedAssetAddr,uint256 encodedAssetId)"
        );

    /// @notice Internal initializer
    /// @param contractName Name of the contract
    /// @param contractVersion Version of the contract
    function __OperationEIP712_init(
        string memory contractName,
        string memory contractVersion
    ) internal onlyInitializing {
        __EIP712_init(contractName, contractVersion);
    }

    /// @notice Computes EIP712 digest of operation
    /// @dev The inherited EIP712 domain separator includes block.chainid for replay protection.
    /// @param op OperationWithoutProof
    function _computeDigest(
        Operation calldata op
    ) public view returns (uint256) {
        bytes32 domainSeparator = _domainSeparatorV4();
        bytes32 structHash = _hashOperation(op);

        bytes32 digest = ECDSAUpgradeable.toTypedDataHash(
            domainSeparator,
            structHash
        );

        // mod digest by BN254 since this is PI to joinsplit circuit
        return uint256(digest) % Utils.BN254_SCALAR_FIELD_MODULUS;
    }

    /// @notice Hashes operation
    /// @param op Operation
    /// @dev We hash every field of operation except for the joinsplit proofs
    function _hashOperation(
        Operation calldata op
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    OPERATION_TYPEHASH,
                    _hashPublicJoinSplits(op.pubJoinSplits),
                    _hashJoinSplits(op.confJoinSplits),
                    _hashCompressedStealthAddress(op.refundAddr),
                    _hashTrackedAssets(op.trackedAssets),
                    _hashActions(op.actions),
                    _hashEncodedAsset(op.encodedGasAsset),
                    op.gasAssetRefundThreshold,
                    op.executionGasLimit,
                    op.gasPrice,
                    op.deadline,
                    uint256(op.atomicActions ? 1 : 0)
                )
            );
    }

    function _hashPublicJoinSplits(
        PublicJoinSplit[] calldata publicJoinSplits
    ) internal pure returns (bytes32) {
        uint256 numPublicJoinSplits = publicJoinSplits.length;
        bytes32[] memory publicJoinSplitHashes = new bytes32[](
            numPublicJoinSplits
        );
        for (uint256 i = 0; i < numPublicJoinSplits; i++) {
            publicJoinSplitHashes[i] = _hashPublicJoinSplit(
                publicJoinSplits[i]
            );
        }

        return keccak256(abi.encodePacked(publicJoinSplitHashes));
    }

    function _hashPublicJoinSplit(
        PublicJoinSplit calldata publicJoinSplit
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    PUBLIC_JOINSPLIT_WITHOUT_PROOF_TYPEHASH,
                    _hashJoinSplit(publicJoinSplit.joinSplit),
                    uint256(publicJoinSplit.assetIndex),
                    publicJoinSplit.publicSpend
                )
            );
    }

    /// @notice Hashes array of joinsplits
    /// @param joinSplits JoinSplits
    /// @dev We hash every field except for the joinSplit proofs
    function _hashJoinSplits(
        JoinSplit[] calldata joinSplits
    ) internal pure returns (bytes32) {
        uint256 numJoinSplits = joinSplits.length;
        bytes32[] memory joinSplitHashes = new bytes32[](numJoinSplits);
        for (uint256 i = 0; i < numJoinSplits; i++) {
            joinSplitHashes[i] = _hashJoinSplit(joinSplits[i]);
        }

        return keccak256(abi.encodePacked(joinSplitHashes));
    }

    /// @notice Hashes single joinsplit
    /// @param joinSplit JoinSplit
    /// @dev We hash every field except for the proof
    function _hashJoinSplit(
        JoinSplit calldata joinSplit
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    JOINSPLIT_WITHOUT_PROOF_TYPEHASH,
                    joinSplit.commitmentTreeRoot,
                    joinSplit.nullifierA,
                    joinSplit.nullifierB,
                    joinSplit.newNoteACommitment,
                    joinSplit.newNoteBCommitment,
                    joinSplit.senderCommitment,
                    joinSplit.joinSplitInfoCommitment,
                    _hashEncryptedNote(joinSplit.newNoteAEncrypted),
                    _hashEncryptedNote(joinSplit.newNoteBEncrypted)
                )
            );
    }

    /// @notice Hashes array of actions
    /// @param actions Actions
    function _hashActions(
        Action[] calldata actions
    ) internal pure returns (bytes32) {
        uint256 numActions = actions.length;
        bytes32[] memory actionHashes = new bytes32[](numActions);
        for (uint256 i = 0; i < numActions; i++) {
            actionHashes[i] = _hashAction(actions[i]);
        }

        return keccak256(abi.encodePacked(actionHashes));
    }

    /// @notice Hashes single action
    /// @param action Action
    function _hashAction(
        Action calldata action
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    ACTION_TYPEHASH,
                    action.contractAddress,
                    keccak256(action.encodedFunction)
                )
            );
    }

    /// @notice Hashes encrypted note
    /// @param encryptedNote Encrypted note
    function _hashEncryptedNote(
        EncryptedNote calldata encryptedNote
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    ENCRYPTED_NOTE_TYPEHASH,
                    keccak256(encryptedNote.ciphertextBytes),
                    keccak256(encryptedNote.encapsulatedSecretBytes)
                )
            );
    }

    /// @notice Hashes stealth address
    /// @param stealthAddress Compressed stealth address
    function _hashCompressedStealthAddress(
        CompressedStealthAddress calldata stealthAddress
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

    /// @notice Hashes tracked assets
    /// @param trackedAssets Encoded refund assets
    function _hashTrackedAssets(
        TrackedAsset[] calldata trackedAssets
    ) internal pure returns (bytes32) {
        uint256 numTrackedAssets = trackedAssets.length;
        bytes32[] memory trackedAssetHashes = new bytes32[](numTrackedAssets);
        for (uint256 i = 0; i < numTrackedAssets; i++) {
            trackedAssetHashes[i] = _hashTrackedAsset(trackedAssets[i]);
        }

        return keccak256(abi.encodePacked(trackedAssetHashes));
    }

    /// @notice Hashes tracked asset
    /// @param trackedAsset Tracked asset
    function _hashTrackedAsset(
        TrackedAsset calldata trackedAsset
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    TRACKED_ASSET_TYPEHASH,
                    _hashEncodedAsset(trackedAsset.encodedAsset),
                    trackedAsset.minRefundValue
                )
            );
    }

    /// @notice Hashes encoded asset
    /// @param encodedAsset Encoded asset
    function _hashEncodedAsset(
        EncodedAsset calldata encodedAsset
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

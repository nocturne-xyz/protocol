// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

// External
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Versioned} from "./upgrade/Versioned.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
// Internal
import {ITeller} from "./interfaces/ITeller.sol";
import {IHandler} from "./interfaces/IHandler.sol";
import {IJoinSplitVerifier} from "./interfaces/IJoinSplitVerifier.sol";
import {IPoseidonExtT7} from "./interfaces/IPoseidonExt.sol";
import {OperationEIP712} from "./OperationEIP712.sol";
import {Utils} from "./libs/Utils.sol";
import {Validation} from "./libs/Validation.sol";
import {AssetUtils} from "./libs/AssetUtils.sol";
import {OperationUtils} from "./libs/OperationUtils.sol";
import {Groth16} from "./libs/OperationUtils.sol";
import "./libs/Types.sol";

/// @title Teller
/// @author Nocturne Labs
/// @notice Teller stores deposited funds and serves as the entry point contract for operations.
contract Teller is
    ITeller,
    OperationEIP712,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    Ownable2StepUpgradeable,
    Versioned
{
    using OperationLib for Operation;

    // Domain separator hashed with joinsplit info for joinsplit info commitment
    uint256 public constant JOINSPLIT_INFO_COMMITMENT_DOMAIN_SEPARATOR =
        uint256(keccak256(bytes("JOINSPLIT_INFO_COMMITMENT")));

    // Handler contract
    IHandler public _handler;

    // JoinSplit verifier contract
    IJoinSplitVerifier public _joinSplitVerifier;

    // Set of contracts which can deposit funds into Teller
    mapping(address => bool) public _depositSources;

    // 6 elem poseidon hasher
    IPoseidonExtT7 public _poseidonExtT7;

    // Gap for upgrade safety
    uint256[50] private __GAP;

    /// @notice Event emitted when a deposit source is given/revoked permission
    event DepositSourcePermissionSet(address source, bool permission);

    /// @notice Event emitted when an operation is processed/executed (one per operation)
    event OperationProcessed(
        uint256 indexed operationDigest,
        bool opProcessed,
        bool assetsUnwrapped,
        string failureReason,
        bool[] callSuccesses,
        bytes[] callResults,
        uint128 preOpMerkleCount,
        uint128 postOpMerkleCount
    );

    /// @notice Initializer function
    /// @param handler Address of the handler contract
    /// @param joinSplitVerifier Address of the joinsplit verifier contract
    function initialize(
        string calldata contractName,
        string calldata contractVersion,
        address handler,
        address joinSplitVerifier,
        address poseidonExtT7
    ) external initializer {
        __Pausable_init();
        __Ownable2Step_init();
        __ReentrancyGuard_init();
        __OperationEIP712_init(contractName, contractVersion);
        _handler = IHandler(handler);
        _joinSplitVerifier = IJoinSplitVerifier(joinSplitVerifier);
        _poseidonExtT7 = IPoseidonExtT7(poseidonExtT7);
    }

    /// @notice Only callable by the Handler, so Handler can request assets
    modifier onlyHandler() {
        require(msg.sender == address(_handler), "Only handler");
        _;
    }

    /// @notice Only callable by allowed deposit source
    modifier onlyDepositSource() {
        require(_depositSources[msg.sender], "Only deposit source");
        _;
    }

    /// @notice Only callable by EOA
    modifier onlyEoa() {
        require(tx.origin == msg.sender, "Only eoa");
        _;
    }

    /// @notice Pauses contract, only callable by owner
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses contract, only callable by owner
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Sets permission for a deposit source
    /// @param source Address of the contract or EOA
    /// @param permission Whether or not the source is allowed to deposit funds
    function setDepositSourcePermission(
        address source,
        bool permission
    ) external onlyOwner {
        _depositSources[source] = permission;
        emit DepositSourcePermissionSet(source, permission);
    }

    /// @notice Deposits funds into the Teller contract and calls on handler to add new notes
    /// @dev Only callable by allowed deposit source when not paused
    /// @param deposit Deposit
    function depositFunds(
        Deposit calldata deposit
    )
        external
        override
        whenNotPaused
        onlyDepositSource
        returns (uint128 merkleIndex)
    {
        merkleIndex = _handler.handleDeposit(deposit);
        AssetUtils.transferAssetFrom(
            deposit.encodedAsset,
            msg.sender,
            deposit.value
        );
    }

    /// @notice Sends assets to the Handler to fund operation, only callable by Handler contract
    /// @param encodedAsset Encoded asset being requested
    /// @param value Amount of asset to send
    function requestAsset(
        EncodedAsset calldata encodedAsset,
        uint256 value
    ) external override whenNotPaused onlyHandler {
        AssetUtils.transferAssetTo(encodedAsset, address(_handler), value);
    }

    /// @notice Processes a bundle of operations. Verifies all proofs, then loops through each op
    ///         and passes to Handler for processing/execution. Emits one OperationProcessed event
    ///         per op.
    /// @dev Restricts caller of entrypoint to EOA to ensure processBundle cannot be atomically
    ///      called with another transaction.
    /// @param bundle Bundle of operations to process
    function processBundle(
        Bundle calldata bundle
    )
        external
        override
        whenNotPaused
        nonReentrant
        onlyEoa
        returns (uint256[] memory opDigests, OperationResult[] memory opResults)
    {
        Operation[] calldata ops = bundle.operations;
        require(ops.length > 0, "empty bundle");

        opDigests = new uint256[](ops.length);
        for (uint256 i = 0; i < ops.length; i++) {
            Validation.validateOperation(ops[i]);
            opDigests[i] = _computeDigest(ops[i]);
        }

        (bool success, uint256 perJoinSplitVerifyGas) = _verifyAllProofsMetered(
            ops,
            opDigests
        );
        require(success, "Batch JoinSplit verify failed");

        uint256 numOps = ops.length;
        opResults = new OperationResult[](numOps);
        for (uint256 i = 0; i < numOps; i++) {
            try
                _handler.handleOperation(
                    ops[i],
                    perJoinSplitVerifyGas,
                    msg.sender
                )
            returns (OperationResult memory result) {
                opResults[i] = result;
            } catch (bytes memory reason) {
                // Indicates revert because of expired deadline or error processing joinsplits.
                // Bundler is not compensated and we do not bubble up further OperationResult
                // info other than failureReason.
                string memory revertMsg = OperationUtils.getRevertMsg(reason);
                if (bytes(revertMsg).length == 0) {
                    opResults[i]
                        .failureReason = "handleOperation failed silently";
                } else {
                    opResults[i].failureReason = revertMsg;
                }
            }
            emit OperationProcessed(
                opDigests[i],
                opResults[i].opProcessed,
                opResults[i].assetsUnwrapped,
                opResults[i].failureReason,
                opResults[i].callSuccesses,
                opResults[i].callResults,
                opResults[i].preOpMerkleCount,
                opResults[i].postOpMerkleCount
            );
        }
        return (opDigests, opResults);
    }

    /// @notice Verifies or batch verifies joinSplit proofs for an array of operations.
    /// @dev If there is a single proof, it is cheaper to single verify. If multiple proofs,
    ///      we batch verify.
    /// @param ops Array of operations
    /// @param opDigests Array of operation digests in same order as the ops
    /// @return success Whether or not all proofs were successfully verified
    /// @return perJoinSplitVerifyGas Gas cost of verifying a single joinSplit proof (total batch
    ///         verification cost divided by number of proofs)
    function _verifyAllProofsMetered(
        Operation[] calldata ops,
        uint256[] memory opDigests
    ) internal view returns (bool success, uint256 perJoinSplitVerifyGas) {
        uint256 preVerificationGasLeft = gasleft();

        (uint256[8][] memory proofs, uint256[][] memory allPis) = OperationUtils
            .extractJoinSplitProofsAndPis(ops, opDigests);

        if (proofs.length == 1) {
            success = _joinSplitVerifier.verifyProof(proofs[0], allPis[0]);
        } else {
            success = _joinSplitVerifier.batchVerifyProofs(proofs, allPis);
        }

        perJoinSplitVerifyGas =
            (preVerificationGasLeft - gasleft()) /
            proofs.length;
        return (success, perJoinSplitVerifyGas);
    }
}

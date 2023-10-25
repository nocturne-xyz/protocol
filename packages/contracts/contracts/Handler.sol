// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

// Internal
import {IHandler} from "./interfaces/IHandler.sol";
import {BalanceManager} from "./BalanceManager.sol";
import {NocturneReentrancyGuard} from "./NocturneReentrancyGuard.sol";
import {Utils} from "./libs/Utils.sol";
import {OperationUtils} from "./libs/OperationUtils.sol";
import {Groth16} from "./libs/Groth16.sol";
import {AssetUtils} from "./libs/AssetUtils.sol";
import "./libs/Types.sol";

/// @title Handler
/// @author Nocturne Labs
/// @notice Handler contract for processing and executing operations.
contract Handler is IHandler, BalanceManager, NocturneReentrancyGuard {
    using OperationLib for Operation;

    bytes4 public constant ERC20_APPROVE_SELECTOR = bytes4(0x095ea7b3);
    uint256 public constant ERC_20_APPROVE_FN_DATA_LENGTH = 4 + 32 + 32;

    // Set of supported contracts
    mapping(address => bool) public _supportedContracts;

    // Set of callable protocol methods (key = address | selector)
    // NOTE: If an upgradeable contract with malicious admins is whitelisted, the contract could be
    // upgraded to add a new method that has a selector clash with an already-whitelisted method.
    // This would allow a malicious admin to make methods not intended to be called callable. This
    // scenario would allow for bypassing of deposit limits if new method allows for large inflow
    // of funds.
    mapping(uint192 => bool) public _supportedContractMethods;

    // Gap for upgrade safety
    uint256[50] private __GAP;

    /// @notice Event emitted when a contract is given/revoked allowlist permission
    event ContractMethodPermissionSet(
        address contractAddress,
        bytes4 selector,
        bool permission
    );

    /// @notice Event emitted when a token is given/revoked allowlist permission
    event ContractPermissionSet(address contractAddress, bool permission);

    /// @notice Initialization function
    /// @param subtreeUpdateVerifier Address of the subtree update verifier contract
    /// @param leftoverTokensHolder Address of the leftover tokens holder contract
    function initialize(
        address subtreeUpdateVerifier,
        address leftoverTokensHolder
    ) external initializer {
        __NocturneReentrancyGuard_init();
        __BalanceManager_init(subtreeUpdateVerifier, leftoverTokensHolder);
    }

    /// @notice Only callable by the handler itself (used so handler can message call itself)
    modifier onlyThis() {
        require(msg.sender == address(this), "Only this");
        _;
    }

    /// @notice Only callable by the Teller contract
    modifier onlyTeller() {
        require(msg.sender == address(_teller), "Only teller");
        _;
    }

    /// @notice Pauses the contract, only callable by owner
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract, only callable by owner
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Sets allowlist permission of the given contract, only callable by owner
    /// @param contractAddress Address of the contract to add
    /// @param permission Whether to enable or revoke permission
    /// @dev This whitelists the contract but none of its methods. This is used for checks such as
    ///      checks that a token is supported or when checking that a spender being approved for an
    ///      erc20 is allowed.
    function setContractPermission(
        address contractAddress,
        bool permission
    ) external onlyOwner {
        _supportedContracts[contractAddress] = permission;
        emit ContractPermissionSet(contractAddress, permission);
    }

    /// @notice Sets allowlist permission of the given contract, only callable by owner
    /// @param contractAddress Address of the contract to add
    /// @param permission Whether to enable or revoke permission
    function setContractMethodPermission(
        address contractAddress,
        bytes4 selector,
        bool permission
    ) external onlyOwner {
        uint192 addressAndSelector = _addressAndSelector(
            contractAddress,
            selector
        );
        _supportedContractMethods[addressAndSelector] = permission;
        emit ContractMethodPermissionSet(contractAddress, selector, permission);
    }

    /// @notice Handles deposit call from Teller. Inserts new note commitment for deposit.
    /// @dev This method is only callable by the Teller contract when contract is not paused.
    /// @dev Function checks asset is on the allowlist to avoid unsupported tokens getting stuck.
    /// @param deposit Deposit to handle
    function handleDeposit(
        Deposit calldata deposit
    ) external override whenNotPaused onlyTeller returns (uint128 merkleIndex) {
        // Ensure deposit asset is supported
        EncodedAsset memory encodedAsset = deposit.encodedAsset;
        (, address assetAddr, ) = AssetUtils.decodeAsset(encodedAsset);
        require(_supportedContracts[assetAddr], "!supported deposit asset");

        merkleIndex = _handleRefundNote(
            encodedAsset,
            deposit.depositAddr,
            deposit.value
        );

        return merkleIndex;
    }

    /// @notice Handles an operation after proofs have been verified by the Teller. Checks
    ///         joinSplits, requests proven funds from the Teller, executes op.actions, compensates
    ///         the bundler, then handles refunds.
    /// @dev This method is only callable by the Teller contract when contract is not paused.
    /// @dev There are 3 call nested call contexts used to isolate different types of errors:
    ///         1. handleOperation: A revert here means the bundler failed to perform standard
    ///            checks that are predictable (e.g. valid chainid, valid deadline, enough gas
    ///            assets, etc). The bundler is not compensated when reverts happen here because
    ///            the revert happens before _gatherReservedGasAssetAndPayBundler is called.
    ///         2. executeActions: A revert here can be due to unpredictable reasons, mainly if
    ///            there is not enough executionGas for the actions or if after executing actions,
    ///            there are fewer refund tokens than what was specified in trackedAssets
    ///            minRefundValues.
    ///         3. _makeExternalCall: A revert here only leads to top level revert if
    ///            op.atomicActions = true (requires all actions to succeed atomically or none at
    ///            all).
    /// @dev If the op.isForcedExit, this function will tell _processJoinSplitsReservingFee
    ///      NOT to create any output notes and will NOT handle any refunds. This will leave
    ///      leftover funds in the Handler contract, which will be sent away to the
    ///      leftoverTokensHolder upon the next operation that spends those same remaining assets.
    ///      Tokens in the leftoverTokensHolder will be unclaimable.
    /// @param op Operation to handle
    /// @param perJoinSplitVerifyGas Gas usage for verifying a single joinSplit proof
    /// @param bundler Address of the bundler
    function handleOperation(
        Operation calldata op,
        uint256 perJoinSplitVerifyGas,
        address bundler
    )
        external
        whenNotPaused
        onlyTeller
        handleOperationGuard
        returns (OperationResult memory opResult)
    {
        // Ensure all assets supported
        uint256 numTrackedAssets = op.trackedAssets.length;
        for (uint256 i = 0; i < numTrackedAssets; i++) {
            (, address assetAddr, ) = AssetUtils.decodeAsset(
                op.trackedAssets[i].encodedAsset
            );
            require(_supportedContracts[assetAddr], "!supported asset");
        }

        // Ensure all token balances of tokens to be used are zeroed out
        _ensureZeroedBalances(op);

        // Mark merkle count pre operation
        opResult.preOpMerkleCount = totalCount();

        // Handle all joinsplits
        uint256 numJoinSplitAssets = _processJoinSplitsReservingFee(
            op,
            perJoinSplitVerifyGas
        );

        // If reached this point, assets have been unwrapped and will have refunds to handle
        opResult.assetsUnwrapped = true;

        uint256 preExecutionGas = gasleft();
        try this.executeActions{gas: op.executionGasLimit}(op) returns (
            bool[] memory successes,
            bytes[] memory results,
            uint256 numRefundsToHandle
        ) {
            opResult.opProcessed = true;
            opResult.callSuccesses = successes;
            opResult.callResults = results;
            opResult.numRefunds = numRefundsToHandle;
        } catch (bytes memory reason) {
            // Indicates revert because of one of the following reasons:
            // 1. `executeActions` yielded fewer refund tokens than expected in
            //    trackedAssets
            // 2. `executeActions` exceeded `executionGasLimit`, but in its outer call context
            //    (i.e. while not making an external call)
            // 3. There was a revert when executing actions (e.g. atomic actions, unsupported
            //    contract call, etc)

            // We explicitly catch cases 1 and 3 in `executeActions`, so if `executeActions` failed
            // silently, then it must be case 2.
            string memory revertMsg = OperationUtils.getRevertMsg(reason);
            if (bytes(revertMsg).length == 0) {
                opResult.failureReason = "exceeded `executionGasLimit`";
            } else {
                opResult.failureReason = revertMsg;
            }

            // In case that action execution reverted, num refunds to handle will be number of
            // joinSplit assets. NOTE that this could be higher estimate than actual if joinsplits
            // are not organized in contiguous subarrays by user.
            opResult.numRefunds = numJoinSplitAssets;
        }

        // Set verification and execution gas after getting opResult
        opResult.verificationGas =
            perJoinSplitVerifyGas *
            op.totalNumJoinSplits();
        opResult.executionGas = Utils.min(
            op.executionGasLimit,
            preExecutionGas - gasleft()
        );

        // Gather reserved gas asset and process gas payment to bundler
        _gatherReservedGasAssetAndPayBundler(
            op,
            opResult,
            perJoinSplitVerifyGas,
            bundler
        );

        if (!op.isForcedExit) {
            _handleAllRefunds(op);
        }

        // Mark new merkle count post operation
        opResult.postOpMerkleCount = totalCount();

        return opResult;
    }

    /// @notice Executes an array of actions for an operation.
    /// @dev This function is only callable by the Handler itself when not paused.
    /// @dev This function can revert if any of the below occur (revert not within action itself):
    ///         1. The call runs out of gas in the outer call context (OOG)
    ///         2. The executed actions result in fewer refunds than expected in
    ///            trackedAssets
    ///         3. An action reverts and atomicActions is set to true
    ///         4. A call to an unsupported protocol is attempted
    ///         5. An action attempts to re-enter by calling the Teller contract
    /// @param op Operation to execute actions for
    function executeActions(
        Operation calldata op
    )
        external
        whenNotPaused
        onlyThis
        executeActionsGuard
        returns (
            bool[] memory successes,
            bytes[] memory results,
            uint256 numRefundsToHandle
        )
    {
        uint256 numActions = op.actions.length;
        successes = new bool[](numActions);
        results = new bytes[](numActions);

        // Execute each external call
        for (uint256 i = 0; i < numActions; i++) {
            (successes[i], results[i]) = _makeExternalCall(op.actions[i]);
            if (op.atomicActions && !successes[i]) {
                string memory revertMsg = OperationUtils.getRevertMsg(
                    results[i]
                );
                if (bytes(revertMsg).length == 0) {
                    // TODO maybe say which action?
                    revert("action silently reverted");
                } else {
                    revert(revertMsg);
                }
            }
        }

        // NOTE: if any tokens have < expected refund value, the below call will revert. This causes
        // executeActions to revert, undoing all state changes in this call context. The user still
        // ends up compensating the bundler for gas in this case.
        numRefundsToHandle = _ensureMinRefundValues(op);
    }

    /// @notice Makes an external call to execute a single action
    /// @dev Reverts if caller attempts to call unsupported contract OR if caller tries
    ///      to re-enter by calling the Teller contract.
    /// @dev There is a special check on methods with the erc20.approve selector that ensures only
    ///      whitelisted protocols can be approved as `spender` for erc20 tokens. Without this
    ///      check, users can call erc20.approve(amount, spender) from the Handler contract to
    ///      approve arbitrary spenders.
    function _makeExternalCall(
        Action calldata action
    ) internal returns (bool success, bytes memory result) {
        // Ensure contract exists
        require(action.contractAddress.code.length != 0, "!zero code");

        // Block re-entrancy from teller calling self
        require(
            action.contractAddress != address(_teller),
            "Cannot call the Nocturne Teller"
        );

        // Ensure contract and method to call are supported
        bytes4 selector = _extractFunctionSelector(action.encodedFunction);
        uint192 addressAndSelector = _addressAndSelector(
            action.contractAddress,
            selector
        );
        require(
            _supportedContractMethods[addressAndSelector],
            "Cannot call non-allowed protocol method"
        );

        // NOTE: If an allowed protocol has a selector clash with erc20.approve, then abi.decode
        // will yield whatever data is formatted at bytes 4:23 for spender. This will likely revert
        // and cause the clashing function to not be callable. If 1st argument happens to be a
        // whitelisted address, then the clashing function will be callable. Selector clashes,
        // however, are not an issue here, as this check is only meant to ensure the normal case
        // (erc20s with standard approve fn signature) have protection against arbitrary approvals
        // and is not intended to have any bearing on other non-erc20 or non-approve cases. Worst
        // case outcome is that small number of functions with signature clash will not be callable.
        if (selector == ERC20_APPROVE_SELECTOR) {
            require(
                action.encodedFunction.length == ERC_20_APPROVE_FN_DATA_LENGTH,
                "!approve fn length"
            );
            (address spender, ) = abi.decode(
                action.encodedFunction[4:],
                (address, uint256)
            );
            require(_supportedContracts[spender], "!approve spender");
        }

        (success, result) = action.contractAddress.call(action.encodedFunction);
    }

    /// @notice Extract function selector from encoded function data
    /// @param encodedFunctionData Encoded function data
    function _extractFunctionSelector(
        bytes calldata encodedFunctionData
    ) internal pure returns (bytes4 selector) {
        require(encodedFunctionData.length >= 4, "!encoded fn length");
        return bytes4(encodedFunctionData[:4]);
    }

    /// @notice Concat address and selector as key to contract allowlist
    /// @param contractAddress Address of the contract
    /// @param selector Selector of the function
    function _addressAndSelector(
        address contractAddress,
        bytes4 selector
    ) internal pure returns (uint192) {
        return (uint192(uint160(contractAddress)) << 32) | uint32(selector);
    }
}

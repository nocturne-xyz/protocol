// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title NocturneReentrancyGuard
/// @author Nocturne Labs
/// @notice Custom reentrancy guard that track stages of operation processing/execution.
/// @dev Modified from OpenZeppelin ReentrancyGuard.sol
contract NocturneReentrancyGuard is Initializable {
    // No operation entered (before Teller calls handler.handleOperation)
    uint256 public constant NOT_ENTERED = 1;
    // Once an operation is entered for processing (after Teller calls handler.handleOperation)
    uint256 public constant ENTERED_HANDLE_OPERATION = 2;
    // Once an operation is entered for execution (after Teller calls handler.executeActions)
    uint256 public constant ENTERED_EXECUTE_ACTIONS = 3;

    // Operation stage
    uint256 private _operationStage;

    // Gap for upgrade safety
    uint256[50] private __GAP;

    /// @notice Internal initializer
    function __NocturneReentrancyGuard_init() internal onlyInitializing {
        _operationStage = NOT_ENTERED;
    }

    /// @notice Requires current stage to be NOT_ENTERED.
    /// @dev Moves stage to ENTERED_HANDLE_OPERATION before function execution, then resets stage
    ///      to NOT_ENTERED at end of call context.
    modifier handleOperationGuard() {
        require(_operationStage == NOT_ENTERED, "Reentry into handleOperation");
        _operationStage = ENTERED_HANDLE_OPERATION;

        _;

        _operationStage = NOT_ENTERED;
    }

    /// @notice Requires current stage to be ENTERED_HANDLE_OPERATION.
    /// @dev Moves stage to ENTERED_EXECUTE_ACTIONS before function execution, then resets stage to
    ///      ENTERED_HANDLE_OPERATION at end of call context.
    modifier executeActionsGuard() {
        require(
            _operationStage == ENTERED_HANDLE_OPERATION,
            "Reentry into executeActions"
        );
        _operationStage = ENTERED_EXECUTE_ACTIONS;

        _;

        _operationStage = ENTERED_HANDLE_OPERATION;
    }

    /// @notice Returns current operation stage
    function reentrancyGuardStage() public view returns (uint256) {
        return _operationStage;
    }
}

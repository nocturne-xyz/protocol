// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

// From https://github.com/rocket-pool/rocketpool/blob/master/contracts/interface/deposit/RocketDepositPoolInterface.sol
interface IRocketDepositPool {
    function getBalance() external view returns (uint256);

    function getNodeBalance() external view returns (uint256);

    function getUserBalance() external view returns (int256);

    function getExcessBalance() external view returns (uint256);

    function deposit() external payable;

    function getMaximumDepositAmount() external view returns (uint256);

    function nodeDeposit(uint256 _totalAmount) external payable;

    function nodeCreditWithdrawal(uint256 _amount) external;

    function recycleDissolvedDeposit() external payable;

    function recycleExcessCollateral() external payable;

    function recycleLiquidatedStake() external payable;

    function assignDeposits() external;

    function maybeAssignDeposits() external returns (bool);

    function withdrawExcessBalance(uint256 _amount) external;
}

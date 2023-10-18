// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

// Represents the type of deposits required by a minipool
enum MinipoolDeposit {
    None, // Marks an invalid deposit type
    Full, // The minipool requires 32 ETH from the node operator, 16 ETH of which will be refinanced from user deposits
    Half, // The minipool required 16 ETH from the node operator to be matched with 16 ETH from user deposits
    Empty, // The minipool requires 0 ETH from the node operator to be matched with 32 ETH from user deposits (trusted nodes only)
    Variable // Indicates this minipool is of the new generation that supports a variable deposit amount
}

interface IRocketMinipoolQueue {
    function getTotalLength() external view returns (uint256);

    function getContainsLegacy() external view returns (bool);

    function getLengthLegacy(
        MinipoolDeposit _depositType
    ) external view returns (uint256);

    function getLength() external view returns (uint256);

    function getTotalCapacity() external view returns (uint256);

    function getEffectiveCapacity() external view returns (uint256);

    function getNextCapacityLegacy() external view returns (uint256);

    function getNextDepositLegacy()
        external
        view
        returns (MinipoolDeposit, uint256);

    function enqueueMinipool(address _minipool) external;

    function dequeueMinipoolByDepositLegacy(
        MinipoolDeposit _depositType
    ) external returns (address minipoolAddress);

    function dequeueMinipools(
        uint256 _maxToDequeue
    ) external returns (address[] memory minipoolAddress);

    function removeMinipool(MinipoolDeposit _depositType) external;

    function getMinipoolAt(uint256 _index) external view returns (address);

    function getMinipoolPosition(
        address _minipool
    ) external view returns (int256);
}

// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

interface IPoseidonT3 {
    function poseidon(uint256[2] memory) external pure returns (uint256);
}

interface IPoseidonT4 {
    function poseidon(uint256[3] memory) external pure returns (uint256);
}

interface IPoseidonT5 {
    function poseidon(uint256[4] memory) external pure returns (uint256);
}

interface IPoseidonT6 {
    function poseidon(uint256[5] memory) external pure returns (uint256);
}

interface IPoseidonT7 {
    function poseidon(uint256[6] memory) external pure returns (uint256);
}

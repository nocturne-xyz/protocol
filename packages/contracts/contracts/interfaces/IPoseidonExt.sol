// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

interface IPoseidonExtT3 {
    function poseidonExt(
        uint256,
        uint256[2] memory
    ) external pure returns (uint256);
}

interface IPoseidonExtT4 {
    function poseidonExt(
        uint256,
        uint256[3] memory
    ) external pure returns (uint256);
}

interface IPoseidonExtT7 {
    function poseidonExt(
        uint256,
        uint256[6] memory
    ) external pure returns (uint256);
}

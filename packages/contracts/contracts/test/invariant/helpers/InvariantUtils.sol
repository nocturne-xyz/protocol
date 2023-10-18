// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

contract InvariantUtils is Test {
    uint256 internal rerandomizationCounter = 0;

    function _rerandomize(uint256 seed) internal returns (uint256) {
        uint256 newRandom;
        unchecked {
            newRandom = uint256(
                keccak256(
                    abi.encodePacked(seed, uint256(rerandomizationCounter))
                )
            );
            rerandomizationCounter++;
        }

        return newRandom;
    }
}

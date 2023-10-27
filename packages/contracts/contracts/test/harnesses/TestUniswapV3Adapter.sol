// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import {UniswapV3Adapter} from "../../adapters/UniswapV3Adapter.sol";

contract TestUniswapV3Adapter is UniswapV3Adapter {
    constructor(address swapRouter) UniswapV3Adapter(swapRouter) {}

    function testTokensAreAllowed(
        bytes memory path
    ) external view returns (bool) {
        return tokensAreAllowed(path);
    }

    function testExtractTokenAddressFromPath(
        bytes memory path,
        uint256 index
    ) external pure returns (address) {
        return extractTokenAddressFromPath(path, index);
    }
}

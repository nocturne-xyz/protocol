// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ISwapRouter} from "../interfaces/ISwapRouter.sol";

contract UniswapV3Adapter is Ownable {
    // UniswapV3 SwapRouter
    ISwapRouter public immutable _swapRouter;

    // Whitelist of tokens that can be used in a path
    mapping(address => bool) private _allowedTokens;

    constructor(address swapRouter) Ownable() {
        _swapRouter = ISwapRouter(swapRouter);
    }

    // Add a token to the whitelist (you can also remove or have other admin functionalities as needed)
    function addToWhitelist(address token) external onlyOwner {
        // Only an owner or admin can add to the whitelist; implement accordingly
        _allowedTokens[token] = true;
    }

    function tokensAreAllowed(bytes memory path) public view returns (bool) {
        uint256 length = path.length;

        // Ensure the path length is correct: (20 + 3) * n + 20
        require((length - 20) % 23 == 0, "Invalid path length");

        uint256 numAddresses = (length - 20) / 23 + 1;

        for (uint256 i = 0; i < numAddresses; i++) {
            address tokenAddress = extractTokenAddressFromPath(path, i * 23);
            if (!_allowedTokens[tokenAddress]) {
                return false;
            }
        }

        return true;
    }

    // Internal function to extract token address from path using inline assembly
    function extractTokenAddressFromPath(
        bytes memory path,
        uint256 index
    ) internal pure returns (address) {
        address tokenAddr;
        
        // Load 32 bytes that are at 0 + 32 (length prefix) + index bytes offset
        // Shift right by 12 bytes to get the token address (those 12 will be spillover to right)
        assembly {
            tokenAddr := shr(96, mload(add(add(path, 0x20), index)))
        }

        return tokenAddr;
    }
}

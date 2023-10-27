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

    // Function to check if all token addresses in a path are whitelisted
    function tokensAreInWhitelist(bytes memory path) public view returns (bool) {
        uint256 pathLength = path.length;
        require(pathLength % 23 == 0, "Invalid path length"); // Each (address-fee) pair is 23 bytes: 20 bytes for address and 3 bytes for fee

        for (uint256 i = 0; i < pathLength; i += 23) {
            address tokenAddr = getTokenAddressFromPath(path, i);
            if (!_allowedTokens[tokenAddr]) {
                return false;
            }
        }
        return true;
    }

    // Internal function to extract token address from path using inline assembly
    function getTokenAddressFromPath(bytes memory path, uint256 index) internal pure returns (address) {
        address tokenAddr;
        assembly {
            tokenAddr := and(mload(add(add(path, 0x20), index)), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        }
        return tokenAddr;
    }
}

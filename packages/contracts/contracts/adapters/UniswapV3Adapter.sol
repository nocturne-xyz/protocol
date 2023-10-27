// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISwapRouter} from "../interfaces/ISwapRouter.sol";

contract UniswapV3Adapter is Ownable {
    // UniswapV3 SwapRouter
    ISwapRouter public immutable _swapRouter;

    // Whitelist of tokens that can be used in a path
    mapping(address => bool) private _allowedTokens;

    event TokenPermissionSet(address token, bool permission);

    constructor(address swapRouter) Ownable() {
        _swapRouter = ISwapRouter(swapRouter);
    }

    // Add a token to the whitelist (you can also remove or have other admin functionalities as needed)
    function setTokenPermission(
        address token,
        bool permission
    ) external onlyOwner {
        _allowedTokens[token] = permission;
        emit TokenPermissionSet(token, permission);
    }

    function exactInputSingle(
        ISwapRouter.ExactInputSingleParams memory params
    ) external returns (uint256 amountOut) {
        require(_allowedTokens[params.tokenIn], "!allowed token");
        require(params.recipient == msg.sender, "!recipient");

        IERC20(params.tokenIn).transferFrom(
            address(msg.sender),
            address(this),
            params.amountIn
        );
        IERC20(params.tokenIn).approve(address(_swapRouter), params.amountIn);

        amountOut = _swapRouter.exactInputSingle(params);
    }

    function exactInput(
        ISwapRouter.ExactInputParams memory params
    ) external returns (uint256 amountOut) {
        require(tokensAreAllowed(params.path), "!allowed path");
        require(params.recipient == msg.sender, "!recipient");

        address tokenIn = extractTokenAddressFromPath(params.path, 0);

        IERC20(tokenIn).transferFrom(
            address(msg.sender),
            address(this),
            params.amountIn
        );
        IERC20(tokenIn).approve(address(_swapRouter), params.amountIn);

        amountOut = _swapRouter.exactInput(params);
    }

    function tokensAreAllowed(bytes memory path) internal view returns (bool) {
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

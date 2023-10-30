// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISwapRouter} from "../interfaces/ISwapRouter.sol";

/// @title UniswapV3Adapter
/// @author Nocturne Labs
/// @notice Adapter contract for interacting with the Uniswap SwapRouter contract. Technically
///         Nocturne does not need an adapter but for the sake of avoiding attacks that bypass
///         deposit limits, we needed some calldata validation. This contract validates the tokenIn
///         of a single swap and path of a multi-hop swap to ensure no custom-deployed tokens are
///         used.
/// @dev This contract is Ownable and non-upgradeable. The only power the owner has is adding
///      and removing tokens from the whitelist.
contract UniswapV3Adapter is Ownable {
    // UniswapV3 SwapRouter
    ISwapRouter public immutable _swapRouter;

    // Whitelist of tokens that can be used in a path
    mapping(address => bool) public _allowedTokens;

    /// @notice Event emitted when a token is added to the whitelist
    event TokenPermissionSet(address token, bool permission);

    // Constructor, sets uniswap swap router contract
    constructor(address swapRouter) Ownable() {
        _swapRouter = ISwapRouter(swapRouter);
    }

    /// @notice Set token permission in whitelist
    /// @param token Token address
    /// @param permission Whether token is allowed
    function setTokenPermission(
        address token,
        bool permission
    ) external onlyOwner {
        _allowedTokens[token] = permission;
        emit TokenPermissionSet(token, permission);
    }

    /// @notice Proxy for exactInputSingle function of Uniswap SwapRouter. Ensures tokenIn and 
    ///         tokenOut are allowed and recipient is caller.
    /// @param params ExactInputSingleParams (see ISwapRouter)
    function exactInputSingle(
        ISwapRouter.ExactInputSingleParams memory params
    ) external returns (uint256 amountOut) {
        require(_allowedTokens[params.tokenIn], "!tokenIn");
        require(_allowedTokens[params.tokenOut], "!tokenOut");
        require(params.recipient == msg.sender, "!recipient");

        IERC20(params.tokenIn).transferFrom(
            address(msg.sender),
            address(this),
            params.amountIn
        );
        IERC20(params.tokenIn).approve(address(_swapRouter), params.amountIn);

        amountOut = _swapRouter.exactInputSingle(params);
    }

    /// @notice Proxy for exactInput function of Uniswap SwapRouter.
    ///         Ensures all tokens in path are is allowed and recipient is caller.
    /// @param params ExactInputParams (see ISwapRouter)
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

    /// @notice Checks that all tokens in path are allowed, returns false if any are not
    /// @param path Path of tokens
    /// @dev One Uniswap pool is denoted as (address tokenIn, uint24 poolFee, address tokenOut).
    ///      The path param describes which pools are used in the swap. Path is encoded as follows:
    ///      `(address tokenIn) || hops`, where `hops` is a sequence of `(uint24 fee, address
    ///      tokenOut)` pairs (i.e. for an intermediate hop, the tokenOut of the last hop is the
    ///      tokenIn of the next). The length of path will always be `20 + ((20 + 3) * N)` bytes.
    function tokensAreAllowed(bytes memory path) internal view returns (bool) {
        // NOTE: function reverts if path is not the correct length 20 + ((20 + 3) * n)
        uint256 numTokens = mustGetNumTokensInPath(path);

        for (uint256 i = 0; i < numTokens; i++) {
            address tokenAddress = extractTokenAddressFromPath(path, i);
            if (!_allowedTokens[tokenAddress]) {
                return false;
            }
        }

        return true;
    }

    function mustGetNumTokensInPath(
        bytes memory path
    ) internal pure returns (uint256) {
        uint256 length = path.length;

        // Ensure the path length is correct: ((20 + 3) * n) + 20
        require((length - 20) % 23 == 0, "Invalid path length");

        return (length - 20) / 23 + 1;
    }

    /// @notice Extracts token address from path at a given index into the path
    /// @param path Path of tokens
    /// @param tokenIndex Index of token in path, 0 for tokenIn, N for tokenOut for N hop path
    function extractTokenAddressFromPath(
        bytes memory path,
        uint256 tokenIndex
    ) internal pure returns (address) {
        // Load 32 bytes that are at offset 0 + 32 (length prefix) + index * 23 bytes
        // Shift right by 12 bytes to get the token address, which is first 20 bytes
        address tokenAddr;
        assembly {
            tokenAddr := shr(
                96,
                mload(add(add(path, 0x20), mul(tokenIndex, 0x17)))
            )
        }

        return tokenAddr;
    }
}

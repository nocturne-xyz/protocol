// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {TestUniswapV3Adapter} from "../harnesses/TestUniswapV3Adapter.sol";
import {ISwapRouter} from "../../interfaces/ISwapRouter.sol";

contract UniswapV3AdapterTest is Test {
    TestUniswapV3Adapter uniswapAdapter;
    address dummySwapRouter =
        address(0x1234567890123456789012345678901234567890);

    function setUp() public {
        uniswapAdapter = new TestUniswapV3Adapter(dummySwapRouter);
    }

    function generateRandomPath(
        uint256 seed,
        uint256 minNumHops
    )
        internal
        view
        returns (
            bytes memory path,
            address[] memory tokens,
            uint24[] memory fees
        )
    {
        uint256 numHops = bound(seed, minNumHops, 9);

        tokens = new address[](numHops + 1);
        fees = new uint24[](numHops);
        for (uint256 i = 0; i < numHops; i++) {
            tokens[i] = address(
                uint160(uint256(keccak256(abi.encodePacked(seed, i))))
            );
            fees[i] = uint24(uint256(keccak256(abi.encodePacked(seed, i + 1))));

            if (i + 1 == numHops) {
                tokens[i + 1] = address(
                    uint160(uint256(keccak256(abi.encodePacked(seed, i + 1))))
                );
            }
        }

        for (uint256 i = 0; i < numHops; i++) {
            if (i + 1 == numHops) {
                path = abi.encodePacked(path, tokens[i]);
                break;
            }

            path = abi.encodePacked(path, tokens[i], fees[i]);
        }
    }

    function testFuzz_ArbitraryTokenPathExtraction(uint256 seed) public {
        (
            bytes memory path,
            address[] memory tokens,
            uint24[] memory fees
        ) = generateRandomPath(seed, 1);
        uint256 numHops = fees.length;

        for (uint256 i = 0; i < numHops; i++) {
            address extractedToken = uniswapAdapter
                .testExtractTokenAddressFromPath(path, i * 23);
            assertEq(extractedToken, tokens[i]);
        }
    }

    function testFuzz_TokensInWhitelist(uint256 seed) public {
        (bytes memory path, address[] memory tokens, ) = generateRandomPath(
            seed,
            1
        );

        for (uint256 i = 0; i < tokens.length; i++) {
            uniswapAdapter.setTokenPermission(tokens[i], true);
        }

        bool isInWhitelist = uniswapAdapter.testTokensAreAllowed(path);
        assertTrue(isInWhitelist);
    }

    function testFuzz_TokensNotInWhitelist(uint256 seed) public {
        (
            bytes memory path,
            address[] memory tokens,
            uint24[] memory fees
        ) = generateRandomPath(seed, 2);

        uint256 tokenToWhitelistIndex = bound(seed, 0, fees.length);

        uniswapAdapter.setTokenPermission(tokens[tokenToWhitelistIndex], true);

        bool isInWhitelist = uniswapAdapter.testTokensAreAllowed(path);
        assertFalse(isInWhitelist, "Token should not be in whitelist");
    }
}

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

    function generateRandomPath(uint256 seed) internal returns(bytes memory path, address[] memory tokens, uint24[] memory fees) {
        uint256 numHops = bound(seed, 1, 9);

        tokens = new address[](numHops + 1);
        fees = new uint24[](numHops);
        for (uint256 i = 0; i < numHops; i++) {
            tokens[i] = address(uint160(uint256(keccak256(abi.encodePacked(seed, i)))));
            fees[i] = uint24(uint256(keccak256(abi.encodePacked(seed, i + 1))));

            if (i + 1 == numHops) {
                tokens[i + 1] = address(uint160(uint256(keccak256(abi.encodePacked(seed, i + 1)))));
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

    function testSettingSwapRouter() public {
        assertEq(
            address(uniswapAdapter._swapRouter()),
            dummySwapRouter,
            "SwapRouter should be set to dummySwapRouter"
        );
    }

    function testExtractTokenAddressFromPath() public {
        address dummyToken1 = address(0xaBCdEf123456789012345678901234567890AbCd);
        address dummyToken2 = address(0xfEDCbA987654321098765432109876543210fEdC);
        
        bytes memory path = abi.encodePacked(dummyToken1, uint24(0x000003), dummyToken2);
        
        address extractedToken1 = uniswapAdapter.testExtractTokenAddressFromPath(path, 0);
        assertEq(extractedToken1, dummyToken1, "First token extracted should be dummyToken1");
        
        address extractedToken2 = uniswapAdapter.testExtractTokenAddressFromPath(path, 23);  // 23 bytes offset to get to the next token
        assertEq(extractedToken2, dummyToken2, "Second token extracted should be dummyToken2");
    }

    function testTokenInWhitelist() public {
        address dummyToken = address(
            0xaBCdEf123456789012345678901234567890AbCd
        );
        uniswapAdapter.addToWhitelist(dummyToken);

        bool isInWhitelist = uniswapAdapter.tokensAreAllowed(
            abi.encodePacked(dummyToken, uint24(0x000003), dummyToken)
        );
        assertTrue(isInWhitelist, "Token should be in whitelist");
    }

    function testFuzz_ArbitraryTokenPath(uint256 seed) public {
        (bytes memory path, address[] memory tokens, uint24[] memory fees) = generateRandomPath(seed);
        uint256 numHops = fees.length;

        for (uint256 i = 0; i < numHops; i++) {
            address extractedToken = uniswapAdapter.testExtractTokenAddressFromPath(path, i * 23);
            assertEq(extractedToken, tokens[i], "Token extracted should be tokens[i]");
        }
    }

    function testFuzz_TokensNotInWhitelist() public {
        (bytes memory path, address[] memory tokens, uint24[] memory fees) = generateRandomPath(seed);
        uint256 numHops = fees.length;

        uniswapAdapter.addToWhitelist(tokens[0]);

        address dummyToken1 = address(
            0xaBCdEf123456789012345678901234567890AbCd
        );
        address dummyToken2 = address(
            0xfEDCbA987654321098765432109876543210fEdC
        );

        bool isInWhitelist = uniswapAdapter.tokensAreAllowed(
            abi.encodePacked(dummyToken1, uint24(0x000003), dummyToken2)
        );
        assertFalse(isInWhitelist, "Token should not be in whitelist");
    }
}

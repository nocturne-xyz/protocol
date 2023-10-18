// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {Utils} from "../../libs/Utils.sol";
import {TreeUtils} from "../../libs/TreeUtils.sol";
import {ParseUtils} from "../utils/ParseUtils.sol";

contract TestTreeUtils is Test {
    function testEncodePathAndHash() public {
        // test encoding with an accumulator hash whose hi bits are 011 and the 12th subtree
        uint256 idx = 12 * TreeUtils.BATCH_SIZE;
        uint256 accumulatorHash = (1 << 255) - 1;
        (uint256 hi, ) = TreeUtils.uint256ToFieldElemLimbs(accumulatorHash);
        assertEq(3, hi);

        uint256 encodedPathAndhash = TreeUtils.encodePathAndHash(
            uint128(idx),
            hi
        );

        // expect encodedPathAndHash to contain 011 as the hash bits and the most significant
        // 28 bits of the index of the idx for path bits
        uint256 expected = (3 <<
            (2 * (TreeUtils.DEPTH - TreeUtils.BATCH_SUBTREE_DEPTH))) |
            (idx >> (2 * TreeUtils.BATCH_SUBTREE_DEPTH));

        assertEq(expected, encodedPathAndhash);
    }

    function testSha256U256ArrayBE() public {
        uint256[] memory preimage = new uint256[](6);
        preimage[
            0
        ] = 8211457073961997158506488979239684278927357403782602045318568006344346608831;
        preimage[
            1
        ] = 16944372215571059891266649284950291224916108504672476006326749577154080514358;
        preimage[2] = 1;
        preimage[3] = 917551056842671309452305380979543736893630245704;
        preimage[4] = 5;
        preimage[5] = 100;

        bytes32 digest = TreeUtils.sha256U256ArrayBE(preimage);
        bytes32 expectedDigest = 0xb8c4f8495d1187262f374f23d92f892ccaa2336f819094ef59394ff138789a95;

        assertEq(expectedDigest, digest);
    }

    function testSplitUint256ToLimbs() public {
        uint256 n = 5 | (5 << 128);
        (uint256 hi, uint256 lo) = TreeUtils._splitUint256ToLimbs(n, 128);

        assertEq(5, hi);
        assertEq(5, lo);
    }

    function testUint256ToFieldElemLimbs() public {
        uint256 n = ((1 << 255) - 1) << 1;
        (uint256 hi, uint256 lo) = TreeUtils.uint256ToFieldElemLimbs(n);

        assertEq(7, hi);
        assertEq(n, lo + (hi << 253));
    }
}

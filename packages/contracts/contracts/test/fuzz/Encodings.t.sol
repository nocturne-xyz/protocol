// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {AssetUtils} from "../../libs/AssetUtils.sol";
import {TreeUtils} from "../../libs/TreeUtils.sol";
import "../../libs/Types.sol";

contract EncodingsTest is Test {
    function testFuzz_EncodeDecodeAsset(
        uint256 assetTypeUnbounded,
        address asset,
        uint256 id
    ) public {
        uint256 assetType = bound(assetTypeUnbounded, 0, 2);

        EncodedAsset memory encodedAsset = AssetUtils.encodeAsset(
            AssetType(assetType),
            asset,
            id
        );

        (
            AssetType decodedAssetType,
            address decodedAssetAddr,
            uint256 decodedId
        ) = AssetUtils.decodeAsset(encodedAsset);

        assertEq(uint256(decodedAssetType), uint256(assetType));
        assertEq(decodedAssetAddr, address(asset));
        assertEq(decodedId, id);
    }

    function testFuzz_EncodedPathAndHash(
        uint256 idxUnbounded,
        uint256 accumulatorHash
    ) public {
        uint256 largestBatchIndex = ((4 ** 16) / TreeUtils.BATCH_SIZE) - 1;
        uint256 batchIndex = bound(idxUnbounded, 0, largestBatchIndex);
        uint256 idx = batchIndex * TreeUtils.BATCH_SIZE;

        (uint256 hi, ) = TreeUtils.uint256ToFieldElemLimbs(accumulatorHash);

        uint256 encodedPathAndhash = TreeUtils.encodePathAndHash(
            uint128(idx),
            hi
        );

        uint256 expected = (hi <<
            (2 * (TreeUtils.DEPTH - TreeUtils.BATCH_SUBTREE_DEPTH))) |
            (idx >> (2 * TreeUtils.BATCH_SUBTREE_DEPTH));

        assertEq(expected, encodedPathAndhash);
    }

    function testFuzz_SplitUint256ToLimbs(
        uint8 lowerSplit,
        uint256 number
    ) public {
        (uint256 hi, uint256 lo) = TreeUtils._splitUint256ToLimbs(
            number,
            lowerSplit
        );

        assertEq(hi, number >> lowerSplit);
        assertEq(lo, number & ((1 << lowerSplit) - 1));
    }
}

// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "./Types.sol";
import "./Utils.sol";
import {AssetUtils} from "./AssetUtils.sol";

library Validation {
    uint256 constant MAX_NOTE_VALUE = (1 << 252) - 1; // value must fit in 252 bits
    uint256 constant ENCODED_ASSET_ADDR_MASK = ((1 << 163) - 1) | (7 << 249);
    uint256 constant MAX_ASSET_ID = (1 << 253) - 1;

    uint256 constant CURVE_A = 168700;
    uint256 constant CURVE_D = 168696;
    uint256 constant COMPRESSED_POINT_Y_MASK = ~uint256(1 << 254);

    function validateOperation(Operation calldata op) internal view {
        // Ensure public spend > 0 for public joinsplit. Ensures handler only deals
        // with assets that are actually unwrappable. If asset has > 0 public spend, then
        // circuit guarantees that note with the _revealed_ asset is included in the tree is
        // unwrappable. If asset has public spend = 0, circuit guarantees that the note with the
        // _masked_ asset is included in the tree and unwrappable, but the revealed asset for public
        // spend = 0 is (0,0) and is not unwrappable.
        for (uint256 i = 0; i < op.pubJoinSplits.length; i++) {
            require(op.pubJoinSplits[i].publicSpend > 0, "0 public spend");
        }

        // Ensure timestamp for op has not already expired
        require(block.timestamp <= op.deadline, "expired deadline");

        // Ensure gas asset is erc20 to ensure transfers to bundler retain control flow (no
        // callbacks/receiver hooks)
        (AssetType assetType, , ) = AssetUtils.decodeAsset(op.encodedGasAsset);
        require(assetType == AssetType.ERC20, "!gas erc20");
    }

    // Ensure note fields are also valid as circuit inputs
    function validateNote(EncodedNote memory note) internal pure {
        require(
            // nonce is a valid field element
            note.nonce < Utils.BN254_SCALAR_FIELD_MODULUS &&
                // encodedAssetAddr is a valid field element
                note.encodedAssetAddr < Utils.BN254_SCALAR_FIELD_MODULUS &&
                // encodedAssetAddr doesn't have any bits set outside bits 0-162 and 250-252
                note.encodedAssetAddr & (~ENCODED_ASSET_ADDR_MASK) == 0 &&
                // encodedAssetId is a 253 bit number (and therefore a valid field element)
                note.encodedAssetId <= MAX_ASSET_ID &&
                // value is < the 2^252 limit (and therefore a valid field element)
                note.value <= MAX_NOTE_VALUE,
            "invalid note"
        );

        validateCompressedBJJPoint(note.ownerH1);
        validateCompressedBJJPoint(note.ownerH2);
    }

    function validateCompressedBJJPoint(uint256 p) internal pure {
        // Clear X-sign bit. Leaves MSB untouched for the next check.
        uint256 y = p & COMPRESSED_POINT_Y_MASK;
        // Simultaneously check that the high-bit is unset and Y is a canonical field element
        // this works because y >= Utils.BN254_SCALAR_FIELD_MODULUS if high bit is set or y is not a valid field element
        require(y < Utils.BN254_SCALAR_FIELD_MODULUS, "invalid point");
    }
}

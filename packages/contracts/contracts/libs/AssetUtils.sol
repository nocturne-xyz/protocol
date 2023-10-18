// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import {Utils} from "../libs/Utils.sol";
import "../libs/Types.sol";

library AssetUtils {
    using SafeERC20 for IERC20;

    uint256 constant MASK_111 = 7;
    uint256 constant MASK_11 = 3;
    uint256 constant BITS_250_TO_252_MASK = (MASK_111 << 250);
    uint256 constant BOTTOM_253_MASK = (1 << 253) - 1;
    uint256 constant BOTTOM_160_MASK = (1 << 160) - 1;

    function encodeAsset(
        AssetType assetType,
        address assetAddr,
        uint256 id
    ) internal pure returns (EncodedAsset memory encodedAsset) {
        uint256 encodedAssetId = id & BOTTOM_253_MASK;
        uint256 assetTypeBits;
        if (assetType == AssetType.ERC20) {
            assetTypeBits = uint256(0);
        } else if (assetType == AssetType.ERC721) {
            assetTypeBits = uint256(1);
        } else if (assetType == AssetType.ERC1155) {
            assetTypeBits = uint256(2);
        } else {
            revert("Invalid assetType");
        }

        uint256 encodedAssetAddr = ((id >> 3) & BITS_250_TO_252_MASK) |
            (assetTypeBits << 160) |
            (uint256(uint160(assetAddr)));

        return
            EncodedAsset({
                encodedAssetAddr: encodedAssetAddr,
                encodedAssetId: encodedAssetId
            });
    }

    function decodeAsset(
        EncodedAsset memory encodedAsset
    )
        internal
        pure
        returns (AssetType assetType, address assetAddr, uint256 id)
    {
        id =
            ((encodedAsset.encodedAssetAddr & BITS_250_TO_252_MASK) << 3) |
            encodedAsset.encodedAssetId;
        assetAddr = address(
            uint160(encodedAsset.encodedAssetAddr & BOTTOM_160_MASK)
        );
        uint256 assetTypeBits = (encodedAsset.encodedAssetAddr >> 160) &
            MASK_11;
        if (assetTypeBits == 0) {
            assetType = AssetType.ERC20;
        } else if (assetTypeBits == 1) {
            assetType = AssetType.ERC721;
        } else if (assetTypeBits == 2) {
            assetType = AssetType.ERC1155;
        } else {
            revert("Invalid encodedAssetAddr");
        }
        return (assetType, assetAddr, id);
    }

    function hashEncodedAsset(
        EncodedAsset memory encodedAsset
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    encodedAsset.encodedAssetAddr,
                    encodedAsset.encodedAssetId
                )
            );
    }

    function balanceOfAsset(
        EncodedAsset memory encodedAsset
    ) internal view returns (uint256) {
        (AssetType assetType, address assetAddr, uint256 id) = AssetUtils
            .decodeAsset(encodedAsset);
        uint256 value = 0;
        if (assetType == AssetType.ERC20) {
            value = IERC20(assetAddr).balanceOf(address(this));
        } else if (assetType == AssetType.ERC721) {
            // If erc721 not minted, return balance = 0
            try IERC721(assetAddr).ownerOf(id) returns (address owner) {
                if (owner == address(this)) {
                    value = 1;
                }
            } catch {}
        } else if (assetType == AssetType.ERC1155) {
            value = IERC1155(assetAddr).balanceOf(address(this), id);
        } else {
            revert("Invalid asset");
        }

        return value;
    }

    /**
      @dev Transfer asset to receiver. Throws if unsuccssful.
    */
    function transferAssetTo(
        EncodedAsset memory encodedAsset,
        address receiver,
        uint256 value
    ) internal {
        (AssetType assetType, address assetAddr, ) = decodeAsset(encodedAsset);
        if (assetType == AssetType.ERC20) {
            IERC20(assetAddr).safeTransfer(receiver, value);
        } else if (assetType == AssetType.ERC721) {
            revert("!supported");
        } else if (assetType == AssetType.ERC1155) {
            revert("!supported");
        } else {
            revert("Invalid asset");
        }
    }

    /**
      @dev Transfer asset from spender. Throws if unsuccssful.
    */
    function transferAssetFrom(
        EncodedAsset memory encodedAsset,
        address spender,
        uint256 value
    ) internal {
        (AssetType assetType, address assetAddr, ) = decodeAsset(encodedAsset);
        if (assetType == AssetType.ERC20) {
            IERC20(assetAddr).safeTransferFrom(spender, address(this), value);
        } else if (assetType == AssetType.ERC721) {
            revert("!supported");
        } else if (assetType == AssetType.ERC1155) {
            revert("!supported");
        } else {
            revert("Invalid asset");
        }
    }

    /**
      @dev Approve asset to spender for value. Throws if unsuccssful.
    */
    function approveAsset(
        EncodedAsset memory encodedAsset,
        address spender,
        uint256 value
    ) internal {
        (AssetType assetType, address assetAddr, ) = decodeAsset(encodedAsset);

        if (assetType == AssetType.ERC20) {
            // TODO: next OZ release will add SafeERC20.forceApprove
            IERC20(assetAddr).approve(spender, 0);
            IERC20(assetAddr).approve(spender, value);
        } else if (assetType == AssetType.ERC721) {
            revert("!supported");
        } else if (assetType == AssetType.ERC1155) {
            revert("!supported");
        } else {
            revert("Invalid asset");
        }
    }

    function eq(
        EncodedAsset calldata assetA,
        EncodedAsset calldata assetB
    ) internal pure returns (bool) {
        return
            (assetA.encodedAssetAddr == assetB.encodedAssetAddr) &&
            (assetA.encodedAssetId == assetB.encodedAssetId);
    }
}

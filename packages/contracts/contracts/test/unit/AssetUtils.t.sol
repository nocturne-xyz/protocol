// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {AssetUtils} from "../../libs/AssetUtils.sol";
import {ISimpleERC20Token, ISimpleERC721Token, ISimpleERC1155Token} from "../tokens/ISimpleToken.sol";
import {SimpleERC20Token} from "../tokens/SimpleERC20Token.sol";
import {SimpleERC721Token} from "../tokens/SimpleERC721Token.sol";
import {SimpleERC1155Token} from "../tokens/SimpleERC1155Token.sol";
import "../../libs/Types.sol";

contract AssetUtilsTest is Test {
    SimpleERC20Token erc20;
    SimpleERC721Token erc721;
    SimpleERC1155Token erc1155;

    function setUp() public {
        erc20 = new SimpleERC20Token();
        erc721 = new SimpleERC721Token();
        erc1155 = new SimpleERC1155Token();
    }

    function testEncodeDecodeAssets() public {
        for (uint256 i = 0; i < 3; i++) {
            AssetType assetType = _uintToAssetType(i);
            address asset = _uintToAsset(i);
            uint256 id = 115792089237316195423570985008687907853269984665640564039457584007913129639933;

            EncodedAsset memory encodedAsset = AssetUtils.encodeAsset(
                assetType,
                address(asset),
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
    }

    function _uintToAssetType(uint256 i) internal pure returns (AssetType) {
        if (i == 0) {
            return AssetType.ERC20;
        } else if (i == 1) {
            return AssetType.ERC721;
        } else if (i == 2) {
            return AssetType.ERC1155;
        } else {
            revert("Invalid asset type");
        }
    }

    function _uintToAsset(uint256 i) internal view returns (address) {
        if (i == 0) {
            return address(erc20);
        } else if (i == 1) {
            return address(erc721);
        } else if (i == 2) {
            return address(erc1155);
        } else {
            revert("Invalid asset");
        }
    }
}

// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

interface ISimpleERC20Token is IERC20 {
    function reserveTokens(address account, uint256 amount) external;
}

interface ISimpleERC721Token is IERC721 {
    function reserveToken(address account, uint256 tokenId) external;
}

interface ISimpleERC1155Token is IERC1155 {
    function reserveTokens(
        address account,
        uint256 id,
        uint256 amount
    ) external;
}

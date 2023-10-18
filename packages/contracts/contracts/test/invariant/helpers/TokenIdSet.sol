// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

struct TokenIdSet {
    uint256[] tokenIds;
    mapping(uint256 => bool) saved;
}

library LibTokenIdSet {
    function getIds(
        TokenIdSet storage s
    ) internal view returns (uint256[] memory) {
        return s.tokenIds;
    }

    function add(TokenIdSet storage s, uint256 tokenId) internal {
        if (!s.saved[tokenId]) {
            s.tokenIds.push(tokenId);
            s.saved[tokenId] = true;
        }
    }

    function contains(
        TokenIdSet storage s,
        uint256 tokenId
    ) internal view returns (bool) {
        return s.saved[tokenId];
    }

    function count(TokenIdSet storage s) internal view returns (uint256) {
        return s.tokenIds.length;
    }

    function rand(
        TokenIdSet storage s,
        uint256 seed
    ) internal view returns (uint256) {
        if (s.tokenIds.length > 0) {
            return s.tokenIds[seed % s.tokenIds.length];
        } else {
            return 0;
        }
    }

    function forEach(
        TokenIdSet storage s,
        function(uint256) external func
    ) internal {
        for (uint256 i; i < s.tokenIds.length; ++i) {
            func(s.tokenIds[i]);
        }
    }

    function reduce(
        TokenIdSet storage s,
        uint256 acc,
        function(uint256, uint256) external returns (uint256) func
    ) internal returns (uint256) {
        for (uint256 i; i < s.tokenIds.length; ++i) {
            acc = func(acc, s.tokenIds[i]);
        }
        return acc;
    }
}

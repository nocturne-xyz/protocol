// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "../../libs/Types.sol";
import "forge-std/Vm.sol";

library EventParsing {
    function decodeDepositRequestFromDepositEvent(
        Vm.Log memory entry
    ) public pure returns (DepositRequest memory) {
        address spender = address(uint160(uint256(entry.topics[1])));
        (
            uint256 encodedAssetAddr,
            uint256 encodedAssetId,
            uint256 value,
            uint256 h1,
            uint256 h2,
            uint256 nonce,
            uint256 gasCompensation
        ) = abi.decode(
                entry.data,
                (uint256, uint256, uint256, uint256, uint256, uint256, uint256)
            );

        return
            DepositRequest({
                spender: spender,
                encodedAsset: EncodedAsset({
                    encodedAssetAddr: encodedAssetAddr,
                    encodedAssetId: encodedAssetId
                }),
                value: value,
                depositAddr: CompressedStealthAddress({h1: h1, h2: h2}),
                nonce: nonce,
                gasCompensation: gasCompensation
            });
    }

    function decodeNoteFromRefundProcessedEvent(
        Vm.Log memory entry
    ) public pure returns (EncodedNote memory) {
        (
            CompressedStealthAddress memory refundAddr,
            uint256 nonce,
            uint256 encodedAssetAddr,
            uint256 encodedAssetId,
            uint256 value
        ) = abi.decode(
                entry.data,
                ((CompressedStealthAddress), uint256, uint256, uint256, uint256)
            );

        return
            EncodedNote({
                ownerH1: refundAddr.h1,
                ownerH2: refundAddr.h2,
                nonce: nonce,
                encodedAssetAddr: encodedAssetAddr,
                encodedAssetId: encodedAssetId,
                value: value
            });
    }
}

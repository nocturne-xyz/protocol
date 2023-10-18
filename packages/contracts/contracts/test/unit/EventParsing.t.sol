// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import "../../libs/Types.sol";
import {NocturneUtils} from "../utils/NocturneUtils.sol";
import {EventParsing} from "../utils/EventParsing.sol";

contract EventParsingTest is Test {
    event DepositInstantiated(
        address indexed spender,
        EncodedAsset encodedAsset,
        uint256 value,
        CompressedStealthAddress depositAddr,
        uint256 nonce,
        uint256 gasCompensation
    );

    function testDecodeDepositRequestFromDepositEvent() public {
        vm.recordLogs();
        emit DepositInstantiated(
            address(0x1),
            EncodedAsset({encodedAssetAddr: 1, encodedAssetId: 2}),
            3,
            NocturneUtils.defaultStealthAddress(),
            4,
            5
        );

        Vm.Log[] memory entries = vm.getRecordedLogs();
        Vm.Log memory entry = entries[entries.length - 1];
        DepositRequest memory req = EventParsing
            .decodeDepositRequestFromDepositEvent(entry);

        assertEq(req.spender, address(0x1));
        assertEq(req.encodedAsset.encodedAssetAddr, 1);
        assertEq(req.encodedAsset.encodedAssetId, 2);
        assertEq(req.value, 3);
        assertEq(req.depositAddr.h1, NocturneUtils.defaultStealthAddress().h1);
        assertEq(req.depositAddr.h2, NocturneUtils.defaultStealthAddress().h2);
        assertEq(req.nonce, 4);
        assertEq(req.gasCompensation, 5);
    }
}

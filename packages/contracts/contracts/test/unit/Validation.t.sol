// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import "../../libs/Types.sol";
import {Validation} from "../../libs/Validation.sol";
import {AlgebraicUtils} from "../utils/AlgebraicUtils.sol";

// only for gas
contract TestValidation is Test {
    uint256 constant COMPRESSED_ADDR_H1 =
        16950150798460657717958625567821834550301663161624707787222815936182638968203;

    function testValidateNote() public pure {
        // Valid note passes
        EncodedNote memory note = EncodedNote(
            COMPRESSED_ADDR_H1,
            COMPRESSED_ADDR_H1,
            1,
            1,
            1,
            1
        );
        Validation.validateNote(note);
    }

    function testInvalidNonceFails() public {
        EncodedNote memory note = EncodedNote(
            COMPRESSED_ADDR_H1,
            COMPRESSED_ADDR_H1,
            type(uint256).max,
            1,
            1,
            1
        );
        vm.expectRevert("invalid note");
        Validation.validateNote(note);
    }

    function testInvalidOwnerFails() public {
        EncodedNote memory note = EncodedNote(
            type(uint256).max,
            type(uint256).max,
            1,
            1,
            1,
            1
        );
        vm.expectRevert("invalid point");
        Validation.validateNote(note);
    }

    function testInvalidAssetAddrFails() public {
        EncodedNote memory note = EncodedNote(
            COMPRESSED_ADDR_H1,
            COMPRESSED_ADDR_H1,
            1,
            type(uint256).max,
            1,
            1
        );
        vm.expectRevert("invalid note");
        Validation.validateNote(note);
    }

    function testInvalidAssetIdFails() public {
        EncodedNote memory note = EncodedNote(
            COMPRESSED_ADDR_H1,
            COMPRESSED_ADDR_H1,
            1,
            1,
            type(uint256).max,
            1
        );
        vm.expectRevert("invalid note");
        Validation.validateNote(note);
    }

    function testInvalidValueFails() public {
        EncodedNote memory note = EncodedNote(
            COMPRESSED_ADDR_H1,
            COMPRESSED_ADDR_H1,
            1,
            1,
            1,
            Validation.MAX_NOTE_VALUE + 1
        );
        vm.expectRevert("invalid note");
        Validation.validateNote(note);
    }
}

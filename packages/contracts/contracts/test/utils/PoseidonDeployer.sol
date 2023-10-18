// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {ParseUtils} from "./ParseUtils.sol";
import {IPoseidonT3, IPoseidonT4, IPoseidonT5, IPoseidonT6} from "../interfaces/IPoseidon.sol";
import {IPoseidonExtT3, IPoseidonExtT4, IPoseidonExtT7} from "../../interfaces/IPoseidonExt.sol";

contract PoseidonDeployer is Test {
    IPoseidonT3 _poseidonT3;
    IPoseidonT4 _poseidonT4;
    IPoseidonT5 _poseidonT5;
    IPoseidonT6 _poseidonT6;

    IPoseidonExtT3 _poseidonExtT3;
    IPoseidonExtT4 _poseidonExtT4;
    IPoseidonExtT7 _poseidonExtT7;

    function deployPoseidons() public {
        string memory root = vm.projectRoot();
        address[4] memory poseidonAddrs;

        for (uint8 i = 0; i < 4; i++) {
            bytes memory path = abi.encodePacked(
                bytes(root),
                "/packages/contracts/poseidon-bytecode/PoseidonT"
            );
            path = abi.encodePacked(path, bytes(Strings.toString(i + 3)));
            path = abi.encodePacked(path, ".txt");

            string memory bytecodeStr = vm.readFile(string(path));
            bytes memory bytecode = ParseUtils.hexToBytes(bytecodeStr);

            address deployed;
            assembly {
                deployed := create(0, add(bytecode, 0x20), mload(bytecode))
            }
            poseidonAddrs[i] = deployed;
        }

        _poseidonT3 = IPoseidonT3(poseidonAddrs[0]);
        _poseidonT4 = IPoseidonT4(poseidonAddrs[1]);
        _poseidonT5 = IPoseidonT5(poseidonAddrs[2]);
        _poseidonT6 = IPoseidonT6(poseidonAddrs[3]);
    }

    function deployPoseidonExts() public {
        string memory root = vm.projectRoot();
        address[3] memory poseidonAddrs;

        uint8[3] memory widths = [3, 4, 7];

        for (uint256 i = 0; i < 3; i++) {
            bytes memory path = abi.encodePacked(
                bytes(root),
                "/packages/contracts/poseidon-bytecode/PoseidonExtT"
            );
            path = abi.encodePacked(path, bytes(Strings.toString(widths[i])));
            path = abi.encodePacked(path, ".txt");

            string memory bytecodeStr = vm.readFile(string(path));
            bytes memory bytecode = ParseUtils.hexToBytes(bytecodeStr);

            address deployed;
            assembly {
                deployed := create(0, add(bytecode, 0x20), mload(bytecode))
            }
            poseidonAddrs[i] = deployed;
        }

        _poseidonExtT3 = IPoseidonExtT3(poseidonAddrs[0]);
        _poseidonExtT4 = IPoseidonExtT4(poseidonAddrs[1]);
        _poseidonExtT7 = IPoseidonExtT7(poseidonAddrs[2]);
    }
}

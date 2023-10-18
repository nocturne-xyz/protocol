// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import {EthTransferAdapter} from "../adapters/EthTransferAdapter.sol";

contract DeployEthTransferAdapter is Script {
    address wethAddress;

    function loadEnvVars() public {
        wethAddress = vm.envAddress("WETH_ADDRESS");
    }

    function run() external {
        loadEnvVars();

        vm.startBroadcast();
        new EthTransferAdapter(wethAddress);
        vm.stopBroadcast();
    }
}

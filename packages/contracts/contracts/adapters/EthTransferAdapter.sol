// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import {IWeth} from "../interfaces/IWeth.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/// @title EthTransferAdapter
/// @author Nocturne Labs
/// @notice Adapter contract for converting weth to eth and transfering eth to specified address.
///         The Handler contract does not support ETH value transfers directly, thus we need a thin
///         adapter for handling the weth -> eth step then transferring the eth.
/// @dev Note that we ensure the recipient is is an EOA to avoid reentrancy. Reentrancy would allow
///      a recipient to send back funds to the Handler and bypass deposit limits.
contract EthTransferAdapter {
    // Weth contract
    IWeth public _weth;

    // Constructor, takes weth
    constructor(address weth) {
        _weth = IWeth(weth);
    }

    // Receive eth when withdrawing weth to eth
    receive() external payable {}

    /// @notice Convert weth to eth and send to recipient
    /// @param to Recipient address
    /// @param value Amount of weth to convert and send
    /// @dev We ensure recipient is EOA to avoid reentrancy (which could help attacker bypass
    ///      deposit limits).
    /// @dev Gas optimization where we keep weth balance from resetting to 0 does not require any
    ///      additional code. If weth is force-sent to this contract outside, it will be stuck
    ///      here forever.
    function transfer(address to, uint256 value) external {
        require(to.code.length == 0, "!eoa");
        _weth.transferFrom(msg.sender, address(this), value);
        _weth.withdraw(value);
        Address.sendValue(payable(to), value);
    }
}

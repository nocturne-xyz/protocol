// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import {IWeth} from "../interfaces/IWeth.sol";
import {IWsteth} from "../interfaces/IWsteth.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/// @title WstethAdapter
/// @author Nocturne Labs
/// @notice Adapter contract for interacting with wsteth. The Handler contract does not support ETH
///         value transfers directly, thus we need a thin adapter for handling the weth -> eth step
///         when depositing weth to wsteth.
contract WstethAdapter {
    // Weth contract
    IWeth public _weth;

    // Wsteth contract
    IWsteth public _wsteth;

    // Constructor, takes weth and wsteth
    constructor(address weth, address wsteth) {
        _weth = IWeth(weth);
        _wsteth = IWsteth(wsteth);
    }

    // Receive eth when withdrawing weth to eth
    receive() external payable {}

    /// @notice Convert weth to wsteth for caller
    /// @param amount Amount of weth to deposit
    /// @dev Transfers weth to self, unwraps to eth, deposits eth and gets back wsteth, then
    ///      transfers wsteth back to caller.
    /// @dev We attempt to withhold tokens previously force-sent to adapter so we can avoid wsteth
    ///      balance from resetting to 0 (gas optimization).
    function deposit(uint256 amount) external {
        _weth.transferFrom(msg.sender, address(this), amount);
        _weth.withdraw(amount);

        // Get balance of wsteth before conversion so we can attempt to withhold before sending
        // wsteth back (gas optimization to keep wsteth in balance from resetting to 0)
        uint256 wstethBalancePre = _wsteth.balanceOf(address(this));

        // Deposit ETH to wsteth contract, get back wsteth
        Address.sendValue(payable(address(_wsteth)), amount);

        // Send back wsteth to caller
        _wsteth.transfer(
            msg.sender,
            _wsteth.balanceOf(address(this)) - wstethBalancePre
        );
    }
}

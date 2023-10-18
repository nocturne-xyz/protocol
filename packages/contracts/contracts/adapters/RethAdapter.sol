// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import {IWeth} from "../interfaces/IWeth.sol";
import {IReth} from "../interfaces/IReth.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IRocketStorage} from "../interfaces/IRocketStorage.sol";
import {IRocketDepositPool} from "../interfaces/IRocketDepositPool.sol";

/// @title RethAdapter
/// @author Nocturne Labs
/// @notice Adapter contract for interacting with reth. The Handler contract does not support ETH
///         value transfers directly, thus we need a thin adapter for handling the weth -> eth step
///         when depositing weth to reth.
contract RethAdapter {
    // Weth contract
    IWeth public _weth;

    // Rocket pool storage interface
    IRocketStorage _rocketStorage;

    // Constructor, takes weth and reth
    constructor(address weth, address rocketStorage) {
        _weth = IWeth(weth);
        _rocketStorage = IRocketStorage(rocketStorage);
    }

    // Receive eth when withdrawing weth to eth
    receive() external payable {}

    /// @notice Convert weth to reth for caller by calling rocket pool deposit pool
    /// @param amount Amount of weth to deposit
    /// @dev Transfers weth to self, unwraps to eth, deposits eth and gets back reth, then
    ///      transfers reth back to caller.
    /// @dev We attempt to withhold tokens previously force-sent to adapter so we can avoid reth
    ///      balance from resetting to 0 (gas optimization).
    function deposit(uint256 amount) external {
        _weth.transferFrom(msg.sender, address(this), amount);
        _weth.withdraw(amount);

        // Get balance of reth before conversion so we can attempt to withhold before sending
        // reth back (gas optimization to keep reth in balance from resetting to 0)
        IReth reth = IReth(
            _rocketStorage.getAddress(
                keccak256(
                    abi.encodePacked("contract.address", "rocketTokenRETH")
                )
            )
        );
        uint256 rethBalancePre = reth.balanceOf(address(this));

        // Deposit ETH into rocket pool, get back reth
        IRocketDepositPool rocketDepositPool = IRocketDepositPool(
            _rocketStorage.getAddress(
                keccak256(
                    abi.encodePacked("contract.address", "rocketDepositPool")
                )
            )
        );
        rocketDepositPool.deposit{value: amount}();

        // Send back reth to caller
        reth.transfer(
            msg.sender,
            reth.balanceOf(address(this)) - rethBalancePre
        );
    }
}

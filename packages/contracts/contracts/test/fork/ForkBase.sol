// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {NocturneUtils} from "../utils/NocturneUtils.sol";
import {Teller} from "../../Teller.sol";
import {Handler} from "../../Handler.sol";
import {TestJoinSplitVerifier} from "../harnesses/TestJoinSplitVerifier.sol";
import {TestSubtreeUpdateVerifier} from "../harnesses/TestSubtreeUpdateVerifier.sol";
import {PoseidonDeployer} from "../utils/PoseidonDeployer.sol";
import "../../libs/Types.sol";
import "../../libs/AssetUtils.sol";

contract ForkBase is Test, PoseidonDeployer {
    address public constant DEPOSIT_SOURCE = address(0x111);
    address public constant ALICE = address(0x222);
    address public constant BUNDLER = address(0x333);

    Teller teller;
    Handler handler;

    function baseSetUp() public {
        deployPoseidonExts();

        teller = new Teller();
        handler = new Handler();

        TestJoinSplitVerifier joinSplitVerifier = new TestJoinSplitVerifier();
        TestSubtreeUpdateVerifier subtreeUpdateVerifier = new TestSubtreeUpdateVerifier();

        teller.initialize(
            "NocturneTeller",
            "v1",
            address(handler),
            address(joinSplitVerifier),
            address(_poseidonExtT7)
        );
        handler.initialize(address(subtreeUpdateVerifier), address(0x111));
        handler.setTeller(address(teller));

        teller.setDepositSourcePermission(DEPOSIT_SOURCE, true);
        handler.setSubtreeBatchFillerPermission(address(this), true);
    }

    function reserveAndDeposit(address token, uint256 amount) internal {
        deal(address(token), DEPOSIT_SOURCE, amount);

        CompressedStealthAddress memory addr = NocturneUtils
            .defaultStealthAddress();
        Deposit memory deposit = NocturneUtils.formatDeposit(
            ALICE,
            address(token),
            amount,
            ERC20_ID,
            addr
        );

        vm.prank(DEPOSIT_SOURCE);
        IERC20(token).approve(address(teller), amount);

        vm.prank(DEPOSIT_SOURCE);
        teller.depositFunds(deposit);
    }
}

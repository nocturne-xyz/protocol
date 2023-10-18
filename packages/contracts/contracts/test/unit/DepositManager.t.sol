// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";

import "../../libs/Types.sol";
import {NocturneUtils} from "../utils/NocturneUtils.sol";
import {ParseUtils} from "../utils/ParseUtils.sol";
import {EventParsing} from "../utils/EventParsing.sol";
import {AssetUtils} from "../../libs/AssetUtils.sol";
import {TestDepositManager} from "../harnesses/TestDepositManager.sol";
import {Handler} from "../../Handler.sol";
import {Teller} from "../../Teller.sol";
import {TestJoinSplitVerifier} from "../harnesses/TestJoinSplitVerifier.sol";
import {TestSubtreeUpdateVerifier} from "../harnesses/TestSubtreeUpdateVerifier.sol";
import {SimpleERC20Token} from "../tokens/SimpleERC20Token.sol";
import {WETH9} from "../tokens/WETH9.sol";
import {PoseidonDeployer} from "../utils/PoseidonDeployer.sol";

contract DepositManagerTest is Test, PoseidonDeployer {
    Teller public teller;
    Handler public handler;
    TestDepositManager public depositManager;
    WETH9 public weth;

    SimpleERC20Token[3] ERC20s;

    string constant CONTRACT_NAME = "NocturneDepositManager";
    string constant CONTRACT_VERSION = "v1";

    address constant ALICE = address(1);
    address constant BOB = address(2);
    uint256 constant SCREENER_PRIVKEY = 1;
    address SCREENER = vm.addr(SCREENER_PRIVKEY);

    uint256 constant RESERVE_AMOUNT = 50_000_000;
    uint256 constant GAS_COMP_AMOUNT = 150_000 * 50 gwei;

    uint32 constant MAX_DEPOSIT_SIZE = 100_000_000;
    uint32 constant GLOBAL_CAP = 1_000_000_000;

    event DepositInstantiated(
        address indexed spender,
        EncodedAsset encodedAsset,
        uint256 value,
        CompressedStealthAddress depositAddr,
        uint256 nonce,
        uint256 gasCompensation
    );

    event DepositRetrieved(
        address indexed spender,
        EncodedAsset encodedAsset,
        uint256 value,
        CompressedStealthAddress depositAddr,
        uint256 nonce,
        uint256 gasCompensation
    );

    event DepositCompleted(
        address indexed spender,
        EncodedAsset encodedAsset,
        uint256 value,
        CompressedStealthAddress depositAddr,
        uint256 nonce,
        uint256 gasCompensation,
        uint128 merkleIndex
    );

    function setUp() public virtual {
        deployPoseidonExts();

        teller = new Teller();
        handler = new Handler();
        weth = new WETH9();

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

        depositManager = new TestDepositManager();
        depositManager.initialize(
            CONTRACT_NAME,
            CONTRACT_VERSION,
            address(teller),
            address(weth)
        );

        depositManager.setScreenerPermission(SCREENER, true);
        teller.setDepositSourcePermission(address(depositManager), true);

        handler.setContractPermission(address(weth), true);
        handler.setContractMethodPermission(
            address(weth),
            weth.approve.selector,
            true
        );
        handler.setContractMethodPermission(
            address(weth),
            weth.transfer.selector,
            true
        );

        depositManager.setErc20Cap(
            address(weth),
            GLOBAL_CAP,
            MAX_DEPOSIT_SIZE,
            uint8(1),
            18
        );

        // Instantiate token contracts
        for (uint256 i = 0; i < 3; i++) {
            ERC20s[i] = new SimpleERC20Token();

            handler.setContractPermission(address(ERC20s[i]), true);
            handler.setContractMethodPermission(
                address(ERC20s[i]),
                ERC20s[i].approve.selector,
                true
            );
            handler.setContractMethodPermission(
                address(ERC20s[i]),
                ERC20s[i].transfer.selector,
                true
            );

            depositManager.setErc20Cap(
                address(ERC20s[i]),
                GLOBAL_CAP,
                MAX_DEPOSIT_SIZE,
                uint8(1),
                18
            );
        }
    }

    function testSetErc20CapSuccess() public {
        SimpleERC20Token token = ERC20s[0];
        uint32 globalCapWholeTokens = 1_000;
        uint32 maxDepositSizeWholeTokens = 100;
        uint8 precision = 18;

        depositManager.setErc20Cap(
            address(token),
            globalCapWholeTokens,
            maxDepositSizeWholeTokens,
            uint8(1),
            precision
        );

        (
            uint128 _runningGlobalDeposited,
            uint32 _globalCapWholeTokens,
            uint32 _maxDepositSizeWholeTokens,
            uint32 _lastResetTimestamp,
            uint8 _resetWindowHours,
            uint8 _precision
        ) = depositManager._erc20Caps(address(token));
        assertEq(_runningGlobalDeposited, 0);
        assertEq(_globalCapWholeTokens, globalCapWholeTokens);
        assertEq(_maxDepositSizeWholeTokens, maxDepositSizeWholeTokens);
        assertEq(_lastResetTimestamp, block.timestamp);
        assertEq(_resetWindowHours, 1);
        assertEq(_precision, precision);
    }

    function testSetErc20CapFailureOutOfBounds() public {
        SimpleERC20Token token = ERC20s[0];
        uint32 globalCapWholeTokens = uint32(type(uint128).max / (10 ** 18)) +
            5;
        uint32 maxDepositSizeWholeTokens = 100;
        uint8 precision = 50;

        vm.expectRevert("globalCap > uint128.max");
        depositManager.setErc20Cap(
            address(token),
            globalCapWholeTokens,
            maxDepositSizeWholeTokens,
            uint8(1),
            precision
        );

        globalCapWholeTokens = 1_000;
        precision = 18;

        vm.expectRevert("maxDepositSize > globalCap");
        depositManager.setErc20Cap(
            address(token),
            globalCapWholeTokens,
            globalCapWholeTokens + 1,
            uint8(1),
            precision
        );
    }

    function testInstantiateDepositSuccess() public {
        SimpleERC20Token token = ERC20s[0];
        deal(address(token), ALICE, RESERVE_AMOUNT);

        uint256 depositAmount = RESERVE_AMOUNT / 2;

        // Approve 25M tokens for deposit
        vm.prank(ALICE);
        token.approve(address(depositManager), depositAmount);

        DepositRequest memory deposit = NocturneUtils.formatDepositRequest(
            ALICE,
            address(token),
            depositAmount,
            ERC20_ID,
            NocturneUtils.defaultStealthAddress(),
            depositManager._nonce(),
            GAS_COMP_AMOUNT // 10M gas comp
        );

        // Deposit hash not yet marked true and ETH balance empty
        bytes32 depositHash = depositManager.hashDepositRequest(deposit);
        assertFalse(depositManager._outstandingDepositHashes(depositHash));
        assertEq(address(depositManager).balance, 0);

        // Set ALICE balance to 10M wei
        vm.deal(ALICE, GAS_COMP_AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit DepositInstantiated(
            deposit.spender,
            deposit.encodedAsset,
            deposit.value,
            deposit.depositAddr,
            deposit.nonce,
            deposit.gasCompensation
        );
        vm.prank(ALICE);

        uint256[] memory depositAmounts = new uint256[](1);
        depositAmounts[0] = depositAmount;
        depositManager.instantiateErc20MultiDeposit{value: GAS_COMP_AMOUNT}(
            address(token),
            depositAmounts,
            NocturneUtils.defaultStealthAddress()
        );

        // Deposit hash marked true
        assertTrue(depositManager._outstandingDepositHashes(depositHash));

        // Token escrowed by manager contract
        assertEq(token.balanceOf(address(depositManager)), deposit.value);
        assertEq(address(depositManager).balance, GAS_COMP_AMOUNT);
        assertEq(ALICE.balance, 0);
    }

    function testInstantiateETHDepositSuccess() public {
        uint256 depositAmount = GAS_COMP_AMOUNT;
        DepositRequest memory deposit = NocturneUtils.formatDepositRequest(
            ALICE,
            address(weth),
            depositAmount,
            ERC20_ID,
            NocturneUtils.defaultStealthAddress(),
            depositManager._nonce(),
            GAS_COMP_AMOUNT // 10M gas comp
        );

        // Deposit hash not yet marked true and ETH balance empty
        bytes32 depositHash = depositManager.hashDepositRequest(deposit);
        assertFalse(depositManager._outstandingDepositHashes(depositHash));
        assertEq(address(depositManager).balance, 0);

        // Set ALICE balance to 20M wei, enough for deposit and gas comp
        vm.deal(ALICE, GAS_COMP_AMOUNT + depositAmount);

        vm.expectEmit(true, true, true, true);
        emit DepositInstantiated(
            deposit.spender,
            deposit.encodedAsset,
            deposit.value,
            deposit.depositAddr,
            deposit.nonce,
            deposit.gasCompensation
        );
        vm.prank(ALICE);

        uint256[] memory depositAmounts = new uint256[](1);
        depositAmounts[0] = depositAmount;
        depositManager.instantiateETHMultiDeposit{
            value: GAS_COMP_AMOUNT + depositAmount
        }(depositAmounts, NocturneUtils.defaultStealthAddress());

        // Deposit hash marked true
        assertTrue(depositManager._outstandingDepositHashes(depositHash));

        // Token + eth escrowed by manager contract
        assertEq(weth.balanceOf(address(depositManager)), depositAmount);
        assertEq(address(depositManager).balance, GAS_COMP_AMOUNT);
        assertEq(ALICE.balance, 0);
    }

    function testInstantiateETHDepositNotEnoughETH() public {
        uint256 depositAmount = GAS_COMP_AMOUNT;

        // Set ALICE balance to 20M wei, enough for deposit and gas comp
        vm.deal(ALICE, GAS_COMP_AMOUNT + depositAmount);
        vm.expectRevert("msg.value < deposit weth");
        vm.prank(ALICE);

        uint256[] memory depositAmounts = new uint256[](1);
        depositAmounts[0] = depositAmount;
        depositManager.instantiateETHMultiDeposit{value: depositAmount - 1}(
            depositAmounts,
            NocturneUtils.defaultStealthAddress()
        );
    }

    function testInstantiateDepositFailureUnsupportedToken() public {
        SimpleERC20Token token = new SimpleERC20Token();
        deal(address(token), ALICE, RESERVE_AMOUNT);

        vm.prank(ALICE);
        token.approve(address(depositManager), RESERVE_AMOUNT);

        vm.deal(ALICE, GAS_COMP_AMOUNT);
        vm.prank(ALICE);
        vm.expectRevert("!supported erc20");

        uint256[] memory depositAmounts = new uint256[](1);
        depositAmounts[0] = RESERVE_AMOUNT;
        depositManager.instantiateErc20MultiDeposit{value: GAS_COMP_AMOUNT}(
            address(token),
            depositAmounts,
            NocturneUtils.defaultStealthAddress()
        );
    }

    function testInstantiateDepositFailureExceedsMaxDepositSize() public {
        uint256 overMaxSizeAmount = (uint256(MAX_DEPOSIT_SIZE) * (10 ** 18)) +
            1;
        SimpleERC20Token token = ERC20s[0];
        deal(address(token), ALICE, overMaxSizeAmount);

        vm.prank(ALICE);
        token.approve(address(depositManager), overMaxSizeAmount);

        vm.deal(ALICE, GAS_COMP_AMOUNT);
        vm.prank(ALICE);
        vm.expectRevert("maxDepositSize exceeded");

        uint256[] memory depositAmounts = new uint256[](1);
        depositAmounts[0] = overMaxSizeAmount;
        depositManager.instantiateErc20MultiDeposit{value: GAS_COMP_AMOUNT}(
            address(token),
            depositAmounts,
            NocturneUtils.defaultStealthAddress()
        );
    }

    function testRetrieveDepositSuccess() public {
        SimpleERC20Token token = ERC20s[0];
        deal(address(token), ALICE, RESERVE_AMOUNT);

        // Approve all 50M tokens for deposit
        vm.prank(ALICE);
        token.approve(address(depositManager), RESERVE_AMOUNT);

        DepositRequest memory deposit = NocturneUtils.formatDepositRequest(
            ALICE,
            address(token),
            RESERVE_AMOUNT,
            ERC20_ID,
            NocturneUtils.defaultStealthAddress(),
            depositManager._nonce(),
            GAS_COMP_AMOUNT
        );
        bytes32 depositHash = depositManager.hashDepositRequest(deposit);

        // Call instantiateDeposit
        vm.deal(ALICE, GAS_COMP_AMOUNT);
        vm.prank(ALICE);

        uint256[] memory depositAmounts = new uint256[](1);
        depositAmounts[0] = RESERVE_AMOUNT;
        depositManager.instantiateErc20MultiDeposit{value: GAS_COMP_AMOUNT}(
            address(token),
            depositAmounts,
            NocturneUtils.defaultStealthAddress()
        );

        // Deposit hash marked true
        assertTrue(depositManager._outstandingDepositHashes(depositHash));

        // Token escrowed by manager contract
        assertEq(token.balanceOf(address(depositManager)), deposit.value);

        // Eth received
        assertEq(address(depositManager).balance, GAS_COMP_AMOUNT);
        assertEq(ALICE.balance, 0);

        // Call retrieveDeposit
        vm.expectEmit(true, true, true, true);
        emit DepositRetrieved(
            deposit.spender,
            deposit.encodedAsset,
            deposit.value,
            deposit.depositAddr,
            deposit.nonce,
            deposit.gasCompensation
        );
        vm.prank(ALICE);
        depositManager.retrieveDeposit(deposit);

        // Deposit hash marked false again
        assertFalse(depositManager._outstandingDepositHashes(depositHash));

        // Token sent back to user
        assertEq(token.balanceOf(address(depositManager)), 0);
        assertEq(token.balanceOf(address(ALICE)), deposit.value);

        // Eth gas sent back to user
        assertEq(address(depositManager).balance, 0);
        assertEq(ALICE.balance, GAS_COMP_AMOUNT);
    }

    function testRetrieveETHDepositSuccess() public {
        uint256 depositAmount = GAS_COMP_AMOUNT;
        DepositRequest memory deposit = NocturneUtils.formatDepositRequest(
            ALICE,
            address(weth),
            depositAmount,
            ERC20_ID,
            NocturneUtils.defaultStealthAddress(),
            depositManager._nonce(),
            GAS_COMP_AMOUNT // 10M gas comp
        );

        // Deposit hash not yet marked true and ETH balance empty
        bytes32 depositHash = depositManager.hashDepositRequest(deposit);
        assertFalse(depositManager._outstandingDepositHashes(depositHash));
        assertEq(address(depositManager).balance, 0);

        // Set ALICE balance to enough for deposit and gas comp
        vm.deal(ALICE, GAS_COMP_AMOUNT + depositAmount);
        vm.prank(ALICE);

        uint256[] memory depositAmounts = new uint256[](1);
        depositAmounts[0] = depositAmount;
        depositManager.instantiateETHMultiDeposit{
            value: GAS_COMP_AMOUNT + depositAmount
        }(depositAmounts, NocturneUtils.defaultStealthAddress());

        // Deposit hash marked true
        assertTrue(depositManager._outstandingDepositHashes(depositHash));

        // ETH escrowed by manager contract
        assertEq(weth.balanceOf(address(depositManager)), deposit.value);

        // Eth received
        assertEq(address(depositManager).balance, GAS_COMP_AMOUNT);
        assertEq(ALICE.balance, 0);

        // Call retrieveDeposit
        vm.expectEmit(true, true, true, true);
        emit DepositRetrieved(
            deposit.spender,
            deposit.encodedAsset,
            deposit.value,
            deposit.depositAddr,
            deposit.nonce,
            deposit.gasCompensation
        );
        vm.prank(ALICE);
        depositManager.retrieveETHDeposit(deposit);

        // Deposit hash marked false again
        assertFalse(depositManager._outstandingDepositHashes(depositHash));

        // All eth sent back to user
        assertEq(weth.balanceOf(address(depositManager)), 0);
        assertEq(ALICE.balance, GAS_COMP_AMOUNT + deposit.value);
    }

    function testRetrieveDepositFailureNotSpender() public {
        SimpleERC20Token token = ERC20s[0];
        deal(address(token), ALICE, RESERVE_AMOUNT);

        // Approve all 50M tokens for deposit
        vm.prank(ALICE);
        token.approve(address(depositManager), RESERVE_AMOUNT);

        DepositRequest memory deposit = NocturneUtils.formatDepositRequest(
            ALICE,
            address(token),
            RESERVE_AMOUNT,
            ERC20_ID,
            NocturneUtils.defaultStealthAddress(),
            depositManager._nonce(),
            0
        );

        // Call instantiateDeposit
        vm.prank(ALICE);

        uint256[] memory depositAmounts = new uint256[](1);
        depositAmounts[0] = RESERVE_AMOUNT;
        depositManager.instantiateErc20MultiDeposit(
            address(token),
            depositAmounts,
            NocturneUtils.defaultStealthAddress()
        );

        // Call retrieveDeposit, but prank as BOB
        vm.expectRevert("Only spender can retrieve deposit");
        vm.prank(BOB);
        depositManager.retrieveDeposit(deposit);
    }

    function testRetrieveDepositFailureNoDeposit() public {
        SimpleERC20Token token = ERC20s[0];
        deal(address(token), ALICE, RESERVE_AMOUNT);

        // Create deposit request but never instantiate deposit with it
        DepositRequest memory deposit = NocturneUtils.formatDepositRequest(
            ALICE,
            address(token),
            RESERVE_AMOUNT,
            ERC20_ID,
            NocturneUtils.defaultStealthAddress(),
            depositManager._nonce(),
            0
        );

        vm.expectRevert("deposit !exists");
        vm.prank(ALICE);
        depositManager.retrieveDeposit(deposit);
    }

    function testCompleteDepositSuccessSingle() public {
        SimpleERC20Token token = ERC20s[0];
        deal(address(token), ALICE, RESERVE_AMOUNT);

        // Approve 50M tokens for deposit
        vm.prank(ALICE);
        token.approve(address(depositManager), RESERVE_AMOUNT);

        DepositRequest memory deposit = NocturneUtils.formatDepositRequest(
            ALICE,
            address(token),
            RESERVE_AMOUNT,
            ERC20_ID,
            NocturneUtils.defaultStealthAddress(),
            depositManager._nonce(),
            GAS_COMP_AMOUNT // 10M gas comp
        );

        bytes32 depositHash = depositManager.hashDepositRequest(deposit);

        vm.deal(ALICE, GAS_COMP_AMOUNT);
        vm.prank(ALICE);

        uint256[] memory depositAmounts = new uint256[](1);
        depositAmounts[0] = RESERVE_AMOUNT;
        depositManager.instantiateErc20MultiDeposit{value: GAS_COMP_AMOUNT}(
            address(token),
            depositAmounts,
            NocturneUtils.defaultStealthAddress()
        );

        // Deposit hash marked true
        assertTrue(depositManager._outstandingDepositHashes(depositHash));

        // Deposit manager has tokens and gas funds
        assertEq(token.balanceOf(address(depositManager)), RESERVE_AMOUNT);
        assertEq(address(depositManager).balance, GAS_COMP_AMOUNT);

        bytes32 digest = depositManager.computeDigest(deposit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SCREENER_PRIVKEY, digest);
        bytes memory signature = ParseUtils.rsvToSignatureBytes(
            uint256(r),
            uint256(s),
            v
        );

        uint128 merkleIndex = handler.totalCount();

        vm.expectEmit(true, true, true, false);
        emit DepositCompleted(
            deposit.spender,
            deposit.encodedAsset,
            deposit.value,
            deposit.depositAddr,
            deposit.nonce,
            deposit.gasCompensation,
            merkleIndex
        );

        vm.prank(SCREENER);
        vm.txGasPrice(30 gwei);
        depositManager.completeErc20Deposit(deposit, signature);

        // Deposit hash marked false again
        assertFalse(depositManager._outstandingDepositHashes(depositHash));

        // Ensure teller now has ALICE's tokens
        assertEq(token.balanceOf(address(teller)), RESERVE_AMOUNT);
        assertEq(token.balanceOf(address(depositManager)), 0);

        // Ensure bundler has > 0 eth but ALICE has < GAS_COMP_AMOUNT eth
        assertEq(address(depositManager).balance, 0);
        assertGt(SCREENER.balance, 0);
        assertLt(ALICE.balance, GAS_COMP_AMOUNT);
    }

    function testCompleteDepositSuccessMulti() public {
        SimpleERC20Token token = ERC20s[0];

        uint256 numDeposits = 10;
        uint256[] memory depositAmounts = new uint256[](numDeposits);
        for (uint256 i = 0; i < numDeposits; i++) {
            depositAmounts[i] = RESERVE_AMOUNT;
        }

        deal(address(token), ALICE, RESERVE_AMOUNT * numDeposits);

        // Approve 50M tokens for deposit
        vm.prank(ALICE);
        token.approve(address(depositManager), RESERVE_AMOUNT * numDeposits);

        DepositRequest[] memory deposits = new DepositRequest[](numDeposits);
        bytes32[] memory depositHashes = new bytes32[](numDeposits);
        for (uint256 i = 0; i < numDeposits; i++) {
            deposits[i] = NocturneUtils.formatDepositRequest(
                ALICE,
                address(token),
                RESERVE_AMOUNT,
                ERC20_ID,
                NocturneUtils.defaultStealthAddress(),
                depositManager._nonce() + i,
                GAS_COMP_AMOUNT // 10M gas comp
            );
            depositHashes[i] = depositManager.hashDepositRequest(deposits[i]);
        }

        vm.deal(ALICE, GAS_COMP_AMOUNT * numDeposits);
        vm.prank(ALICE);
        depositManager.instantiateErc20MultiDeposit{
            value: GAS_COMP_AMOUNT * numDeposits
        }(
            address(token),
            depositAmounts,
            NocturneUtils.defaultStealthAddress()
        );

        // Deposit hash marked true
        for (uint256 i = 0; i < numDeposits; i++) {
            assertTrue(
                depositManager._outstandingDepositHashes(depositHashes[i])
            );
        }

        // Deposit manager has tokens and gas funds
        assertEq(
            token.balanceOf(address(depositManager)),
            RESERVE_AMOUNT * numDeposits
        );
        assertEq(
            address(depositManager).balance,
            GAS_COMP_AMOUNT * numDeposits
        );

        bytes[] memory signatures = new bytes[](numDeposits);
        for (uint256 i = 0; i < numDeposits; i++) {
            bytes32 digest = depositManager.computeDigest(deposits[i]);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(SCREENER_PRIVKEY, digest);
            signatures[i] = ParseUtils.rsvToSignatureBytes(
                uint256(r),
                uint256(s),
                v
            );
        }

        for (uint256 i = 0; i < numDeposits; i++) {
            uint128 merkleIndex = handler.totalCount();

            vm.expectEmit(true, true, true, false);
            emit DepositCompleted(
                deposits[i].spender,
                deposits[i].encodedAsset,
                deposits[i].value,
                deposits[i].depositAddr,
                deposits[i].nonce,
                deposits[i].gasCompensation,
                merkleIndex
            );

            vm.prank(SCREENER);
            vm.txGasPrice(50 gwei);
            depositManager.completeErc20Deposit(deposits[i], signatures[i]);

            // Deposit hash marked false again
            assertFalse(
                depositManager._outstandingDepositHashes(depositHashes[i])
            );
        }

        // Ensure teller now has ALICE's tokens
        assertEq(
            token.balanceOf(address(teller)),
            RESERVE_AMOUNT * numDeposits
        );
        assertEq(token.balanceOf(address(depositManager)), 0);

        assertEq(address(depositManager).balance, 0);
        assertGt(SCREENER.balance, 0);
        assertLt(ALICE.balance, GAS_COMP_AMOUNT * numDeposits);
    }

    function testCompleteDepositFailureExceedsGlobalCap() public {
        SimpleERC20Token token = ERC20s[0];
        uint256 chunkAmount = (uint256(GLOBAL_CAP) * (10 ** 18)) / 10;

        // Deposit one chunk size over global cap
        DepositRequest memory deposit;
        bytes memory signature;
        for (uint256 i = 0; i < 11; i++) {
            deal(address(token), ALICE, chunkAmount);

            vm.prank(ALICE);
            token.approve(address(depositManager), chunkAmount);

            deposit = NocturneUtils.formatDepositRequest(
                ALICE,
                address(token),
                chunkAmount,
                ERC20_ID,
                NocturneUtils.defaultStealthAddress(),
                depositManager._nonce(),
                GAS_COMP_AMOUNT // 10M gas comp
            );

            vm.deal(ALICE, GAS_COMP_AMOUNT);
            vm.prank(ALICE);

            uint256[] memory depositAmounts = new uint256[](1);
            depositAmounts[0] = chunkAmount;
            depositManager.instantiateErc20MultiDeposit{value: GAS_COMP_AMOUNT}(
                address(token),
                depositAmounts,
                NocturneUtils.defaultStealthAddress()
            );

            bytes32 digest = depositManager.computeDigest(deposit);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(SCREENER_PRIVKEY, digest);
            signature = ParseUtils.rsvToSignatureBytes(
                uint256(r),
                uint256(s),
                v
            );

            // Last chunk reverts due to exceeding global cap
            if (i == 10) {
                vm.expectRevert("globalCap exceeded");
            }
            depositManager.completeErc20Deposit(deposit, signature);
        }

        // Last chunk goes through after moving forward timestamp 1h
        vm.warp(block.timestamp + 3_601);
        depositManager.completeErc20Deposit(deposit, signature);
    }

    function testCompleteDepositFailureBadSignature() public {
        SimpleERC20Token token = ERC20s[0];
        deal(address(token), ALICE, RESERVE_AMOUNT);

        // Approve 50M tokens for deposit
        vm.prank(ALICE);
        token.approve(address(depositManager), RESERVE_AMOUNT);

        DepositRequest memory deposit = NocturneUtils.formatDepositRequest(
            ALICE,
            address(token),
            RESERVE_AMOUNT,
            ERC20_ID,
            NocturneUtils.defaultStealthAddress(),
            depositManager._nonce(),
            GAS_COMP_AMOUNT // 10M gas comp
        );

        vm.deal(ALICE, GAS_COMP_AMOUNT);
        vm.prank(ALICE);

        uint256[] memory depositAmounts = new uint256[](1);
        depositAmounts[0] = RESERVE_AMOUNT;
        depositManager.instantiateErc20MultiDeposit{value: GAS_COMP_AMOUNT}(
            address(token),
            depositAmounts,
            NocturneUtils.defaultStealthAddress()
        );

        bytes32 digest = depositManager.computeDigest(deposit);
        uint256 randomPrivkey = 123;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(randomPrivkey, digest);
        bytes memory badSignature = ParseUtils.rsvToSignatureBytes(
            uint256(r),
            uint256(s),
            v
        );

        vm.expectRevert("request signer !screener");
        vm.prank(SCREENER);
        depositManager.completeErc20Deposit(deposit, badSignature);
    }

    function testCompleteDepositFailureNonExistentDeposit() public {
        SimpleERC20Token token = ERC20s[0];
        deal(address(token), ALICE, RESERVE_AMOUNT);

        // Approve 50M tokens for deposit
        vm.prank(ALICE);
        token.approve(address(depositManager), RESERVE_AMOUNT);

        // Format deposit request but do NOT instantiate deposit
        DepositRequest memory deposit = NocturneUtils.formatDepositRequest(
            ALICE,
            address(token),
            RESERVE_AMOUNT,
            ERC20_ID,
            NocturneUtils.defaultStealthAddress(),
            depositManager._nonce(),
            GAS_COMP_AMOUNT // 10M gas comp
        );

        bytes32 digest = depositManager.computeDigest(deposit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SCREENER_PRIVKEY, digest);
        bytes memory signature = ParseUtils.rsvToSignatureBytes(
            uint256(r),
            uint256(s),
            v
        );

        vm.expectRevert("deposit !exists");
        vm.prank(SCREENER);
        depositManager.completeErc20Deposit(deposit, signature);
    }
}

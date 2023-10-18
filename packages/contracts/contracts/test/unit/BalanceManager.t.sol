// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import {IJoinSplitVerifier} from "../../interfaces/IJoinSplitVerifier.sol";
import {ISubtreeUpdateVerifier} from "../../interfaces/ISubtreeUpdateVerifier.sol";
import {LibOffchainMerkleTree, OffchainMerkleTree} from "../../libs/OffchainMerkleTree.sol";
import {TestJoinSplitVerifier} from "../harnesses/TestJoinSplitVerifier.sol";
import {TestSubtreeUpdateVerifier} from "../harnesses/TestSubtreeUpdateVerifier.sol";
import {OperationUtils} from "../../libs/OperationUtils.sol";
import {Teller} from "../../Teller.sol";
import {TestBalanceManager} from "../harnesses/TestBalanceManager.sol";
import "../utils/NocturneUtils.sol";
import {SimpleERC20Token} from "../tokens/SimpleERC20Token.sol";
import {Utils} from "../../libs/Utils.sol";
import {AssetUtils} from "../../libs/AssetUtils.sol";
import {PoseidonDeployer} from "../utils/PoseidonDeployer.sol";
import "../../libs/Types.sol";

contract BalanceManagerTest is Test, PoseidonDeployer {
    using LibOffchainMerkleTree for OffchainMerkleTree;
    using stdJson for string;
    using OperationLib for Operation;

    // Check storage layout file
    uint256 constant OPERATION_STAGE_STORAGE_SLOT = 277;
    uint256 constant NOT_ENTERED = 1;

    uint256 constant DEFAULT_GAS_LIMIT = 500_000;

    address constant ALICE = address(1);
    address constant BOB = address(2);
    address constant BUNDLER = address(3);
    uint256 constant PER_NOTE_AMOUNT = uint256(500_000_000);

    uint256 constant DEFAULT_PER_JOINSPLIT_VERIFY_GAS = 170_000;

    TestBalanceManager balanceManager;
    Teller teller;
    IJoinSplitVerifier joinSplitVerifier;
    ISubtreeUpdateVerifier subtreeUpdateVerifier;
    SimpleERC20Token[3] ERC20s;

    function setUp() public virtual {
        deployPoseidonExts();

        // Instantiate teller, joinSplitVerifier, tree, and balanceManager
        teller = new Teller();
        balanceManager = new TestBalanceManager();

        joinSplitVerifier = new TestJoinSplitVerifier();
        subtreeUpdateVerifier = new TestSubtreeUpdateVerifier();

        balanceManager.initialize(
            address(subtreeUpdateVerifier),
            address(0x111)
        );
        balanceManager.setTeller(address(teller));

        // NOTE: TestBalanceManager implements IHandler so we can test with
        // teller
        teller.initialize(
            "NocturneTeller",
            "v1",
            address(balanceManager),
            address(joinSplitVerifier),
            address(_poseidonExtT7)
        );
        teller.setDepositSourcePermission(ALICE, true);

        // Instantiate token contracts
        for (uint256 i = 0; i < 3; i++) {
            ERC20s[i] = new SimpleERC20Token();

            // Prefill the balance manager with 1 token
            deal(address(ERC20s[i]), address(balanceManager), 1);
        }
    }

    function reserveAndDepositFunds(
        address recipient,
        SimpleERC20Token token,
        uint256 amount
    ) internal {
        deal(address(token), recipient, amount);

        CompressedStealthAddress memory addr = NocturneUtils
            .defaultStealthAddress();
        Deposit memory deposit = NocturneUtils.formatDeposit(
            recipient,
            address(token),
            amount,
            ERC20_ID,
            addr
        );

        vm.prank(recipient);
        token.approve(address(teller), amount);

        vm.prank(ALICE);
        teller.depositFunds(deposit);
    }

    function testMakeDepositSuccess() public {
        SimpleERC20Token token = ERC20s[0];
        uint256 depositAmount = 10;

        // Pre-deposit state
        assertEq(balanceManager.totalCount(), 0);
        assertEq(token.balanceOf(address(teller)), 0);

        reserveAndDepositFunds(ALICE, token, depositAmount);

        // Post-deposit state
        assertEq(balanceManager.totalCount(), 1);
        assertEq(token.balanceOf(address(teller)), depositAmount);
    }

    function testProcessJoinSplitsGasPriceZeroSuccess() public {
        SimpleERC20Token token = ERC20s[0];

        // Reserves + deposits 2 notes worth of tokens
        reserveAndDepositFunds(ALICE, token, PER_NOTE_AMOUNT * 2);

        TrackedAsset[] memory trackedRefundAssets = new TrackedAsset[](0);

        // Unwrap 2 notes worth of tokens (alice has sufficient balance)
        Operation memory op = NocturneUtils.formatOperation(
            FormatOperationArgs({
                joinSplitTokens: NocturneUtils._joinSplitTokensArrayOfOneToken(
                    address(token)
                ),
                joinSplitRefundValues: new uint256[](1),
                gasToken: address(token),
                root: balanceManager.root(),
                joinSplitsPublicSpends: NocturneUtils
                    ._publicSpendsArrayOfOnePublicSpendArray(
                        NocturneUtils.fillJoinSplitPublicSpends(
                            PER_NOTE_AMOUNT,
                            2
                        )
                    ),
                trackedRefundAssets: trackedRefundAssets,
                gasAssetRefundThreshold: 0,
                executionGasLimit: DEFAULT_GAS_LIMIT,
                gasPrice: 0,
                actions: new Action[](0),
                atomicActions: false,
                operationFailureType: OperationFailureType.NONE
            })
        );

        // Balance manager took up 2 notes of tokens
        assertEq(token.balanceOf(address(balanceManager)), 1); // +1 since prefill
        balanceManager.processJoinSplitsReservingFee(
            op,
            DEFAULT_PER_JOINSPLIT_VERIFY_GAS
        );
        assertEq(
            token.balanceOf(address(balanceManager)),
            (PER_NOTE_AMOUNT * 2) + 1
        );
    }

    function testProcessJoinSplitsReservingFeeSingleFeeNoteSuccess() public {
        SimpleERC20Token token = ERC20s[0];

        reserveAndDepositFunds(ALICE, token, PER_NOTE_AMOUNT * 2);

        TrackedAsset[] memory trackedRefundAssets = new TrackedAsset[](0);

        // Unwrap both notes with gas price of 50 (see total
        // fee below)
        Operation memory op = NocturneUtils.formatOperation(
            FormatOperationArgs({
                joinSplitTokens: NocturneUtils._joinSplitTokensArrayOfOneToken(
                    address(token)
                ),
                joinSplitRefundValues: new uint256[](1),
                gasToken: address(token),
                root: balanceManager.root(),
                joinSplitsPublicSpends: NocturneUtils
                    ._publicSpendsArrayOfOnePublicSpendArray(
                        NocturneUtils.fillJoinSplitPublicSpends(
                            PER_NOTE_AMOUNT,
                            2
                        )
                    ),
                trackedRefundAssets: trackedRefundAssets,
                executionGasLimit: DEFAULT_GAS_LIMIT,
                gasAssetRefundThreshold: 0,
                gasPrice: 50,
                actions: new Action[](0),
                atomicActions: false,
                operationFailureType: OperationFailureType.NONE
            })
        );

        uint256 totalFeeReserved = balanceManager.calculateOpMaxGasAssetCost(
            op,
            DEFAULT_PER_JOINSPLIT_VERIFY_GAS
        );

        // Balance manager took up both notes minus the amount to reserve
        assertEq(token.balanceOf(address(balanceManager)), 1); // +1 since prefill
        balanceManager.processJoinSplitsReservingFee(
            op,
            DEFAULT_PER_JOINSPLIT_VERIFY_GAS
        );
        assertEq(
            token.balanceOf(address(balanceManager)),
            (2 * PER_NOTE_AMOUNT) - totalFeeReserved + 1
        );
        assertEq(token.balanceOf(address(teller)), totalFeeReserved);
    }

    function testProcessJoinSplitsThreeContiguousJoinSplitSubarraysMultiAssetSuccess()
        public
    {
        SimpleERC20Token token1 = ERC20s[0];
        SimpleERC20Token token2 = ERC20s[1];
        SimpleERC20Token token3 = ERC20s[2];

        // Reserves + deposits 4 notes worth of each token
        reserveAndDepositFunds(ALICE, token1, PER_NOTE_AMOUNT * 4);
        reserveAndDepositFunds(ALICE, token2, PER_NOTE_AMOUNT * 4);
        reserveAndDepositFunds(ALICE, token3, PER_NOTE_AMOUNT * 4);

        address[] memory tokens = new address[](3);
        tokens[0] = address(token1);
        tokens[1] = address(token2);
        tokens[2] = address(token3);

        uint256[][] memory joinSplitsPublicSpends = new uint256[][](3);
        for (uint256 i = 0; i < 3; i++) {
            joinSplitsPublicSpends[i] = NocturneUtils.fillJoinSplitPublicSpends(
                PER_NOTE_AMOUNT,
                4
            );
        }

        // Unwrap all 4 notes worth for each token and setting gas price to 50
        Operation memory op = NocturneUtils.formatOperation(
            FormatOperationArgs({
                joinSplitTokens: tokens,
                joinSplitRefundValues: new uint256[](tokens.length),
                gasToken: address(token1),
                root: balanceManager.root(),
                joinSplitsPublicSpends: joinSplitsPublicSpends,
                trackedRefundAssets: new TrackedAsset[](0),
                gasAssetRefundThreshold: 0,
                executionGasLimit: DEFAULT_GAS_LIMIT,
                gasPrice: 50,
                actions: new Action[](0),
                atomicActions: false,
                operationFailureType: OperationFailureType.NONE
            })
        );

        uint256 totalFeeReserved = balanceManager.calculateOpMaxGasAssetCost(
            op,
            DEFAULT_PER_JOINSPLIT_VERIFY_GAS
        );
        console.log("totalFeeReserved", totalFeeReserved);

        // Balance manager took up 4 notes worth for each token but for token1 4 notes worth minus
        // the amount to reserve
        assertEq(token1.balanceOf(address(balanceManager)), 1); // +1 since prefill
        balanceManager.processJoinSplitsReservingFee(
            op,
            DEFAULT_PER_JOINSPLIT_VERIFY_GAS
        );
        assertEq(
            token1.balanceOf(address(balanceManager)),
            (4 * PER_NOTE_AMOUNT) - totalFeeReserved + 1
        );
        assertEq(
            token2.balanceOf(address(balanceManager)),
            (4 * PER_NOTE_AMOUNT) + 1
        );
        assertEq(
            token3.balanceOf(address(balanceManager)),
            (4 * PER_NOTE_AMOUNT) + 1
        );
        assertEq(token1.balanceOf(address(teller)), totalFeeReserved);
    }

    function testGatherReservedGasAssetAndPayBundlerSuccess() public {
        SimpleERC20Token token = ERC20s[0];

        // Reserves + deposits 2 notes worth of tokens
        reserveAndDepositFunds(ALICE, token, PER_NOTE_AMOUNT * 2);

        TrackedAsset[] memory trackedRefundAssets = new TrackedAsset[](0);

        // Unwrap 2 notes worth of tokens and set gas price to 50
        Operation memory op = NocturneUtils.formatOperation(
            FormatOperationArgs({
                joinSplitTokens: NocturneUtils._joinSplitTokensArrayOfOneToken(
                    address(token)
                ),
                joinSplitRefundValues: new uint256[](1),
                gasToken: address(token),
                root: balanceManager.root(),
                joinSplitsPublicSpends: NocturneUtils
                    ._publicSpendsArrayOfOnePublicSpendArray(
                        NocturneUtils.fillJoinSplitPublicSpends(
                            PER_NOTE_AMOUNT,
                            2
                        )
                    ),
                trackedRefundAssets: trackedRefundAssets,
                gasAssetRefundThreshold: 0,
                executionGasLimit: DEFAULT_GAS_LIMIT,
                gasPrice: 50,
                actions: new Action[](0),
                atomicActions: false,
                operationFailureType: OperationFailureType.NONE
            })
        );

        uint256 totalFeeReserved = balanceManager.calculateOpMaxGasAssetCost(
            op,
            DEFAULT_PER_JOINSPLIT_VERIFY_GAS
        );

        // Take up 2 notes worth minus fee
        assertEq(token.balanceOf(address(balanceManager)), 1); // +1 since prefill
        balanceManager.processJoinSplitsReservingFee(
            op,
            DEFAULT_PER_JOINSPLIT_VERIFY_GAS
        );
        assertEq(
            token.balanceOf(address(balanceManager)),
            (2 * PER_NOTE_AMOUNT) - totalFeeReserved + 1
        );

        // Calculate payout to bundler based on dummy op
        OperationResult memory opResult = NocturneUtils
            .formatDummyOperationResult(op);
        uint256 onlyBundlerFee = balanceManager.calculateBundlerGasAssetPayout(
            op,
            opResult
        );

        // Gather reserved gas asset and pay bundler
        // Ensure bundler gets the calculated payout amount
        balanceManager.gatherReservedGasAssetAndPayBundler(
            op,
            opResult,
            DEFAULT_PER_JOINSPLIT_VERIFY_GAS,
            BUNDLER
        );
        assertEq(
            token.balanceOf(address(balanceManager)),
            (2 * PER_NOTE_AMOUNT) - onlyBundlerFee + 1
        );
        assertEq(token.balanceOf(BUNDLER), onlyBundlerFee);
    }

    function testGatherReservedGasAssetAndPayBundlerBelowRefundThresholdSuccess()
        public
    {
        SimpleERC20Token token = ERC20s[0];

        // Reserves + deposits 2 notes worth of tokens
        reserveAndDepositFunds(ALICE, token, PER_NOTE_AMOUNT * 2);

        TrackedAsset[] memory trackedRefundAssets = new TrackedAsset[](0);

        // Unwrap 2 notes worth of tokens and set gas price to 50
        Operation memory op = NocturneUtils.formatOperation(
            FormatOperationArgs({
                joinSplitTokens: NocturneUtils._joinSplitTokensArrayOfOneToken(
                    address(token)
                ),
                joinSplitRefundValues: new uint256[](1),
                gasToken: address(token),
                root: balanceManager.root(),
                joinSplitsPublicSpends: NocturneUtils
                    ._publicSpendsArrayOfOnePublicSpendArray(
                        NocturneUtils.fillJoinSplitPublicSpends(
                            PER_NOTE_AMOUNT,
                            2
                        )
                    ),
                trackedRefundAssets: trackedRefundAssets,
                // threshold = sum(publicSpend) means it will always pay bundler whole amount
                gasAssetRefundThreshold: 2 * PER_NOTE_AMOUNT,
                executionGasLimit: DEFAULT_GAS_LIMIT,
                gasPrice: 50,
                actions: new Action[](0),
                atomicActions: false,
                operationFailureType: OperationFailureType.NONE
            })
        );

        // Calculate amount to reserve
        uint256 totalFeeReserved = balanceManager.calculateOpMaxGasAssetCost(
            op,
            DEFAULT_PER_JOINSPLIT_VERIFY_GAS
        );

        // Take up 2 notes worth minus reserve amount
        assertEq(token.balanceOf(address(balanceManager)), 1); // +1 since prefill
        balanceManager.processJoinSplitsReservingFee(
            op,
            DEFAULT_PER_JOINSPLIT_VERIFY_GAS
        );
        assertEq(
            token.balanceOf(address(balanceManager)),
            (2 * PER_NOTE_AMOUNT) - totalFeeReserved + 1
        );

        // Calculate payout to bundler based on dummy op
        OperationResult memory opResult = NocturneUtils
            .formatDummyOperationResult(op);
        uint256 onlyBundlerFee = balanceManager.calculateBundlerGasAssetPayout(
            op,
            opResult
        );

        // What the bundler would've been paid is less than totalFeeReserved but gets whole
        // reserved amount due to low threshold
        assertLt(onlyBundlerFee, totalFeeReserved);

        balanceManager.gatherReservedGasAssetAndPayBundler(
            op,
            opResult,
            DEFAULT_PER_JOINSPLIT_VERIFY_GAS,
            BUNDLER
        );

        // assert entire fee reserved went to bundler this time due to high refund threshold
        assertEq(
            token.balanceOf(address(balanceManager)),
            (2 * PER_NOTE_AMOUNT) - totalFeeReserved + 1
        );
        assertEq(token.balanceOf(BUNDLER), totalFeeReserved);
    }

    function testProcessJoinSplitsNotEnoughForFeeFailure() public {
        SimpleERC20Token token = ERC20s[0];

        reserveAndDepositFunds(ALICE, token, PER_NOTE_AMOUNT);

        TrackedAsset[] memory trackedRefundAssets = new TrackedAsset[](0);

        // Unwrap whole note across 50 joinsplits, not enough for bundler comp with 50 joinsplits
        // and gas price of 50
        Operation memory op = NocturneUtils.formatOperation(
            FormatOperationArgs({
                joinSplitTokens: NocturneUtils._joinSplitTokensArrayOfOneToken(
                    address(token)
                ),
                joinSplitRefundValues: new uint256[](1),
                gasToken: address(token),
                root: balanceManager.root(),
                joinSplitsPublicSpends: NocturneUtils
                    ._publicSpendsArrayOfOnePublicSpendArray(
                        NocturneUtils.fillJoinSplitPublicSpends(
                            PER_NOTE_AMOUNT / 50,
                            50
                        )
                    ),
                trackedRefundAssets: trackedRefundAssets,
                gasAssetRefundThreshold: 0,
                executionGasLimit: DEFAULT_GAS_LIMIT,
                gasPrice: 50,
                actions: new Action[](0),
                atomicActions: false,
                operationFailureType: OperationFailureType.NONE
            })
        );

        // Will be too large number given there are 50 joinsplits (total fee to reserve >
        // publicSpend in the 50 joinsplits)
        uint256 totalFeeReserved = balanceManager.calculateOpMaxGasAssetCost(
            op,
            DEFAULT_PER_JOINSPLIT_VERIFY_GAS
        );
        assertGt(totalFeeReserved, PER_NOTE_AMOUNT);

        // Expect revert due to not having enough to pay fee
        vm.expectRevert("Too few gas tokens");
        balanceManager.processJoinSplitsReservingFee(
            op,
            DEFAULT_PER_JOINSPLIT_VERIFY_GAS
        );
    }

    function testProcessJoinSplitsNotEnoughFundsForUnwrapFailure() public {
        SimpleERC20Token token = ERC20s[0];

        // Only reserves + deposits 1 note worth of tokens
        reserveAndDepositFunds(ALICE, token, PER_NOTE_AMOUNT * 1);

        TrackedAsset[] memory trackedRefundAssets = new TrackedAsset[](0);

        // Attempts to unwrap 2 notes worth of token (we only deposited 1 note worth)
        Operation memory op = NocturneUtils.formatOperation(
            FormatOperationArgs({
                joinSplitTokens: NocturneUtils._joinSplitTokensArrayOfOneToken(
                    address(token)
                ),
                joinSplitRefundValues: new uint256[](1),
                gasToken: address(token),
                root: balanceManager.root(),
                joinSplitsPublicSpends: NocturneUtils
                    ._publicSpendsArrayOfOnePublicSpendArray(
                        NocturneUtils.fillJoinSplitPublicSpends(
                            PER_NOTE_AMOUNT,
                            2
                        )
                    ),
                trackedRefundAssets: trackedRefundAssets,
                gasAssetRefundThreshold: 0,
                executionGasLimit: DEFAULT_GAS_LIMIT,
                gasPrice: 0,
                actions: new Action[](0),
                atomicActions: false,
                operationFailureType: OperationFailureType.NONE
            })
        );

        // Expect revert for processing joinsplits
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        balanceManager.processJoinSplitsReservingFee(
            op,
            DEFAULT_PER_JOINSPLIT_VERIFY_GAS
        );
    }

    function testProcessJoinSplitsBadRootFailure() public {
        SimpleERC20Token token = ERC20s[0];

        // Reserves + deposits 1 note worth of token
        reserveAndDepositFunds(ALICE, token, PER_NOTE_AMOUNT * 1);

        TrackedAsset[] memory trackedRefundAssets = new TrackedAsset[](0);

        // Operation with bad merkle root fails joinsplit processing
        Operation memory op = NocturneUtils.formatOperation(
            FormatOperationArgs({
                joinSplitTokens: NocturneUtils._joinSplitTokensArrayOfOneToken(
                    address(token)
                ),
                joinSplitRefundValues: new uint256[](1),
                gasToken: address(token),
                root: balanceManager.root(),
                joinSplitsPublicSpends: NocturneUtils
                    ._publicSpendsArrayOfOnePublicSpendArray(
                        NocturneUtils.fillJoinSplitPublicSpends(
                            PER_NOTE_AMOUNT,
                            2
                        )
                    ),
                trackedRefundAssets: trackedRefundAssets,
                gasAssetRefundThreshold: 0,
                executionGasLimit: DEFAULT_GAS_LIMIT,
                gasPrice: 0,
                actions: new Action[](0),
                atomicActions: false,
                operationFailureType: OperationFailureType.JOINSPLIT_BAD_ROOT
            })
        );

        // Expect revert for processing joinsplits
        vm.expectRevert("Tree root not past root");
        balanceManager.processJoinSplitsReservingFee(
            op,
            DEFAULT_PER_JOINSPLIT_VERIFY_GAS
        );
    }

    function testProcessJoinSplitsAlreadyUsedNullifierFailure() public {
        SimpleERC20Token token = ERC20s[0];

        // Reserves + deposits 1 note worth of token
        reserveAndDepositFunds(ALICE, token, PER_NOTE_AMOUNT * 1);

        TrackedAsset[] memory trackedRefundAssets = new TrackedAsset[](0);

        // Create operation with two joinsplits where 1st uses NF included in
        // 2nd joinsplit
        Operation memory op = NocturneUtils.formatOperation(
            FormatOperationArgs({
                joinSplitTokens: NocturneUtils._joinSplitTokensArrayOfOneToken(
                    address(token)
                ),
                joinSplitRefundValues: new uint256[](1),
                gasToken: address(token),
                root: balanceManager.root(),
                joinSplitsPublicSpends: NocturneUtils
                    ._publicSpendsArrayOfOnePublicSpendArray(
                        NocturneUtils.fillJoinSplitPublicSpends(
                            PER_NOTE_AMOUNT,
                            2
                        )
                    ),
                trackedRefundAssets: trackedRefundAssets,
                gasAssetRefundThreshold: 0,
                executionGasLimit: DEFAULT_GAS_LIMIT,
                gasPrice: 0,
                actions: new Action[](0),
                atomicActions: false,
                operationFailureType: OperationFailureType
                    .JOINSPLIT_NF_ALREADY_IN_SET
            })
        );

        // Expect revert for processing joinsplits
        vm.expectRevert("Nullifier A already used");
        balanceManager.processJoinSplitsReservingFee(
            op,
            DEFAULT_PER_JOINSPLIT_VERIFY_GAS
        );
    }

    function testProcessJoinSplitsMatchingNullifiersFailure() public {
        SimpleERC20Token token = ERC20s[0];

        // Reserves + deposits 1 note worth of token
        reserveAndDepositFunds(ALICE, token, PER_NOTE_AMOUNT * 1);

        TrackedAsset[] memory trackedRefundAssets = new TrackedAsset[](0);

        // Create operation with one of the joinsplits has matching NFs A and B
        Operation memory op = NocturneUtils.formatOperation(
            FormatOperationArgs({
                joinSplitTokens: NocturneUtils._joinSplitTokensArrayOfOneToken(
                    address(token)
                ),
                joinSplitRefundValues: new uint256[](1),
                gasToken: address(token),
                root: balanceManager.root(),
                joinSplitsPublicSpends: NocturneUtils
                    ._publicSpendsArrayOfOnePublicSpendArray(
                        NocturneUtils.fillJoinSplitPublicSpends(
                            PER_NOTE_AMOUNT,
                            2
                        )
                    ),
                trackedRefundAssets: trackedRefundAssets,
                gasAssetRefundThreshold: 0,
                executionGasLimit: DEFAULT_GAS_LIMIT,
                gasPrice: 0,
                actions: new Action[](0),
                atomicActions: false,
                operationFailureType: OperationFailureType.JOINSPLIT_NFS_SAME
            })
        );

        // Expect revert for processing joinsplits
        vm.expectRevert("2 nfs should !equal");
        balanceManager.processJoinSplitsReservingFee(
            op,
            DEFAULT_PER_JOINSPLIT_VERIFY_GAS
        );
    }

    function testHandleRefundsJoinSplitsSingleAssetSuccess() public {
        SimpleERC20Token token = ERC20s[0];

        // Reserves + deposits 2 notes worth of token
        reserveAndDepositFunds(ALICE, token, PER_NOTE_AMOUNT * 2);

        TrackedAsset[] memory trackedRefundAssets = new TrackedAsset[](0);

        // Unwrap 2 notes worth of token
        Operation memory op = NocturneUtils.formatOperation(
            FormatOperationArgs({
                joinSplitTokens: NocturneUtils._joinSplitTokensArrayOfOneToken(
                    address(token)
                ),
                joinSplitRefundValues: new uint256[](1),
                gasToken: address(token),
                root: balanceManager.root(),
                joinSplitsPublicSpends: NocturneUtils
                    ._publicSpendsArrayOfOnePublicSpendArray(
                        NocturneUtils.fillJoinSplitPublicSpends(
                            PER_NOTE_AMOUNT,
                            2
                        )
                    ),
                trackedRefundAssets: trackedRefundAssets,
                gasAssetRefundThreshold: 0,
                executionGasLimit: DEFAULT_GAS_LIMIT,
                gasPrice: 0, // don't reserve any gas, teller takes up all
                actions: new Action[](0),
                atomicActions: false,
                operationFailureType: OperationFailureType.NONE
            })
        );

        // Take up 2 notes worth tokens
        balanceManager.processJoinSplitsReservingFee(
            op,
            DEFAULT_PER_JOINSPLIT_VERIFY_GAS
        );
        assertEq(
            token.balanceOf(address(balanceManager)),
            (2 * PER_NOTE_AMOUNT) + 1 // +1 due to prefill
        );
        assertEq(token.balanceOf(address(teller)), 0);

        // Expect all 2 notes worth to be refunded to teller
        balanceManager.handleAllRefunds(op);
        assertEq(token.balanceOf(address(balanceManager)), 1);
        assertEq(token.balanceOf(address(teller)), (2 * PER_NOTE_AMOUNT));
    }

    function testHandleRefundsRefundAssetsSingleAssetSuccess() public {
        SimpleERC20Token joinSplitToken = ERC20s[0];
        SimpleERC20Token refundToken = ERC20s[1];

        // Refund asset
        EncodedAsset[] memory refundAssets = new EncodedAsset[](1);
        refundAssets[0] = AssetUtils.encodeAsset(
            AssetType.ERC20,
            address(refundToken),
            ERC20_ID
        );

        TrackedAsset[] memory trackedRefundAssets = new TrackedAsset[](1);
        trackedRefundAssets[0] = TrackedAsset({
            encodedAsset: AssetUtils.encodeAsset(
                AssetType.ERC20,
                address(refundToken),
                ERC20_ID
            ),
            minRefundValue: 0
        });

        // Dummy operation, we're only interested in refundAssets
        Operation memory op = NocturneUtils.formatOperation(
            FormatOperationArgs({
                joinSplitTokens: NocturneUtils._joinSplitTokensArrayOfOneToken(
                    address(joinSplitToken)
                ),
                joinSplitRefundValues: new uint256[](1),
                gasToken: address(joinSplitToken),
                root: balanceManager.root(),
                joinSplitsPublicSpends: NocturneUtils
                    ._publicSpendsArrayOfOnePublicSpendArray(
                        NocturneUtils.fillJoinSplitPublicSpends(
                            PER_NOTE_AMOUNT,
                            2
                        )
                    ),
                trackedRefundAssets: trackedRefundAssets,
                gasAssetRefundThreshold: 0,
                executionGasLimit: DEFAULT_GAS_LIMIT,
                gasPrice: 0,
                actions: new Action[](0),
                atomicActions: false,
                operationFailureType: OperationFailureType.NONE
            })
        );

        // Send refund tokens to balance manager
        uint256 refundAmount = 10_000_000;
        deal(address(refundToken), address(ALICE), refundAmount);
        vm.prank(ALICE);
        refundToken.transfer(address(balanceManager), refundAmount);

        // Expect all refund tokens to be refunded to teller
        balanceManager.handleAllRefunds(op);
        assertEq(refundToken.balanceOf(address(balanceManager)), 1); // +1 due to prefill
        assertEq(refundToken.balanceOf(address(teller)), refundAmount);
    }
}

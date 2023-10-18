// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

import {InvariantsBase} from "./InvariantsBase.sol";
import {EthTransferAdapter} from "../../adapters/EthTransferAdapter.sol";
import {DepositManagerHandler} from "./actors/DepositManagerHandler.sol";
import {TellerHandler} from "./actors/TellerHandler.sol";
import {HandlerHandler} from "./actors/HandlerHandler.sol";
import {TokenSwapper, SwapRequest} from "../utils/TokenSwapper.sol";
import {TestJoinSplitVerifier} from "../harnesses/TestJoinSplitVerifier.sol";
import {TestSubtreeUpdateVerifier} from "../harnesses/TestSubtreeUpdateVerifier.sol";
import "../utils/NocturneUtils.sol";
import {TestDepositManager} from "../harnesses/TestDepositManager.sol";
import {Teller} from "../../Teller.sol";
import {Handler} from "../../Handler.sol";
import {ParseUtils} from "../utils/ParseUtils.sol";
import {EventParsing} from "../utils/EventParsing.sol";
import {WETH9} from "../tokens/WETH9.sol";
import {SimpleERC20Token} from "../tokens/SimpleERC20Token.sol";
import {Utils} from "../../libs/Utils.sol";
import {PoseidonDeployer} from "../utils/PoseidonDeployer.sol";
import "../../libs/Types.sol";

contract ProtocolInvariants is Test, InvariantsBase, PoseidonDeployer {
    function setUp() public virtual {
        deployPoseidonExts();

        teller = new Teller();
        handler = new Handler();
        depositManager = new TestDepositManager();

        WETH9 weth = new WETH9();
        EthTransferAdapter ethTransferAdapter = new EthTransferAdapter(
            address(weth)
        );

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

        teller.setDepositSourcePermission(address(depositManager), true);
        handler.setSubtreeBatchFillerPermission(address(this), true);

        depositManager.initialize(
            CONTRACT_NAME,
            CONTRACT_VERSION,
            address(teller),
            address(weth)
        );
        depositManager.setScreenerPermission(SCREENER_ADDRESS, true);

        SimpleERC20Token depositErc20 = new SimpleERC20Token();

        // WETH is always first
        depositErc20s.push(address(weth));
        depositErc20s.push(address(depositErc20));

        depositManagerHandler = new DepositManagerHandler(
            depositManager,
            depositErc20s,
            SCREENER_PRIVKEY
        );

        swapper = new TokenSwapper();
        swapErc20 = new SimpleERC20Token();

        tellerHandler = new TellerHandler(
            teller,
            handler,
            swapper,
            depositErc20s,
            swapErc20,
            BUNDLER_ADDRESS,
            TRANSFER_RECIPIENT_ADDRESS,
            address(weth),
            payable(address(ethTransferAdapter))
        );

        depositManager.setErc20Cap(
            address(weth),
            type(uint32).max,
            type(uint32).max,
            uint8(1),
            weth.decimals()
        );

        depositManager.setErc20Cap(
            address(depositErc20),
            type(uint32).max,
            type(uint32).max,
            uint8(1),
            depositErc20.decimals()
        );

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

        handler.setContractPermission(address(ethTransferAdapter), true);
        handler.setContractMethodPermission(
            address(ethTransferAdapter),
            ethTransferAdapter.transfer.selector,
            true
        );

        handler.setContractPermission(address(depositErc20), true);
        handler.setContractMethodPermission(
            address(depositErc20),
            depositErc20.approve.selector,
            true
        );
        handler.setContractMethodPermission(
            address(depositErc20),
            depositErc20.transfer.selector,
            true
        );

        handler.setContractPermission(address(swapErc20), true);
        handler.setContractMethodPermission(
            address(swapErc20),
            swapErc20.approve.selector,
            true
        );
        handler.setContractMethodPermission(
            address(swapErc20),
            swapErc20.transfer.selector,
            true
        );

        handler.setContractPermission(address(swapper), true);
        handler.setContractMethodPermission(
            address(swapper),
            swapper.swap.selector,
            true
        );

        handler.setSubtreeBatchFillerPermission(
            address(SUBTREE_BATCH_FILLER_ADDRESS),
            true
        );

        handlerHandler = new HandlerHandler(
            handler,
            SUBTREE_BATCH_FILLER_ADDRESS,
            depositErc20
        );

        bytes4[] memory depositManagerHandlerSelectors = new bytes4[](5);
        depositManagerHandlerSelectors[0] = depositManagerHandler
            .instantiateDepositETH
            .selector;
        depositManagerHandlerSelectors[1] = depositManagerHandler
            .instantiateDepositErc20
            .selector;
        depositManagerHandlerSelectors[2] = depositManagerHandler
            .retrieveDepositETH
            .selector;
        depositManagerHandlerSelectors[3] = depositManagerHandler
            .retrieveDepositErc20
            .selector;
        depositManagerHandlerSelectors[4] = depositManagerHandler
            .completeDepositErc20
            .selector;

        bytes4[] memory tellerHandlerSelectors = new bytes4[](1);
        tellerHandlerSelectors[0] = tellerHandler.processBundle.selector;

        bytes4[] memory handlerHandlerSelectors = new bytes4[](1);
        handlerHandlerSelectors[0] = handlerHandler.fillBatchWithZeros.selector;

        targetContract(address(depositManagerHandler));
        targetSelector(
            FuzzSelector({
                addr: address(depositManagerHandler),
                selectors: depositManagerHandlerSelectors
            })
        );

        targetContract(address(tellerHandler));
        targetSelector(
            FuzzSelector({
                addr: address(tellerHandler),
                selectors: tellerHandlerSelectors
            })
        );

        targetContract(address(handlerHandler));
        targetSelector(
            FuzzSelector({
                addr: address(handlerHandler),
                selectors: handlerHandlerSelectors
            })
        );

        excludeSender(address(0x0));
        excludeSender(BUNDLER_ADDRESS);
        excludeSender(TRANSFER_RECIPIENT_ADDRESS);
        excludeSender(SCREENER_ADDRESS);
        excludeSender(address(tellerHandler));
        excludeSender(address(handlerHandler));
        excludeSender(address(depositManagerHandler));
        excludeSender(address(ethTransferAdapter));
        excludeSender(address(swapper));
        excludeSender(address(teller));
        excludeSender(address(handler));
        excludeSender(address(depositManager));
        excludeSender(address(weth));

        teller.transferOwnership(OWNER);
        handler.transferOwnership(OWNER);
    }

    function invariant_callSummary() external view {
        print_callSummary();
    }

    /*****************************
     * Protocol-Wide
     *****************************/
    function invariant_protocol_tellerNonWethErc20BalancesConsistent()
        external
    {
        assert_protocol_tellerNonWethErc20BalancesConsistent();
    }

    function invariant_protocol_tellerWethBalanceConsistent() external {
        assert_protocol_tellerWethBalanceConsistent();
    }

    function invariant_protocol_ethTransferredOutBalance() external {
        assert_protocol_ethTransferredOutBalance();
    }

    function invariant_protocol_handlerErc20BalancesAlwaysZeroOrOne() external {
        assert_protocol_handlerErc20BalancesAlwaysZeroOrOne();
    }

    /*****************************
     * Deposits
     *****************************/
    function invariant_deposit_outNeverExceedsInErc20s() external {
        assert_deposit_outNeverExceedsInErc20s();
    }

    function invariant_deposit_depositManagerBalanceEqualsInMinusOutErc20s()
        external
    {
        assert_deposit_depositManagerBalanceEqualsInMinusOutErc20s();
    }

    function invariant_deposit_allActorsBalanceSumEqualsRetrieveDepositSumErc20s()
        external
    {
        assert_deposit_allActorsBalanceSumEqualsRetrieveDepositSumErc20s();
    }

    function invariant_deposit_actorBalanceAlwaysEqualsRetrievedErc20s()
        external
    {
        assert_deposit_actorBalanceAlwaysEqualsRetrievedErc20s();
    }

    function invariant_deposit_actorBalanceNeverExceedsInstantiatedErc20s()
        external
    {
        assert_deposit_actorBalanceNeverExceedsInstantiatedErc20s();
    }

    function invariant_deposit_screenerBalanceInBounds() external {
        assert_deposit_screenerBalanceInBounds();
    }

    function invariant_deposit_actorBalancesInBounds() external {
        assert_deposit_actorBalancesInBounds();
    }

    /*****************************
     * Operations
     *****************************/
    function invariant_operation_totalSwapErc20ReceivedMatchesTellerBalance()
        external
    {
        assert_operation_totalSwapErc20ReceivedMatchesTellerBalance();
    }

    function invariant_operation_bundlerBalanceMatchesTracked() external {
        assert_operation_bundlerBalanceMatchesTracked();
    }

    function invariant_operation_joinSplitTokensTransferredOutNeverExceedsUnwrappedByMoreThanNumberOfTimesPrefillTaken()
        external
    {
        assert_operation_joinSplitTokensTransferredOutNeverExceedsUnwrappedByMoreThanNumberOfTimesPrefillTaken();
    }
}

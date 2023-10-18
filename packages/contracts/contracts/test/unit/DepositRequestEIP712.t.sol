// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.2;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {ParseUtils} from "../utils/ParseUtils.sol";
import {JsonDecodings, SignedDepositRequestFixture} from "../utils/JsonDecodings.sol";
import "../harnesses/TestDepositRequestEIP712.sol";

contract DepositRequestEIP712Test is Test, JsonDecodings {
    string constant SIGNED_DEPOSIT_REQ_FIXTURE_PATH =
        "/fixtures/signedDepositRequest.json";

    TestDepositRequestEIP712 public depositManagerBase;

    function testVerifiesSignedDepositFixture() public {
        SignedDepositRequestFixture memory fixture = JsonDecodings
            .loadSignedDepositRequestFixture(SIGNED_DEPOSIT_REQ_FIXTURE_PATH);

        depositManagerBase = new TestDepositRequestEIP712();
        depositManagerBase.initialize(
            fixture.contractName,
            fixture.contractVersion
        );

        // Override chainid, bytecode, and storage for fixture.contractAddress
        vm.chainId(fixture.chainId);
        vm.etch(fixture.contractAddress, address(depositManagerBase).code);
        vm.store(
            fixture.contractAddress,
            bytes32(uint256(1)),
            keccak256(bytes(fixture.contractName))
        );
        vm.store(
            fixture.contractAddress,
            bytes32(uint256(2)),
            keccak256(bytes(fixture.contractVersion))
        );

        address recovered = ITestDepositRequestEIP712(fixture.contractAddress)
            .recoverDepositRequestSigner(
                fixture.depositRequest,
                fixture.signature
            );

        assertEq(recovered, fixture.screenerAddress);
    }

    function testDepositRequestHashMatchesOffchainImpl() public {
        SignedDepositRequestFixture memory fixture = JsonDecodings
            .loadSignedDepositRequestFixture(SIGNED_DEPOSIT_REQ_FIXTURE_PATH);

        depositManagerBase = new TestDepositRequestEIP712();
        depositManagerBase.initialize(
            fixture.contractName,
            fixture.contractVersion
        );

        bytes32 depositRequestHash = depositManagerBase.hashDepositRequest(
            fixture.depositRequest
        );

        assertEq(depositRequestHash, fixture.depositRequestHash);
    }
}

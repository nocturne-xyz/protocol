// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";

import "../../libs/Types.sol";
import "../utils/NocturneUtils.sol";
import "../../CanonicalAddressRegistry.sol";
import "../../interfaces/ICanonAddrSigCheckVerifier.sol";
import "../harnesses/TestCanonAddrSigCheckVerifier.sol";

contract CanonicalAddressRegistryTest is Test {
    address constant ALICE = address(0x11111);

    CanonicalAddressRegistry public registry;
    ICanonAddrSigCheckVerifier public sigCheckVerifier;

    function setUp() public virtual {
        registry = new CanonicalAddressRegistry();
        sigCheckVerifier = ICanonAddrSigCheckVerifier(
            new TestCanonAddrSigCheckVerifier()
        );

        registry.initialize(
            "NocturneCanonicalAddressRegistry",
            "v1",
            address(sigCheckVerifier)
        );
    }

    function testSetCanonAddrSuccess() public {
        uint256 compressedCanonAddr = 1234;
        uint256[8] memory dummyProof = NocturneUtils.dummyProof();

        assertEq(registry._ethAddressToCompressedCanonAddr(ALICE), uint256(0));
        assertEq(registry._compressedCanonAddrToNonce(compressedCanonAddr), 0);

        vm.prank(ALICE);
        registry.setCanonAddr(compressedCanonAddr, dummyProof);

        assertEq(
            registry._ethAddressToCompressedCanonAddr(ALICE),
            compressedCanonAddr
        );
        assertEq(registry._compressedCanonAddrToNonce(compressedCanonAddr), 1);
    }

    // NOTE: more comprehensive test with real verifier are found in e2e tests
}

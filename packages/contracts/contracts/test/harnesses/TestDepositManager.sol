// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "../../libs/Types.sol";
import {DepositManager} from "../../DepositManager.sol";

contract TestDepositManager is DepositManager {
    function computeDigest(
        DepositRequest calldata req
    ) public view returns (bytes32) {
        return _computeDigest(req);
    }

    function hashDepositRequest(
        DepositRequest calldata req
    ) public pure returns (bytes32) {
        return _hashDepositRequest(req);
    }
}

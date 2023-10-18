// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "../../Teller.sol";

contract TestTeller is Teller {
    function computeDigest(
        Operation calldata op
    ) external view returns (uint256) {
        return _computeDigest(op);
    }
}

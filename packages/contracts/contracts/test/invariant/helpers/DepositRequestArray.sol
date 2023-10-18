// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "../../../libs/Types.sol";

library LibDepositRequestArray {
    function pop(DepositRequest[] storage self, uint256 index) internal {
        require(index < self.length);
        self[index] = self[self.length - 1];
        self.pop();
    }

    function getRandom(
        DepositRequest[] storage self,
        uint256 seed
    ) internal view returns (DepositRequest memory req, uint256 index) {
        if (self.length > 0) {
            index = seed % self.length;
            req = self[index];
        } else {
            req = DepositRequest({
                spender: address(0),
                encodedAsset: EncodedAsset({
                    encodedAssetAddr: 0,
                    encodedAssetId: 0
                }),
                value: 0,
                depositAddr: CompressedStealthAddress({h1: 0, h2: 0}),
                nonce: 0,
                gasCompensation: 0
            });
        }
    }
}

// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;
struct ActorSumSet {
    mapping(address => uint256) deposits;
    address[] actors;
}

library LibActorSumSet {
    function addToActorSum(
        ActorSumSet storage self,
        address actor,
        uint256 amount
    ) internal {
        if (self.deposits[actor] == 0 && amount > 0) {
            self.actors.push(actor);
        }

        self.deposits[actor] += amount;
    }

    function getSumForActor(
        ActorSumSet storage self,
        address actor
    ) internal view returns (uint256) {
        return self.deposits[actor];
    }

    function getTotalForAll(
        ActorSumSet storage self
    ) public view returns (uint256) {
        uint256 totalDeposits = 0;

        for (uint256 i = 0; i < self.actors.length; i++) {
            address currentActor = self.actors[i];
            totalDeposits += self.deposits[currentActor];
        }

        return totalDeposits;
    }
}

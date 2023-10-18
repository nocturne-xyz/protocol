import fs from "fs";

const SCRIPT_DIR = __dirname;
const CONTRACTS_DIR = `${SCRIPT_DIR}/../../contracts/contracts`;

interface Groth16VerifyingKey {
  protocol: string;
  curve: string;
  nPublic: number;
  vk_alpha_1: string[];
  vk_beta_2: [string, string][];
  vk_gamma_2: [string, string][];
  vk_delta_2: [string, string][];
  vk_alphabeta_12: [[string, string][], [string, string][]];
  IC: [string, string, string][];
}

function generateSolidityContract(
  verifyingKey: Groth16VerifyingKey,
  contractName: string
): string {
  const solidityTemplate = `
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import {Pairing} from "./libs/Pairing.sol";
import {Groth16} from "./libs/Groth16.sol";
import {I${contractName}} from "./interfaces/I${contractName}.sol";

contract ${contractName} is I${contractName} {
    function verifyingKey()
        internal
        pure
        returns (Groth16.VerifyingKey memory vk)
    {
        vk.alpha1 = Pairing.G1Point(
            ${verifyingKey.vk_alpha_1[0]},
            ${verifyingKey.vk_alpha_1[1]}
        );

        vk.beta2 = Pairing.G2Point(
            [
                ${verifyingKey.vk_beta_2[0][1]},
                ${verifyingKey.vk_beta_2[0][0]}
            ],
            [
                ${verifyingKey.vk_beta_2[1][1]},
                ${verifyingKey.vk_beta_2[1][0]}
            ]
        );
        vk.gamma2 = Pairing.G2Point(
            [
                ${verifyingKey.vk_gamma_2[0][1]},
                ${verifyingKey.vk_gamma_2[0][0]}
            ],
            [
                ${verifyingKey.vk_gamma_2[1][1]},
                ${verifyingKey.vk_gamma_2[1][0]}
            ]
        );
        vk.delta2 = Pairing.G2Point(
            [
                ${verifyingKey.vk_delta_2[0][1]},
                ${verifyingKey.vk_delta_2[0][0]}
            ],
            [
                ${verifyingKey.vk_delta_2[1][1]},
                ${verifyingKey.vk_delta_2[1][0]}
            ]
        );
        vk.IC = new Pairing.G1Point[](${verifyingKey.IC.length});

        ${verifyingKey.IC.map(
          (ic, index) => `
        vk.IC[${index}] = Pairing.G1Point(
            ${ic[0]},
            ${ic[1]}
        );`
        ).join("")}
    }

    /// @return r  bool true if proof is valid
    function verifyProof(
        uint256[8] memory proof,
        uint256[] memory pi
    ) public view override returns (bool r) {
        return Groth16.verifyProof(verifyingKey(), proof, pi);
    }

    /// @return r bool true if proofs are valid
    function batchVerifyProofs(
        uint256[8][] memory proofs,
        uint256[][] memory allPis
    ) public view override returns (bool) {
        return Groth16.batchVerifyProofs(verifyingKey(), proofs, allPis);
    }
}
`;

  return solidityTemplate;
}

function writeVerifierContract(vkeyPath: string, contractName: string) {
  const vkJSON = JSON.parse(
    fs.readFileSync(vkeyPath, "utf8").toString()
  ) as Groth16VerifyingKey;
  const solidityContract = generateSolidityContract(vkJSON, contractName);
  fs.writeFileSync(`${CONTRACTS_DIR}/${contractName}.sol`, solidityContract);
}

// invoke with `yarn ts-node <this_script> <vkey_path> <contract_name>`
// e.g. `yarn ts-node "$ROOT_SCRIPT_DIR/genSolidityVerifier.ts" "$OUTPUT_DIR/vkey.json" JoinSplitVerifier`
const vkeyPath = process.argv[2];
const contractName = process.argv[3];
writeVerifierContract(vkeyPath, contractName);

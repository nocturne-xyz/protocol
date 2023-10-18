#!/bin/bash
#
# USGGE: ./gen_solidity_verifier.sh [path to solidity verifier]
# Apply various changes the default circom solidity verifier


FILE="$1"
FILENAME="${FILE##*/}"
VERIFIERNAME="${FILENAME%.*}"

CMD="sed"

if [[ $OSTYPE == 'darwin'* ]]; then
  echo "macOS detected... using gsed instead"
  CMD="gsed"
fi

echo "Post processing solidity vierfier at $FILE with verifier name $VERIFIERNAME.."

# grab vk from generated solidity file
VKEY="$(cat "$FILE" | $CMD \
  's/alfa/alpha/g
  1,/verifyingKey/d
  /}/,$d')"

# write header
echo '// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Pairing} from "./libs/Pairing.sol";
import {Groth16} from "./libs/Groth16.sol";
import {I'"$VERIFIERNAME"'} from "./interfaces/I'"$VERIFIERNAME"'.sol";

contract '"$VERIFIERNAME"' is I'"$VERIFIERNAME"' {
    function verifyingKey()
        internal
        pure
        returns (Groth16.VerifyingKey memory vk)
    {' > "$FILE"

# write vkey
echo "$VKEY" >> "$FILE"

# write the public methods code and closing brace afterwards
echo '
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
' >> "$FILE"
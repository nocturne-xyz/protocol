// From https://github.com/semaphore-protocol/semaphore/blob/main/circuits/tree.circom
pragma circom 2.0.0;

include "include/poseidon.circom";
include "include/mux2.circom";
include "include/bitify.circom";
include "lib.circom";


// inclusion proof for a quaternary merkle tree instantiated over the Poseidon hash function
//@requires(1) nLevels > 0
//@ensures(1) `siblings` and `pathIndices` comprise a valid merkle inclusion proof for `leaf` against `root
//@ensures(2) `pathIndices` are all valid 2-bit numbers
template MerkleTreeInclusionProof(nLevels) {
    signal input leaf;
    signal input pathIndices[nLevels];
    signal input siblings[nLevels][3];

    signal output root;

    component poseidons[nLevels];
    component mux[nLevels];

    signal hashes[nLevels + 1];
    hashes[0] <== leaf;

    signal pathIndexBits[nLevels][2];

    for (var i = 0; i < nLevels; i++) {
        // check that pathIndices are all valid 2-bit numbers
        pathIndexBits[i] <== Num2Bits(2)(pathIndices[i]);

        poseidons[i] = Poseidon(4);
        mux[i] = MultiMux2(4);

        // path index = 0
        mux[i].c[0][0] <== hashes[i];
        mux[i].c[1][0] <== siblings[i][0];
        mux[i].c[2][0] <== siblings[i][1];
        mux[i].c[3][0] <== siblings[i][2];

        // path index = 1
        mux[i].c[0][1] <== siblings[i][0];
        mux[i].c[1][1] <== hashes[i];
        mux[i].c[2][1] <== siblings[i][1];
        mux[i].c[3][1] <== siblings[i][2];

        // path index = 2
        mux[i].c[0][2] <== siblings[i][0];
        mux[i].c[1][2] <== siblings[i][1];
        mux[i].c[2][2] <== hashes[i];
        mux[i].c[3][2] <== siblings[i][2];

        // path index = 3
        mux[i].c[0][3] <== siblings[i][0];
        mux[i].c[1][3] <== siblings[i][1];
        mux[i].c[2][3] <== siblings[i][2];
        mux[i].c[3][3] <== hashes[i];

        mux[i].s <== pathIndexBits[i];

        poseidons[i].inputs[0] <== mux[i].out[0];
        poseidons[i].inputs[1] <== mux[i].out[1];
        poseidons[i].inputs[2] <== mux[i].out[2];
        poseidons[i].inputs[3] <== mux[i].out[3];

        hashes[i + 1] <== poseidons[i].out;
    }

    root <== hashes[nLevels];
}

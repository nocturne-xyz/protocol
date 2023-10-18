#!/bin/bash
CIRCUIT_NAME=joinsplit
SCRIPT_DIR=$(dirname "$0")
ROOT_SCRIPT_DIR="$SCRIPT_DIR/../"
ROOT_DIR="$SCRIPT_DIR/../../../../"
CIRCUIT_ARTIFACTS_DIR="$ROOT_DIR/circuit-artifacts"
PHASE1_PATH="$SCRIPT_DIR/../../data/powersOfTau28_hez_final_15.ptau"
CIRCUIT_PATH="$SCRIPT_DIR/../../circuits/$CIRCUIT_NAME.circom"
BUILD_DIR="$CIRCUIT_ARTIFACTS_DIR/$CIRCUIT_NAME"
OUTPUT_DIR="$BUILD_DIR"/"$CIRCUIT_NAME"_cpp
CONTRACTS_DIR="$ROOT_DIR/packages/contracts/contracts"

if [ -f "$PHASE1_PATH" ]; then
    echo "Found Phase 1 ptau file"
else
    echo "No Phase 1 ptau file found. Exiting..."
    exit 1
fi

if [ ! -d "$BUILD_DIR" ]; then
    echo "No build directory found. Creating build directory..."
    mkdir -p "$BUILD_DIR"
fi

echo "****COMPILING CIRCUIT****"
start=`date +%s`
circom "$CIRCUIT_PATH" --r1cs --wasm --sym --c --wat --output "$BUILD_DIR"
end=`date +%s`
echo "DONE ($((end-start))s)"

# echo "****GENERATING WITNESS FOR SAMPLE INPUT****"
# start=`date +%s`
# node "$BUILD_DIR"/"$CIRCUIT_NAME"_js/generate_witness.js "$BUILD_DIR"/"$CIRCUIT_NAME"_js/"$CIRCUIT_NAME".wasm input_joinsplit.json "$BUILD_DIR"/witness.wtns
# end=`date +%s`
# echo "DONE ($((end-start))s)"

echo "****GENERATING ZKEY 0****"
start=`date +%s`
npx snarkjs groth16 setup "$BUILD_DIR"/"$CIRCUIT_NAME".r1cs "$PHASE1_PATH" "$OUTPUT_DIR"/"$CIRCUIT_NAME"_0.zkey
end=`date +%s`
echo "DONE ($((end-start))s)"

echo "****CONTRIBUTE TO THE PHASE 2 CEREMONY****"
start=`date +%s`
echo "test" | npx snarkjs zkey contribute "$OUTPUT_DIR"/"$CIRCUIT_NAME"_0.zkey "$OUTPUT_DIR"/"$CIRCUIT_NAME"_1.zkey --name="1st Contributor Name"
end=`date +%s`
echo "DONE ($((end-start))s)"

echo "****GENERATING FINAL ZKEY****"
start=`date +%s`
npx snarkjs zkey beacon "$OUTPUT_DIR"/"$CIRCUIT_NAME"_1.zkey "$OUTPUT_DIR"/"$CIRCUIT_NAME".zkey 0102030405060708090a0b0c0d0e0f101112231415161718221a1b1c1d1e1f 10 -n="Final Beacon phase2"
end=`date +%s`
echo "DONE ($((end-start))s)"

echo "****VERIFYING FINAL ZKEY****"
start=`date +%s`
npx snarkjs zkey verify "$BUILD_DIR"/"$CIRCUIT_NAME".r1cs "$PHASE1_PATH" "$OUTPUT_DIR"/"$CIRCUIT_NAME".zkey
end=`date +%s`
echo "DONE ($((end-start))s)"

echo "****EXPORTING VKEY****"
start=`date +%s`
npx snarkjs zkey export verificationkey "$OUTPUT_DIR"/"$CIRCUIT_NAME".zkey "$OUTPUT_DIR"/vkey.json
end=`date +%s`
echo "DONE ($((end-start))s)"

# echo "****GENERATING PROOF FOR SAMPLE INPUT****"
# start=`date +%s`
# npx snarkjs groth16 prove "$BUILD_DIR"/"$CIRCUIT_NAME".zkey "$BUILD_DIR"/witness.wtns "$BUILD_DIR"/proof.json "$BUILD_DIR"/public.json
# end=`date +%s`
# echo "DONE ($((end-start))s)"

# echo "****VERIFYING PROOF FOR SAMPLE INPUT****"
# start=`date +%s`
# npx snarkjs groth16 verify "$BUILD_DIR"/vkey.json "$BUILD_DIR"/public.json "$BUILD_DIR"/proof.json
# end=`date +%s`
# echo "DONE ($((end-start))s)"

echo "****EXPORTING SOLIDITY SMART CONTRACT****"
start=`date +%s`
yarn ts-node "$ROOT_SCRIPT_DIR/genSolidityVerifier.ts" "$OUTPUT_DIR/vkey.json" JoinSplitVerifier
end=`date +%s`
echo "DONE ($((end-start))s)"

#!/bin/bash

# https://stackoverflow.com/questions/4774054/reliable-way-for-a-bash-script-to-get-the-full-path-to-itself
SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )" 
ROOT_DIR="$SCRIPT_DIR/../../../"
CIRCUIT_ARTIFACTS_DIR="$ROOT_DIR/circuit-artifacts/"
CIRCUIT_CPP_DIR="$CIRCUIT_ARTIFACTS_DIR/subtreeupdate/subtreeupdate_cpp"

RAPIDSNARK_PATH="$ROOT_DIR/rapidsnark/build/prover"

if [[ "${USE_RAPIDSNARK}" != "true" ]]; then
	echo "skipping rapidsnark setup..."
else
	echo "checking circuit has been built..."
	if [[ ! -d "$CIRCUIT_CPP_DIR" ]]; then
		echo "circuit hasn't been built yet. please build the circuits first"
		echo "you can do this by running `yarn circuits:build` from the monorepo root"
		exit 1
	else
		echo "found circuit artifacts"
	fi

	echo "checking rapidsnark is installed at the expected location..."
	if [[ ! -f "$RAPIDSNARK_PATH" ]]; then
		echo "rapidsnark not found at $RAPIDSNARK_PATH. installing..."
		$SCRIPT_DIR/install_rapidsnark.sh || exit 1
	else
		echo "rapidsnark found at $RAPIDSNARK_PATH"
	fi

	echo "checking C++ witness generator binary has been built..."
	if [[ ! -f "$CIRCUIT_CPP_DIR"/subtreeupdate ]]; then
		echo "witness generator has not been built. building..."
		$SCRIPT_DIR/build_witness_generator.sh || exit 1
	else
		echo "witness generator found at $CIRCUIT_CPP_PATH/subtreeupdate"
	fi
fi

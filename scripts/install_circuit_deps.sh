#!/usr/bin/env bash
set -u

# https://stackoverflow.com/questions/4774054/reliable-way-for-a-bash-script-to-get-the-full-path-to-itself
SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )" 
ROOT_DIR="$SCRIPT_DIR/../../.."
cd "$ROOT_DIR"

echo "Installing circuit deps..."
echo "checking if cargo is installed..."
if ! command cargo --version >/dev/null 2>&1; then
	echo "cargo not found. installing via rustup..."
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
	source ~/.bashrc

	CARGO_VERSION=$(cargo --version | head -n 1) || exit 1
	echo "installed cargo version $CARGO_VERSION"
else
	CARGO_VERSION=$(cargo --version | head -n 1) || exit 1
	echo "found cargo version $CARGO_VERSION"
	echo ""
fi

echo "checking if circom 2.1.2 is installed..."
CIRCOM_VERSION=$(circom --version | cut -d " " -f3)
if [ "$CIRCOM_VERSION" == "2.1.2" ]
then
	echo "found circom version 2.1.2"
	echo ""
else
	echo "circom not found. installing..."
	rm -rf circom
	git clone https://github.com/iden3/circom.git --branch v2.1.2

	pushd circom
	cargo build --release
	cargo install --path circom
	popd

	CIRCOM_VERSION=$(circom --version | cut -d " " -f3) || exit 1
	echo "installed circom version $CIRCOM_VERSION"
	echo ""
fi

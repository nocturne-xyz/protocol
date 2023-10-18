#!/bin/bash

# https://stackoverflow.com/questions/4774054/reliable-way-for-a-bash-script-to-get-the-full-path-to-itself
SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )" 
ROOT_DIR="$SCRIPT_DIR/../../../"
RAPIDSNARK_DIR="$ROOT_DIR/rapidsnark"

echo "cloning rapdisnark..."
pushd $ROOT_DIR
git submodule update
popd

echo "checking for rapidsnark dependencies..."

dpkg -l | grep build-essential \
	&& dpkg -l | grep libgmp-dev \
	&& dpkg -l | grep libsodium-dev \
	&& dpkg -l | grep nasm \
	&& dpkg -l | grep nlohmann-json3-dev

if [ $? -ne 0 ]; then
	echo "rapidsnark dependencies not found. please install them with the following command:"
	echo "sudo apt install build-essential libgmp-dev libsodium-dev nasm nlohmann-json3-dev"
	exit 1
fi

echo "installing rapidsnark..."
pushd $RAPIDSNARK_DIR
npm install
git submodule init
git submodule update
npx task createFieldSources
npx task buildProver
popd

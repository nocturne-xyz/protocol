#!/usr/bin/env bash
set -e

# Make sure that the working directory is always the monorepo root
SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )" 
ROOT_DIR="$SCRIPT_DIR/.."
DEP_DIR="$ROOT_DIR/lib/forge-std"

cd "$ROOT_DIR"

# check if foundryup is installed
if ! command -v foundryup &> /dev/null; then
  echo "foundryup is not installed. Installing..."
  curl -L https://foundry.paradigm.xyz | bash
fi

# check if forge is installed
if command -v forge &> /dev/null; then
  # forge is installed, check the version
  forge_version_output=$(forge --version)
  commit_hash=$(echo "$forge_version_output" | awk '{print $3}' | tr -d '()')
  if [ "$commit_hash" != "e15e33a" ]; then
    # if foundry version is wrong, install the correct one
    foundryup -v nightly-e15e33a07c0920189fc336391f538c3dad53da73
  fi
else
  # if forge is not installed, run foundryup
  foundryup -v nightly-e15e33a07c0920189fc336391f538c3dad53da73
fi


if [ ! -d "$DEP_DIR" ]; then
  echo "Installing forge deps..."
  rm -rf "$DEP_DIR"
  forge install foundry-rs/forge-std --no-git
fi

#!/usr/bin/env bash

SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )" 
cd "$SCRIPT_DIR/.."

# Use the 'find' command to locate all Solidity files, excluding those in './contracts/test'
# Then pipe the list of file paths to 'sha256sum'
find ./contracts -type f -name "*.sol" ! -path "./contracts/test/*" -exec sha256sum {} + > shasums.txt

# Sort the shasums in alphabetical order by filename
sort -k 2 -o shasums.txt shasums.txt

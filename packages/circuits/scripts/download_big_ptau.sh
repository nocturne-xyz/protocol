#!/bin/bash

echo "Downloading large ptau file. May take a while..."
SCRIPT_DIR=$(dirname "$0")
curl -L -C - https://www.dropbox.com/sh/mn47gnepqu88mzl/AACXdEyzF6V5G5SLwlcV24pYa/powersOfTau28_hez_final_23.ptau -o "$SCRIPT_DIR"/../data/powersOfTau28_hez_final_23.ptau

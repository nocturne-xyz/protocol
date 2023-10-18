#!/bin/bash

echo "Downloading large ptau file. May take a while..."
SCRIPT_DIR=$(dirname "$0")
curl -L "https://www.dropbox.com/sh/mn47gnepqu88mzl/AAAzGtg94saShf044uZdwnuGa/powersOfTau28_hez_final_22.ptau?dl=1" -o "$SCRIPT_DIR"/../data/powersOfTau28_hez_final_22.ptau

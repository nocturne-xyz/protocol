#!/bin/bash

# Load environment variables from .env file
export $(grep -v '^#' .env | xargs)

# Run the command
forge script contracts/script/DeployEthTransferAdapter.s.sol --rpc-url $RPC_URL --etherscan-api-key $ETHERSCAN_API_KEY --broadcast -vvvv --private-key $PRIVATE_KEY --slow
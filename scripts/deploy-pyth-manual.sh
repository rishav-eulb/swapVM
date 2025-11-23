#!/bin/bash

# Manual Pyth Adapter Deployment
# Quick deployment without fancy output

set -e

# Load environment
source .env

echo "Deploying PythPriceAdapter..."
echo "Network: $RPC_URL"
echo "Pyth: 0xA2aa501b19aff244D90cc15a4Cf739D2725B5729"
echo ""

cd packages/pseudo-arbitrage-amm

forge create src/oracles/PythPriceAdapter.sol:PythPriceAdapter \
  --constructor-args 0xA2aa501b19aff244D90cc15a4Cf739D2725B5729 3600 \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY"

echo ""
echo "Done! Copy the 'Deployed to:' address above to your .env file as PYTH_ADAPTER_ADDRESS"


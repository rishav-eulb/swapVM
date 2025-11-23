#!/bin/bash
# Force the RPC URL via environment variable

cd /Users/rj39/Desktop/NexusNetwork/swap_vm/packages/pseudo-arbitrage-amm

# Set RPC URL as environment variable (Foundry uses this)
export ETH_RPC_URL="https://base-sepolia.g.alchemy.com/v2/7LSRP1cyL_uCXtI2xgfupX0Tk1RjntRf"

echo "Deploying to: $ETH_RPC_URL"
echo ""

forge create src/oracles/PythPriceAdapter.sol:PythPriceAdapter \
  --constructor-args 0xA2aa501b19aff244D90cc15a4Cf739D2725B5729 3600 \
  --private-key "$PRIVATE_KEY" \
  --legacy

echo ""
echo "Done!"


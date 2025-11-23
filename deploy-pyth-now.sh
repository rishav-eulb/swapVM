#!/bin/bash
# Ultra-simple Pyth deployment

cd /Users/rj39/Desktop/NexusNetwork/swap_vm/packages/pseudo-arbitrage-amm

forge create src/oracles/PythPriceAdapter.sol:PythPriceAdapter \
  --constructor-args 0xA2aa501b19aff244D90cc15a4Cf739D2725B5729 3600 \
  --rpc-url "https://base-sepolia.g.alchemy.com/v2/7LSRP1cyL_uCXtI2xgfupX0Tk1RjntRf" \
  --private-key "$PRIVATE_KEY"


#!/bin/bash
set -e

echo "======================================"
echo "Deploying PythPriceAdapter via Script"
echo "======================================"
echo ""

# Load environment
source .env

# Check required vars
if [ -z "$RPC_URL" ]; then
    echo "Error: RPC_URL not set in .env"
    exit 1
fi

if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY not set in .env"
    exit 1
fi

echo "Network: $RPC_URL"
echo ""

cd packages/pseudo-arbitrage-amm

# Use forge script (more reliable than forge create)
forge script script/DeployPythAdapter.s.sol:DeployPythAdapter \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --broadcast \
  -vvv

echo ""
echo "======================================"
echo "Deployment complete!"
echo "Check the output above for the deployed address"
echo "======================================"


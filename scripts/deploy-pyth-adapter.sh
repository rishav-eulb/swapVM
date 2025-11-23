#!/bin/bash

##############################################################################
# Deploy Pyth Price Adapter Script
##############################################################################
# This script deploys the PythPriceAdapter contract to your network
#
# Usage:
#   ./scripts/deploy-pyth-adapter.sh [MAX_PRICE_AGE]
#
# Arguments:
#   MAX_PRICE_AGE: Maximum age for price data in seconds (default: 3600 = 1 hour)
#
# Examples:
#   ./scripts/deploy-pyth-adapter.sh           # Deploy with 1 hour max age
#   ./scripts/deploy-pyth-adapter.sh 7200      # Deploy with 2 hour max age
#   ./scripts/deploy-pyth-adapter.sh 86400     # Deploy with 24 hour max age (for testnets)
#
##############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MAX_PRICE_AGE=${1:-3600}  # Default: 1 hour

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Pyth Price Adapter Deployment Script                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}✗ Error: .env file not found${NC}"
    echo ""
    echo "Please create a .env file with the following variables:"
    echo "  RPC_URL=https://..."
    echo "  PRIVATE_KEY=0x..."
    echo "  PYTH_ADDRESS=0x..."
    echo ""
    echo "See env.example for a template:"
    echo "  cp env.example .env"
    echo ""
    exit 1
fi

# Load environment variables
source .env

# Validate required variables
if [ -z "$RPC_URL" ]; then
    echo -e "${RED}✗ Error: RPC_URL not set in .env${NC}"
    exit 1
fi

if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}✗ Error: PRIVATE_KEY not set in .env${NC}"
    exit 1
fi

if [ -z "$PYTH_ADDRESS" ]; then
    echo -e "${RED}✗ Error: PYTH_ADDRESS not set in .env${NC}"
    echo ""
    echo "Set PYTH_ADDRESS to the Pyth contract for your network."
    echo "See: https://docs.pyth.network/price-feeds/contract-addresses/evm"
    echo ""
    echo "Common addresses:"
    echo "  Ethereum Mainnet: 0x4305FB66699C3B2702D4d05CF36551390A4c69C6"
    echo "  Base:            0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a"
    echo "  Base Sepolia:    0xA2aa501b19aff244D90cc15a4Cf739D2725B5729"
    echo "  Arbitrum:        0xff1a0f4744e8582DF1aE09D5611b887B6a12925C"
    echo "  Sepolia:         0xDd24F84d36BF92C65F92307595335bdFab5Bbd21"
    echo ""
    exit 1
fi

# Display configuration
echo -e "${YELLOW}Configuration:${NC}"
echo "  RPC URL:        $RPC_URL"
echo "  Pyth Contract:  $PYTH_ADDRESS"
echo "  Max Price Age:  $MAX_PRICE_AGE seconds ($((MAX_PRICE_AGE / 60)) minutes)"
echo ""

# Navigate to pseudo-arbitrage-amm package
cd packages/pseudo-arbitrage-amm

echo -e "${YELLOW}Deploying PythPriceAdapter...${NC}"
echo ""

# Deploy contract
DEPLOY_OUTPUT=$(forge create src/oracles/PythPriceAdapter.sol:PythPriceAdapter \
    --constructor-args "$PYTH_ADDRESS" "$MAX_PRICE_AGE" \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    2>&1)

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Deployment failed!${NC}"
    echo "$DEPLOY_OUTPUT"
    exit 1
fi

echo "$DEPLOY_OUTPUT"

# Extract deployed address
ADAPTER_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "Deployed to:" | awk '{print $3}')

if [ -z "$ADAPTER_ADDRESS" ]; then
    echo -e "${RED}✗ Could not extract deployed address${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                   Deployment Successful!                       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Pyth Adapter Address: $ADAPTER_ADDRESS${NC}"
echo ""

# Update .env file
cd ../..
if grep -q "PYTH_ADAPTER_ADDRESS" .env; then
    # Update existing variable
    sed -i.bak "s|PYTH_ADAPTER_ADDRESS=.*|PYTH_ADAPTER_ADDRESS=$ADAPTER_ADDRESS|" .env
    rm .env.bak 2>/dev/null || true
    echo -e "${GREEN}✓ Updated PYTH_ADAPTER_ADDRESS in .env${NC}"
else
    # Append new variable
    echo "" >> .env
    echo "# Pyth Price Adapter (deployed $(date))" >> .env
    echo "PYTH_ADAPTER_ADDRESS=$ADAPTER_ADDRESS" >> .env
    echo -e "${GREEN}✓ Added PYTH_ADAPTER_ADDRESS to .env${NC}"
fi

echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Configure price feeds (as the owner):"
echo "   ${BLUE}cast send $ADAPTER_ADDRESS \\${NC}"
echo "   ${BLUE}  \"setPriceFeed(address,address,bytes32)\" \\${NC}"
echo "   ${BLUE}  \$WETH_ADDRESS \$USDC_ADDRESS \\${NC}"
echo "   ${BLUE}  0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace \\${NC}"
echo "   ${BLUE}  --rpc-url \$RPC_URL --private-key \$PRIVATE_KEY${NC}"
echo ""
echo "   Common price feeds:"
echo "     ETH/USD: 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace"
echo "     BTC/USD: 0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43"
echo "     USDC/USD: 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a"
echo ""
echo "2. Test the adapter:"
echo "   ${BLUE}npm run test:pyth${NC}"
echo ""
echo "3. Use with Pseudo-Arbitrage AMM:"
echo "   ${BLUE}ammBuilder.buildProgram({${NC}"
echo "   ${BLUE}     oracle: \"$ADAPTER_ADDRESS\",${NC}"
echo "   ${BLUE}     ...${NC}"
echo "   ${BLUE}   })${NC}"
echo ""

# Save deployment info
DEPLOY_FILE="deployments/pyth-adapter-latest.json"
mkdir -p deployments
cat > "$DEPLOY_FILE" << EOF
{
  "pythAdapter": "$ADAPTER_ADDRESS",
  "pyth": "$PYTH_ADDRESS",
  "maxPriceAge": $MAX_PRICE_AGE,
  "deployedAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "network": "$RPC_URL"
}
EOF

echo -e "${GREEN}✓ Saved deployment info to $DEPLOY_FILE${NC}"
echo ""
echo -e "${GREEN}Deployment complete!${NC}"


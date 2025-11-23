#!/bin/bash

# Complete Deployment Script for All AMM Systems
# This script deploys Concentrated AMM, Pseudo-Arbitrage AMM, and Cross-AMM Arbitrage

set -e  # Exit on error

echo "=========================================="
echo "  AMM System Deployment Script"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f .env ]; then
    echo "Loading environment variables..."
    export $(cat .env | grep -v '^#' | xargs)
else
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Please create a .env file with required variables:"
    echo "  PRIVATE_KEY"
    echo "  RPC_URL"
    echo "  AQUA_ADDRESS (optional)"
    exit 1
fi

# Validate required variables
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}Error: PRIVATE_KEY not set in .env${NC}"
    exit 1
fi

if [ -z "$RPC_URL" ]; then
    echo -e "${RED}Error: RPC_URL not set in .env${NC}"
    exit 1
fi

# Create deployments directory
mkdir -p deployments

echo -e "${GREEN}Starting deployment...${NC}"
echo ""

# Step 1: Deploy Concentrated AMM
echo "=========================================="
echo "Step 1/3: Deploying Concentrated AMM"
echo "=========================================="
echo ""

cd files/concentrated-amm

echo "Building contracts..."
forge build

echo "Running tests..."
forge test --gas-report > ../../deployments/concentrated-amm-test-report.txt

echo "Deploying contracts..."
forge script script/DeployConcentratedAMM.s.sol:DeployConcentratedAMM \
    --rpc-url $RPC_URL \
    --broadcast \
    ${ETHERSCAN_API_KEY:+--verify} \
    2>&1 | tee ../../deployments/concentrated-amm-deployment.log

# Extract addresses from deployment
if [ -f "./deployments/concentrated-amm-latest.json" ]; then
    echo -e "${GREEN}✓ Concentrated AMM deployed successfully${NC}"
    cat ./deployments/concentrated-amm-latest.json
    
    # Export for next steps
    export CONCENTRATED_AMM_ADDRESS=$(jq -r '.concentratedAMM' ./deployments/concentrated-amm-latest.json)
    export CONCENTRATED_BUILDER_ADDRESS=$(jq -r '.strategyBuilder' ./deployments/concentrated-amm-latest.json)
    export AQUA_ADDRESS=$(jq -r '.aqua' ./deployments/concentrated-amm-latest.json)
    
    cp ./deployments/concentrated-amm-latest.json ../../deployments/
else
    echo -e "${RED}✗ Failed to deploy Concentrated AMM${NC}"
    exit 1
fi

cd ../..
echo ""

# Step 2: Deploy Pseudo-Arbitrage AMM
echo "=========================================="
echo "Step 2/3: Deploying Pseudo-Arbitrage AMM"
echo "=========================================="
echo ""

cd files/pseudo-arbitrage-amm

echo "Building contracts..."
forge build

echo "Running tests..."
forge test --gas-report > ../../deployments/pseudo-arb-test-report.txt

echo "Deploying SwapVM Router..."
forge script lib/swap-vm/script/DeployAquaSwapVMRouter.s.sol \
    --rpc-url $RPC_URL \
    --broadcast \
    ${ETHERSCAN_API_KEY:+--verify} \
    2>&1 | tee ../../deployments/pseudo-arb-deployment.log

echo -e "${GREEN}✓ Pseudo-Arbitrage AMM deployed successfully${NC}"

cd ../..
echo ""

# Step 3: Deploy Cross-AMM Arbitrage
echo "=========================================="
echo "Step 3/3: Deploying Cross-AMM Arbitrage"
echo "=========================================="
echo ""

cd files/cross-amm-arbitrage

echo "Building contracts..."
forge build

echo "Running tests..."
forge test --gas-report > ../../deployments/cross-amm-test-report.txt

echo "Deploying arbitrage system..."
forge script DeployCrossAMMArbitrage.s.sol:DeployCrossAMMArbitrage \
    --rpc-url $RPC_URL \
    --broadcast \
    ${ETHERSCAN_API_KEY:+--verify} \
    2>&1 | tee ../../deployments/cross-amm-deployment.log

# Extract bot address from deployment log
export BOT_ADDRESS=$(grep "CrossAMMArbitrageBot deployed at:" ../../deployments/cross-amm-deployment.log | awk '{print $4}')
export ARBITRAGE_ADDRESS=$(grep "CrossAMMArbitrage deployed at:" ../../deployments/cross-amm-deployment.log | awk '{print $4}')

if [ -n "$BOT_ADDRESS" ]; then
    echo -e "${GREEN}✓ Cross-AMM Arbitrage deployed successfully${NC}"
else
    echo -e "${RED}✗ Failed to deploy Cross-AMM Arbitrage${NC}"
    exit 1
fi

cd ../..
echo ""

# Create comprehensive deployment summary
echo "=========================================="
echo "  DEPLOYMENT COMPLETE"
echo "=========================================="
echo ""

cat > deployments/deployment-summary.json <<EOF
{
  "network": "${RPC_URL}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "contracts": {
    "aqua": "${AQUA_ADDRESS}",
    "concentratedAMM": "${CONCENTRATED_AMM_ADDRESS}",
    "concentratedBuilder": "${CONCENTRATED_BUILDER_ADDRESS}",
    "crossAMMArbitrage": "${ARBITRAGE_ADDRESS}",
    "crossAMMArbitrageBot": "${BOT_ADDRESS}"
  }
}
EOF

echo "Deployment Summary:"
cat deployments/deployment-summary.json
echo ""

# Create .env.deployed for easy sourcing
cat > .env.deployed <<EOF
# Auto-generated deployment addresses
# Generated: $(date)

AQUA_ADDRESS=${AQUA_ADDRESS}
CONCENTRATED_AMM_ADDRESS=${CONCENTRATED_AMM_ADDRESS}
CONCENTRATED_BUILDER_ADDRESS=${CONCENTRATED_BUILDER_ADDRESS}
ARBITRAGE_ADDRESS=${ARBITRAGE_ADDRESS}
BOT_ADDRESS=${BOT_ADDRESS}
EOF

echo -e "${GREEN}Deployment addresses saved to:${NC}"
echo "  - deployments/deployment-summary.json"
echo "  - .env.deployed"
echo ""

# Next steps
echo "=========================================="
echo "  NEXT STEPS"
echo "=========================================="
echo ""
echo "1. Verify contracts on block explorer (if not auto-verified)"
echo "2. Fund the arbitrage bot:"
echo "   cast send $BOT_ADDRESS \"depositCapital(address,uint256)\" \$TOKEN_X 1000000000000000000000 --rpc-url \$RPC_URL --private-key \$PRIVATE_KEY"
echo ""
echo "3. Configure bot parameters:"
echo "   cast send $BOT_ADDRESS \"setMinProfitBps(uint256)\" 50 --rpc-url \$RPC_URL --private-key \$PRIVATE_KEY"
echo ""
echo "4. Start monitoring:"
echo "   forge script files/cross-amm-arbitrage/DeployCrossAMMArbitrage.s.sol:MonitorOpportunities --rpc-url \$RPC_URL"
echo ""
echo "5. Run the bot:"
echo "   node scripts/monitor.js"
echo ""
echo -e "${GREEN}Deployment successful! 🚀${NC}"


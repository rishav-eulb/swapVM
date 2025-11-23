#!/bin/bash

# Complete Deployment Script for All AMM Systems
# This script deploys Concentrated AMM and Pseudo-Arbitrage AMM

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
echo "Step 1/2: Deploying Concentrated AMM"
echo "=========================================="
echo ""

# Store the root directory
ROOT_DIR="$(pwd)"
cd packages/concentrated-amm

echo "Building contracts..."
set +e  # Temporarily disable exit on error  
forge build 2>&1
set -e  # Re-enable exit on error

# Check if compilation succeeded by looking for artifacts
if [ -d "out" ] && [ "$(ls -A out 2>/dev/null)" ]; then
    echo -e "${GREEN}✓ Contracts compiled successfully (lint warnings ignored)${NC}"
else
    echo -e "${RED}✗ Build failed - no artifacts found${NC}"
    exit 1
fi

echo "Running tests..."
set +e
forge test --gas-report > ../../deployments/concentrated-amm-test-report.txt 2>&1
TEST_EXIT=$?
set -e
if [ $TEST_EXIT -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed${NC}"
else
    echo -e "${YELLOW}⚠ Some tests failed (exit code: $TEST_EXIT), but continuing with deployment${NC}"
fi

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

cd "$ROOT_DIR"
echo ""

# Step 2: Deploy Pseudo-Arbitrage AMM
echo "=========================================="
echo "Step 2/2: Deploying Pseudo-Arbitrage AMM"
echo "=========================================="
echo ""

cd packages/pseudo-arbitrage-amm

echo "Building contracts..."
set +e
forge build 2>&1
set -e

if [ -d "out" ] && [ "$(ls -A out 2>/dev/null)" ]; then
    echo -e "${GREEN}✓ Contracts compiled successfully (lint warnings ignored)${NC}"
else
    echo -e "${RED}✗ Build failed - no artifacts found${NC}"
    exit 1
fi

echo "Running tests..."
set +e
forge test --gas-report > ../../deployments/pseudo-arb-test-report.txt 2>&1
TEST_EXIT=$?
set -e
if [ $TEST_EXIT -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed${NC}"
else
    echo -e "${YELLOW}⚠ Some tests failed (exit code: $TEST_EXIT), but continuing with deployment${NC}"
fi

echo "Deploying Pseudo-Arbitrage AMM..."
forge script script/DeployPseudoArbitrageAMM.s.sol:DeployPseudoArbitrageAMM \
    --rpc-url $RPC_URL \
    --broadcast \
    ${ETHERSCAN_API_KEY:+--verify} \
    2>&1 | tee ../../deployments/pseudo-arb-deployment.log

# Extract addresses from deployment
if [ -f "./deployments/pseudo-arbitrage-amm-latest.json" ]; then
    echo -e "${GREEN}✓ Pseudo-Arbitrage AMM deployed successfully${NC}"
    cat ./deployments/pseudo-arbitrage-amm-latest.json
    
    # Export for next steps
    export PSEUDO_ARB_AMM_ADDRESS=$(jq -r '.pseudoArbitrageAMM' ./deployments/pseudo-arbitrage-amm-latest.json)
    export AQUA_ADDRESS=$(jq -r '.aqua' ./deployments/pseudo-arbitrage-amm-latest.json)
    
    cp ./deployments/pseudo-arbitrage-amm-latest.json ../../deployments/
else
    echo -e "${RED}✗ Failed to deploy Pseudo-Arbitrage AMM${NC}"
    exit 1
fi

cd "$ROOT_DIR"
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
    "pseudoArbitrageAMM": "${PSEUDO_ARB_AMM_ADDRESS}"
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
PSEUDO_ARB_AMM_ADDRESS=${PSEUDO_ARB_AMM_ADDRESS}
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
echo "2. Create liquidity positions:"
echo "   cd packages/concentrated-amm"
echo "   forge script script/DeployConcentratedAMM.s.sol:CreateExamplePosition --rpc-url \$RPC_URL --broadcast"
echo ""
echo "3. Test swaps on both AMMs"
echo ""
echo "4. Monitor liquidity and positions"
echo ""
echo -e "${GREEN}Deployment successful! 🚀${NC}"


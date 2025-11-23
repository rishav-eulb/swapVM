#!/bin/bash

# Script to deploy mock tokens for testing
# Usage: ./deploy-mock-tokens.sh [network]
# Example: ./deploy-mock-tokens.sh base-sepolia

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Network configuration
NETWORK=${1:-base-sepolia}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Mock Token Deployment Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found!${NC}"
    echo "Please create a .env file with PRIVATE_KEY"
    exit 1
fi

# Source .env file
source .env

if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}Error: PRIVATE_KEY not set in .env file${NC}"
    exit 1
fi

# Set default token configurations if not provided
export TOKEN0_NAME="${TOKEN0_NAME:-Mock USDC}"
export TOKEN0_SYMBOL="${TOKEN0_SYMBOL:-USDC}"
export TOKEN0_DECIMALS="${TOKEN0_DECIMALS:-6}"
export TOKEN0_INITIAL_SUPPLY="${TOKEN0_INITIAL_SUPPLY:-1000000000000}" # 1M USDC (6 decimals)

export TOKEN1_NAME="${TOKEN1_NAME:-Mock WETH}"
export TOKEN1_SYMBOL="${TOKEN1_SYMBOL:-WETH}"
export TOKEN1_DECIMALS="${TOKEN1_DECIMALS:-18}"
export TOKEN1_INITIAL_SUPPLY="${TOKEN1_INITIAL_SUPPLY:-1000000000000000000000000}" # 1M WETH (18 decimals)

echo -e "${YELLOW}Configuration:${NC}"
echo "Network: $NETWORK"
echo "Token 0: $TOKEN0_NAME ($TOKEN0_SYMBOL) - $TOKEN0_DECIMALS decimals"
echo "Token 1: $TOKEN1_NAME ($TOKEN1_SYMBOL) - $TOKEN1_DECIMALS decimals"
echo ""

# Get RPC URL for the network
case $NETWORK in
    base-sepolia)
        RPC_URL="${BASE_SEPOLIA_RPC_URL:-https://sepolia.base.org}"
        ETHERSCAN_API_KEY="${BASESCAN_API_KEY}"
        VERIFIER_URL="https://api-sepolia.basescan.org/api"
        ;;
    base)
        RPC_URL="${BASE_RPC_URL:-https://mainnet.base.org}"
        ETHERSCAN_API_KEY="${BASESCAN_API_KEY}"
        VERIFIER_URL="https://api.basescan.org/api"
        ;;
    sepolia)
        RPC_URL="${SEPOLIA_RPC_URL:-https://rpc.sepolia.org}"
        ETHERSCAN_API_KEY="${ETHERSCAN_API_KEY}"
        VERIFIER_URL="https://api-sepolia.etherscan.io/api"
        ;;
    mainnet)
        RPC_URL="${MAINNET_RPC_URL:-https://eth.llamarpc.com}"
        ETHERSCAN_API_KEY="${ETHERSCAN_API_KEY}"
        VERIFIER_URL="https://api.etherscan.io/api"
        ;;
    localhost)
        RPC_URL="http://localhost:8545"
        ETHERSCAN_API_KEY=""
        VERIFIER_URL=""
        ;;
    *)
        echo -e "${RED}Unknown network: $NETWORK${NC}"
        echo "Supported networks: base-sepolia, base, sepolia, mainnet, localhost"
        exit 1
        ;;
esac

echo -e "${YELLOW}Deploying to: $RPC_URL${NC}"
echo ""

# Create deployments directory if it doesn't exist
mkdir -p deployments

# Deploy the contracts
echo -e "${GREEN}Starting deployment...${NC}"
forge script script/DeployMockTokens.s.sol:DeployMockTokens \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --verify \
    --legacy \
    -vvv 2>&1 | tee /tmp/deploy-output.log

# Extract deployment info from logs (handles both success and file permission error)
DEPLOY_LOG="/tmp/deploy-output.log"

# Look for token addresses in the output
TOKEN0_ADDR=$(grep -A 1 "Deploying Token 0..." "$DEPLOY_LOG" | grep "Address:" | awk '{print $NF}')
TOKEN1_ADDR=$(grep -A 1 "Deploying Token 1..." "$DEPLOY_LOG" | grep "Address:" | awk '{print $NF}')

if [ -n "$TOKEN0_ADDR" ] && [ -n "$TOKEN1_ADDR" ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Deployment Successful!${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    # Manually create the JSON file
    cat > deployments/mock-tokens-latest.json <<EOF
{
  "chainId": $(cast chain-id --rpc-url "$RPC_URL" 2>/dev/null || echo "84532"),
  "network": "$NETWORK",
  "deployer": "$(cast wallet address --private-key $PRIVATE_KEY 2>/dev/null || echo 'unknown')",
  "token0": {
    "name": "$TOKEN0_NAME",
    "symbol": "$TOKEN0_SYMBOL",
    "decimals": $TOKEN0_DECIMALS,
    "address": "$TOKEN0_ADDR"
  },
  "token1": {
    "name": "$TOKEN1_NAME",
    "symbol": "$TOKEN1_SYMBOL",
    "decimals": $TOKEN1_DECIMALS,
    "address": "$TOKEN1_ADDR"
  }
}
EOF
    
    echo ""
    echo -e "${YELLOW}Deployment Details:${NC}"
    cat deployments/mock-tokens-latest.json
    echo ""
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Add these to your .env file:${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo "TOKEN0_ADDRESS=$TOKEN0_ADDR"
    echo "TOKEN1_ADDRESS=$TOKEN1_ADDR"
    echo -e "${GREEN}========================================${NC}"
    
    # Cleanup
    rm -f "$DEPLOY_LOG"
else
    echo ""
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}Deployment Failed!${NC}"
    echo -e "${RED}========================================${NC}"
    rm -f "$DEPLOY_LOG"
    exit 1
fi


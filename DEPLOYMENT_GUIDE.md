# Complete Deployment Guide

This guide walks you through deploying both AMM systems: Pseudo-Arbitrage AMM and Concentrated AMM.

---

## 📋 Prerequisites

### 1. Install Dependencies

```bash
# Install Foundry if you haven't
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Navigate to project root
cd /Users/rj39/Desktop/NexusNetwork/swap_vm

# Install dependencies for each project
cd packages/pseudo-arbitrage-amm && forge install
cd ../concentrated-amm && forge install
```

### 2. Setup Environment Variables

Create a `.env` file in the root directory:

```bash
# Copy example environment file
cp .env.example .env

# Edit with your values
nano .env
```

**Required Variables:**
```bash
# Wallet
PRIVATE_KEY=0x... # Your deployer private key (NO QUOTES)

# Network RPC
RPC_URL=https://... # Your RPC endpoint

# Network-specific (optional)
ETHERSCAN_API_KEY=... # For contract verification

# For using existing Aqua (recommended for production)
AQUA_ADDRESS=0x499943e74fb0ce105688beee8ef2abec5d936d31

# For testing/examples
TOKEN_X=0x... # Address of first token (e.g., WETH)
TOKEN_Y=0x... # Address of second token (e.g., USDC)
ORACLE_ADDRESS=0x... # Pyth or Chainlink oracle address
```

---

## 🚀 Deployment Options

### Option A: Quick Deploy (All Systems at Once)

Deploy everything in one command:

```bash
./deploy-all.sh
```

This will:
1. Deploy or use existing Aqua
2. Deploy ConcentratedAMM + Builder
3. Deploy PseudoArbitrageAMM
4. Save all addresses to `deployments/`

### Option B: Step-by-Step Deploy (Recommended)

Deploy each system individually for more control.

---

## 📦 Step-by-Step Deployment

### Step 1: Deploy Concentrated AMM

```bash
cd packages/concentrated-amm

# Build contracts
forge build

# Run tests to verify
forge test -vv

# Deploy to testnet
forge script script/DeployConcentratedAMM.s.sol:DeployConcentratedAMM \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify

# Save addresses from output
```

**What Gets Deployed:**
- ✅ Aqua (if AQUA_ADDRESS not set)
- ✅ ConcentratedAMM
- ✅ ConcentratedAMMStrategyBuilder

**Output Location:**
- `deployments/concentrated-amm-latest.json`

---

### Step 2: Deploy Pseudo-Arbitrage AMM

```bash
cd ../pseudo-arbitrage-amm

# Build contracts
forge build

# Run tests
forge test -vv

# Deploy router
forge script lib/swap-vm/script/DeployAquaSwapVMRouter.s.sol \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify

# Note the router address from output
```

**What Gets Deployed:**
- ✅ PseudoArbitrageSwapVMRouter
- ✅ PseudoArbitrageAMM (strategy builder)

**Important:** This uses the same Aqua instance as ConcentratedAMM.

---

---

## 🌐 Network-Specific Deployment

### Testnet Deployment (Recommended First)

**Sepolia (Ethereum Testnet):**
```bash
export RPC_URL=https://rpc.sepolia.org
export ETHERSCAN_API_KEY=your_key
forge script script/DeployAll.s.sol --rpc-url $RPC_URL --broadcast --verify
```

**Base Sepolia:**
```bash
export RPC_URL=https://sepolia.base.org
forge script script/DeployAll.s.sol --rpc-url $RPC_URL --broadcast
```

### Mainnet Deployment

**Use Existing Aqua (Recommended):**
```bash
# Set existing Aqua address
export AQUA_ADDRESS=0x499943e74fb0ce105688beee8ef2abec5d936d31

# Available on these networks:
# - Ethereum Mainnet
# - Base
# - Optimism
# - Arbitrum
# - Polygon
# - Avalanche
# - BSC
# - Linea
# - Sonic
# - Unichain
# - Gnosis
# - zkSync

# Deploy
forge script script/DeployAll.s.sol \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify \
    --legacy  # Use for some networks
```

---

## ✅ Verify Deployment

### 1. Check Contract Addresses

```bash
# View saved addresses
cat deployments/concentrated-amm-latest.json
cat deployments/pseudo-arbitrage-amm-latest.json
cat deployments/deployment-summary.json
```

### 2. Run Integration Tests

```bash
# Test concentrated AMM position creation
export BUILDER_ADDRESS=<from deployment>
export TOKEN0_ADDRESS=<your token>
export TOKEN1_ADDRESS=<your token>

forge script packages/concentrated-amm/script/DeployConcentratedAMM.s.sol:CreateExamplePosition \
    --rpc-url $RPC_URL \
    --broadcast
```

### 3. Verify Contracts on Block Explorer

```bash
# Check contracts are verified
cast code $CONCENTRATED_AMM_ADDRESS --rpc-url $RPC_URL
cast code $PSEUDO_ARB_AMM_ADDRESS --rpc-url $RPC_URL
```

---

## 🎮 Post-Deployment Setup

### 1. Create Liquidity Positions

**Concentrated AMM:**
```bash
cd packages/concentrated-amm

# Create a concentrated liquidity position
forge script script/DeployConcentratedAMM.s.sol:CreateExamplePosition \
    --rpc-url $RPC_URL \
    --broadcast
```

**Pseudo-Arbitrage AMM:**
```bash
cd packages/pseudo-arbitrage-amm

# Deploy strategies with oracle pricing
forge script script/DeployPseudoArbitrageAMM.s.sol \
    --rpc-url $RPC_URL \
    --broadcast
```

### 2. Configure AMM Parameters

```bash
# Set fee tier for Concentrated AMM (0.3% = 3000)
cast send $CONCENTRATED_AMM_ADDRESS \
    "setFeeTier(uint24)" \
    3000 \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY

# Update oracle for Pseudo-Arbitrage AMM
cast send $PSEUDO_ARB_AMM_ADDRESS \
    "updateOracle(address)" \
    $ORACLE_ADDRESS \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY
```

### 3. Test Swaps

```bash
# Test swap on Concentrated AMM
cast send $CONCENTRATED_AMM_ADDRESS \
    "swap(address,address,uint256,uint256,address)" \
    $TOKEN0 $TOKEN1 1000000000000000000 0 $YOUR_ADDRESS \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY
```

---

## 💼 Using the AMMs

### Trading on Concentrated AMM

```bash
# Execute a swap
cast send $CONCENTRATED_AMM_ADDRESS \
    "swap(address,address,uint256,uint256,address)" \
    $TOKEN0 $TOKEN1 $AMOUNT_IN 0 $RECIPIENT \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY
```

### Adding Liquidity

```bash
# Add concentrated liquidity
forge script packages/concentrated-amm/script/DeployConcentratedAMM.s.sol:AddLiquidity \
    --rpc-url $RPC_URL \
    --broadcast
```

### Monitoring Positions

```bash
# Check position status
cast call $CONCENTRATED_AMM_ADDRESS \
    "getPosition(address,int24,int24)" \
    $OWNER $LOWER_TICK $UPPER_TICK \
    --rpc-url $RPC_URL
```

---

## 📊 Monitoring & Analytics

### View AMM Status

```bash
# Check Concentrated AMM liquidity
cast call $CONCENTRATED_AMM_ADDRESS \
    "getTotalLiquidity()" \
    --rpc-url $RPC_URL

# Check Pseudo-Arbitrage AMM pricing
cast call $PSEUDO_ARB_AMM_ADDRESS \
    "getCurrentPrice()" \
    --rpc-url $RPC_URL
```

### View Transaction History

```bash
# Get swap events
cast logs \
    --address $CONCENTRATED_AMM_ADDRESS \
    --from-block earliest \
    --rpc-url $RPC_URL \
    "Swap(address,address,uint256,uint256)"
```

---

## 🔧 Troubleshooting

### Issue: "Aqua not found"

```bash
# Solution: Deploy Aqua first or set existing address
export AQUA_ADDRESS=0x499943e74fb0ce105688beee8ef2abec5d936d31
```

### Issue: "Insufficient liquidity"

```bash
# Solution: Add more liquidity to the AMM
forge script packages/concentrated-amm/script/DeployConcentratedAMM.s.sol:AddLiquidity \
    --rpc-url $RPC_URL --broadcast
```

### Issue: "Price out of range"

**Causes:**
1. Concentrated liquidity position is out of range
2. Oracle price has deviated significantly

**Solutions:**
```bash
# Rebalance concentrated liquidity position
# Or expand price range when creating new positions
```

### Issue: "Transaction reverts"

```bash
# Debug with detailed trace
forge script ... --rpc-url $RPC_URL --broadcast -vvvv
```

---

## 🔐 Security Checklist

Before mainnet deployment:

- [ ] Audit private keys (use hardware wallet for production)
- [ ] Verify all contract addresses
- [ ] Test on testnet first
- [ ] Start with small capital
- [ ] Set conservative thresholds
- [ ] Monitor for first 24 hours
- [ ] Consider external audit
- [ ] Setup alerting for bot issues
- [ ] Document emergency procedures
- [ ] Have kill switch ready

---

## 📝 Deployment Summary Template

After deployment, fill this out:

```
=== Deployment Summary ===

Network: [Mainnet/Testnet]
Date: [YYYY-MM-DD]

Addresses:
- Aqua: 0x...
- ConcentratedAMM: 0x...
- ConcentratedBuilder: 0x...
- PseudoArbitrageAMM: 0x...

Configuration:
- Concentrated AMM Fee Tier: [X]%
- Pseudo-Arb Oracle: 0x...
- Token Pairs: [TOKEN0]/[TOKEN1]

Liquidity:
- Concentrated AMM TVL: [X] tokens
- Pseudo-Arb AMM TVL: [X] tokens

Status:
- [ ] Contracts deployed
- [ ] Contracts verified on explorer
- [ ] Liquidity positions created
- [ ] Parameters configured
- [ ] First swap tested
```

---

## 🎉 You're Ready!

Your AMM system should now be deployed and running. Monitor the bot for the first few hours and adjust parameters as needed.

**Next Steps:**
1. Create liquidity positions on both AMMs
2. Test swaps on each AMM
3. Monitor position performance
4. Optimize fee tiers and ranges
5. Scale up liquidity gradually

**Need Help?**
- Check logs: `cat deployments/*-deployment.log`
- Review docs: See each AMM's documentation
- Test mode: Run on testnet first

**Happy Building! 🚀**


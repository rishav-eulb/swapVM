# Complete Deployment Guide

This guide walks you through deploying all three AMM systems: Pseudo-Arbitrage AMM, Concentrated AMM, and Cross-AMM Arbitrage.

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
cd files/pseudo-arbitrage-amm && forge install
cd ../concentrated-amm && forge install
cd ../cross-amm-arbitrage && forge install
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
3. Deploy PseudoArbitrageAMM + Router
4. Deploy CrossAMMArbitrage + Bot
5. Save all addresses to `deployments/`

### Option B: Step-by-Step Deploy (Recommended)

Deploy each system individually for more control.

---

## 📦 Step-by-Step Deployment

### Step 1: Deploy Concentrated AMM

```bash
cd files/concentrated-amm

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

### Step 3: Deploy Cross-AMM Arbitrage

```bash
cd ../cross-amm-arbitrage

# Build contracts
forge build

# Run tests
forge test -vv

# Deploy arbitrage system
forge script DeployCrossAMMArbitrage.s.sol:DeployCrossAMMArbitrage \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify
```

**What Gets Deployed:**
- ✅ CrossAMMArbitrage
- ✅ CrossAMMArbitrageBot

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
# Concentrated AMM
forge script files/concentrated-amm/script/DeployConcentratedAMM.s.sol:VerifyDeployment \
    --rpc-url $RPC_URL

# View saved addresses
cat deployments/concentrated-amm-latest.json
```

### 2. Run Integration Tests

```bash
# Test concentrated AMM position creation
export BUILDER_ADDRESS=<from deployment>
export TOKEN0_ADDRESS=<your token>
export TOKEN1_ADDRESS=<your token>

forge script files/concentrated-amm/script/DeployConcentratedAMM.s.sol:CreateExamplePosition \
    --rpc-url $RPC_URL \
    --broadcast
```

### 3. Check Arbitrage Bot Status

```bash
export BOT_ADDRESS=<from deployment>
export TOKEN_X=<your token>

forge script files/cross-amm-arbitrage/DeployCrossAMMArbitrage.s.sol:MonitorOpportunities \
    --rpc-url $RPC_URL
```

---

## 🎮 Post-Deployment Setup

### 1. Fund the Arbitrage Bot

```bash
# Set bot address
export BOT_ADDRESS=0x...

# Run setup script
node scripts/fundBot.js
```

Or manually via Foundry:
```bash
cast send $BOT_ADDRESS \
    "depositCapital(address,uint256)" \
    $TOKEN_X \
    1000000000000000000000 \  # 1000 tokens (adjust decimals)
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY
```

### 2. Configure Bot Parameters

```bash
# Set minimum profit threshold (0.5% = 50 bps)
cast send $BOT_ADDRESS \
    "setMinProfitBps(uint256)" \
    50 \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY

# Set minimum discrepancy (1% = 100 bps)
cast send $BOT_ADDRESS \
    "setMinDiscrepancyBps(uint256)" \
    100 \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY

# Set max capital per arbitrage
cast send $BOT_ADDRESS \
    "setMaxCapitalPerArbitrage(address,uint256)" \
    $TOKEN_X \
    100000000000000000000 \  # 100 tokens
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY
```

### 3. Add Authorized Executors

```bash
# Add your keeper/bot address
cast send $BOT_ADDRESS \
    "setExecutor(address,bool)" \
    0xYourKeeperAddress \
    true \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY
```

---

## 🤖 Running the Arbitrage Bot

### Option 1: Automated Monitoring (Recommended)

Create a monitoring script (`scripts/monitor.js`):

```javascript
const { ethers } = require('ethers');

const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

const botAddress = process.env.BOT_ADDRESS;
const botABI = [...]; // Load from artifacts

const bot = new ethers.Contract(botAddress, botABI, wallet);

async function monitorAndExecute() {
    console.log('Checking for opportunities...');
    
    try {
        // Check if opportunities exist
        const [hasOpp, profit] = await bot.checkForOpportunities();
        
        if (hasOpp) {
            console.log(`Opportunity found! Estimated profit: ${profit}`);
            
            // Execute
            const tx = await bot.scanAllStrategies();
            const receipt = await tx.wait();
            
            console.log(`Executed! Gas used: ${receipt.gasUsed}`);
            console.log(`Transaction: ${receipt.transactionHash}`);
        } else {
            console.log('No opportunities at this time');
        }
    } catch (error) {
        console.error('Error:', error.message);
    }
}

// Run every 30 seconds
setInterval(monitorAndExecute, 30000);
```

Run it:
```bash
node scripts/monitor.js
```

### Option 2: Manual Execution

```bash
# Check for opportunities
forge script files/cross-amm-arbitrage/DeployCrossAMMArbitrage.s.sol:MonitorOpportunities \
    --rpc-url $RPC_URL

# Execute if found
forge script files/cross-amm-arbitrage/DeployCrossAMMArbitrage.s.sol:ExecuteArbitrage \
    --rpc-url $RPC_URL \
    --broadcast
```

### Option 3: Use Gelato Network (Automated)

Deploy a Gelato resolver for fully automated execution without maintaining infrastructure.

---

## 📊 Monitoring & Analytics

### View Bot Performance

```bash
# Check performance stats
cast call $BOT_ADDRESS \
    "getPerformanceStats(address)" \
    $TOKEN_X \
    --rpc-url $RPC_URL

# Check capital status
cast call $BOT_ADDRESS \
    "getCapitalStatus(address)" \
    $TOKEN_X \
    --rpc-url $RPC_URL
```

### View Transaction History

```bash
# Get bot execution events
cast logs \
    --address $BOT_ADDRESS \
    --from-block earliest \
    --rpc-url $RPC_URL \
    "ArbitrageExecuted(address,address,uint256,uint256,uint256,uint256)"
```

---

## 🔧 Troubleshooting

### Issue: "Aqua not found"

```bash
# Solution: Deploy Aqua first or set existing address
export AQUA_ADDRESS=0x499943e74fb0ce105688beee8ef2abec5d936d31
```

### Issue: "Insufficient capital"

```bash
# Solution: Fund the bot
cast send $BOT_ADDRESS "depositCapital(address,uint256)" ...
```

### Issue: "No opportunities found"

**Causes:**
1. Prices are in sync (no arbitrage available)
2. Minimum thresholds too high
3. Insufficient liquidity on one side

**Solutions:**
```bash
# Lower thresholds
cast send $BOT_ADDRESS "setMinProfitBps(uint256)" 25 ...
cast send $BOT_ADDRESS "setMinDiscrepancyBps(uint256)" 50 ...
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
- PseudoArbRouter: 0x...
- PseudoArbBuilder: 0x...
- CrossAMMArbitrage: 0x...
- CrossAMMArbitrageBot: 0x...

Configuration:
- Min Profit: [X]%
- Min Discrepancy: [X]%
- Max Capital Per Trade: [X] tokens
- Monitoring Interval: [X] seconds

Funding:
- Bot Capital: [X] tokens
- Token Address: 0x...

Status:
- [ ] Contracts deployed
- [ ] Contracts verified on explorer
- [ ] Bot funded
- [ ] Parameters configured
- [ ] Monitoring active
- [ ] First arbitrage tested
```

---

## 🎉 You're Ready!

Your AMM system should now be deployed and running. Monitor the bot for the first few hours and adjust parameters as needed.

**Next Steps:**
1. Create liquidity positions on both AMMs
2. Start the monitoring bot
3. Watch for first arbitrage execution
4. Optimize parameters based on results
5. Scale up capital gradually

**Need Help?**
- Check logs: `tail -f bot.log`
- Review docs: See each AMM's documentation
- Test mode: Run on testnet first

**Happy Trading! 🚀**


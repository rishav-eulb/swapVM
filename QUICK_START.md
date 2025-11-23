# Quick Start Guide

Get your AMM system deployed and running in 10 minutes!

---

## 🚀 Super Quick Deploy (1 command)

```bash
# 1. Setup environment
cp .env.example .env
nano .env  # Add your PRIVATE_KEY and RPC_URL

# 2. Deploy everything
./deploy-all.sh

# Done! 🎉
```

---

## 📝 Step-by-Step (5 minutes)

### 1. Prerequisites (30 seconds)

```bash
# Check Foundry is installed
forge --version

# If not installed:
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. Configure Environment (1 minute)

```bash
# Copy example file
cp .env.example .env

# Edit with your details
nano .env
```

**Minimum Required:**
```bash
PRIVATE_KEY=your_private_key_here_no_0x
RPC_URL=https://eth-sepolia.g.alchemy.com/v2/your-key
```

**Optional (use existing Aqua):**
```bash
AQUA_ADDRESS=0x499943e74fb0ce105688beee8ef2abec5d936d31
```

### 3. Deploy Contracts (2 minutes)

```bash
# Deploy all systems
./deploy-all.sh
```

This deploys:
- ✅ Aqua (if needed)
- ✅ ConcentratedAMM
- ✅ PseudoArbitrageAMM
- ✅ CrossAMMArbitrage Bot

### 4. Fund the Bot (1 minute)

```bash
# Load deployment addresses
source .env.deployed

# Fund bot with 1000 tokens (adjust for your token decimals)
cast send $BOT_ADDRESS \
    "depositCapital(address,uint256)" \
    $TOKEN_X \
    1000000000000000000000 \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY
```

### 5. Start Monitoring (30 seconds)

```bash
# Install Node.js dependencies
npm install ethers dotenv

# Run the bot
node scripts/monitor.js
```

**Done!** Your bot is now monitoring for arbitrage opportunities. 🤖

---

## 🎮 Testing on Testnet

### Sepolia (Ethereum Testnet)

```bash
# Get testnet ETH
# Visit: https://sepoliafaucet.com/

# Get testnet tokens
# Use Uniswap on Sepolia or a faucet

# Deploy
export RPC_URL=https://rpc.sepolia.org
./deploy-all.sh
```

### Create Test Positions

```bash
# After deployment, create liquidity positions
cd files/concentrated-amm

export BUILDER_ADDRESS=$(cat ../../deployments/concentrated-amm-latest.json | jq -r '.strategyBuilder')
export TOKEN0_ADDRESS=0xYourTestToken0
export TOKEN1_ADDRESS=0xYourTestToken1

forge script script/DeployConcentratedAMM.s.sol:CreateExamplePosition \
    --rpc-url $RPC_URL \
    --broadcast
```

---

## 🔧 Quick Configuration

### Set Bot Parameters

```bash
source .env.deployed

# Minimum profit: 0.5%
cast send $BOT_ADDRESS "setMinProfitBps(uint256)" 50 \
    --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# Minimum discrepancy: 1%
cast send $BOT_ADDRESS "setMinDiscrepancyBps(uint256)" 100 \
    --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# Max capital per trade: 100 tokens
cast send $BOT_ADDRESS "setMaxCapitalPerArbitrage(address,uint256)" \
    $TOKEN_X 100000000000000000000 \
    --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

---

## 📊 Quick Status Check

### Check Bot Status

```bash
source .env.deployed

# Check for opportunities
forge script files/cross-amm-arbitrage/DeployCrossAMMArbitrage.s.sol:MonitorOpportunities \
    --rpc-url $RPC_URL
```

### View Performance

```bash
# Get performance stats
cast call $BOT_ADDRESS \
    "getPerformanceStats(address)(uint256,uint256,uint256,uint256,uint256)" \
    $TOKEN_X \
    --rpc-url $RPC_URL
```

### Check Capital

```bash
# View available capital
cast call $BOT_ADDRESS \
    "getCapitalStatus(address)(uint256,uint256,uint256)" \
    $TOKEN_X \
    --rpc-url $RPC_URL
```

---

## 💡 Common Issues & Solutions

### "Insufficient Funds"

```bash
# Check your wallet balance
cast balance $YOUR_ADDRESS --rpc-url $RPC_URL

# Get testnet funds from faucet
```

### "Contract Not Found"

```bash
# Verify deployment
cat deployments/deployment-summary.json

# Re-deploy if needed
./deploy-all.sh
```

### "No Opportunities Found"

This is normal! Arbitrage opportunities appear when:
1. Market price changes
2. Oracle updates (PseudoArbitrageAMM)
3. ConcentratedAMM prices become stale

**To test manually:**
- Create price differences by trading on one AMM
- Wait for oracle to update
- Bot should detect the gap

### "Transaction Reverts"

```bash
# Run with detailed logging
forge script ... --rpc-url $RPC_URL --broadcast -vvvv

# Check gas balance
cast balance $YOUR_ADDRESS --rpc-url $RPC_URL
```

---

## 🎯 Next Steps

After deployment:

1. **Monitor First 24 Hours**
   - Watch bot logs
   - Check for first arbitrage
   - Adjust parameters if needed

2. **Optimize Parameters**
   ```bash
   # Lower thresholds for more trades
   cast send $BOT_ADDRESS "setMinProfitBps(uint256)" 25 ...
   
   # Or raise for more selective trading
   cast send $BOT_ADDRESS "setMinProfitBps(uint256)" 100 ...
   ```

3. **Scale Up**
   ```bash
   # Add more capital
   cast send $BOT_ADDRESS "depositCapital(address,uint256)" ...
   
   # Add more strategies
   cast send $BOT_ADDRESS "addStrategy(...)" ...
   ```

4. **Production Deployment**
   ```bash
   # Use mainnet RPC
   export RPC_URL=https://eth-mainnet.g.alchemy.com/v2/your-key
   
   # Use existing Aqua
   export AQUA_ADDRESS=0x499943e74fb0ce105688beee8ef2abec5d936d31
   
   # Deploy
   ./deploy-all.sh
   ```

---

## 📚 More Information

- **Full Guide**: See [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)
- **Architecture**: See each AMM's documentation
- **Troubleshooting**: Check deployment logs in `deployments/`

---

## 🆘 Need Help?

**Check Logs:**
```bash
# Deployment logs
cat deployments/*-deployment.log

# Test reports
cat deployments/*-test-report.txt

# Deployment summary
cat deployments/deployment-summary.json
```

**Verify Contracts:**
```bash
# Check if contracts exist
cast code $BOT_ADDRESS --rpc-url $RPC_URL
```

**Test Connection:**
```bash
# Check RPC
cast block-number --rpc-url $RPC_URL

# Check wallet
cast balance $YOUR_ADDRESS --rpc-url $RPC_URL
```

---

## 🎉 You're All Set!

Your AMM arbitrage system is now deployed and running. The bot will automatically:
- ✅ Monitor for price discrepancies
- ✅ Calculate optimal arbitrage amounts
- ✅ Execute profitable trades
- ✅ Track performance metrics

**Happy Trading! 🚀**

---

## ⚡ One-Liner Cheat Sheet

```bash
# Full deployment
cp .env.example .env && nano .env && ./deploy-all.sh && source .env.deployed && npm install && node scripts/monitor.js

# Just monitoring (after deployment)
source .env.deployed && node scripts/monitor.js

# Quick status check
source .env.deployed && forge script files/cross-amm-arbitrage/DeployCrossAMMArbitrage.s.sol:MonitorOpportunities --rpc-url $RPC_URL

# Quick fund bot
source .env.deployed && cast send $BOT_ADDRESS "depositCapital(address,uint256)" $TOKEN_X 1000000000000000000000 --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```


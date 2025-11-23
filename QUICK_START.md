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

# 3. Create liquidity positions
cd packages/concentrated-amm
forge script script/DeployConcentratedAMM.s.sol:CreateExamplePosition --rpc-url $RPC_URL --broadcast

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

### 4. Create Liquidity Positions (1 minute)

```bash
# Load deployment addresses
source .env.deployed

# Create a concentrated liquidity position
cd packages/concentrated-amm
forge script script/DeployConcentratedAMM.s.sol:CreateExamplePosition \
    --rpc-url $RPC_URL \
    --broadcast
```

### 5. Test Your AMMs (30 seconds)

```bash
# Test a swap on Concentrated AMM
cast send $CONCENTRATED_AMM_ADDRESS \
    "swap(address,address,uint256,uint256,address)" \
    $TOKEN0 $TOKEN1 1000000000000000000 0 $YOUR_ADDRESS \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY
```

**Done!** Your AMM system is now live! 🚀

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
cd packages/concentrated-amm

export BUILDER_ADDRESS=$(cat ../../deployments/concentrated-amm-latest.json | jq -r '.strategyBuilder')
export TOKEN0_ADDRESS=0xYourTestToken0
export TOKEN1_ADDRESS=0xYourTestToken1

forge script script/DeployConcentratedAMM.s.sol:CreateExamplePosition \
    --rpc-url $RPC_URL \
    --broadcast
```

---

## 🔧 Quick Configuration

### Set AMM Parameters

```bash
source .env.deployed

# Set Concentrated AMM fee tier (0.3% = 3000)
cast send $CONCENTRATED_AMM_ADDRESS "setFeeTier(uint24)" 3000 \
    --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# Update Pseudo-Arbitrage AMM oracle
cast send $PSEUDO_ARB_AMM_ADDRESS "updateOracle(address)" $ORACLE_ADDRESS \
    --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

---

## 📊 Quick Status Check

### Check AMM Status

```bash
source .env.deployed

# Check Concentrated AMM liquidity
cast call $CONCENTRATED_AMM_ADDRESS "getTotalLiquidity()" --rpc-url $RPC_URL

# Check Pseudo-Arbitrage AMM pricing
cast call $PSEUDO_ARB_AMM_ADDRESS "getCurrentPrice()" --rpc-url $RPC_URL
```

### View Deployment Info

```bash
# View all deployed contracts
cat deployments/deployment-summary.json

# Check specific AMM
cast call $CONCENTRATED_AMM_ADDRESS "aqua()" --rpc-url $RPC_URL
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

### "No Liquidity"

This is expected after initial deployment!

**To add liquidity:**
- Create positions on Concentrated AMM with specific price ranges
- Deploy strategies on Pseudo-Arbitrage AMM with oracle pricing
- Both AMMs will share the Aqua liquidity layer

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

1. **Add More Liquidity**
   - Create multiple positions with different ranges
   - Monitor fee earnings from trades
   - Rebalance positions as needed

2. **Optimize Positions**
   ```bash
   # Create tighter ranges for higher fees
   forge script packages/concentrated-amm/script/DeployConcentratedAMM.s.sol:CreateTightPosition \
       --rpc-url $RPC_URL --broadcast
   ```

3. **Scale Up**
   ```bash
   # Add more token pairs
   # Deploy to multiple networks
   # Integrate with your dApp
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
cast code $CONCENTRATED_AMM_ADDRESS --rpc-url $RPC_URL
cast code $PSEUDO_ARB_AMM_ADDRESS --rpc-url $RPC_URL
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

Your AMM system is now deployed and running. You can now:
- ✅ Create liquidity positions on both AMMs
- ✅ Execute swaps with competitive pricing
- ✅ Earn fees from traders
- ✅ Manage positions efficiently

**Happy Building! 🚀**

---

## ⚡ One-Liner Cheat Sheet

```bash
# Full deployment
cp .env.example .env && nano .env && ./deploy-all.sh && source .env.deployed

# Create liquidity position
source .env.deployed && cd packages/concentrated-amm && forge script script/DeployConcentratedAMM.s.sol:CreateExamplePosition --rpc-url $RPC_URL --broadcast

# Quick status check
source .env.deployed && cast call $CONCENTRATED_AMM_ADDRESS "getTotalLiquidity()" --rpc-url $RPC_URL

# Check deployment
cat deployments/deployment-summary.json
```


# TypeScript Testing Suite - Quick Start

## 🎯 What You Got

I've created a complete TypeScript testing infrastructure for your AMM system and Pyth Price Adapter:

### 📁 New Files

1. **Test Scripts** (in `scripts/`)
   - `test-liquidity.ts` - Tests liquidity provisioning & swapping
   - `test-pyth-adapter.ts` - Tests Pyth price oracle integration
   - `deploy-pyth-adapter.sh` - Automated Pyth adapter deployment
   - `README.md` - Detailed script documentation

2. **Configuration**
   - `tsconfig.json` - TypeScript configuration
   - `env.example` - Environment variable template
   - Updated `package.json` - Added TypeScript dependencies & scripts

3. **Documentation**
   - `TESTING_GUIDE.md` - Complete testing guide (prerequisites, setup, troubleshooting)
   - `TEST_SCRIPTS_SUMMARY.md` - Overview and features
   - This file - Quick start instructions

## ⚡ 3-Minute Quick Start

```bash
# 1. Install dependencies
npm install

# 2. Configure environment
cp env.example .env
# Edit .env and add your RPC_URL and PRIVATE_KEY

# 3. Run tests
npm run test:liquidity  # Test AMM functionality
npm run test:pyth       # Test Pyth adapter
npm run test:all        # Run both
```

## 📊 What Gets Tested

### Liquidity & Swap Tests (`test-liquidity.ts`)

✅ **Token Balances**
- ETH balance check
- WETH balance check  
- USDC balance check

✅ **Concentrated AMM**
- Get total liquidity
- Quote swap amounts
- Build liquidity programs
- Validate program structure

✅ **Pseudo-Arbitrage AMM**
- Build programs with various parameters
- Input validation (zero balances, excessive fees)
- Error handling
- Different price scenarios

### Pyth Adapter Tests (`test-pyth-adapter.ts`)

✅ **System Diagnostics**
- Network verification
- Wallet balance check
- Configuration validation

✅ **Pyth Network Connection**
- Connect to Pyth contract
- Check price feed availability
- Fetch raw price data
- Verify price freshness

✅ **Adapter Configuration**
- Verify deployment
- Check settings (maxPriceAge, owner)
- Test ownership permissions
- Configure price feeds

✅ **Price Operations**
- Fetch raw Pyth prices
- Convert prices (Pyth format → 1e18)
- Handle stale prices
- Test error cases

✅ **Integration**
- Simulate AMM usage
- Estimate gas costs
- Validate compatibility

## 🛠️ Available Commands

```bash
# Testing
npm run test:liquidity   # Test AMM liquidity & swaps
npm run test:pyth        # Test Pyth price adapter
npm run test:all         # Run all tests

# Monitoring
npm run monitor          # Monitor deployed contracts

# Deployment
./scripts/deploy-pyth-adapter.sh [MAX_AGE]
```

## 📖 Example Output

### Successful Test Run

```
======================================================================
AMM LIQUIDITY & SWAP TEST SUITE
======================================================================

[2025-11-23T...] Network: https://base-sepolia.g.alchemy.com/v2/...
[2025-11-23T...] Wallet: 0x742d35Cc...

✓ Check ETH Balance (125ms)
ℹ ETH Balance: 0.5234 ETH

✓ Build Liquidity Program (198ms)
ℹ Program built successfully
ℹ Bytecode length: 512 bytes

✓ Get Converted Price (234ms)
ℹ Converted Price: 3000.0 (in 1e18 format)

======================================================================
TEST SUMMARY
======================================================================
Total Tests: 15
Passed: 15 ✓
Failed: 0 ✗
```

## 🔧 Configuration

### Minimal .env Setup

```env
RPC_URL=https://base-sepolia.g.alchemy.com/v2/YOUR_API_KEY
PRIVATE_KEY=0xYOUR_PRIVATE_KEY
```

### Full Configuration (Optional)

```env
# Required
RPC_URL=https://base-sepolia.g.alchemy.com/v2/...
PRIVATE_KEY=0x...

# Pyth Configuration
PYTH_ADDRESS=0xA2aa501b19aff244D90cc15a4Cf739D2725B5729
PYTH_ADAPTER_ADDRESS=0x...  # After deployment

# Token Addresses
WETH_ADDRESS=0x...
USDC_ADDRESS=0x...

# Contract Addresses (auto-populated by deploy-all.sh)
AQUA_ADDRESS=0x...
CONCENTRATED_AMM_ADDRESS=0x...
PSEUDO_ARB_AMM_ADDRESS=0x...
```

See `env.example` for complete configuration options.

## 🚀 Deployment Workflow

### Complete Setup (First Time)

```bash
# 1. Install and configure
npm install
cp env.example .env
# Edit .env

# 2. Deploy AMM contracts
./deploy-all.sh
source .env.deployed

# 3. Deploy Pyth adapter
./scripts/deploy-pyth-adapter.sh 3600

# 4. Configure price feeds
cast send $PYTH_ADAPTER_ADDRESS \
  "setPriceFeed(address,address,bytes32)" \
  $WETH_ADDRESS $USDC_ADDRESS \
  0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# 5. Run tests
npm run test:all
```

### Testing Existing Deployment

```bash
# Just need .env configured
npm run test:all
```

## 🧪 Test Features

### Smart Error Handling

Tests gracefully handle:
- ❌ Missing configuration → Clear instructions
- ❌ Contract not deployed → Shows deployment commands
- ❌ Stale prices → Explains testnet behavior
- ❌ Insufficient funds → Links to faucets
- ❌ Permission errors → Explains ownership

### Rich Logging

- ✓ Success (green checkmarks)
- ℹ Info (operation details)
- ⚠ Warnings (non-fatal issues)
- ✗ Errors (with solutions)

### Real-World Tests

- Fetches live prices from Pyth Network
- Tests with realistic AMM parameters
- Validates gas costs
- Checks edge cases

## 📚 Documentation

| File | Purpose |
|------|---------|
| `TESTING_GUIDE.md` | Complete testing guide (setup, troubleshooting, advanced) |
| `TEST_SCRIPTS_SUMMARY.md` | Overview, features, and examples |
| `scripts/README.md` | Script details and API reference |
| `env.example` | Configuration template with all options |
| This file | Quick start instructions |

## 🐛 Quick Troubleshooting

### "Price is stale"

**Common on testnets** - Pyth updates infrequently

**Fix**: Deploy with longer maxPriceAge:
```bash
./scripts/deploy-pyth-adapter.sh 86400  # 24 hours
```

### "PriceFeedNotConfigured"

**Need to configure price feed first**

**Fix**:
```bash
cast send $PYTH_ADAPTER_ADDRESS \
  "setPriceFeed(address,address,bytes32)" \
  $WETH $USDC 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

### "Insufficient funds"

**Need testnet ETH**

**Fix**: Visit faucet:
- Base Sepolia: https://www.coinbase.com/faucets/base-ethereum-goerli-faucet

### More Help

See `TESTING_GUIDE.md` → Troubleshooting section

## 🎓 Learning Path

1. **Start Here**: Run tests with your configuration
   ```bash
   npm run test:all
   ```

2. **Understand Output**: Read test results and logs

3. **Read Docs**: Check `TESTING_GUIDE.md` for details

4. **Explore Code**: Scripts are well-commented

5. **Extend Tests**: Add your own test cases

## 💡 Key Resources

### Pyth Network

- **Contract Addresses**: https://docs.pyth.network/price-feeds/contract-addresses/evm
- **Price Feed IDs**: https://pyth.network/developers/price-feed-ids
- **Documentation**: https://docs.pyth.network/

### Common Price Feeds

| Pair | ID |
|------|-----|
| ETH/USD | `0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace` |
| BTC/USD | `0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43` |
| USDC/USD | `0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a` |

### Pyth Contract Addresses

| Network | Address |
|---------|---------|
| Base | `0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a` |
| Base Sepolia | `0xA2aa501b19aff244D90cc15a4Cf739D2725B5729` |
| Ethereum | `0x4305FB66699C3B2702D4d05CF36551390A4c69C6` |
| Arbitrum | `0xff1a0f4744e8582DF1aE09D5611b887B6a12925C` |

## ✨ What Makes This Special

✅ **Zero On-Chain Transactions** - Tests run locally (fast & free)  
✅ **Real Price Data** - Fetches live prices from Pyth Network  
✅ **Comprehensive** - Tests all major functionality  
✅ **Developer-Friendly** - TypeScript, clear errors, good docs  
✅ **Production-Ready** - Proper error handling & validation  
✅ **Extensible** - Easy to add custom tests  
✅ **CI/CD Ready** - Exit codes for automated testing  

## 🚦 Next Steps

After successful testing:

1. ✅ Deploy contracts (if not done): `./deploy-all.sh`
2. ✅ Deploy Pyth adapter: `./scripts/deploy-pyth-adapter.sh`
3. ✅ Configure price feeds (see above)
4. ✅ Run tests: `npm run test:all`
5. 🚀 Start using the AMM system!

## 📝 Summary

You now have:
- ✅ Complete TypeScript testing suite
- ✅ Liquidity & swap tests
- ✅ Pyth adapter tests
- ✅ Deployment automation
- ✅ Comprehensive documentation
- ✅ Error handling & troubleshooting

**Start testing in 3 commands:**
```bash
npm install
cp env.example .env  # Then edit with your config
npm run test:all
```

Happy testing! 🎉

---

**Questions?** Check:
- `TESTING_GUIDE.md` for detailed guide
- `scripts/README.md` for script details
- Source code for implementation details


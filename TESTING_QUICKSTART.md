# Testing Quick Start Guide

**Get testing in 5 minutes!** ⚡

## ✅ What You Have

I've created comprehensive TypeScript tests for:
- ✅ Liquidity provisioning and swapping
- ✅ Pyth Price Adapter (oracle integration)
- ✅ Program building and validation
- ✅ Error handling and edge cases

## 🚀 Start Testing NOW

### Step 1: Install (30 seconds)

```bash
npm install
```

### Step 2: Configure (2 minutes)

```bash
# Copy configuration template
cp env.example .env

# Edit .env and add these 2 required values:
nano .env
```

**Minimum required:**
```env
RPC_URL=https://base-sepolia.g.alchemy.com/v2/YOUR_API_KEY
PRIVATE_KEY=0xYOUR_PRIVATE_KEY
```

**Get these:**
- RPC URL: Sign up at [Alchemy](https://www.alchemy.com/) (free)
- Private Key: Export from MetaMask (use a test wallet!)

### Step 3: Run Tests (30 seconds)

```bash
# Test AMM liquidity and swaps
npm run test:liquidity

# Test Pyth price adapter  
npm run test:pyth

# Or run both
npm run test:all
```

That's it! 🎉

## 📊 What You'll See

```
======================================================================
AMM LIQUIDITY & SWAP TEST SUITE
======================================================================

[2025-11-23T...] Wallet: 0x742d35Cc...

✓ Check ETH Balance (125ms)
✓ Build Liquidity Program (198ms)
✓ Quote Swap (156ms)

======================================================================
TEST SUMMARY
======================================================================
Total Tests: 8
Passed: 8 ✓
Failed: 0 ✗
```

## 🎯 Test Commands

| Command | What It Tests |
|---------|---------------|
| `npm run test:liquidity` | AMM liquidity & swaps |
| `npm run test:pyth` | Pyth price oracle |
| `npm run test:all` | Everything |
| `npm run monitor` | Live contract monitoring |

## 📖 Documentation

| File | When to Read |
|------|--------------|
| **TESTS_README.md** | Start here - Overview |
| **TESTING_GUIDE.md** | Detailed setup & troubleshooting |
| **scripts/README.md** | Script API reference |
| **env.example** | All configuration options |

## 🎓 Learning Path

```
1. Run tests                    ← You are here
   └─> npm run test:all

2. Read test output
   └─> Understand what's tested

3. Review docs (if needed)
   └─> TESTING_GUIDE.md

4. Deploy contracts (if needed)
   └─> ./deploy-all.sh

5. Deploy Pyth adapter (optional)
   └─> ./scripts/deploy-pyth-adapter.sh
```

## 🐛 Common First-Time Issues

### ❌ "Cannot find module 'ts-node'"

**Fix:** Run `npm install` first

### ❌ "RPC_URL not set"

**Fix:** Create `.env` file (see Step 2 above)

### ❌ "Contract not deployed"

**This is OK!** Many tests work without deployments. To deploy:
```bash
./deploy-all.sh
```

### ❌ "Price is stale" (Pyth tests)

**This is normal on testnets.** Pyth prices update slowly on test networks.

**Fix:** Deploy adapter with longer maxPriceAge:
```bash
./scripts/deploy-pyth-adapter.sh 86400  # 24 hours
```

## ✨ What Makes These Tests Special

| Feature | Benefit |
|---------|---------|
| ✅ **No gas fees** | Tests run locally |
| ✅ **Fast** | Complete in seconds |
| ✅ **Real prices** | Fetches from Pyth Network |
| ✅ **Type-safe** | TypeScript catches errors |
| ✅ **Well-documented** | Clear errors & solutions |
| ✅ **Extensible** | Easy to add tests |

## 🎯 Quick Wins

### Test 1: Check Your Balance

```bash
npm run test:liquidity
```

Instantly see:
- ✅ Your ETH balance
- ✅ Token balances
- ✅ Network connection

### Test 2: Check Pyth Network

```bash
npm run test:pyth
```

Instantly see:
- ✅ Pyth contract connectivity
- ✅ Live ETH/USD price
- ✅ Network diagnostics

### Test 3: Build AMM Programs

```bash
npm run test:liquidity
```

See:
- ✅ Program building working
- ✅ Parameter validation
- ✅ Error handling

## 🔥 Pro Tips

### Tip 1: Test Without Deployments

Most tests work without deployed contracts! They test:
- Program building
- Quote generation  
- Price fetching
- Parameter validation

### Tip 2: Use Testnet First

Always test on Base Sepolia or Sepolia first:
- Free testnet ETH
- No risk
- Fast iteration

### Tip 3: Read Error Messages

Tests give clear error messages with solutions:

```
✗ Configure ETH/USD Price Feed
  Error: PriceFeedNotConfigured

ℹ Run: adapter.setPriceFeed(WETH, USDC, FEED_ID)
```

### Tip 4: Check Gas Costs

Pyth tests estimate gas costs:
```
ℹ Estimated gas for getPrice(): 45000
ℹ Estimated cost: 0.0001 ETH
```

## 🚀 Next Steps

After testing works:

1. ✅ **Deploy contracts** (if needed)
   ```bash
   ./deploy-all.sh
   ```

2. ✅ **Deploy Pyth adapter** (for oracle)
   ```bash
   ./scripts/deploy-pyth-adapter.sh
   ```

3. ✅ **Configure price feeds**
   ```bash
   cast send $PYTH_ADAPTER_ADDRESS \
     "setPriceFeed(address,address,bytes32)" \
     $WETH $USDC $FEED_ID \
     --rpc-url $RPC_URL --private-key $PRIVATE_KEY
   ```

4. ✅ **Test again**
   ```bash
   npm run test:all
   ```

5. 🎉 **Start using the AMM!**

## 💡 Need More Help?

### Quick Questions

Check `TESTS_README.md` (overview) or `TESTING_GUIDE.md` (detailed).

### Specific Issues

See `TESTING_GUIDE.md` → Troubleshooting section.

### Understanding Code

Scripts are heavily commented - read the source:
- `scripts/test-liquidity.ts`
- `scripts/test-pyth-adapter.ts`

### Pyth Network

- Docs: https://docs.pyth.network/
- Price Feeds: https://pyth.network/developers/price-feed-ids
- Contracts: https://docs.pyth.network/price-feeds/contract-addresses/evm

## 📦 What's Included

```
Created Files:
✅ scripts/test-liquidity.ts          - Liquidity & swap tests
✅ scripts/test-pyth-adapter.ts       - Pyth adapter tests
✅ scripts/deploy-pyth-adapter.sh     - Deployment automation
✅ scripts/README.md                  - Script documentation
✅ tsconfig.json                      - TypeScript config
✅ env.example                        - Config template
✅ TESTING_GUIDE.md                   - Complete guide
✅ TESTS_README.md                    - Overview
✅ TEST_SCRIPTS_SUMMARY.md            - Feature summary
✅ This file                          - Quick start

Updated Files:
✅ package.json                       - Added TS deps & scripts
```

## 🎉 You're Ready!

**Start testing:**
```bash
npm install
cp env.example .env  # Edit with your RPC_URL & PRIVATE_KEY
npm run test:all
```

**Time to results:** ~3 minutes from start to finish!

---

**Questions?** Check the docs above or read the source code (it's well-commented).

**Enjoy testing!** 🚀


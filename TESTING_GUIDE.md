# Testing Guide

Complete guide for testing the AMM system and Pyth Price Adapter.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Running Tests](#running-tests)
- [Test Coverage](#test-coverage)
- [Troubleshooting](#troubleshooting)
- [Advanced Usage](#advanced-usage)

## Prerequisites

### Required Software

- **Node.js** >= 14.0.0 ([Download](https://nodejs.org/))
- **npm** (comes with Node.js)
- **Foundry** (for contract deployment) ([Install](https://getfoundry.sh/))

### Required Accounts

1. **RPC Provider**: Alchemy, Infura, or similar
   - Sign up at [Alchemy](https://www.alchemy.com/) or [Infura](https://infura.io/)
   - Create a project for your network (e.g., Base Sepolia)

2. **Wallet**: MetaMask or similar
   - Export your private key (use a burner wallet for testing!)
   - Get testnet ETH from faucets

3. **Block Explorer** (optional, for verification):
   - [Basescan](https://basescan.org/)
   - [Etherscan](https://etherscan.io/)

## Quick Start

### 1. Install Dependencies

```bash
npm install
```

This installs:
- `ethers@5.7.2` - Ethereum library
- `dotenv` - Environment variables
- `typescript` - TypeScript compiler
- `ts-node` - TypeScript runtime
- `@types/node` - Node.js types

### 2. Configure Environment

```bash
# Copy example configuration
cp env.example .env

# Edit .env with your settings
nano .env  # or use your favorite editor
```

Minimum required configuration:
```env
RPC_URL=https://base-sepolia.g.alchemy.com/v2/YOUR_API_KEY
PRIVATE_KEY=0xYOUR_PRIVATE_KEY
```

### 3. Get Testnet ETH

Visit these faucets:
- **Base Sepolia**: https://www.coinbase.com/faucets/base-ethereum-goerli-faucet
- **Sepolia**: https://sepoliafaucet.com/
- **Mumbai**: https://faucet.polygon.technology/

You need at least 0.01 ETH for testing.

### 4. Deploy Contracts (if not already deployed)

```bash
# Deploy all AMM contracts
./deploy-all.sh

# Load deployed addresses into environment
source .env.deployed
```

### 5. Run Tests

```bash
# Test liquidity and swapping
npm run test:liquidity

# Test Pyth price adapter
npm run test:pyth

# Run all tests
npm run test:all
```

## Detailed Setup

### Step 1: Deploy Mock Tokens (Optional)

If you need test tokens for swapping:

```bash
./deploy-mock-tokens.sh
```

This deploys:
- Mock WETH (Wrapped ETH)
- Mock USDC (USD Coin)

Addresses will be automatically added to `.env.deployed`.

### Step 2: Deploy Pyth Price Adapter

#### Option A: Using the deployment script (recommended)

```bash
# Deploy with default settings (1 hour max age)
./scripts/deploy-pyth-adapter.sh

# Deploy with custom max age (24 hours for testnets)
./scripts/deploy-pyth-adapter.sh 86400
```

The script will:
- ✓ Validate your configuration
- ✓ Deploy the adapter contract
- ✓ Update your `.env` file
- ✓ Save deployment info
- ✓ Show next steps

#### Option B: Manual deployment

```bash
cd packages/pseudo-arbitrage-amm

# Set Pyth address for your network
# Base Sepolia: 0xA2aa501b19aff244D90cc15a4Cf739D2725B5729
PYTH_ADDRESS="0xA2aa501b19aff244D90cc15a4Cf739D2725B5729"

# Deploy adapter (3600 = 1 hour max age)
forge create src/oracles/PythPriceAdapter.sol:PythPriceAdapter \
  --constructor-args $PYTH_ADDRESS 3600 \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

# Copy deployed address to .env
echo "PYTH_ADAPTER_ADDRESS=0x..." >> ../../.env
```

### Step 3: Configure Price Feeds

After deploying the adapter, configure price feeds for token pairs:

```bash
# Set WETH/USDC price feed to ETH/USD
cast send $PYTH_ADAPTER_ADDRESS \
  "setPriceFeed(address,address,bytes32)" \
  $WETH_ADDRESS $USDC_ADDRESS \
  0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

Common price feed IDs:
| Pair | Feed ID |
|------|---------|
| ETH/USD | `0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace` |
| BTC/USD | `0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43` |
| USDC/USD | `0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a` |
| USDT/USD | `0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b` |

Find more at: https://pyth.network/developers/price-feed-ids

## Running Tests

### Liquidity & Swap Tests

Tests the core AMM functionality:

```bash
npm run test:liquidity
```

**What it tests:**
- ✓ Token balance checks (ETH, WETH, USDC)
- ✓ Concentrated AMM
  - Get total liquidity
  - Quote swap amounts
  - Build liquidity programs
- ✓ Pseudo-Arbitrage AMM
  - Build programs with various parameters
  - Input validation
  - Error handling

**Expected output:**
```
======================================================================
AMM LIQUIDITY & SWAP TEST SUITE
======================================================================

[2025-11-23T...] Network: https://base-sepolia.g.alchemy.com/v2/...
[2025-11-23T...] Wallet: 0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1

======================================================================
TOKEN BALANCE CHECKS
======================================================================

✓ Check ETH Balance (125ms)
ℹ ETH Balance: 0.5234 ETH

✓ Check WETH Balance (234ms)
ℹ WETH Balance: 100.0 WETH

======================================================================
CONCENTRATED AMM TESTS
======================================================================

✓ Get Total Liquidity (156ms)
ℹ Total Liquidity: 100.0 tokens

✓ Quote Swap (245ms)
ℹ Quote: 1.0 WETH -> 2950.5 USDC

✓ Build Liquidity Program (198ms)
ℹ Program built successfully
ℹ Bytecode length: 512 bytes

======================================================================
TEST SUMMARY
======================================================================

Total Tests: 8
Passed: 8 ✓
Failed: 0 ✗
```

### Pyth Adapter Tests

Tests Pyth Network integration:

```bash
npm run test:pyth
```

**What it tests:**
- ✓ System diagnostics (network, wallet)
- ✓ Pyth Network connection
  - Contract accessibility
  - Price feed availability
  - Raw price fetching
- ✓ Adapter configuration
  - Deployment verification
  - Settings check (maxPriceAge, owner)
  - Ownership permissions
- ✓ Price feed configuration
  - Check existing configs
  - Configure new feeds (if owner)
  - Read back configuration
- ✓ Price fetching
  - Fetch raw Pyth prices
  - Test price conversion
  - Handle staleness
  - Error handling
- ✓ Price conversion tests
  - Understand Pyth format
  - Test conversion examples
- ✓ Integration tests
  - Simulate AMM usage
  - Check gas costs

**Expected output:**
```
======================================================================
PYTH PRICE ADAPTER TEST SUITE
======================================================================

[2025-11-23T...] Network: https://base-sepolia.g.alchemy.com/v2/...
[2025-11-23T...] Pyth Contract: 0xA2aa501b19aff244D90cc15a4Cf739D2725B5729

======================================================================
PYTH NETWORK CONNECTION TESTS
======================================================================

✓ Connect to Pyth Contract (156ms)
ℹ Pyth contract found at 0xA2aa...

✓ Fetch Raw ETH/USD Price (345ms)
ℹ Raw Price: 300000000000
ℹ Exponent: -8
ℹ Actual ETH Price: $3000.00

======================================================================
PYTH ADAPTER CONFIGURATION TESTS
======================================================================

✓ Verify Adapter Deployment (123ms)
ℹ Adapter contract found at 0x1234...

✓ Check Adapter Configuration (198ms)
ℹ Pyth Contract: 0xA2aa501b19aff244D90cc15a4Cf739D2725B5729
ℹ Max Price Age: 3600 seconds (60 minutes)
ℹ Owner: 0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1

✓ Verify Ownership (89ms)
✓ You are the owner (can configure price feeds)

======================================================================
PRICE FETCHING TESTS
======================================================================

✓ Get Converted Price (1e18 format) (234ms)
✓ Price fetched successfully
ℹ Converted Price: 3000.0 (in 1e18 format)
ℹ Human-readable: $3000.00 per token

======================================================================
TEST SUMMARY
======================================================================

Total Tests: 15
Passed: 15 ✓
Failed: 0 ✗
```

### All Tests

Run both test suites:

```bash
npm run test:all
```

## Test Coverage

### Covered Features

#### Liquidity Provisioning ✓
- [x] Token balance verification
- [x] ETH balance checks
- [x] Program building (Concentrated AMM)
- [x] Program building (Pseudo-Arbitrage AMM)
- [x] Parameter validation
- [x] Error handling

#### Swapping ✓
- [x] Quote generation
- [x] Swap simulation
- [x] Fee calculation
- [x] Slippage protection

#### Pyth Integration ✓
- [x] Pyth contract connection
- [x] Price feed configuration
- [x] Price fetching
- [x] Price conversion (Pyth format → 1e18)
- [x] Staleness handling
- [x] Error handling
- [x] Gas cost estimation

### Not Covered (Requires On-Chain Execution)

- [ ] Actual liquidity addition (requires Aqua.ship())
- [ ] Actual swap execution (requires Aqua.ship())
- [ ] Multi-hop swaps
- [ ] Flash loans
- [ ] Cross-chain operations

For these, use Foundry tests:
```bash
forge test -vv
```

## Troubleshooting

### Common Issues

#### 1. "RPC_URL not set in .env"

**Cause**: Missing or incorrect `.env` file

**Fix**:
```bash
cp env.example .env
nano .env  # Add your RPC_URL and PRIVATE_KEY
```

#### 2. "Price is stale"

**Cause**: Pyth prices on testnets update infrequently

**Fixes**:
1. **Increase maxPriceAge** (recommended for testnets):
   ```bash
   ./scripts/deploy-pyth-adapter.sh 86400  # 24 hours
   ```

2. **Use Hermes updates** (advanced):
   See [Pyth Hermes docs](https://docs.pyth.network/documentation/pythnet-price-feeds/hermes)

3. **For testing only**: Deploy with very large maxPriceAge

#### 3. "PriceFeedNotConfigured"

**Cause**: Price feed not set up for token pair

**Fix**:
```bash
cast send $PYTH_ADAPTER_ADDRESS \
  "setPriceFeed(address,address,bytes32)" \
  $TOKEN_IN $TOKEN_OUT $PRICE_FEED_ID \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

#### 4. "OnlyOwner"

**Cause**: You're not the owner of the adapter

**Fixes**:
1. **Use owner's key**: Switch to the private key that deployed the adapter
2. **Transfer ownership** (from current owner):
   ```bash
   cast send $PYTH_ADAPTER_ADDRESS \
     "transferOwnership(address)" $YOUR_ADDRESS \
     --rpc-url $RPC_URL --private-key $OWNER_PRIVATE_KEY
   ```
3. **Deploy your own**: `./scripts/deploy-pyth-adapter.sh`

#### 5. "Insufficient funds for gas"

**Cause**: Low ETH balance

**Fix**: Get more testnet ETH from faucets:
- Base Sepolia: https://www.coinbase.com/faucets/base-ethereum-goerli-faucet
- Sepolia: https://sepoliafaucet.com/

#### 6. "Network Error" or "Invalid JSON-RPC"

**Cause**: RPC provider issues or rate limiting

**Fixes**:
1. **Check RPC URL**: Ensure it's correct and includes API key
2. **Try different provider**: Switch to Infura, QuickNode, etc.
3. **Wait and retry**: May be temporary rate limiting

#### 7. Tests pass but no contracts deployed

**Cause**: Tests simulate calls but don't execute transactions

**Fix**: Deploy contracts first:
```bash
./deploy-all.sh
source .env.deployed
```

### Getting Help

If you're still stuck:

1. **Check logs**: Look for detailed error messages
2. **Verify configuration**: Run `npm run test:pyth` to diagnose setup
3. **Review documentation**:
   - [Pyth Network Docs](https://docs.pyth.network/)
   - [Ethers.js Docs](https://docs.ethers.org/v5/)
4. **Check contract state**: Use block explorer or Cast

## Advanced Usage

### Custom Configuration

Override environment variables for specific test runs:

```bash
# Test on different network
RPC_URL=https://eth-mainnet.g.alchemy.com/v2/... npm run test:pyth

# Use different wallet
PRIVATE_KEY=0x... npm run test:liquidity

# Test with specific adapter
PYTH_ADAPTER_ADDRESS=0x... npm run test:pyth
```

### Programmatic Usage

Import test classes in your own scripts:

```typescript
import { PythAdapterTester, PYTH_PRICE_FEEDS } from './scripts/test-pyth-adapter';
import { TestRunner } from './scripts/test-liquidity';

// Custom Pyth test
const pythTester = new PythAdapterTester({
  rpcUrl: process.env.RPC_URL!,
  privateKey: process.env.PRIVATE_KEY!,
  pythAddress: process.env.PYTH_ADDRESS,
  pythAdapterAddress: process.env.PYTH_ADAPTER_ADDRESS
});

await pythTester.runAllTests();

// Custom liquidity test
const liquidityTester = new TestRunner({
  rpcUrl: process.env.RPC_URL!,
  privateKey: process.env.PRIVATE_KEY!,
  concentratedAmmAddress: process.env.CONCENTRATED_AMM_ADDRESS,
  pseudoArbAmmAddress: process.env.PSEUDO_ARB_AMM_ADDRESS
});

await liquidityTester.runAllTests();
```

### Adding Custom Tests

Add new tests to existing test classes:

```typescript
// In test-pyth-adapter.ts
async testCustomFeature() {
  await this.runTest('My Custom Test', async () => {
    // Your test logic here
    const result = await this.adapterContract!.someFunction();
    
    if (result !== expectedValue) {
      throw new Error('Test failed');
    }
    
    this.logSuccess('Custom test passed');
  });
}

// Add to runAllTests()
async runAllTests() {
  // ... existing tests ...
  await this.testCustomFeature();
}
```

### Continuous Integration

Run tests in CI/CD pipelines:

```yaml
# .github/workflows/test.yml
name: Test AMM System

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup Node.js
        uses: actions/setup-node@v2
        with:
          node-version: '18'
      
      - name: Install dependencies
        run: npm install
      
      - name: Run tests
        env:
          RPC_URL: ${{ secrets.RPC_URL }}
          PRIVATE_KEY: ${{ secrets.PRIVATE_KEY }}
          PYTH_ADDRESS: ${{ secrets.PYTH_ADDRESS }}
        run: npm run test:all
```

### Performance Testing

Measure gas costs and execution time:

```bash
# Enable verbose output
VERBOSE_TESTS=true npm run test:pyth

# Measure gas costs for specific operations
cast estimate $PYTH_ADAPTER_ADDRESS \
  "getPrice(address,address)" \
  $WETH_ADDRESS $USDC_ADDRESS \
  --rpc-url $RPC_URL
```

## Next Steps

After successful testing:

1. **Deploy to mainnet** (use different wallet with real funds)
2. **Configure production price feeds**
3. **Set up monitoring** (`npm run monitor`)
4. **Implement trading strategies**
5. **Add liquidity to pools**

## Resources

- [Pyth Network Documentation](https://docs.pyth.network/)
- [Pyth Price Feed IDs](https://pyth.network/developers/price-feed-ids)
- [Ethers.js Documentation](https://docs.ethers.org/v5/)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)
- [Foundry Book](https://book.getfoundry.sh/)

## License

Same as parent project.


# Testing Scripts

This directory contains TypeScript testing scripts for the AMM system and Pyth Price Adapter.

## 📁 Scripts

### 1. `test-liquidity.ts`
Tests liquidity provisioning and swapping functionality for both AMMs:
- **Concentrated AMM**: Tick-based liquidity, quote generation, program building
- **Pseudo-Arbitrage AMM**: Program building, parameter validation
- **Integration**: Token balances, approvals

### 2. `test-pyth-adapter.ts`
Comprehensive tests for PythPriceAdapter.sol:
- **Pyth Network Connection**: Verify Pyth contract accessibility
- **Adapter Configuration**: Check deployment and settings
- **Price Feed Configuration**: Set up price feeds for token pairs
- **Price Fetching**: Fetch and convert prices from Pyth Network
- **Integration**: Simulate usage with Pseudo-Arbitrage AMM

### 3. `monitor.js`
Monitors deployed AMM contracts for activity and health.

## 🚀 Quick Start

### 1. Install Dependencies

```bash
npm install
```

This will install:
- `typescript` - TypeScript compiler
- `ts-node` - TypeScript execution
- `ethers@5.7.2` - Ethereum library
- `dotenv` - Environment variables
- `@types/node` - TypeScript types

### 2. Configure Environment

Create a `.env` file in the project root:

```bash
cp .env.example .env
# Edit .env with your settings
```

Required variables:
```env
RPC_URL=https://base-sepolia.g.alchemy.com/v2/YOUR_KEY
PRIVATE_KEY=0x...

# Optional - will be loaded from deployments if not set
CONCENTRATED_AMM_ADDRESS=0x...
PSEUDO_ARB_AMM_ADDRESS=0x...
AQUA_ADDRESS=0x...

# For Pyth tests
PYTH_ADDRESS=0xA2aa501b19aff244D90cc15a4Cf739D2725B5729  # Base Sepolia
PYTH_ADAPTER_ADDRESS=0x...  # Deploy this first

# Token addresses (for testing swaps)
WETH_ADDRESS=0x...
USDC_ADDRESS=0x...
```

### 3. Run Tests

#### Test Liquidity & Swaps
```bash
npm run test:liquidity
```

Or directly:
```bash
ts-node scripts/test-liquidity.ts
```

#### Test Pyth Price Adapter
```bash
npm run test:pyth
```

Or directly:
```bash
ts-node scripts/test-pyth-adapter.ts
```

#### Run All Tests
```bash
npm run test:all
```

## 📖 Detailed Usage

### Testing Liquidity Provisioning

The liquidity test script performs the following tests:

1. **Token Balance Checks**
   - Verify ETH balance (for gas)
   - Check WETH balance
   - Check USDC balance

2. **Concentrated AMM Tests**
   - Get total liquidity
   - Quote swap amounts
   - Build liquidity programs

3. **Pseudo-Arbitrage AMM Tests**
   - Build programs with various parameters
   - Test input validation
   - Verify error handling

Example output:
```
======================================================================
AMM LIQUIDITY & SWAP TEST SUITE
======================================================================

[2025-11-23T...] Network: https://base-sepolia.g.alchemy.com/v2/...
[2025-11-23T...] Wallet: 0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1

✓ Check ETH Balance (125ms)
ℹ ETH Balance: 0.5234 ETH

✓ Get Total Liquidity (234ms)
ℹ Total Liquidity: 100.0 tokens

✓ Build Liquidity Program (456ms)
ℹ Program built successfully
```

### Testing Pyth Price Adapter

The Pyth adapter test script performs:

1. **System Diagnostics**
   - Check network and suggest Pyth contract
   - Verify wallet balance

2. **Pyth Network Connection**
   - Connect to Pyth contract
   - Check price feed availability
   - Fetch raw prices

3. **Adapter Configuration**
   - Verify deployment
   - Check configuration (maxPriceAge, owner)
   - Test ownership permissions

4. **Price Feed Configuration**
   - Check existing configs
   - Configure price feeds (if owner)
   - Read back configuration

5. **Price Fetching**
   - Fetch raw Pyth prices
   - Test price conversion
   - Handle staleness and errors

6. **Integration Tests**
   - Simulate usage with AMM
   - Check gas costs

Example output:
```
======================================================================
PYTH PRICE ADAPTER TEST SUITE
======================================================================

[2025-11-23T...] Network: https://base-sepolia.g.alchemy.com/v2/...
[2025-11-23T...] Pyth Contract: 0xA2aa501b19aff244D90cc15a4Cf739D2725B5729

✓ Connect to Pyth Contract (156ms)
ℹ Pyth contract found at 0xA2aa...

✓ Fetch Raw ETH/USD Price (345ms)
ℹ Raw Price: 300000000000
ℹ Exponent: -8
ℹ Actual ETH Price: $3000.00

✓ Get Converted Price (1e18 format) (234ms)
ℹ Converted Price: 3000.0 (in 1e18 format)
ℹ Human-readable: $3000.00 per token
```

## 🔧 Configuration Details

### Pyth Network Contracts

| Network | Pyth Contract Address |
|---------|----------------------|
| Ethereum Mainnet | `0x4305FB66699C3B2702D4d05CF36551390A4c69C6` |
| Arbitrum | `0xff1a0f4744e8582DF1aE09D5611b887B6a12925C` |
| Base | `0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a` |
| Base Sepolia | `0xA2aa501b19aff244D90cc15a4Cf739D2725B5729` |
| Sepolia | `0xDd24F84d36BF92C65F92307595335bdFab5Bbd21` |

Resources:
- [Pyth Contract Addresses](https://docs.pyth.network/price-feeds/contract-addresses/evm)
- [Price Feed IDs](https://pyth.network/developers/price-feed-ids)

### Common Price Feed IDs

| Pair | Price Feed ID |
|------|---------------|
| ETH/USD | `0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace` |
| BTC/USD | `0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43` |
| USDC/USD | `0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a` |
| USDT/USD | `0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b` |

## 🏗️ Deploying PythPriceAdapter

Before running Pyth tests, you need to deploy the adapter:

```bash
cd packages/pseudo-arbitrage-amm

# Deploy adapter
forge create src/oracles/PythPriceAdapter.sol:PythPriceAdapter \
  --constructor-args <PYTH_ADDRESS> 3600 \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --verify

# Example for Base Sepolia:
forge create src/oracles/PythPriceAdapter.sol:PythPriceAdapter \
  --constructor-args 0xA2aa501b19aff244D90cc15a4Cf739D2725B5729 3600 \
  --rpc-url https://base-sepolia.g.alchemy.com/v2/YOUR_KEY \
  --private-key 0x... \
  --verify
```

Constructor parameters:
- `_pyth`: Pyth contract address for your network
- `_maxPriceAge`: Maximum price age in seconds (e.g., 3600 = 1 hour)

After deployment, add to `.env`:
```env
PYTH_ADAPTER_ADDRESS=<deployed_address>
```

## 🧪 Advanced Usage

### Custom Test Configuration

You can override environment variables when running tests:

```bash
# Use different network
RPC_URL=https://mainnet.infura.io/v3/... npm run test:pyth

# Use different wallet
PRIVATE_KEY=0x... npm run test:liquidity

# Test with specific adapter
PYTH_ADAPTER_ADDRESS=0x... npm run test:pyth
```

### Programmatic Usage

Import and use the test classes in your own scripts:

```typescript
import { PythAdapterTester, PYTH_PRICE_FEEDS } from './scripts/test-pyth-adapter';

const tester = new PythAdapterTester({
  rpcUrl: 'https://base-sepolia.g.alchemy.com/v2/...',
  privateKey: '0x...',
  pythAddress: '0xA2aa501b19aff244D90cc15a4Cf739D2725B5729',
  pythAdapterAddress: '0x...'
});

await tester.runAllTests();
```

### Continuous Monitoring

Use the monitor script for continuous monitoring:

```bash
npm run monitor
```

Configure monitoring interval in `.env`:
```env
MONITORING_INTERVAL=30  # Check every 30 seconds
```

## 🐛 Troubleshooting

### "Price is stale" Error

This is common on testnets where Pyth price updates are less frequent.

**Solutions:**
1. Increase `maxPriceAge` when deploying adapter
2. Use Hermes price updates (see Pyth docs)
3. For testing, deploy with a very large `maxPriceAge` (e.g., 86400 = 24 hours)

### "PriceFeedNotConfigured" Error

You need to configure price feeds first:

```typescript
// Call setPriceFeed as the adapter owner
await adapter.setPriceFeed(
  WETH_ADDRESS,
  USDC_ADDRESS,
  PYTH_PRICE_FEEDS['ETH/USD']
);
```

### "OnlyOwner" Error

You're not the owner of the adapter. Either:
1. Use the owner's private key
2. Call `transferOwnership()` from current owner
3. Deploy your own adapter

### Gas Estimation Failed

Some view functions may fail on testnets due to stale prices. This is expected behavior. The test scripts handle these gracefully.

### Low Balance Warning

Ensure you have enough ETH for:
- Gas fees for transactions
- At least 0.01 ETH recommended for testing

Get testnet ETH:
- [Base Sepolia Faucet](https://www.coinbase.com/faucets/base-ethereum-goerli-faucet)
- [Sepolia Faucet](https://sepoliafaucet.com/)

## 📚 Additional Resources

- [Pyth Network Documentation](https://docs.pyth.network/)
- [Ethers.js Documentation](https://docs.ethers.org/v5/)
- [TypeScript Documentation](https://www.typescriptlang.org/docs/)
- [Foundry Book](https://book.getfoundry.sh/)

## 🤝 Contributing

To add new tests:

1. Create a new test method in the appropriate class
2. Add it to the test suite in `runAllTests()`
3. Update this README with documentation

Example:
```typescript
async testNewFeature() {
  await this.runTest('Test New Feature', async () => {
    // Your test code here
    this.logInfo('Testing...');
  });
}
```

## 📝 License

Same as parent project.


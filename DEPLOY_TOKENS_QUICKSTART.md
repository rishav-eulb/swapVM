# 🚀 Deploy Mock Tokens - Quick Start

Deploy two mock ERC20 tokens in 3 simple steps!

## Step 1️⃣: Setup Environment

```bash
# Copy the template
cp env.mock-tokens.template .env

# Edit .env and add your private key
nano .env
```

Minimum required in `.env`:
```bash
PRIVATE_KEY=your_key_here
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
```

## Step 2️⃣: Deploy

```bash
# Deploy with default config (Mock USDC + Mock WETH)
./deploy-mock-tokens.sh base-sepolia
```

That's it! The script will:
- ✅ Deploy two ERC20 tokens
- ✅ Mint initial supply to your address
- ✅ Verify contracts on Basescan
- ✅ Save deployment info to JSON
- ✅ Display addresses for your .env

## Step 3️⃣: Save Addresses

Copy the output and add to your `.env`:

```bash
TOKEN0_ADDRESS=0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb
TOKEN1_ADDRESS=0x7a2088a1bFc9d81c55368AE168C2C02570cB814F
```

## 🎨 Customize (Optional)

Before deploying, export custom token configs:

```bash
# Example: Deploy DAI + USDC pair
export TOKEN0_NAME="Dai Stablecoin"
export TOKEN0_SYMBOL="DAI"
export TOKEN0_DECIMALS=18
export TOKEN0_INITIAL_SUPPLY=1000000000000000000000000

export TOKEN1_NAME="USD Coin"
export TOKEN1_SYMBOL="USDC"
export TOKEN1_DECIMALS=6
export TOKEN1_INITIAL_SUPPLY=1000000000000

./deploy-mock-tokens.sh base-sepolia
```

## 📦 What Gets Deployed

Default configuration:
- **Token 0**: Mock USDC (6 decimals, 1M supply)
- **Token 1**: Mock WETH (18 decimals, 1M supply)

Both tokens support:
- Standard ERC20 functions
- Unrestricted `mint(address, uint256)` for testing
- `burn(uint256)` to destroy tokens

## 🔗 Use With Your AMMs

### Concentrated AMM
```bash
cd packages/concentrated-amm
forge script script/DeployConcentratedAMM.s.sol:CreateExamplePosition \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast
```

### Pseudo-Arbitrage AMM
```bash
cd packages/pseudo-arbitrage-amm
forge script script/DeployPseudoArbitrageAMM.s.sol:CreateExamplePosition \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast
```

## 🌐 Other Networks

```bash
./deploy-mock-tokens.sh base          # Base mainnet
./deploy-mock-tokens.sh sepolia       # Ethereum Sepolia
./deploy-mock-tokens.sh localhost     # Local Anvil node
```

## 💡 Pro Tips

1. **Get testnet ETH**: https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet
2. **View deployment details**: `cat deployments/mock-tokens-latest.json`
3. **Check balance**: `cast call $TOKEN0_ADDRESS "balanceOf(address)(uint256)" $YOUR_ADDRESS`
4. **Mint more tokens**: `cast send $TOKEN0_ADDRESS "mint(address,uint256)" $RECIPIENT 1000000000000000000`

## 📚 Full Documentation

See `MOCK_TOKENS_DEPLOYMENT.md` for:
- Complete customization options
- Integration examples
- Advanced usage
- Troubleshooting

## ⚠️ Warning

These are **TEST TOKENS ONLY** with unrestricted minting. Do NOT use in production!

---

**Need Help?** See the full guide: [MOCK_TOKENS_DEPLOYMENT.md](MOCK_TOKENS_DEPLOYMENT.md)


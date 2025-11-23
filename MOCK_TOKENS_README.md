# Mock Tokens Deployment Guide

This guide explains how to deploy two mock ERC20 tokens for testing your AMM and arbitrage strategies.

## Overview

The mock token deployment script creates two fully-functional ERC20 tokens with customizable:
- Names and symbols
- Decimal places
- Initial supply (minted to deployer)

## Quick Start

### 1. Deploy with Default Configuration

```bash
# Make the script executable
chmod +x deploy-mock-tokens.sh

# Deploy to Base Sepolia testnet
./deploy-mock-tokens.sh base-sepolia
```

This deploys:
- **Token 0**: Mock USDC (6 decimals, 1M initial supply)
- **Token 1**: Mock WETH (18 decimals, 1M initial supply)

### 2. Deploy with Custom Configuration

Set environment variables in your `.env` file or export them:

```bash
# Token 0 Configuration
export TOKEN0_NAME="My Token A"
export TOKEN0_SYMBOL="TKA"
export TOKEN0_DECIMALS=18
export TOKEN0_INITIAL_SUPPLY=1000000000000000000000000  # 1M with 18 decimals

# Token 1 Configuration
export TOKEN1_NAME="My Token B"
export TOKEN1_SYMBOL="TKB"
export TOKEN1_DECIMALS=18
export TOKEN1_INITIAL_SUPPLY=1000000000000000000000000  # 1M with 18 decimals

# Deploy
./deploy-mock-tokens.sh base-sepolia
```

## Manual Deployment with Forge

If you prefer to use forge directly:

```bash
forge script script/DeployMockTokens.s.sol:DeployMockTokens \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --verify \
    --legacy \
    -vvvv
```

## Deployment Output

After successful deployment, you'll receive:

1. **Console output** with deployment addresses and summary
2. **JSON file** at `./deployments/mock-tokens-latest.json`:
   ```json
   {
     "chainId": 84532,
     "deployer": "0x...",
     "token0": {
       "name": "Mock USDC",
       "symbol": "USDC",
       "decimals": 6,
       "address": "0x...",
       "totalSupply": "1000000000000"
     },
     "token1": {
       "name": "Mock WETH",
       "symbol": "WETH",
       "decimals": 18,
       "address": "0x...",
       "totalSupply": "1000000000000000000000000"
     }
   }
   ```

## Using the Mock Tokens

### Update Your .env File

After deployment, add the token addresses to your `.env`:

```bash
TOKEN0_ADDRESS=0x...  # From deployment output
TOKEN1_ADDRESS=0x...  # From deployment output
```

### Minting Additional Tokens

The mock tokens have an unrestricted `mint()` function for testing:

```solidity
// In your test or script
MockERC20 token = MockERC20(TOKEN0_ADDRESS);
token.mint(address(this), 1000e18);  // Mint 1000 tokens
```

### Using with AMM Strategies

After deploying tokens, you can use them with the AMM deployment scripts:

```bash
# Deploy Concentrated AMM with mock tokens
cd packages/concentrated-amm
forge script script/DeployConcentratedAMM.s.sol:CreateExamplePosition \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast
```

Or with the Pseudo-Arbitrage AMM:

```bash
# Deploy Pseudo-Arbitrage position
cd packages/pseudo-arbitrage-amm
forge script script/DeployPseudoArbitrageAMM.s.sol:CreateExamplePosition \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast
```

## Supported Networks

The deployment script supports the following networks:

- `base-sepolia` - Base Sepolia Testnet (default)
- `base` - Base Mainnet
- `sepolia` - Ethereum Sepolia Testnet
- `mainnet` - Ethereum Mainnet
- `localhost` - Local development network

## Contract Features

### MockERC20 Contract

Located at: `packages/shared-utils/src/MockERC20.sol`

**Features:**
- Standard ERC20 implementation (OpenZeppelin)
- Unrestricted `mint()` function for testing
- `burn()` function for token destruction
- Configurable decimals
- Full ERC20 compatibility

**Interface:**
```solidity
function mint(address to, uint256 amount) external;
function burn(uint256 amount) external;
function decimals() public view returns (uint8);
// ... standard ERC20 functions
```

## Troubleshooting

### "PRIVATE_KEY not set"
Make sure your `.env` file contains:
```bash
PRIVATE_KEY=0x...  # Your private key (without 0x prefix)
```

### "RPC connection failed"
Check your RPC URL in `.env`:
```bash
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
```

### "Insufficient funds"
Make sure your deployer address has enough ETH for gas fees. For testnets, use a faucet:
- Base Sepolia: https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet

### Verification Failed
If contract verification fails, you can verify manually:
```bash
forge verify-contract \
    --chain-id 84532 \
    --compiler-version v0.8.13+commit.abaa5c0e \
    <TOKEN_ADDRESS> \
    packages/shared-utils/src/MockERC20.sol:MockERC20 \
    --constructor-args $(cast abi-encode "constructor(string,string,uint8)" "Mock USDC" "USDC" 6)
```

## Security Notice

⚠️ **WARNING**: These mock tokens are for TESTING ONLY!

- The `mint()` function is unrestricted
- Anyone can mint unlimited tokens
- Do NOT use in production
- Do NOT send real value to these contracts

For production deployments, use properly secured token contracts with access control.

## Next Steps

After deploying mock tokens:

1. **Deploy an Oracle** (for Pseudo-Arbitrage AMM):
   ```bash
   cd packages/pseudo-arbitrage-amm
   forge script script/DeployPseudoArbitrageAMM.s.sol:DeployPythOracle \
       --rpc-url $BASE_SEPOLIA_RPC_URL \
       --broadcast
   ```

2. **Create a liquidity position**:
   - See the AMM-specific deployment guides in each package
   - `packages/concentrated-amm/docs/QUICKSTART.md`
   - `packages/pseudo-arbitrage-amm/USER_GUIDE.md`

3. **Test swaps**:
   - Use the monitoring script: `node scripts/monitor.js`
   - Or interact directly with the deployed contracts

## Additional Resources

- [Concentrated AMM Guide](packages/concentrated-amm/docs/START_HERE.md)
- [Pseudo-Arbitrage AMM Guide](packages/pseudo-arbitrage-amm/USER_GUIDE.md)
- [Main Deployment Guide](DEPLOYMENT_GUIDE.md)
- [Quick Start](QUICK_START.md)


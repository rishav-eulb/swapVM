# Mock Token Deployment - Complete Guide

I've created a complete mock token deployment solution for your NexusNetwork SwapVM project.

## 📦 What Was Created

### 1. Mock ERC20 Contract
**Location:** `packages/shared-utils/src/MockERC20.sol`

A production-quality mock ERC20 token with:
- ✅ Full OpenZeppelin ERC20 implementation
- ✅ Unrestricted `mint()` function for testing
- ✅ `burn()` function for token destruction
- ✅ Configurable decimals (2-24 supported)
- ✅ Standard ERC20 interface compliance

```solidity
contract MockERC20 is ERC20 {
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
    function decimals() public view returns (uint8);
}
```

### 2. Deployment Script
**Location:** `script/DeployMockTokens.s.sol`

A comprehensive Foundry deployment script that:
- ✅ Deploys two configurable ERC20 tokens
- ✅ Supports environment-based configuration
- ✅ Mints initial supply to deployer
- ✅ Saves deployment info to JSON
- ✅ Outputs ready-to-use .env variables

### 3. Shell Script (Automated Deployment)
**Location:** `deploy-mock-tokens.sh` (executable)

A user-friendly bash script that:
- ✅ Validates environment setup
- ✅ Supports multiple networks (Base Sepolia, Base, Sepolia, Mainnet, Localhost)
- ✅ Handles RPC configuration automatically
- ✅ Verifies contracts on Etherscan/Basescan
- ✅ Provides colored output and clear error messages

### 4. Configuration Files

**Root Foundry Config:** `foundry.toml`
- Proper remappings to OpenZeppelin and Forge dependencies
- Network RPC endpoints configuration
- Etherscan API integration for verification

**Example Environment:** See below for .env setup

## 🚀 Quick Start

### Step 1: Configure Environment

Create or update your `.env` file:

```bash
# Required
PRIVATE_KEY=your_private_key_without_0x_prefix

# Network RPC URLs
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
BASESCAN_API_KEY=your_api_key_for_verification

# Optional: Customize tokens (defaults provided)
# TOKEN0_NAME=Mock USDC
# TOKEN0_SYMBOL=USDC
# TOKEN0_DECIMALS=6
# TOKEN0_INITIAL_SUPPLY=1000000000000  # 1M USDC

# TOKEN1_NAME=Mock WETH
# TOKEN1_SYMBOL=WETH
# TOKEN1_DECIMALS=18
# TOKEN1_INITIAL_SUPPLY=1000000000000000000000000  # 1M WETH
```

### Step 2: Deploy Tokens

#### Option A: Using the Shell Script (Recommended)

```bash
# Deploy to Base Sepolia (default)
./deploy-mock-tokens.sh base-sepolia

# Deploy to other networks
./deploy-mock-tokens.sh base
./deploy-mock-tokens.sh sepolia
./deploy-mock-tokens.sh localhost
```

#### Option B: Using Forge Directly

```bash
# Deploy
forge script script/DeployMockTokens.s.sol:DeployMockTokens \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --verify \
    -vvvv

# Simulate without broadcasting (dry run)
forge script script/DeployMockTokens.s.sol:DeployMockTokens \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    -vvvv
```

### Step 3: Save Deployed Addresses

After deployment, add to your `.env`:

```bash
TOKEN0_ADDRESS=0x...  # From deployment output
TOKEN1_ADDRESS=0x...  # From deployment output
```

The deployment script automatically saves this information to:
- Console output (copy/paste ready)
- `deployments/mock-tokens-latest.json` file

## 📊 Deployment Output

### Console Output Example

```
========================================
DEPLOYMENT SUMMARY
========================================
Token 0 (USDC):
  Address:       0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb
  Total Supply:  1000000000000

Token 1 (WETH):
  Address:       0x7a2088a1bFc9d81c55368AE168C2C02570cB814F
  Total Supply:  1000000000000000000000000
========================================
```

### JSON Output (deployments/mock-tokens-latest.json)

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

## 🔧 Customization Examples

### Example 1: Deploy ETH/USDC pair

```bash
export TOKEN0_NAME="Wrapped Ether"
export TOKEN0_SYMBOL="WETH"
export TOKEN0_DECIMALS=18
export TOKEN0_INITIAL_SUPPLY=1000000000000000000000000  # 1M WETH

export TOKEN1_NAME="USD Coin"
export TOKEN1_SYMBOL="USDC"
export TOKEN1_DECIMALS=6
export TOKEN1_INITIAL_SUPPLY=1000000000000  # 1M USDC

./deploy-mock-tokens.sh base-sepolia
```

### Example 2: Deploy identical tokens (for symmetric testing)

```bash
export TOKEN0_NAME="Test Token A"
export TOKEN0_SYMBOL="TTA"
export TOKEN0_DECIMALS=18
export TOKEN0_INITIAL_SUPPLY=10000000000000000000000000  # 10M tokens

export TOKEN1_NAME="Test Token B"
export TOKEN1_SYMBOL="TTB"
export TOKEN1_DECIMALS=18
export TOKEN1_INITIAL_SUPPLY=10000000000000000000000000  # 10M tokens

./deploy-mock-tokens.sh base-sepolia
```

### Example 3: No initial mint (mint later in tests)

```bash
export TOKEN0_INITIAL_SUPPLY=0
export TOKEN1_INITIAL_SUPPLY=0

./deploy-mock-tokens.sh localhost
```

## 🎯 Using the Tokens

### In Solidity Tests

```solidity
import { MockERC20 } from "../packages/shared-utils/src/MockERC20.sol";

contract MyTest is Test {
    MockERC20 token0;
    MockERC20 token1;

    function setUp() public {
        // Use deployed addresses or deploy new
        token0 = MockERC20(TOKEN0_ADDRESS);
        token1 = MockERC20(TOKEN1_ADDRESS);
        
        // Mint more tokens as needed
        token0.mint(address(this), 1000e18);
        token1.mint(alice, 500e6);
    }
}
```

### In Deployment Scripts

```solidity
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployAMM is Script {
    function run() external {
        address token0 = vm.envAddress("TOKEN0_ADDRESS");
        address token1 = vm.envAddress("TOKEN1_ADDRESS");
        
        // Use tokens in your AMM deployment
        // ...
    }
}
```

### Minting Tokens (JavaScript/TypeScript)

```javascript
const { ethers } = require("ethers");

// ABI for mint function
const abi = ["function mint(address to, uint256 amount)"];
const token = new ethers.Contract(TOKEN0_ADDRESS, abi, signer);

// Mint 1000 tokens (adjust for decimals)
await token.mint(userAddress, ethers.parseUnits("1000", 18));
```

## 🔗 Integration with Your AMMs

### With Concentrated AMM

```bash
# 1. Deploy tokens
./deploy-mock-tokens.sh base-sepolia

# 2. Deploy Concentrated AMM
cd packages/concentrated-amm
forge script script/DeployConcentratedAMM.s.sol:DeployConcentratedAMM \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast

# 3. Create position with mock tokens
forge script script/DeployConcentratedAMM.s.sol:CreateExamplePosition \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast
```

### With Pseudo-Arbitrage AMM

```bash
# 1. Deploy tokens
./deploy-mock-tokens.sh base-sepolia

# 2. Deploy Pyth oracle adapter
cd packages/pseudo-arbitrage-amm
forge script script/DeployPseudoArbitrageAMM.s.sol:DeployPythOracle \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast

# 3. Deploy AMM
forge script script/DeployPseudoArbitrageAMM.s.sol:DeployPseudoArbitrageAMM \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast

# 4. Create position
forge script script/DeployPseudoArbitrageAMM.s.sol:CreateExamplePosition \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast
```

## 🧪 Testing Locally

### Start Local Node

```bash
# Terminal 1: Start Anvil
anvil

# Terminal 2: Deploy to local node
./deploy-mock-tokens.sh localhost
```

### Run Tests with Mock Tokens

```bash
# Set token addresses from deployment
export TOKEN0_ADDRESS=0x...
export TOKEN1_ADDRESS=0x...

# Run tests
forge test -vvv
```

## 🛠️ Advanced Usage

### Verify Contracts Manually

If automatic verification fails:

```bash
forge verify-contract \
    --chain-id 84532 \
    --compiler-version v0.8.13+commit.abaa5c0e \
    <TOKEN_ADDRESS> \
    packages/shared-utils/src/MockERC20.sol:MockERC20 \
    --constructor-args $(cast abi-encode "constructor(string,string,uint8)" "Mock USDC" "USDC" 6) \
    --etherscan-api-key $BASESCAN_API_KEY
```

### Check Token Balances

```bash
# Using cast
cast call <TOKEN_ADDRESS> "balanceOf(address)(uint256)" <YOUR_ADDRESS> --rpc-url $BASE_SEPOLIA_RPC_URL

# Using cast with decimals conversion
cast call <TOKEN_ADDRESS> "balanceOf(address)(uint256)" <YOUR_ADDRESS> \
    --rpc-url $BASE_SEPOLIA_RPC_URL | \
    cast to-unit ether
```

### Mint Tokens via Cast

```bash
cast send <TOKEN_ADDRESS> \
    "mint(address,uint256)" \
    <RECIPIENT_ADDRESS> \
    1000000000000000000000 \
    --private-key $PRIVATE_KEY \
    --rpc-url $BASE_SEPOLIA_RPC_URL
```

## ⚠️ Security Warnings

**THESE ARE TEST TOKENS ONLY!**

- ❌ DO NOT use in production
- ❌ DO NOT send real value to these contracts
- ❌ The `mint()` function is UNRESTRICTED
- ❌ Anyone can mint unlimited tokens
- ❌ No access control or security features

For production, use:
- Proper access control (Ownable, AccessControl)
- Minting restrictions
- Supply caps
- Security audits

## 🐛 Troubleshooting

### "PRIVATE_KEY not set"
```bash
# Check .env file exists and has:
PRIVATE_KEY=your_key_without_0x
```

### "Insufficient funds for gas"
- Get testnet ETH from faucets:
  - Base Sepolia: https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet
  - Sepolia: https://sepoliafaucet.com

### "Failed to resolve imports"
- Make sure you're running from project root
- Check that `foundry.toml` exists
- Verify lib dependencies: `git submodule update --init --recursive`

### Compilation errors
```bash
# Clean and rebuild
forge clean
forge build
```

## 📚 Additional Resources

- [Concentrated AMM Docs](packages/concentrated-amm/docs/START_HERE.md)
- [Pseudo-Arbitrage AMM Guide](packages/pseudo-arbitrage-amm/USER_GUIDE.md)
- [Main Deployment Guide](DEPLOYMENT_GUIDE.md)
- [OpenZeppelin ERC20 Docs](https://docs.openzeppelin.com/contracts/4.x/erc20)
- [Foundry Book](https://book.getfoundry.sh/)

## 🎉 Success!

You now have:
- ✅ Reusable MockERC20 contract
- ✅ Automated deployment script
- ✅ Multi-network support
- ✅ Easy customization via environment variables
- ✅ Integration with your existing AMM infrastructure

Deploy your tokens and start testing your AMM strategies! 🚀


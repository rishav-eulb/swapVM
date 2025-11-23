# Complete Step-by-Step Deployment & Testing Guide

## Prerequisites Check

Before starting, ensure you have:

```bash
# Check Foundry installation
forge --version
# Should show: forge 0.2.0 or higher

# Check Node.js (optional, for additional tooling)
node --version
# Should show: v18+ or higher

# Check git
git --version
```

## Step 1: Set Up Project Structure

```bash
# Create and enter project directory
mkdir pseudo-arbitrage-amm
cd pseudo-arbitrage-amm

# Initialize Foundry project
forge init

# Clean default files
rm -rf src/Counter.sol test/Counter.t.sol script/Counter.s.sol
```

## Step 2: Install Dependencies

```bash
# Install OpenZeppelin
forge install OpenZeppelin/openzeppelin-contracts@v5.1.0

# Install 1inch SwapVM (CRITICAL DEPENDENCY)
# Note: You may need to clone this separately and adjust paths
forge install 1inch/swap-vm

# Alternatively, if the above doesn't work:
git clone https://github.com/1inch/swap-vm.git lib/swap-vm
```

## Step 3: Configure Project

Create `foundry.toml`:

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc_version = "0.8.30"
evm_version = "cancun"
optimizer = true
optimizer_runs = 1000000
via_ir = false

# Remappings
remappings = [
    "@openzeppelin/=lib/openzeppelin-contracts/",
    "forge-std/=lib/forge-std/src/",
    "swap-vm/=lib/swap-vm/src/"
]

[rpc_endpoints]
mainnet = "${MAINNET_RPC_URL}"
sepolia = "${SEPOLIA_RPC_URL}"
arbitrum = "${ARBITRUM_RPC_URL}"
base = "${BASE_RPC_URL}"

[etherscan]
mainnet = { key = "${ETHERSCAN_API_KEY}" }
sepolia = { key = "${ETHERSCAN_API_KEY}" }
arbitrum = { key = "${ARBISCAN_API_KEY}" }
base = { key = "${BASESCAN_API_KEY}" }
```

Create `.env` file:

```bash
# Network RPC URLs
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
ARBITRUM_RPC_URL=https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY
BASE_RPC_URL=https://base-mainnet.g.alchemy.com/v2/YOUR_KEY

# Private key (for deployment)
PRIVATE_KEY=your_private_key_here

# Etherscan API keys (for verification)
ETHERSCAN_API_KEY=your_etherscan_api_key
ARBISCAN_API_KEY=your_arbiscan_api_key
BASESCAN_API_KEY=your_basescan_api_key

# Aqua address (get from 1inch docs)
AQUA_ADDRESS=0x0000000000000000000000000000000000000000
```

Load environment:
```bash
source .env
```

## Step 4: Organize Files

Create directory structure:

```bash
mkdir -p src/instructions
mkdir -p src/opcodes
mkdir -p src/routers
mkdir -p src/strategies
mkdir -p test
mkdir -p script
mkdir -p deployments
```

Copy your uploaded files:

```bash
# Copy to appropriate directories
cp PseudoArbitrage.sol src/instructions/
cp PseudoArbitrageOpcodes.sol src/opcodes/
cp PseudoArbitrageAMM.sol src/strategies/
cp PseudoArbitrageSwapVMRouter.sol src/routers/
```

## Step 5: Fix Import Paths

The contracts have relative imports that need to be fixed. You'll need to:

1. Update imports in each file to match your directory structure
2. Ensure SwapVM dependencies are correctly referenced

Example fixes needed in `PseudoArbitrage.sol`:

```solidity
// Change this:
import { Calldata } from "../libs/Calldata.sol";
import { Context, ContextLib } from "../libs/VM.sol";

// To this (depending on your setup):
import { Calldata } from "swap-vm/libs/Calldata.sol";
import { Context, ContextLib } from "swap-vm/libs/VM.sol";
```

## Step 6: Compile Contracts

```bash
# Attempt compilation
forge build

# If errors occur, fix import paths and dependencies
# Common issues:
# - Missing SwapVM contracts
# - Incorrect import paths
# - Missing instruction implementations
```

Expected output:
```
[⠊] Compiling...
[⠒] Compiling 45 files with 0.8.30
[⠑] Solc 0.8.30 finished in 3.21s
Compiler run successful!
```

## Step 7: Run Tests

```bash
# Run all tests
forge test

# Run with verbose output
forge test -vv

# Run specific test file
forge test --match-contract PseudoArbitrageTest -vvv

# Run with gas reporting
forge test --gas-report
```

## Step 8: Deploy to Local Network (Anvil)

```bash
# Terminal 1: Start local node
anvil

# Terminal 2: Deploy
forge script script/Deploy.s.sol:DeployWithMocksScript \
  --rpc-url http://localhost:8545 \
  --broadcast

# Check deployment
cat deployments/latest.json
```

## Step 9: Deploy to Testnet (Sepolia)

```bash
# Ensure you have testnet ETH
# Get from: https://sepoliafaucet.com/

# Deploy
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY

# Save deployment addresses
```

## Step 10: Verify Deployment

After deployment, verify contracts on Etherscan:

```bash
# If auto-verification fails, verify manually
forge verify-contract \
  --chain-id 11155111 \
  --compiler-version v0.8.30 \
  <CONTRACT_ADDRESS> \
  src/routers/PseudoArbitrageSwapVMRouter.sol:PseudoArbitrageSwapVMRouter \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --constructor-args $(cast abi-encode "constructor(address,string,string)" $AQUA_ADDRESS "PseudoArbitrageSwapVM" "1.0.0")
```

## Step 11: Create Your First AMM

After deployment, interact with the contracts:

```bash
# Using cast (Foundry's CLI tool)

# 1. Approve tokens
cast send $TOKEN_X_ADDRESS \
  "approve(address,uint256)" \
  $AQUA_ADDRESS \
  1000000000000000000000 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY

cast send $TOKEN_Y_ADDRESS \
  "approve(address,uint256)" \
  $AQUA_ADDRESS \
  3000000000000000000000 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY

# 2. Build AMM order (use script or direct call)
# This requires calling buildProgram() on the AMM builder

# 3. Execute trades against the AMM
```

## Step 12: Monitor and Test

```bash
# Watch events
cast logs --address $ROUTER_ADDRESS \
  --rpc-url $SEPOLIA_RPC_URL

# Check state
cast call $ROUTER_ADDRESS \
  "pseudoArbitrageStates(bytes32)(int256,int256,uint256,uint256,uint256,uint256,bool)" \
  $ORDER_HASH \
  --rpc-url $SEPOLIA_RPC_URL

# Monitor gas usage
cast call $ROUTER_ADDRESS "..." \
  --trace \
  --rpc-url $SEPOLIA_RPC_URL
```

## Common Issues & Solutions

### Issue 1: Compilation Fails - Missing SwapVM

**Solution:**
```bash
# Clone SwapVM separately
cd lib
git clone https://github.com/1inch/swap-vm.git
cd ..

# Update remappings in foundry.toml
```

### Issue 2: Import Path Errors

**Solution:**
Search and replace import paths:
```bash
# Find all import statements
grep -r "import {" src/

# Update each file to use correct paths
```

### Issue 3: Test Compilation Fails

**Solution:**
```bash
# Make sure forge-std is installed
forge install foundry-rs/forge-std

# Update test imports
```

### Issue 4: Out of Gas on Deployment

**Solution:**
```bash
# Increase gas limit in script
forge script script/Deploy.s.sol \
  --gas-limit 10000000 \
  --rpc-url $RPC_URL \
  --broadcast
```

## Testing Checklist

- [ ] Unit tests pass
- [ ] Integration tests pass  
- [ ] Gas usage is reasonable
- [ ] Oracle integration works
- [ ] Rate limiting functions correctly
- [ ] Price changes trigger transformations
- [ ] No divergence loss demonstrated
- [ ] Excess reserves can be withdrawn

## Security Checklist

- [ ] Oracle manipulation resistance verified
- [ ] Reentrancy protection in place
- [ ] Access control on withdrawal functions
- [ ] Rate limiting cannot be bypassed
- [ ] Integer overflow/underflow handled
- [ ] External calls are safe
- [ ] State updates are correct

## Production Deployment Checklist

- [ ] Full audit completed
- [ ] Testnet testing passed (1000+ trades)
- [ ] Gas optimization completed
- [ ] Emergency pause mechanism added
- [ ] Multisig for admin functions
- [ ] Documentation complete
- [ ] Monitoring and alerting set up
- [ ] Bug bounty program launched

## Next Steps

1. Complete SwapVM integration
2. Write comprehensive integration tests
3. Test on multiple testnets
4. Get professional audit
5. Deploy to mainnet
6. Set up monitoring infrastructure

## Useful Commands

```bash
# Format code
forge fmt

# Generate gas snapshot
forge snapshot

# Check test coverage
forge coverage

# Run specific test with traces
forge test --match-test testName -vvvv

# Analyze contract size
forge build --sizes

# Clean build artifacts
forge clean
```

## Resources

- [Foundry Book](https://book.getfoundry.sh/)
- [1inch SwapVM Docs](https://github.com/1inch/swap-vm)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts)
- [Engel & Herlihy Paper](https://arxiv.org/abs/2106.00667)

---

**Need help?** Check the error messages carefully and ensure all dependencies are correctly installed.

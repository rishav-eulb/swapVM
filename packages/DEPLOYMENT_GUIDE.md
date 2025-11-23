# PseudoArbitrage Deployment and Testing Guide

## Overview

This project implements a **Pseudo-Arbitrage AMM** based on the Engel & Herlihy paper, integrated with SwapVM. The system eliminates divergence loss by transforming the AMM curve when oracle prices change, rather than allowing arbitrageurs to extract value.

## Contract Architecture

1. **PseudoArbitrage.sol** - Core instruction implementing curve transformation logic
2. **PseudoArbitrageOpcodes.sol** - Opcodes registry with all SwapVM instructions
3. **PseudoArbitrageAMM.sol** - Program builder for creating AMM orders
4. **PseudoArbitrageSwapVMRouter.sol** - Main router contract for execution

## Prerequisites

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Required Solidity version
# pragma solidity 0.8.30
```

## Dependencies

The contracts require:
- OpenZeppelin Contracts
- SwapVM framework (1inch)
- Aqua settlement layer

## Project Setup

### 1. Initialize Foundry Project

```bash
# Create project directory
mkdir pseudo-arbitrage-amm
cd pseudo-arbitrage-amm

# Initialize Foundry
forge init

# Install dependencies
forge install OpenZeppelin/openzeppelin-contracts@v5.1.0
forge install 1inch/swap-vm
```

### 2. Configure foundry.toml

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc_version = "0.8.30"
evm_version = "cancun"
optimizer = true
optimizer_runs = 1000000

[rpc_endpoints]
mainnet = "${MAINNET_RPC_URL}"
sepolia = "${SEPOLIA_RPC_URL}"
base = "${BASE_RPC_URL}"

[etherscan]
mainnet = { key = "${ETHERSCAN_API_KEY}" }
sepolia = { key = "${ETHERSCAN_API_KEY}" }
```

### 3. Directory Structure

```
pseudo-arbitrage-amm/
├── src/
│   ├── instructions/
│   │   └── PseudoArbitrage.sol
│   ├── opcodes/
│   │   └── PseudoArbitrageOpcodes.sol
│   ├── routers/
│   │   └── PseudoArbitrageSwapVMRouter.sol
│   └── strategies/
│       └── PseudoArbitrageAMM.sol
├── test/
│   ├── PseudoArbitrage.t.sol
│   ├── PseudoArbitrageIntegration.t.sol
│   └── mocks/
│       ├── MockOracle.sol
│       └── MockERC20.sol
├── script/
│   ├── Deploy.s.sol
│   └── DeployAndTest.s.sol
└── foundry.toml
```

## Deployment Steps

### Step 1: Deploy Mock Contracts (Testing)

For testing on local/testnet, you'll need:
- Mock ERC20 tokens
- Mock oracle
- Mock Aqua (or use testnet Aqua)

### Step 2: Deploy Main Contracts

Deploy in this order:

1. **Deploy Aqua** (if not already deployed)
2. **Deploy PseudoArbitrageSwapVMRouter**
3. **Deploy PseudoArbitrageAMM Builder**

### Step 3: Create AMM Order

Use the builder to create a pseudo-arbitrage AMM order.

## Important Notes

⚠️ **Missing Dependencies**: These contracts have imports that reference the SwapVM framework structure:
- `../libs/Calldata.sol`
- `../libs/VM.sol`
- `../SwapVM.sol`
- Various instruction contracts (Controls, Balances, XYCSwap, etc.)

You'll need to either:
1. Clone the full SwapVM repository from 1inch
2. Install it as a dependency
3. Adjust import paths accordingly

## Next Steps

1. Set up the full project structure
2. Create deployment scripts
3. Write comprehensive tests
4. Deploy to testnet
5. Audit before mainnet deployment

## Testing Strategy

1. **Unit Tests**: Test each instruction in isolation
2. **Integration Tests**: Test full program execution
3. **Oracle Integration**: Test with different oracle implementations
4. **Edge Cases**: Test price changes, rate limiting, initialization
5. **Gas Optimization**: Profile gas usage for common scenarios

## Security Considerations

- Oracle reliability and manipulation resistance
- Rate limiting parameters
- Excess reserve withdrawal permissions
- Reentrancy protection
- Integer overflow/underflow (handled by Solidity 0.8+)

---

**Ready to proceed with deployment?** Let me create the deployment scripts and test files.

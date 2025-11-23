# Concentrated AMM for Aqua Protocol

**A production-ready tick-based concentrated liquidity AMM built on the Aqua shared liquidity layer.**

---

## 🚀 Quick Start

**Status:** ✅ **FULLY IMPLEMENTED & READY TO USE**

This module provides complete concentrated liquidity functionality similar to Uniswap V3, integrated with the 1inch Aqua protocol.

### Installation (2 minutes)

```bash
# All Aqua contracts are already included!
cd /Users/rj39/Desktop/NexusNetwork/swap_vm/files/concentrated-amm

# Build
forge build

# Run tests
forge test --match-contract ConcentratedAMMTest -vvv
```

### Deploy (5 minutes)

```bash
# Option A: Use existing Aqua (Recommended)
export AQUA_ADDRESS=0x499943e74fb0ce105688beee8ef2abec5d936d31
export PRIVATE_KEY="your_key"
export RPC_URL="your_rpc"

forge script script/DeployConcentratedAMM.s.sol \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify

# Option B: Deploy your own Aqua
unset AQUA_ADDRESS
forge script script/DeployConcentratedAMM.s.sol \
  --rpc-url $RPC_URL \
  --broadcast
```

---

## 📚 Documentation

All documentation is in the `/docs` directory:

### Getting Started
- **[START_HERE.md](./docs/START_HERE.md)** ⭐ - Quick reference and navigation
- **[QUICKSTART.md](./docs/QUICKSTART.md)** - 5-minute setup guide

### Understanding the System
- **[AQUA_INTEGRATION_GUIDE.md](./docs/AQUA_INTEGRATION_GUIDE.md)** ⭐ - How Aqua works, maker/taker flows
- **[ARCHITECTURE_DIAGRAMS.md](./docs/ARCHITECTURE_DIAGRAMS.md)** - Visual system diagrams
- **[README_ConcentratedAMM.md](./docs/README_ConcentratedAMM.md)** - Complete technical docs

### Reference
- **[MATH_REFERENCE.md](./docs/MATH_REFERENCE.md)** - All formulas with examples
- **[STRATEGY_GUIDE.md](./docs/STRATEGY_GUIDE.md)** - Strategy selection guide
- **[INDEX.md](./docs/INDEX.md)** - Master documentation index

### Status & Review
- **[REVIEW_SUMMARY.md](./docs/REVIEW_SUMMARY.md)** ⭐ - Complete implementation review
- **[IMPLEMENTATION_STATUS.md](./docs/IMPLEMENTATION_STATUS.md)** - Detailed status breakdown

---

## 📁 Project Structure

```
concentrated-amm/
├── src/
│   ├── Aqua.sol                          # Core Aqua protocol (from 1inch/aqua)
│   ├── AquaApp.sol                       # Base contract for apps (from 1inch/aqua)
│   ├── ConcentratedAMM.sol               # Main AMM contract
│   ├── ConcentratedAMMStrategyBuilder.sol # Helper utilities
│   ├── interfaces/
│   │   ├── IAqua.sol                     # Aqua interface (from 1inch/aqua)
│   │   └── IConcentratedAMMCallback.sol  # Swap callback interface
│   └── libs/                             # Aqua libraries (from 1inch/aqua)
│       ├── Balance.sol
│       ├── Multicall.sol
│       ├── ReentrancyGuard.sol
│       ├── Simulator.sol
│       ├── Transient.sol
│       └── TransientLock.sol
│
├── test/
│   └── ConcentratedAMM.t.sol            # Comprehensive test suite (10+ scenarios)
│
├── script/
│   └── DeployConcentratedAMM.s.sol      # Deployment scripts
│
├── docs/                                 # All documentation
│   ├── START_HERE.md                    # Quick navigation
│   ├── AQUA_INTEGRATION_GUIDE.md        # Complete Aqua explanation
│   ├── ARCHITECTURE_DIAGRAMS.md         # Visual diagrams
│   ├── REVIEW_SUMMARY.md                # Implementation review
│   ├── IMPLEMENTATION_STATUS.md         # Detailed status
│   ├── QUICKSTART.md                    # Quick start guide
│   ├── README_ConcentratedAMM.md        # Technical documentation
│   ├── MATH_REFERENCE.md                # Mathematical reference
│   ├── STRATEGY_GUIDE.md                # Strategy guide
│   └── INDEX.md                         # Master index
│
└── README.md                            # This file
```

---

## ✨ Key Features

### Concentrated Liquidity
- ✅ Tick-based liquidity concentration (like Uniswap V3)
- ✅ Customizable price ranges
- ✅ Up to 4000x capital efficiency vs traditional AMMs
- ✅ Both exact input and exact output swaps

### Aqua Integration
- ✅ Makers retain custody of tokens
- ✅ Virtual balance tracking
- ✅ Same tokens can back multiple strategies
- ✅ Composable with other Aqua apps

### Production Ready
- ✅ Complete test coverage (10+ scenarios)
- ✅ Reentrancy protection (transient storage)
- ✅ Slippage protection
- ✅ Balance verification
- ✅ Gas optimizations
- ✅ Comprehensive documentation (9 guides!)

---

## 🎯 Use Cases

### For Liquidity Providers (Makers)
- Provide concentrated liquidity in specific price ranges
- Earn fees on swaps
- Retain custody of your tokens
- Create multiple positions with same tokens

### For Traders (Takers)
- Execute swaps with low slippage
- Trade against concentrated liquidity
- Benefit from capital efficiency

### For Developers
- Build on top of Aqua protocol
- Integrate concentrated liquidity into your dApp
- Use as reference for other Aqua apps

---

## 🔧 Basic Usage

### Providing Liquidity

```solidity
import { ConcentratedAMMStrategyBuilder } from "./src/ConcentratedAMMStrategyBuilder.sol";

// Setup builder
ConcentratedAMMStrategyBuilder builder = ConcentratedAMMStrategyBuilder(BUILDER_ADDRESS);

// Approve tokens
IERC20(token0).approve(address(builder), amount0);
IERC20(token1).approve(address(builder), amount1);

// Create position
bytes32 strategyHash = builder.createAndShipStrategy(
    token0,         // Lower address token
    token1,         // Higher address token
    1800e18,        // Lower price bound
    2200e18,        // Upper price bound
    2000e18,        // Current price
    1000000e6,      // Amount of token0
    500e18,         // Amount of token1
    30,             // 0.3% fee
    salt            // Unique identifier
);
```

### Executing Swaps

```solidity
import { ConcentratedAMM } from "./src/ConcentratedAMM.sol";

// Quote swap
uint256 expectedOut = amm.quoteExactIn(
    strategy,
    true,           // zeroForOne
    amountIn
);

// Execute swap
uint256 amountOut = amm.swapExactIn(
    strategy,
    true,
    amountIn,
    amountOutMin,   // Slippage protection
    recipient,
    callbackData
);
```

---

## 🌐 Supported Networks

Use the deployed Aqua contract on:
- Ethereum Mainnet: `0x499943e74fb0ce105688beee8ef2abec5d936d31`
- Base: `0x499943e74fb0ce105688beee8ef2abec5d936d31`
- Optimism: `0x499943e74fb0ce105688beee8ef2abec5d936d31`
- Polygon: `0x499943e74fb0ce105688beee8ef2abec5d936d31`
- Arbitrum: `0x499943e74fb0ce105688beee8ef2abec5d936d31`
- Avalanche: `0x499943e74fb0ce105688beee8ef2abec5d936d31`
- BSC: `0x499943e74fb0ce105688beee8ef2abec5d936d31`
- And more...

---

## 🧪 Testing

Run the comprehensive test suite:

```bash
# All tests
forge test --match-contract ConcentratedAMMTest -vvv

# Specific test
forge test --match-test testSwapExactInWithinRange -vvvv

# With gas reporting
forge test --match-contract ConcentratedAMMTest --gas-report
```

**Test Coverage:**
- Position creation and initialization
- Swap execution (exact in/out)
- Multiple sequential swaps
- Price impact calculations
- Liquidity mathematics
- Token amount calculations
- Tick/price conversions
- Strategy comparisons
- Bidirectional swaps
- Fee accumulation

---

## 📖 Documentation Overview

### Must Read
1. **[START_HERE.md](./docs/START_HERE.md)** - Begin here for overview
2. **[AQUA_INTEGRATION_GUIDE.md](./docs/AQUA_INTEGRATION_GUIDE.md)** - Understand how everything works
3. **[QUICKSTART.md](./docs/QUICKSTART.md)** - Deploy and test quickly

### Reference
- **[MATH_REFERENCE.md](./docs/MATH_REFERENCE.md)** - Formulas and calculations
- **[STRATEGY_GUIDE.md](./docs/STRATEGY_GUIDE.md)** - Choose the right strategy
- **[ARCHITECTURE_DIAGRAMS.md](./docs/ARCHITECTURE_DIAGRAMS.md)** - Visual flows

### Implementation Details
- **[REVIEW_SUMMARY.md](./docs/REVIEW_SUMMARY.md)** - Complete assessment
- **[IMPLEMENTATION_STATUS.md](./docs/IMPLEMENTATION_STATUS.md)** - Status breakdown
- **[README_ConcentratedAMM.md](./docs/README_ConcentratedAMM.md)** - Technical docs

---

## 🔗 Important Links

- **1inch Aqua Protocol:** https://github.com/1inch/aqua
- **Deployed Aqua:** `0x499943e74fb0ce105688beee8ef2abec5d936d31`
- **License Contact:** license@degensoft.com or legal@degensoft.com

---

## 📝 License

Licensed under **LicenseRef-Degensoft-Aqua-Source-1.1**

See the LICENSE file for details. For licensing inquiries, contact:
- 📧 license@degensoft.com
- 📧 legal@degensoft.com

---

## 💡 Key Concepts

### What is Aqua?

Aqua is a **shared liquidity layer** where makers retain custody of their tokens while providing liquidity. Unlike traditional AMMs that hold your tokens, Aqua uses **virtual balance tracking**.

**Traditional AMM:**
```
Your tokens → Deposited into contract → Contract holds them
```

**Aqua Protocol:**
```
Your tokens → Stay in your wallet → Aqua tracks virtual balances
```

### What is Concentrated Liquidity?

Instead of spreading liquidity across the entire price curve (0 to ∞), you can focus your capital within specific price ranges.

**Example:**
- Traditional AMM: Liquidity from $0 to infinity
- Concentrated AMM: Liquidity only from $1,800 to $2,200

**Result:** Up to 4000x more capital efficient!

---

## 🎉 You're Ready!

Everything is set up and ready to use:

1. **✅ Aqua contracts** - Already included from 1inch/aqua
2. **✅ Core AMM** - Fully implemented
3. **✅ Tests** - Comprehensive coverage
4. **✅ Deployment scripts** - Ready to deploy
5. **✅ Documentation** - 9 detailed guides

**Next Steps:**

1. Read [START_HERE.md](./docs/START_HERE.md) for quick navigation
2. Follow [QUICKSTART.md](./docs/QUICKSTART.md) to deploy
3. Check [AQUA_INTEGRATION_GUIDE.md](./docs/AQUA_INTEGRATION_GUIDE.md) to understand the system

---

## 🆘 Need Help?

- **Aqua Protocol Issues:** https://github.com/1inch/aqua/issues
- **Documentation:** Check the `/docs` directory
- **Testing:** Run the test suite for examples
- **Licensing:** license@degensoft.com or legal@degensoft.com

---

**Ready to provide concentrated liquidity?** Start with [docs/START_HERE.md](./docs/START_HERE.md)! 🚀


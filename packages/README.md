# PseudoArbitrage AMM - Complete Deployment Package

## 📋 What You Have

Your contracts implement a **Pseudo-Arbitrage AMM** based on the Engel & Herlihy paper, integrated with 1inch's SwapVM framework. This system eliminates divergence loss for liquidity providers by transforming the AMM curve when oracle prices change.

## 🎯 Quick Start (Fastest Path)

### Option 1: Automated Setup (Recommended)

```bash
# 1. Make setup script executable (if not already)
chmod +x setup.sh

# 2. Run setup script
./setup.sh

# 3. Follow the on-screen instructions
```

### Option 2: Manual Setup

1. **Read the guides** (in order):
   - `DEPLOYMENT_GUIDE.md` - Overview and architecture
   - `STEP_BY_STEP_GUIDE.md` - Detailed walkthrough
   
2. **Set up the project** following Step-by-Step Guide

3. **Copy your contracts** to the right locations

4. **Test and deploy**

## 📦 Files Included

### Documentation
- ✅ `DEPLOYMENT_GUIDE.md` - High-level overview and strategy
- ✅ `STEP_BY_STEP_GUIDE.md` - Detailed deployment instructions
- ✅ `README.md` - This summary document

### Scripts
- ✅ `setup.sh` - Automated setup script
- ✅ `Deploy.s.sol` - Deployment scripts for production and testing

### Tests
- ✅ `PseudoArbitrage.t.sol` - Unit tests for core logic
- ✅ `PseudoArbitrageIntegration.t.sol` - Integration test templates

### Your Original Contracts (to be organized)
- 📄 `PseudoArbitrage.sol` → Goes to `src/instructions/`
- 📄 `PseudoArbitrageOpcodes.sol` → Goes to `src/opcodes/`
- 📄 `PseudoArbitrageAMM.sol` → Goes to `src/strategies/`
- 📄 `PseudoArbitrageSwapVMRouter.sol` → Goes to `src/routers/`

## ⚠️ Critical Dependencies

Your contracts require the **1inch SwapVM framework**, which includes:
- VM execution engine
- Context and state management
- Instruction implementations (Controls, Balances, XYCSwap, etc.)
- Aqua settlement layer integration

### You Must:

1. **Install SwapVM**:
   ```bash
   forge install 1inch/swap-vm
   # OR
   git clone https://github.com/1inch/swap-vm.git lib/swap-vm
   ```

2. **Fix Import Paths**:
   Your contracts have relative imports like:
   ```solidity
   import { Context } from "../libs/VM.sol";
   ```
   
   Change to:
   ```solidity
   import { Context } from "swap-vm/libs/VM.sol";
   ```

3. **Get Aqua Address**:
   - For testing: Deploy mock Aqua (included in Deploy.s.sol)
   - For production: Get from 1inch documentation

## 🚀 Deployment Paths

### Path A: Local Testing (Start Here)

```bash
# Terminal 1: Start local node
anvil

# Terminal 2: Deploy with mocks
forge script script/Deploy.s.sol:DeployWithMocksScript \
  --rpc-url http://localhost:8545 \
  --broadcast

# Run tests
forge test -vv
```

### Path B: Testnet Deployment

```bash
# 1. Get testnet ETH from faucet
# 2. Configure .env with your keys
# 3. Deploy
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify
```

### Path C: Mainnet (After Audit!)

```bash
# ⚠️ ONLY after professional audit!
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $MAINNET_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

## 🧪 Testing Strategy

### 1. Unit Tests (Included)
```bash
forge test --match-contract PseudoArbitrageTest -vv
```

Tests verify:
- Argument parsing
- State initialization
- Price change transformations
- Rate limiting
- Error conditions

### 2. Integration Tests (Template Provided)
```bash
forge test --match-contract PseudoArbitrageIntegrationTest -vvv
```

You need to complete these tests once SwapVM is integrated.

### 3. Gas Profiling
```bash
forge test --gas-report
forge snapshot
```

## 📊 Architecture Overview

```
┌─────────────────────────────────────────────────┐
│         PseudoArbitrageSwapVMRouter             │
│                   (Main Entry)                  │
└────────────────┬────────────────────────────────┘
                 │
                 │ inherits
                 ▼
┌─────────────────────────────────────────────────┐
│          PseudoArbitrageOpcodes                 │
│          (Instruction Registry)                 │
└────┬───────────────────────────────────────┬────┘
     │                                       │
     │ includes                              │ includes
     ▼                                       ▼
┌──────────────────────┐          ┌────────────────────┐
│  PseudoArbitrage     │          │  Other SwapVM      │
│  (Core Logic)        │          │  Instructions      │
└──────────────────────┘          └────────────────────┘

┌─────────────────────────────────────────────────┐
│         PseudoArbitrageAMM                      │
│         (Program Builder)                       │
└─────────────────────────────────────────────────┘
           │
           │ creates orders for
           ▼
┌─────────────────────────────────────────────────┐
│         SwapVM Router                           │
└─────────────────────────────────────────────────┘
```

## 🔧 Common Issues & Solutions

### Issue: "Cannot find SwapVM imports"
**Solution:**
```bash
# Install SwapVM
git clone https://github.com/1inch/swap-vm.git lib/swap-vm

# Update foundry.toml remappings
remappings = [
    "swap-vm/=lib/swap-vm/src/"
]

# Fix imports in your contracts
```

### Issue: "Cannot find instruction contracts"
**Solution:**
Your contracts inherit from SwapVM instructions. You need the full SwapVM framework with:
- Controls.sol
- Balances.sol
- XYCSwap.sol
- Fee.sol
- etc.

These are in the SwapVM repository.

### Issue: Compilation fails
**Solution:**
```bash
# Clean and rebuild
forge clean
forge build

# Check Solidity version matches
forge --version  # Should show 0.8.30
```

### Issue: Tests won't run
**Solution:**
```bash
# Install forge-std
forge install foundry-rs/forge-std

# Verify test file structure
forge test --list
```

## 📚 Learning Resources

### Essential Reading
1. **Engel & Herlihy Paper**: [Pseudo-Arbitrage](https://arxiv.org/abs/2106.00667)
   - Section 6.1 covers the curve transformation strategy

2. **1inch SwapVM Docs**: https://github.com/1inch/swap-vm
   - Understanding the instruction-based architecture
   - How programs are built and executed

3. **Foundry Book**: https://book.getfoundry.sh/
   - Testing framework
   - Deployment scripts

### Code Examples
- See test files for usage examples
- See Deploy.s.sol for deployment patterns
- See PseudoArbitrageAMM.sol for program building

## ✅ Pre-Deployment Checklist

Before mainnet deployment:

- [ ] All tests pass
- [ ] Gas usage optimized
- [ ] Oracle integration verified
- [ ] Rate limiting tested
- [ ] Access controls reviewed
- [ ] Professional audit completed
- [ ] Emergency pause mechanism added
- [ ] Monitoring infrastructure ready
- [ ] Documentation complete
- [ ] Insurance/bug bounty program

## 🎓 Understanding the Contracts

### PseudoArbitrage.sol
The core instruction that:
1. Monitors oracle for price changes
2. Calculates curve transformation when price shifts
3. Adjusts effective balances before swaps
4. Tracks excess reserves

### PseudoArbitrageAMM.sol
Builder that creates SwapVM programs:
1. Sets initial balances
2. Adds pseudo-arbitrage instruction
3. Adds fee instruction (optional)
4. Adds swap instruction
5. Adds controls (deadline, salt)

### PseudoArbitrageOpcodes.sol
Registry that:
1. Inherits all standard SwapVM instructions
2. Adds the pseudo-arbitrage instruction
3. Provides the instruction array to the router

### PseudoArbitrageSwapVMRouter.sol
Main router that:
1. Executes SwapVM programs
2. Uses the extended instruction set
3. Handles order validation and settlement

## 🚦 Recommended Workflow

### Phase 1: Setup (Day 1)
1. Run setup script
2. Install dependencies
3. Fix import paths
4. Achieve successful compilation

### Phase 2: Local Testing (Days 2-3)
1. Deploy to Anvil
2. Run unit tests
3. Complete integration tests
4. Profile gas usage

### Phase 3: Testnet (Week 1)
1. Deploy to Sepolia
2. Create test AMMs
3. Execute test trades
4. Monitor oracle integration
5. Test edge cases

### Phase 4: Audit (Weeks 2-4)
1. Get professional audit
2. Fix any issues found
3. Re-test thoroughly

### Phase 5: Mainnet (Week 5+)
1. Deploy to mainnet
2. Start with limited liquidity
3. Monitor closely
4. Scale gradually

## 💡 Key Concepts

### Divergence Loss Elimination
Traditional AMMs suffer divergence loss when prices change - arbitrageurs extract value. This system transforms the curve instead, preserving LP value.

### Curve Transformation
Uses linear transformations: `A' := (x, f(x - shiftX) - shiftY)`
- When price ↑: Shift curve to maintain equilibrium
- When price ↓: Shift curve to maintain equilibrium

### Oracle Integration
- Requires reliable price feed
- Rate limiting prevents manipulation
- Supports any oracle with `getPrice(address,address)` interface

## 🤝 Getting Help

If you encounter issues:

1. **Check the guides**: Most common issues are covered
2. **Review error messages**: Solidity errors are usually clear
3. **Test incrementally**: Don't try to deploy everything at once
4. **Join communities**:
   - 1inch Discord/Telegram
   - Foundry Telegram
   - Ethereum StackExchange

## 📈 Next Steps

1. ✅ **Complete setup** using the automated script or manual guide
2. ✅ **Integrate SwapVM** dependencies
3. ✅ **Run tests** to verify functionality
4. ✅ **Deploy locally** to test end-to-end
5. ⬜ **Deploy to testnet** for real-world testing
6. ⬜ **Get audit** before mainnet
7. ⬜ **Go to production** with monitoring

---

## 🎉 You're Ready!

You now have everything needed to deploy and test your PseudoArbitrage AMM:

- ✅ Complete documentation
- ✅ Automated setup script
- ✅ Deployment scripts
- ✅ Test suite
- ✅ Configuration templates

**Start with:** `./setup.sh` or read `STEP_BY_STEP_GUIDE.md`

Good luck! 🚀

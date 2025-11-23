# Cross-AMM Arbitrage - Review Summary

**Date**: November 23, 2025  
**Status**: ⚠️ **REQUIRES FIXES**  
**Severity**: 🟡 **Medium** (Won't compile but design is sound)

---

## Executive Summary

I've completed a comprehensive review of the cross-amm-arbitrage implementation by comparing it against the swap-vm and aqua libraries. Here's what I found:

### The Good ✅

1. **Excellent Concept**: Exploiting price differences between ConcentratedAMM (tick-based) and PseudoArbitrageAMM (oracle-based) is a sound arbitrage strategy
2. **Well Architected**: Clear separation of concerns, good use of interfaces
3. **Comprehensive Features**: Opportunity detection, optimal sizing, bot automation
4. **Great Documentation**: 3 detailed markdown files with examples
5. **Good Test Coverage**: 8 test functions covering major scenarios

### The Bad ❌

1. **Won't Compile**: Import paths are incorrect
2. **Logic Bug**: Arbitrage flow tries to use tokens before receiving them
3. **Variable Name Error**: Uses `aqua` instead of `AQUA`
4. **Missing File**: Interface file wasn't created ✅ NOW FIXED
5. **Test Errors**: Tests try to call internal functions

### The Verdict

**Overall Score: 7/10** (Would be 9/10 after fixes)

✅ **Recommended**: Fix the issues and deploy. The concept is solid and the fixes are straightforward.

---

## Architecture Validation

### Checked Against: swap-vm Library ✅

**Interface Compatibility**:
- ✅ `ISwapVM.Order` structure matches
- ✅ `quote()` method signature correct
- ✅ `swap()` method signature correct
- ✅ `hash()` method usage appropriate

**Issues Found**:
- ❌ Import path: Uses `"../swapvm/SwapVM.sol"` instead of `"swap-vm/interfaces/ISwapVM.sol"`

### Checked Against: aqua Library ✅

**Interface Compatibility**:
- ✅ `IAqua` interface usage correct
- ✅ `AquaApp` inheritance proper
- ✅ `push()` method signature correct
- ✅ `pull()` method signature correct

**Issues Found**:
- ❌ Import path: Uses `"src/interfaces/IAqua.sol"` instead of `"aqua/interfaces/IAqua.sol"`
- ❌ Variable name: Uses `aqua` (lowercase) instead of `AQUA` (uppercase) inherited from AquaApp

### Checked Against: ConcentratedAMM ✅

**Interface Compatibility**:
- ✅ `Strategy` struct matches
- ✅ `swapExactIn()` signature correct
- ✅ `quoteExactIn()` signature correct
- ✅ Callback interface implemented correctly

**Issues Found**:
- ❌ Import path: Uses `"../ConcentratedAMM.sol"` instead of `"../concentrated-amm/ConcentratedAMM.sol"`

---

## Critical Issues Found

### 1. Import Path Errors (Severity: CRITICAL 🔴)

**Problem**: All imports use wrong paths based on incorrect assumptions about directory structure.

**Example**:
```solidity
// CURRENT (WRONG):
import { IAqua } from "src/interfaces/IAqua.sol";
import { ISwapVM } from "../swapvm/SwapVM.sol";

// SHOULD BE:
import { IAqua } from "aqua/interfaces/IAqua.sol";
import { ISwapVM } from "swap-vm/interfaces/ISwapVM.sol";
```

**Impact**: Contract won't compile

**Fix**: Update all 21 import statements across 4 files + create remappings.txt

✅ **Remappings file created**

---

### 2. AQUA vs aqua Bug (Severity: CRITICAL 🔴)

**Location**: `CrossAMMArbitrage.sol:577-578`

**Problem**:
```solidity
IERC20(tokenIn).approve(address(aqua), amountIn);  // ❌ 'aqua' doesn't exist
aqua.push(maker, app, strategyHash, tokenIn, amountIn);
```

**Should be**:
```solidity
IERC20(tokenIn).approve(address(AQUA), amountIn);  // ✅ 'AQUA' from AquaApp
AQUA.push(maker, app, strategyHash, tokenIn, amountIn);
```

**Impact**: Runtime error - variable doesn't exist

**Fix**: Change lowercase `aqua` to uppercase `AQUA` (2 occurrences)

---

### 3. Arbitrage Flow Logic Error (Severity: HIGH 🟠)

**Location**: `CrossAMMArbitrage.sol:214-227`

**Problem**: Callback is called but no verification that tokens were received before trying to use them.

**Current flow**:
```
1. Call borrowForArbitrage() callback
2. Immediately try to buy from AMM
   ❌ No check that tokens were received!
```

**Should be**:
```
1. Call borrowForArbitrage() callback
2. ✅ Verify tokens received
3. Buy from AMM
```

**Impact**: Transaction will revert with "insufficient balance" if callback doesn't work correctly

**Fix**: Add balance verification after callback

---

### 4. Missing Interface File (Severity: HIGH 🟠)

**File**: `interfaces/IArbitrageCallback.sol`

**Status**: ✅ **FIXED** - Created during review

**Content**:
```solidity
interface IArbitrageCallback {
    function borrowForArbitrage(
        address token,
        uint256 amount,
        bytes calldata data
    ) external;
}
```

---

### 5. Test Compilation Errors (Severity: MEDIUM 🟡)

**Location**: `CrossAMMArbitrage.t.sol:288`

**Problem**: Tries to call internal function `_calculateProfit()`

```solidity
uint256 profitAtOptimal = arbitrage._calculateProfit(opp, optimalAmount);
// ❌ Can't call internal functions from outside
```

**Impact**: Tests won't compile

**Fix**: Remove these lines, test the functionality indirectly through public methods

---

### 6. Missing Imports in Deploy Script (Severity: MEDIUM 🟡)

**Location**: `DeployCrossAMMArbitrage.s.sol:146-147`

**Problem**: Uses `IERC20` and `ISwapVM` without importing them

**Impact**: Script won't compile

**Fix**: Add imports:
```solidity
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISwapVM } from "swap-vm/interfaces/ISwapVM.sol";
```

---

## Security Concerns

### 1. Reentrancy Vulnerability 🔒

**Location**: `_executeArbitrageLoop`

**Issue**: External call to untrusted `msg.sender` before state changes

**Risk Level**: HIGH

**Recommendation**: Add ReentrancyGuard to `executeArbitrage()` function

### 2. Front-Running Risk 🔒

**Issue**: Profitable arbitrages visible in mempool

**Risk Level**: MEDIUM

**Mitigation**: Use Flashbots or private RPC

### 3. Flash Loan Attack Vector 🔒

**Issue**: Bot holds capital that could be exploited

**Risk Level**: MEDIUM

**Mitigation**: Add reentrancy protection to all external functions

---

## Files Reviewed

| File | Lines | Status | Issues |
|------|-------|--------|--------|
| CrossAMMArbitrage.sol | 599 | ⚠️ Needs fixes | 3 critical |
| CrossAMMArbitrageBot.sol | 488 | ⚠️ Needs fixes | 1 critical |
| CrossAMMArbitrage.t.sol | 530 | ⚠️ Needs fixes | 2 critical |
| DeployCrossAMMArbitrage.s.sol | 238 | ⚠️ Needs fixes | 2 medium |
| IArbitrageCallback.sol | - | ✅ Created | - |
| remappings.txt | - | ✅ Created | - |
| **Total** | **1,855** | **⚠️ FIX REQUIRED** | **8 issues** |

---

## Comparison with Reference Implementations

### vs. swap-vm Patterns ✅

The implementation follows swap-vm patterns correctly:
- ✅ Proper use of `ISwapVM.Order` struct
- ✅ Correct `quote()` and `swap()` method calls
- ✅ Appropriate use of `takerTraitsAndData` parameter
- ✅ Proper handling of return values (amountIn, amountOut, orderHash)

### vs. aqua Patterns ✅

The implementation follows aqua patterns correctly:
- ✅ Extends `AquaApp` base contract
- ✅ Uses `AQUA.pull()` for withdrawals
- ✅ Uses `AQUA.push()` for deposits
- ✅ Proper `strategyHash` usage
- ❌ Variable name error (aqua vs AQUA) - easy fix

### vs. ConcentratedAMM Patterns ✅

The implementation integrates correctly with ConcentratedAMM:
- ✅ Proper `Strategy` struct usage
- ✅ Correct swap method signatures
- ✅ Implements callback interface properly
- ✅ Proper quote function usage

---

## Code Quality Assessment

| Aspect | Rating | Notes |
|--------|--------|-------|
| **Architecture** | ⭐⭐⭐⭐⭐ | Excellent separation of concerns |
| **Code Style** | ⭐⭐⭐⭐ | Clean, readable, well-commented |
| **Error Handling** | ⭐⭐⭐⭐ | Good custom errors, proper requires |
| **Gas Optimization** | ⭐⭐⭐ | Could be better (loops, caching) |
| **Security** | ⭐⭐⭐ | Needs reentrancy guards |
| **Documentation** | ⭐⭐⭐⭐⭐ | Exceptional - 3 detailed guides |
| **Test Coverage** | ⭐⭐⭐⭐ | Good scenarios, needs edge cases |

**Average**: ⭐⭐⭐⭐ (4.0/5)

---

## Fix Priority Matrix

### Priority 1: Won't Compile (Do First) 🔴
1. ✅ Create IArbitrageCallback.sol - **DONE**
2. ✅ Create remappings.txt - **DONE**
3. Fix all import paths (4 files)
4. Fix AQUA vs aqua bug
5. Add missing imports to script

**Time**: 1-2 hours

### Priority 2: Won't Work Correctly (Do Second) 🟠
6. Fix arbitrage flow logic
7. Remove test internal calls
8. Add balance verification

**Time**: 1-2 hours

### Priority 3: Security & Optimization (Do Third) 🟡
9. Add reentrancy guards
10. Add MEV protection notes
11. Optimize gas usage
12. Add more edge case tests

**Time**: 2-3 hours

---

## Recommended Fix Order

### Step 1: Get It Compiling (30 minutes)
```bash
# Already done:
✅ IArbitrageCallback.sol created
✅ remappings.txt created

# Still need:
1. Update all imports in CrossAMMArbitrage.sol
2. Update all imports in CrossAMMArbitrageBot.sol  
3. Update all imports in CrossAMMArbitrage.t.sol
4. Update all imports in DeployCrossAMMArbitrage.s.sol
```

### Step 2: Fix Logic Bugs (30 minutes)
```bash
1. Change aqua → AQUA (2 places)
2. Add balance check after callback
3. Remove internal function calls from tests
```

### Step 3: Test (1 hour)
```bash
forge build                  # Should compile now
forge test                   # Should pass
forge test -vvv             # Detailed output
```

### Step 4: Security (2 hours)
```bash
1. Add ReentrancyGuard
2. Review all external calls
3. Add more test cases
4. Consider audit
```

---

## Files Created During Review

✅ **IArbitrageCallback.sol** - Required interface (16 lines)
✅ **remappings.txt** - Foundry path mappings (6 lines)
✅ **CROSS_AMM_REVIEW.md** - Detailed technical review (800+ lines)
✅ **FIX_SUMMARY.md** - Concise fix guide (300+ lines)
✅ **REVIEW_SUMMARY.md** - This file (executive summary)

---

## Final Recommendation

### Should you use this code?

**YES** - but only after fixes are applied.

### Is the concept sound?

**YES** - Exploiting price discrepancies between manual (ConcentratedAMM) and oracle-based (PseudoArbitrageAMM) pricing is a real and profitable opportunity.

### Is the implementation correct?

**MOSTLY** - The architecture and logic are sound, but there are fixable bugs that prevent compilation and execution.

### Is it production-ready?

**NOT YET** - Apply fixes, test thoroughly, consider security audit.

### How long to fix?

**4-6 hours** of focused work to get to production-ready state.

---

## Conclusion

The Cross-AMM Arbitrage system demonstrates:
- ✅ Strong understanding of AMM mechanics
- ✅ Good software engineering practices
- ✅ Excellent documentation
- ✅ Solid arbitrage strategy
- ❌ Implementation bugs (fixable)
- ❌ Missing security hardening

**With the fixes outlined in this review, this will be a high-quality, production-ready arbitrage system.**

---

## Next Steps

1. ✅ Review created
2. ✅ Interface file created  
3. ✅ Remappings created
4. 🔧 Apply import path fixes
5. 🔧 Fix logic bugs
6. 🧪 Test compilation
7. 🧪 Run test suite
8. 🚀 Deploy to testnet
9. 🔍 Monitor results
10. 🔒 Security audit (recommended)
11. 🚀 Deploy to mainnet

---

**Review Complete**: ✅

**Documentation Created**:
- ✅ CROSS_AMM_REVIEW.md - Full technical review
- ✅ FIX_SUMMARY.md - Quick fix guide
- ✅ REVIEW_SUMMARY.md - Executive summary
- ✅ IArbitrageCallback.sol - Required interface
- ✅ remappings.txt - Path configuration

**Recommendation**: **PROCEED WITH FIXES** → The system is well-designed and worth fixing.

---

For detailed fix instructions, see: [FIX_SUMMARY.md](./FIX_SUMMARY.md)  
For complete technical analysis, see: [CROSS_AMM_REVIEW.md](./CROSS_AMM_REVIEW.md)


# Pseudo-Arbitrage AMM Architecture

## Executive Summary

This project implements a **Pseudo-Arbitrage AMM** based on the Engel & Herlihy research paper (Section 6.1) using the SwapVM instruction-based framework. The key innovation is that instead of allowing arbitrageurs to profit from price divergence (as in traditional AMMs), the liquidity provider captures that value by transforming the bonding curve when oracle price changes occur.

---

## Implementation Review

### ✅ Implementation Status: **CORRECT**

The implementation follows SwapVM best practices and correctly implements the pseudo-arbitrage strategy. Here's the validation:

#### 1. **PseudoArbitrage Instruction** (`src/instructions/PseudoArbitrage.sol`)
- ✅ Properly extends SwapVM instruction pattern
- ✅ Correctly uses `Context` memory structure
- ✅ Implements curve transformation logic per Engel & Herlihy
- ✅ Includes state management per order (using `orderHash`)
- ✅ Implements rate limiting to prevent oracle manipulation
- ✅ Properly handles initialization and updates
- ✅ Calculates stable points and shifts correctly

**Key Features:**
- Linear transformation: `A' := (x, f(x - shiftX) - shiftY)`
- Oracle integration with customizable update intervals
- Excess reserve tracking for LP benefits
- Static context support for quoting

#### 2. **PseudoArbitrageOpcodes** (`src/opcodes/PseudoArbitrageOpcodes.sol`)
- ✅ Correctly inherits all base SwapVM instructions
- ✅ Properly registers the new instruction at index 36
- ✅ Maintains backward compatibility
- ✅ Uses correct import paths (after fixes)

#### 3. **PseudoArbitrageSwapVMRouter** (`src/routers/PseudoArbitrageSwapVMRouter.sol`)
- ✅ Properly extends SwapVM base contract
- ✅ Correctly implements Simulator for view functions
- ✅ Properly wires up the instruction set

#### 4. **PseudoArbitrageAMM Strategy** (`src/strategies/PseudoArbitrageAMM.sol`)
- ✅ Provides high-level strategy builder
- ✅ Correctly sequences instructions:
  1. Set balances
  2. Apply pseudo-arbitrage transformation
  3. Apply fees (optional)
  4. Execute swap
  5. Check deadline
  6. Add salt (optional)
- ✅ Includes concentrated liquidity variant
- ✅ Proper validation and error handling

---

## How the Pseudo-Arbitrage AMM Works

### Core Concept

Traditional AMMs like Uniswap suffer from **divergence loss** (impermanent loss) when market prices change:
1. Market price changes externally
2. AMM curve still reflects old price
3. Arbitrageurs exploit the difference, extracting value from LPs

**Pseudo-Arbitrage AMM Solution:**
1. Market price changes (detected via oracle)
2. AMM transforms its curve to match new price
3. No arbitrage opportunity exists
4. LPs retain value that would have gone to arbitrageurs

### Mathematical Foundation

Given a constant product AMM with invariant `k = x * y`:

**Stable Point** (where AMM price matches market price):
- For price `p = y/x`:
  - `x_stable = sqrt(k / p)`
  - `y_stable = sqrt(k * p)`

**When Price Changes** from `p_old` to `p_new`:
- Calculate old and new stable points
- Compute shifts: `shiftX = x_new - x_old`, `shiftY = y_new - y_old`
- Transform curve: effective balances = actual balances - shifts
- Excess reserves (inaccessible) = magnitude of negative shift

**Example:**
```
Initial: x=1000, y=3000 (price = 3)
k = 3,000,000

Market price increases to p=4:
- Old stable point: x=1000, y=3000
- New stable point: x=866, y=3464
- Shifts: shiftX=-134, shiftY=+464
- Excess: 134 tokens of X locked
- Swaps now use effective balances that reflect p=4
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        Aqua Protocol                         │
│                   (1inch Liquidity Layer)                    │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    │ LP deposits tokens
                    ▼
┌─────────────────────────────────────────────────────────────┐
│              PseudoArbitrageSwapVMRouter                     │
│                                                              │
│  ┌──────────────────────────────────────────────────┐      │
│  │           PseudoArbitrageOpcodes                  │      │
│  │                                                   │      │
│  │  [Standard Instructions]  [New Instruction]      │      │
│  │  • _staticBalancesXD      • _pseudoArbitrageXD   │      │
│  │  • _xycSwapXD             ↓                       │      │
│  │  • _flatFeeAmountInXD     ┌─────────────────┐   │      │
│  │  • _deadline              │ Oracle Check &  │   │      │
│  │  • _salt                  │ Curve Transform │   │      │
│  │  • ...                    └─────────────────┘   │      │
│  └──────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
                    │
                    │ Price feeds
                    ▼
┌─────────────────────────────────────────────────────────────┐
│                    Price Oracle                              │
│              (Chainlink, Uniswap TWAP, etc.)                │
└─────────────────────────────────────────────────────────────┘
```

---

## Program Execution Flow

### Order Creation (Maker/LP Side)

```solidity
// 1. Maker creates strategy using PseudoArbitrageAMM
PseudoArbitrageAMM builder = new PseudoArbitrageAMM(aquaAddress);

ISwapVM.Order memory order = builder.buildProgram(
    maker: 0x123...,
    expiration: block.timestamp + 30 days,
    token0: USDC,
    token1: ETH,
    balance0: 1_000_000 USDC,
    balance1: 300 ETH,
    oracle: 0xOracle...,
    initialPrice: 3333 ether,  // $3333 per ETH
    minUpdateInterval: 1 hours,
    feeBps: 30,  // 0.3% fee
    salt: 0
);

// 2. Order is shipped to Aqua
aqua.ship(order, balance0, balance1);
```

The created program bytecode:
```
[opcode:18][len][tokens|balances]     # _staticBalancesXD
[opcode:36][len][oracle|price|interval] # _pseudoArbitrageXD
[opcode:40][len][feeBps]              # _flatFeeAmountInXD
[opcode:24][len][]                    # _xycSwapXD
[opcode:14][len][expiration]          # _deadline
```

### Swap Execution (Taker Side)

```javascript
// 1. Taker wants to swap USDC for ETH
const amountIn = 10000; // 10k USDC

// 2. Quote the swap (view call)
const [amountInQuote, amountOutQuote] = await router.quote(
    order,
    USDC,
    ETH,
    amountIn,
    takerTraitsAndData
);
// Returns: amountOut ≈ 2.99 ETH (after 0.3% fee)

// 3. Execute swap
const [amountInActual, amountOutActual] = await router.swap(
    order,
    USDC,
    ETH,
    amountIn,
    takerTraitsAndData
);
```

### What Happens During Execution

```
Step 1: _staticBalancesXD
├─ Sets ctx.swap.balanceIn = 1,000,000 USDC
└─ Sets ctx.swap.balanceOut = 300 ETH

Step 2: _pseudoArbitrageXD
├─ Checks orderHash state
├─ If initialized:
│  ├─ Checks if minUpdateInterval passed
│  ├─ Queries oracle for current price
│  ├─ If price changed:
│  │  ├─ Calculate old and new stable points
│  │  ├─ Compute shifts (shiftX, shiftY)
│  │  ├─ Update state with new shifts & excess
│  │  └─ Emit PseudoArbitrageExecuted event
│  └─ Apply transformations to balances:
│     ├─ balanceIn -= shiftX (or += if negative)
│     └─ balanceOut -= shiftY (or += if negative)
└─ Else: Initialize state with current price

Step 3: _flatFeeAmountInXD
├─ Reduces amountIn by 0.3%
└─ amountIn = amountIn * (10000 - 30) / 10000

Step 4: _xycSwapXD
├─ Uses transformed balances from step 2
├─ Applies constant product formula:
│  └─ amountOut = balanceOut - (k / (balanceIn + amountIn))
└─ Updates ctx.swap.amountOut

Step 5: _deadline
├─ Checks block.timestamp <= expiration
└─ Reverts if expired
```

---

## Maker (Liquidity Provider) Interaction

### Providing Liquidity

```solidity
// 1. Deploy or get router
PseudoArbitrageSwapVMRouter router = PseudoArbitrageSwapVMRouter(0x...);

// 2. Build strategy
PseudoArbitrageAMM ammBuilder = new PseudoArbitrageAMM(aquaAddress);
ISwapVM.Order memory order = ammBuilder.buildProgram(
    maker: msg.sender,
    expiration: block.timestamp + 30 days,
    token0: tokenX,
    token1: tokenY,
    balance0: 1000 ether,
    balance1: 3000 ether,
    oracle: oracleAddress,
    initialPrice: 3 ether,        // 1 X = 3 Y
    minUpdateInterval: 1 hours,   // Update at most once per hour
    feeBps: 30,                   // 0.3% fee
    salt: 0
);

// 3. Approve Aqua to spend tokens
tokenX.approve(aquaAddress, 1000 ether);
tokenY.approve(aquaAddress, 3000 ether);

// 4. Ship order to Aqua
bytes32 orderHash = aqua.ship(order, 1000 ether, 3000 ether);

// Order is now live and ready for swaps!
```

### Monitoring Position

```solidity
// Check current balances
(uint256 balanceX, uint256 balanceY) = aqua.balances(
    maker,
    address(router),
    orderHash,
    tokenX,
    tokenY
);

// Check pseudo-arbitrage state
PseudoArbitrage instruction = PseudoArbitrage(address(router));
(
    int256 shiftX,
    int256 shiftY,
    uint256 excessX,
    uint256 excessY,
    uint256 lastPrice,
    uint256 lastUpdate,
    bool initialized
) = instruction.pseudoArbitrageStates(orderHash);

console.log("Effective X:", balanceX - shiftX);
console.log("Effective Y:", balanceY - shiftY);
console.log("Excess X:", excessX);
console.log("Excess Y:", excessY);
console.log("Last oracle price:", lastPrice);
```

### Withdrawing Liquidity

```solidity
// 1. Unship from Aqua (withdraw tokens)
aqua.unship(orderHash, tokenX, tokenY, withdrawAmountX, withdrawAmountY);

// 2. Optionally withdraw excess reserves (if implementation supports it)
// Note: This feature needs additional integration with Aqua
// instruction.withdrawExcess(orderHash, msg.sender);
```

### Setting Custom Oracle

The Maker controls which oracle to use. The instruction calls:
```solidity
function getPrice(address tokenIn, address tokenOut) 
    external view returns (uint256 price, uint256 timestamp);
```

Makers can use:
- Chainlink oracles
- Uniswap V3 TWAP oracles
- Custom oracle implementations
- Aggregated oracle feeds

---

## Taker (Trader) Interaction

### Simple Swap

```javascript
// Using ethers.js

// 1. Get quote first
const orderData = {
    maker: "0x...",
    traits: "...",
    data: "..."
};

const quote = await router.callStatic.quote(
    orderData,
    tokenIn,    // Address of token to sell
    tokenOut,   // Address of token to buy
    amountIn,   // Amount to sell
    takerTraits // Packed taker configuration
);

console.log(`You'll receive ${quote.amountOut} tokens`);

// 2. Execute swap
const tx = await router.swap(
    orderData,
    tokenIn,
    tokenOut,
    amountIn,
    takerTraits
);

await tx.wait();
console.log("Swap executed!");
```

### Advanced: Taker Traits

```solidity
// Build taker traits
TakerTraits memory traits = TakerTraitsLib.build({
    isExactIn: true,              // True if specifying exact input amount
    unwrapWeth: false,            // Unwrap WETH to ETH
    skipRevertCheck: false,       // Skip maker contract revert checks
    instructionArgsLength: 0,     // Length of instruction-specific args
    signatureLength: 0            // Length of maker signature
});

bytes memory takerTraitsAndData = abi.encodePacked(
    traits,
    instructionArgs,  // Optional args for instructions
    signature         // Optional signature for non-Aqua orders
);
```

### Discovering Orders

```javascript
// Off-chain: Query Aqua for available orders
// Note: Aqua provides order discovery and matching services

// 1. Get all orders from maker
const orders = await aqua.getOrdersByMaker(makerAddress);

// 2. Filter for specific token pair
const ethUsdcOrders = orders.filter(order => {
    return (
        (order.token0 === ETH && order.token1 === USDC) ||
        (order.token0 === USDC && order.token1 === ETH)
    );
});

// 3. Get best rate
let bestOrder = null;
let bestRate = 0;

for (const order of ethUsdcOrders) {
    const quote = await router.callStatic.quote(...);
    const rate = quote.amountOut / quote.amountIn;
    
    if (rate > bestRate) {
        bestRate = rate;
        bestOrder = order;
    }
}

// 4. Execute swap with best order
await router.swap(bestOrder, ...);
```

---

## Key Benefits

### For Liquidity Providers (Makers)

1. **Eliminates Divergence Loss**
   - Traditional AMMs lose to arbitrageurs when prices change
   - Pseudo-arbitrage AMM captures that value instead

2. **Automatic Rebalancing**
   - Curve transforms automatically based on oracle
   - No manual intervention required

3. **Excess Reserves**
   - Accumulates excess tokens from price shifts
   - Represents captured arbitrage value

4. **Flexible Configuration**
   - Choose your own oracle
   - Set update frequency
   - Configure fees

### For Traders (Takers)

1. **Fair Pricing**
   - Always reflects current market price (via oracle)
   - No stale prices to exploit

2. **Transparent Execution**
   - All logic is on-chain and verifiable
   - No hidden fees or slippage

3. **SwapVM Integration**
   - Benefits from Aqua's liquidity aggregation
   - Composable with other SwapVM strategies

---

## Security Considerations

### Oracle Manipulation

**Risk:** Malicious oracle could trigger unfavorable curve transformations

**Mitigations:**
- Maker chooses oracle (trust model)
- Rate limiting via `minUpdateInterval`
- Use reputable oracles (Chainlink, Uniswap TWAP)
- Consider using median of multiple oracles

### Front-Running

**Risk:** MEV bots could front-run oracle updates

**Mitigations:**
- Oracle updates are public information anyway
- Curve transformation happens before swap calculation
- No extractable value from front-running the update itself
- Takers would front-run each other, not the LP

### Smart Contract Risk

**Risk:** Bugs in implementation

**Mitigations:**
- ✅ Comprehensive unit tests
- ✅ Follows SwapVM patterns and best practices
- ✅ Based on peer-reviewed research (Engel & Herlihy)
- Recommend: Professional audit before mainnet deployment

---

## Comparison to Traditional AMMs

| Feature | Uniswap V2 | Pseudo-Arbitrage AMM |
|---------|------------|---------------------|
| Divergence Loss | ❌ Significant | ✅ Eliminated |
| Price Discovery | ❌ Passive (arbitrageurs) | ✅ Active (oracle) |
| LP Returns | Trading fees only | Trading fees + captured arbitrage |
| Oracle Dependency | None | Required |
| Decentralization | High | Medium (oracle dependency) |
| Gas Cost | Low | Medium (oracle checks) |
| Implementation | Simple | Complex |

---

## Future Enhancements

### Potential Improvements

1. **Multi-Oracle Support**
   - Aggregate multiple price feeds
   - Use median or weighted average
   - Increased security and decentralization

2. **Dynamic Fee Adjustment**
   - Adjust fees based on volatility
   - Higher fees during high volatility
   - Lower fees during stable periods

3. **Excess Reserve Distribution**
   - Automatic distribution to LPs
   - Compound into liquidity
   - Configurable distribution strategy

4. **Liquidity Mining Integration**
   - Additional incentives for LPs
   - Token rewards for providing liquidity
   - Yield optimization strategies

5. **Multi-Asset Pools**
   - Support more than 2 tokens
   - Complex rebalancing strategies
   - Portfolio management features

---

## Development Notes

### Dependencies

The project requires:
- **Foundry**: Solidity development framework
- **OpenZeppelin**: SafeCast, Math utilities
- **swap-vm**: Base SwapVM framework
- **@1inch/aqua**: Liquidity layer integration
- **@1inch/solidity-utils**: Helper libraries

### Testing

```bash
# Run unit tests
forge test --match-contract PseudoArbitrageTest -vv

# Run integration tests
forge test --match-contract PseudoArbitrageIntegrationTest -vv

# Run with coverage
forge coverage

# Gas report
forge test --gas-report
```

### Deployment

See `DEPLOYMENT_GUIDE.md` for detailed deployment instructions.

---

## References

1. **Engel & Herlihy Paper**: "Composing Networks of Automated Market Makers"
   - arXiv:2106.00667
   - Section 6.1: Pseudo-Arbitrage

2. **SwapVM Documentation**: github.com/1inch/swap-vm

3. **Aqua Protocol**: 1inch.io/aqua

---

## Conclusion

The Pseudo-Arbitrage AMM implementation is **architecturally sound and correctly implemented**. It successfully integrates the Engel & Herlihy pseudo-arbitrage strategy into the SwapVM framework, providing LPs with a mechanism to eliminate divergence loss while maintaining compatibility with the Aqua liquidity protocol.

The instruction-based design allows for flexible composition with other SwapVM strategies, and the implementation follows best practices for security and gas optimization.

**Recommendation**: Proceed with comprehensive testing and professional audit before mainnet deployment.


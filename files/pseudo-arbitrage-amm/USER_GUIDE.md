# Pseudo-Arbitrage AMM User Guide

## Table of Contents

1. [Introduction](#introduction)
2. [For Liquidity Providers (Makers)](#for-liquidity-providers-makers)
3. [For Traders (Takers)](#for-traders-takers)
4. [Example Scenarios](#example-scenarios)
5. [FAQ](#faq)
6. [Troubleshooting](#troubleshooting)

---

## Introduction

### What is a Pseudo-Arbitrage AMM?

A Pseudo-Arbitrage AMM is an automated market maker that **eliminates impermanent loss** (divergence loss) by using oracle price feeds to automatically rebalance its pricing curve.

### Traditional AMM Problem

In a traditional AMM like Uniswap:
1. You provide liquidity (e.g., 1 ETH + 3000 USDC)
2. Market price of ETH changes (e.g., to $3300)
3. Your AMM still prices ETH at $3000
4. Arbitrageurs buy cheap ETH from you and sell it elsewhere
5. **You lose money** (impermanent loss)

### Pseudo-Arbitrage Solution

In a Pseudo-Arbitrage AMM:
1. You provide liquidity (e.g., 1 ETH + 3000 USDC)
2. Market price changes to $3300 (detected via oracle)
3. **AMM automatically adjusts** its curve to price ETH at $3300
4. No arbitrage opportunity exists
5. **You keep the value** that would have been lost

### Key Concepts

- **Maker / Liquidity Provider (LP)**: Someone who deposits tokens to provide liquidity
- **Taker / Trader**: Someone who swaps tokens using the liquidity
- **Oracle**: A trusted price feed (e.g., Chainlink, Uniswap TWAP)
- **Curve Transformation**: Mathematical adjustment of the pricing curve
- **Excess Reserves**: Tokens captured that represent prevented impermanent loss

---

## For Liquidity Providers (Makers)

### Prerequisites

1. **Tokens**: You need both tokens of the pair you want to provide liquidity for
2. **Wallet**: MetaMask or similar Web3 wallet
3. **Oracle Address**: Address of a price oracle for your token pair
4. **Gas Fees**: ETH (or native token) for transaction fees

### Step-by-Step: Providing Liquidity

#### Step 1: Prepare Your Tokens

```javascript
// Example: Providing liquidity for ETH/USDC pair

const tokenA = "0x..."; // WETH address
const tokenB = "0x..."; // USDC address

const amountA = ethers.utils.parseEther("10");      // 10 ETH
const amountB = ethers.utils.parseUnits("30000", 6); // 30,000 USDC
```

#### Step 2: Choose an Oracle

Select a reputable price oracle:

```javascript
// Option 1: Chainlink (recommended)
const oracle = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419"; // ETH/USD Chainlink

// Option 2: Uniswap V3 TWAP
const oracle = "0x..."; // Uniswap V3 TWAP oracle address

// Option 3: Custom oracle (ensure it implements the required interface)
const oracle = "0x..."; // Your oracle address
```

**Oracle Interface Required:**
```solidity
interface IPriceOracle {
    function getPrice(address tokenIn, address tokenOut) 
        external view returns (uint256 price, uint256 timestamp);
}
```

#### Step 3: Configure Your Strategy

```javascript
const config = {
    maker: yourAddress,
    expiration: Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60), // 30 days
    token0: tokenA,
    token1: tokenB,
    balance0: amountA,
    balance1: amountB,
    oracle: oracleAddress,
    initialPrice: ethers.utils.parseEther("3000"), // 1 ETH = 3000 USDC
    minUpdateInterval: 3600, // 1 hour (in seconds)
    feeBps: 30, // 0.3% fee (30 basis points)
    salt: 0 // Unique identifier (optional)
};
```

**Configuration Parameters:**

- **expiration**: When your order expires (Unix timestamp)
- **initialPrice**: Current market price (scaled by 1e18)
  - For ETH/USDC at $3000: `3000 * 1e18`
  - For USDC/ETH: `1/3000 * 1e18`
- **minUpdateInterval**: Minimum seconds between oracle updates
  - Prevents excessive gas costs
  - Recommended: 1-4 hours (3600-14400 seconds)
- **feeBps**: Trading fee in basis points
  - 30 = 0.3% (like Uniswap)
  - 100 = 1%
  - Maximum: 1000 (10%)

#### Step 4: Build the Order

```javascript
// Get the AMM builder contract
const ammBuilder = await ethers.getContractAt(
    "PseudoArbitrageAMM",
    ammBuilderAddress
);

// Build the order
const order = await ammBuilder.buildProgram(
    config.maker,
    config.expiration,
    config.token0,
    config.token1,
    config.balance0,
    config.balance1,
    config.oracle,
    config.initialPrice,
    config.minUpdateInterval,
    config.feeBps,
    config.salt
);
```

#### Step 5: Approve and Ship to Aqua

```javascript
// Approve Aqua to spend your tokens
const aquaAddress = "0x..."; // Aqua contract address

await tokenA.approve(aquaAddress, amountA);
await tokenB.approve(aquaAddress, amountB);

// Ship the order to Aqua
const aqua = await ethers.getContractAt("Aqua", aquaAddress);
const tx = await aqua.ship(order, amountA, amountB);
const receipt = await tx.wait();

// Get order hash from event
const orderHash = receipt.events.find(e => e.event === "OrderShipped").args.orderHash;

console.log("✅ Liquidity provided! Order hash:", orderHash);
```

### Monitoring Your Position

#### Check Balances

```javascript
// Get current token balances in the pool
const [balanceA, balanceB] = await aqua.balances(
    yourAddress,
    routerAddress,
    orderHash,
    tokenA,
    tokenB
);

console.log("Balance A:", ethers.utils.formatEther(balanceA));
console.log("Balance B:", ethers.utils.formatUnits(balanceB, 6));
```

#### Check Pseudo-Arbitrage State

```javascript
const router = await ethers.getContractAt(
    "PseudoArbitrageSwapVMRouter",
    routerAddress
);

const state = await router.pseudoArbitrageStates(orderHash);

console.log("Current State:");
console.log("- Shift X:", state.shiftX.toString());
console.log("- Shift Y:", state.shiftY.toString());
console.log("- Excess X:", ethers.utils.formatEther(state.excessX));
console.log("- Excess Y:", ethers.utils.formatUnits(state.excessY, 6));
console.log("- Last Price:", ethers.utils.formatEther(state.lastMarketPrice));
console.log("- Last Update:", new Date(state.lastUpdateTime * 1000));
console.log("- Initialized:", state.initialized);
```

#### Calculate Effective Balances

The "effective" balances are what traders see:

```javascript
const effectiveBalanceA = balanceA.sub(state.shiftX);
const effectiveBalanceB = balanceB.sub(state.shiftY);

console.log("Effective Balance A:", ethers.utils.formatEther(effectiveBalanceA));
console.log("Effective Balance B:", ethers.utils.formatUnits(effectiveBalanceB, 6));
```

#### Calculate Your Total Value

```javascript
// Get current market price
const currentPrice = await oracle.getPrice(tokenA, tokenB);

// Calculate total value in terms of token A
const valueInA = balanceA.add(
    balanceB.mul(ethers.utils.parseEther("1")).div(currentPrice)
);

console.log("Total Value (in token A):", ethers.utils.formatEther(valueInA));

// Calculate total value in USD (if token B is USDC)
const valueInUSD = balanceB.add(
    balanceA.mul(currentPrice).div(ethers.utils.parseEther("1"))
);

console.log("Total Value (in USD):", ethers.utils.formatUnits(valueInUSD, 6));
```

### Withdrawing Liquidity

#### Full Withdrawal

```javascript
// Unship (withdraw) all liquidity
const tx = await aqua.unship(
    orderHash,
    tokenA,
    tokenB,
    balanceA, // Withdraw all of token A
    balanceB  // Withdraw all of token B
);

await tx.wait();
console.log("✅ Liquidity withdrawn!");
```

#### Partial Withdrawal

```javascript
// Withdraw 50% of liquidity
const withdrawAmountA = balanceA.div(2);
const withdrawAmountB = balanceB.div(2);

const tx = await aqua.unship(
    orderHash,
    tokenA,
    tokenB,
    withdrawAmountA,
    withdrawAmountB
);

await tx.wait();
console.log("✅ Partial withdrawal complete!");
```

### Adjusting Your Position

To change parameters (fees, oracle, etc.), you need to:
1. Withdraw liquidity
2. Create new order with new parameters
3. Provide liquidity again

```javascript
// 1. Withdraw
await aqua.unship(orderHash, tokenA, tokenB, balanceA, balanceB);

// 2. Create new order with different fee
const newConfig = { ...config, feeBps: 50 }; // Change to 0.5%
const newOrder = await ammBuilder.buildProgram(/* new config */);

// 3. Provide liquidity again
await aqua.ship(newOrder, amountA, amountB);
```

### Best Practices for LPs

#### 1. Choose a Reliable Oracle

✅ **Good choices:**
- Chainlink for major pairs (ETH/USD, BTC/USD, etc.)
- Uniswap V3 TWAP for other pairs with good liquidity
- Aggregated oracles (median of multiple sources)

❌ **Avoid:**
- Untested or unaudited oracles
- Single low-liquidity DEX as source
- Oracles you don't control (unless reputable)

#### 2. Set Appropriate Update Intervals

- **High volatility pairs** (e.g., small cap tokens): 15-30 minutes
- **Medium volatility pairs** (e.g., ETH): 1-2 hours
- **Stable pairs** (e.g., USDC/DAI): 4-24 hours

Too frequent = higher gas costs
Too infrequent = may miss price changes

#### 3. Fee Configuration

| Pair Type | Recommended Fee |
|-----------|----------------|
| Stablecoins (USDC/DAI) | 0.01% - 0.05% |
| Major pairs (ETH/USDC) | 0.3% - 0.5% |
| Volatile pairs | 0.5% - 1% |
| Very volatile/risky | 1% - 3% |

#### 4. Monitor Regularly

- Check your position daily
- Watch for large price movements
- Verify oracle is updating correctly
- Monitor excess reserves accumulation

#### 5. Risk Management

- **Diversify**: Don't put all capital in one pair
- **Start small**: Test with small amounts first
- **Set expiration**: Don't leave orders open indefinitely
- **Emergency exit**: Be prepared to withdraw if needed

---

## For Traders (Takers)

### Prerequisites

1. **Wallet**: MetaMask or similar Web3 wallet
2. **Tokens**: The token you want to swap FROM
3. **Gas Fees**: ETH (or native token) for transaction fees

### Step-by-Step: Swapping Tokens

#### Step 1: Find Available Orders

```javascript
// Option 1: Query Aqua for orders
const aqua = await ethers.getContractAt("Aqua", aquaAddress);
const orders = await aqua.getOrdersByTokenPair(tokenIn, tokenOut);

// Option 2: Use order hash if you already know it
const orderHash = "0x...";
```

#### Step 2: Get a Quote

Before executing a swap, get a quote to see what you'll receive:

```javascript
const router = await ethers.getContractAt(
    "PseudoArbitrageSwapVMRouter",
    routerAddress
);

// Build taker traits
const takerTraits = {
    isExactIn: true,              // You're specifying exact input amount
    unwrapWeth: false,            // Set true if you want ETH instead of WETH
    skipRevertCheck: false,
    instructionArgsLength: 0,
    signatureLength: 0
};

// Encode taker data
const takerData = ethers.utils.solidityPack(
    ["uint256"],
    [takerTraits] // Simplified, actual encoding is more complex
);

// Get quote (view call, no gas used)
const [amountInQuote, amountOutQuote] = await router.callStatic.quote(
    order,
    tokenIn,      // Address of token you're selling
    tokenOut,     // Address of token you're buying
    amountIn,     // Amount you're selling
    takerData
);

console.log("You'll receive:", ethers.utils.formatUnits(amountOutQuote, decimals));
```

#### Step 3: Calculate Expected Output

```javascript
// Calculate effective price
const effectivePrice = amountOutQuote.mul(ethers.constants.WeiPerEther).div(amountInQuote);
console.log("Effective Price:", ethers.utils.formatEther(effectivePrice));

// Compare to market price (from oracle)
const marketPrice = await oracle.getPrice(tokenIn, tokenOut);
const priceImpact = effectivePrice.sub(marketPrice).mul(10000).div(marketPrice);
console.log("Price Impact:", priceImpact.toString(), "bps");

// Calculate fees
const feeAmount = amountIn.sub(amountInQuote);
const feePercent = feeAmount.mul(10000).div(amountIn);
console.log("Fee:", ethers.utils.formatEther(feeAmount), `(${feePercent/100}%)`);
```

#### Step 4: Execute the Swap

```javascript
// Approve router to spend your tokens
const tokenInContract = await ethers.getContractAt("IERC20", tokenIn);
await tokenInContract.approve(routerAddress, amountIn);

// Execute swap
const tx = await router.swap(
    order,
    tokenIn,
    tokenOut,
    amountIn,
    takerData,
    {
        gasLimit: 500000 // Adjust as needed
    }
);

console.log("Transaction sent:", tx.hash);

// Wait for confirmation
const receipt = await tx.wait();
console.log("✅ Swap successful!");

// Get actual amounts from event
const swapEvent = receipt.events.find(e => e.event === "Swapped");
const actualAmountOut = swapEvent.args.amountOut;

console.log("Received:", ethers.utils.formatUnits(actualAmountOut, decimals));
```

### Advanced: Slippage Protection

```javascript
// Set maximum slippage (e.g., 0.5%)
const maxSlippageBps = 50; // 0.5%

// Calculate minimum acceptable output
const minAmountOut = amountOutQuote.mul(10000 - maxSlippageBps).div(10000);

// Use TakerTraits to enforce minimum
// (Implementation depends on SwapVM version)
const traitsWithSlippage = {
    ...takerTraits,
    minAmountOut: minAmountOut
};

// Execute with slippage protection
const tx = await router.swap(
    order,
    tokenIn,
    tokenOut,
    amountIn,
    encodeTraits(traitsWithSlippage)
);
```

### Comparing Multiple Orders

If multiple orders exist for the same pair:

```javascript
async function findBestOrder(orders, tokenIn, tokenOut, amountIn) {
    let bestOrder = null;
    let bestOutput = ethers.BigNumber.from(0);
    
    for (const order of orders) {
        try {
            const [, amountOut] = await router.callStatic.quote(
                order,
                tokenIn,
                tokenOut,
                amountIn,
                takerData
            );
            
            if (amountOut.gt(bestOutput)) {
                bestOutput = amountOut;
                bestOrder = order;
            }
        } catch (e) {
            // Order might be expired or invalid, skip
            continue;
        }
    }
    
    return { order: bestOrder, amountOut: bestOutput };
}

// Usage
const { order, amountOut } = await findBestOrder(
    orders,
    tokenIn,
    tokenOut,
    amountIn
);

console.log("Best order will give you:", ethers.utils.formatUnits(amountOut, decimals));
```

### Understanding the Price

The swap price comes from:

1. **Oracle Price**: Current market price
2. **Curve Transformation**: Applied by pseudo-arbitrage instruction
3. **Trading Fee**: Deducted from your input
4. **Slippage**: Impact of your trade size on the curve

```javascript
// Get all components
const state = await router.pseudoArbitrageStates(orderHash);
const [balanceIn, balanceOut] = await aqua.balances(/*...*/);

// Effective balances (after transformation)
const effectiveIn = balanceIn.sub(state.shiftX);
const effectiveOut = balanceOut.sub(state.shiftY);

// Current AMM price
const ammPrice = effectiveOut.mul(ethers.constants.WeiPerEther).div(effectiveIn);

// Oracle price
const oraclePrice = state.lastMarketPrice;

console.log("AMM Price:", ethers.utils.formatEther(ammPrice));
console.log("Oracle Price:", ethers.utils.formatEther(oraclePrice));
console.log("Difference:", ammPrice.sub(oraclePrice).toString());
```

### Best Practices for Traders

#### 1. Always Get a Quote First

Never blindly execute a swap. Always check the expected output:

```javascript
// ✅ Good
const quote = await router.callStatic.quote(/*...*/);
console.log("Will receive:", quote.amountOut);
if (isAcceptable(quote.amountOut)) {
    await router.swap(/*...*/);
}

// ❌ Bad
await router.swap(/*...*/); // No idea what you'll get!
```

#### 2. Set Reasonable Slippage

- For stable pairs: 0.1% - 0.5%
- For normal pairs: 0.5% - 1%
- For volatile pairs: 1% - 3%

#### 3. Check Order Validity

```javascript
// Check if order is expired
if (order.expiration < Date.now() / 1000) {
    console.log("❌ Order expired!");
    return;
}

// Check if order has enough liquidity
const [balanceIn, balanceOut] = await aqua.balances(/*...*/);
if (balanceOut.lt(expectedOutput)) {
    console.log("❌ Insufficient liquidity!");
    return;
}
```

#### 4. Compare to Other Sources

Compare prices with:
- Uniswap
- Other DEXes
- Centralized exchanges

```javascript
// Get Uniswap price for comparison
const uniswapRouter = await ethers.getContractAt("IUniswapV2Router", uniswapAddress);
const uniswapAmounts = await uniswapRouter.getAmountsOut(amountIn, [tokenIn, tokenOut]);
const uniswapOutput = uniswapAmounts[1];

console.log("Pseudo-Arbitrage AMM:", ethers.utils.formatUnits(amountOut, decimals));
console.log("Uniswap:", ethers.utils.formatUnits(uniswapOutput, decimals));

if (amountOut.gt(uniswapOutput)) {
    console.log("✅ Better rate than Uniswap!");
} else {
    console.log("ℹ️ Uniswap has better rate");
}
```

#### 5. Consider Gas Costs

Pseudo-arbitrage AMM may use more gas than simple AMMs:

```javascript
// Estimate gas
const gasEstimate = await router.estimateGas.swap(/*...*/);
const gasPrice = await provider.getGasPrice();
const gasCost = gasEstimate.mul(gasPrice);

console.log("Estimated gas:", gasEstimate.toString());
console.log("Gas cost (ETH):", ethers.utils.formatEther(gasCost));

// Calculate if trade is worth it
const outputValue = amountOut.mul(outputTokenPrice); // in USD
const gasCostUSD = gasCost.mul(ethPrice); // in USD

if (outputValue.sub(inputValue).lt(gasCostUSD)) {
    console.log("⚠️ Trade not profitable after gas!");
}
```

---

## Example Scenarios

### Scenario 1: Providing Liquidity for ETH/USDC

**Goal**: Provide 10 ETH + 30,000 USDC liquidity

**Configuration**:
- Oracle: Chainlink ETH/USD
- Update interval: 1 hour
- Fee: 0.3%
- Expiration: 30 days

**Expected outcomes**:
- Earn 0.3% on all swaps
- Avoid impermanent loss from price changes
- Accumulate excess reserves if price is volatile

**Step-by-step**:

```javascript
// 1. Setup
const ethAmount = ethers.utils.parseEther("10");
const usdcAmount = ethers.utils.parseUnits("30000", 6);
const chainlinkETHUSD = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419";

// 2. Build order
const order = await ammBuilder.buildProgram(
    myAddress,
    Math.floor(Date.now()/1000) + 30*24*60*60, // 30 days
    WETH,
    USDC,
    ethAmount,
    usdcAmount,
    chainlinkETHUSD,
    ethers.utils.parseEther("3000"), // $3000/ETH
    3600, // 1 hour
    30, // 0.3%
    0
);

// 3. Approve and ship
await weth.approve(aqua.address, ethAmount);
await usdc.approve(aqua.address, usdcAmount);
await aqua.ship(order, ethAmount, usdcAmount);

console.log("✅ Liquidity provided!");

// 4. Monitor daily
setInterval(async () => {
    const state = await router.pseudoArbitrageStates(orderHash);
    console.log("Last price:", ethers.utils.formatEther(state.lastMarketPrice));
    console.log("Excess ETH:", ethers.utils.formatEther(state.excessX));
    console.log("Excess USDC:", ethers.utils.formatUnits(state.excessY, 6));
}, 24 * 60 * 60 * 1000); // Daily
```

**After 30 days**:
- Earned trading fees: ~$100 (assuming $10M volume, 0.01% market share)
- Avoided impermanent loss: ~$200 (if ETH price moved 20%)
- Total benefit: ~$300 vs traditional AMM

### Scenario 2: Swapping 1 ETH for USDC

**Goal**: Get best USDC price for 1 ETH

**Steps**:

```javascript
// 1. Find all ETH/USDC orders
const orders = await findOrdersForPair(WETH, USDC);
console.log(`Found ${orders.length} orders`);

// 2. Get quote from each
const ethAmount = ethers.utils.parseEther("1");
const quotes = await Promise.all(
    orders.map(order =>
        router.callStatic.quote(order, WETH, USDC, ethAmount, takerData)
            .then(([, out]) => ({ order, out }))
            .catch(() => null)
    )
);

// 3. Find best
const validQuotes = quotes.filter(q => q !== null);
const best = validQuotes.reduce((best, current) =>
    current.out.gt(best.out) ? current : best
);

console.log(`Best quote: ${ethers.utils.formatUnits(best.out, 6)} USDC`);

// 4. Compare to Uniswap
const uniOut = await getUniswapQuote(WETH, USDC, ethAmount);
console.log(`Uniswap: ${ethers.utils.formatUnits(uniOut, 6)} USDC`);

if (best.out.gt(uniOut)) {
    console.log("✅ Pseudo-Arbitrage AMM is better!");
    
    // 5. Execute swap
    await weth.approve(router.address, ethAmount);
    const tx = await router.swap(
        best.order,
        WETH,
        USDC,
        ethAmount,
        takerData
    );
    
    await tx.wait();
    console.log("✅ Swap complete!");
} else {
    console.log("ℹ️ Use Uniswap instead");
}
```

### Scenario 3: Price Changes and Curve Transformation

**Situation**: ETH price increases from $3000 to $3300

**What happens**:

```javascript
// Before price change
// Pool: 10 ETH + 30,000 USDC
// Oracle price: $3000/ETH
// Shifts: shiftX=0, shiftY=0
// Effective balances: 10 ETH, 30,000 USDC

// Oracle updates to $3300
// Next swap triggers transformation:

// 1. Calculate old stable point
const k = 10 * 30000 = 300000;
const oldStableX = sqrt(k / 3000) ≈ 10 ETH;
const oldStableY = sqrt(k * 3000) ≈ 30000 USDC;

// 2. Calculate new stable point  
const newStableX = sqrt(k / 3300) ≈ 9.53 ETH;
const newStableY = sqrt(k * 3300) ≈ 31464 USDC;

// 3. Calculate shifts
const shiftX = -(9.53 - 10) = 0.47 ETH; // Negative shift
const shiftY = 31464 - 30000 = 1464 USDC; // Positive shift

// 4. New effective balances
effectiveX = 10 - 0.47 = 9.53 ETH;
effectiveY = 30000 + 1464 = 31464 USDC;

// 5. Excess reserves
excessX = 0.47 ETH; // Locked, represents captured arbitrage value
excessY = 0 USDC;

// Traders now see pool at $3300/ETH price!
```

---

## FAQ

### For Liquidity Providers

**Q: How much can I earn?**
A: You earn from two sources:
1. Trading fees (e.g., 0.3% of each swap)
2. Captured arbitrage value (appears as excess reserves)

Total returns depend on volume and price volatility.

**Q: Is this safer than Uniswap?**
A: It eliminates impermanent loss, but adds oracle dependency risk. Choose reputable oracles.

**Q: What if the oracle fails?**
A: The AMM continues working with the last known price until the oracle recovers or you withdraw liquidity.

**Q: Can I change parameters after providing liquidity?**
A: No. You must withdraw and create a new order with new parameters.

**Q: What are excess reserves?**
A: Tokens that get "locked" during curve transformations. They represent the arbitrage value you captured that would have been lost to arbitrageurs in a traditional AMM.

**Q: Can I withdraw excess reserves?**
A: The current implementation doesn't support direct withdrawal of excess reserves. They remain locked in the contract. Future versions may add this feature.

**Q: What happens when my order expires?**
A: Traders can no longer swap against it. You can still withdraw your liquidity normally.

**Q: How do I choose an update interval?**
A: Balance between:
- Shorter interval = more accurate prices but higher gas costs
- Longer interval = lower gas but potential for stale prices
- Recommended: 1-4 hours for most pairs

### For Traders

**Q: Is this cheaper than Uniswap?**
A: Gas costs are similar or slightly higher. Compare the exchange rate to see if it's worth it.

**Q: How do I know if I'm getting a fair price?**
A: Compare the quoted price to:
1. The oracle price (should be close)
2. Uniswap/other DEXes
3. Centralized exchanges

**Q: What if the price changes between my quote and swap?**
A: Use slippage protection (minAmountOut parameter) to ensure you get at least your expected amount.

**Q: Can I be front-run?**
A: MEV bots can front-run any swap, but the oracle-based pricing reduces traditional arbitrage opportunities.

**Q: Why is the price slightly different from the oracle?**
A: Three reasons:
1. Trading fees are deducted
2. Your swap size impacts the curve (slippage)
3. Small rounding differences

### General

**Q: What happens if many people provide liquidity for the same pair?**
A: Each liquidity provider creates a separate order with their own parameters. Traders can choose the best one.

**Q: Is this audited?**
A: The code should be professionally audited before mainnet use. Currently, it's a proof of concept.

**Q: What networks is this deployed on?**
A: Check the deployment addresses in your project documentation. It can be deployed on any EVM-compatible network.

---

## Troubleshooting

### Common Errors

#### Error: "PseudoArbitrageShouldBeCalledBeforeSwap"

**Cause**: The pseudo-arbitrage instruction wasn't executed before the swap instruction.

**Solution**: This is a programming error in the order. The order builder should place pseudo-arbitrage instruction before the swap.

#### Error: "PseudoArbitrageUpdateTooFrequent"

**Cause**: Trying to update the oracle price too quickly.

**Solution**: Wait for the `minUpdateInterval` to pass. This is working as intended to prevent manipulation.

#### Error: "PseudoArbitrageInvalidPrice"

**Cause**: Oracle returned a zero or invalid price.

**Solution**:
1. Check if oracle is working correctly
2. Verify oracle address is correct
3. Ensure oracle supports your token pair

#### Error: "PseudoArbitrageOracleCallFailed"

**Cause**: Oracle contract reverted or doesn't implement the expected interface.

**Solution**:
1. Verify oracle address
2. Check oracle implements: `getPrice(address,address) returns (uint256,uint256)`
3. Ensure network connectivity

#### Error: "Insufficient liquidity"

**Cause**: The order doesn't have enough tokens to fulfill your swap.

**Solution**:
1. Reduce your swap amount
2. Find a different order with more liquidity
3. Split your swap across multiple orders

#### Error: "Expired"

**Cause**: The order has passed its expiration timestamp.

**Solution**: Find a different, non-expired order.

### Gas Issues

**High gas costs:**
- Try during low network usage times
- Increase gas price if transaction is stuck
- Consider if the swap is worth the gas cost

**Transaction fails with "out of gas":**
- Increase gas limit (try 500,000+)
- May indicate an error in the order program

### Price Discrepancies

**AMM price very different from market:**
- Check when the oracle was last updated
- Verify the oracle is for the correct pair
- Check if `minUpdateInterval` is too long

**Getting less than expected:**
- Check the trading fee (e.g., 0.3%)
- Consider slippage from your trade size
- Compare to the quote you received

### For Developers

**Compilation errors:**
- Ensure all dependencies are installed: `forge install`
- Check import paths match your setup
- Verify Solidity version (0.8.30)

**Test failures:**
- Check if oracle mock is properly configured
- Ensure timestamps are being warped correctly in tests
- Verify all contracts are deployed in correct order

---

## Additional Resources

- **SwapVM Documentation**: https://github.com/1inch/swap-vm
- **Aqua Protocol**: https://1inch.io/aqua
- **Engel & Herlihy Paper**: https://arxiv.org/abs/2106.00667
- **Architecture Documentation**: See `ARCHITECTURE.md`
- **Deployment Guide**: See `DEPLOYMENT_GUIDE.md`

---

## Support

For issues, questions, or contributions:
1. Check existing documentation
2. Review the code comments
3. Search for similar issues
4. Open a new issue with details

---

## License

See LICENSE file for details.


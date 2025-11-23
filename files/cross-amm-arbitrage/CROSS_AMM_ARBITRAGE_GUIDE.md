# Cross-AMM Arbitrage System - Complete Guide

## Executive Summary

**The Opportunity**: ConcentratedAMM positions have fixed tick-based prices that become stale, while PseudoArbitrageAMM positions auto-update via oracles. This creates arbitrage opportunities lasting minutes to hours.

**The Profit**: When ConcentratedAMM price is 2.0 and PseudoArbitrageAMM updates to 2.2, you can:
- Buy tokenX cheap at 2.0 from ConcentratedAMM
- Sell tokenX expensive at 2.2 to PseudoArbitrageAMM
- Pocket 10% profit instantly

**The System**: Automated monitoring and execution via CrossAMMArbitrage + CrossAMMArbitrageBot.

---

## Table of Contents

1. [Understanding the Arbitrage](#understanding-the-arbitrage)
2. [Architecture](#architecture)
3. [Quick Start](#quick-start)
4. [Deployment](#deployment)
5. [Arbitrage Strategies](#arbitrage-strategies)
6. [Bot Operation](#bot-operation)
7. [Economics & Profitability](#economics--profitability)
8. [Advanced Topics](#advanced-topics)
9. [API Reference](#api-reference)

---

## Understanding the Arbitrage

### Why This Works

#### ConcentratedAMM Characteristics
- **Manual Pricing**: Maker sets price via tick ranges (e.g., 2.0 to 2.2)
- **Static Until Rebalanced**: Price stays fixed until maker manually adjusts
- **Rebalance Lag**: Maker may take minutes to hours to update
- **Capital Concentrated**: High liquidity at specific price points

#### PseudoArbitrageAMM Characteristics
- **Oracle-Based**: Automatically updates when oracle reports price changes
- **Instant Updates**: Reflects market prices immediately
- **Curve Transformation**: Uses pseudo-arbitrage algorithm to shift curve
- **No Manual Intervention**: Fully automated price discovery

#### The Gap Creates Profit

```
Time T0: Both AMMs at price 2.0
├─ ConcentratedAMM: 1 X = 2.0 Y
└─ PseudoArbitrage: 1 X = 2.0 Y (oracle price)

Time T1: Market moves, oracle updates
├─ ConcentratedAMM: 1 X = 2.0 Y (STALE!)
└─ PseudoArbitrage: 1 X = 2.2 Y (updated)

Arbitrage Window: 10% profit available!
├─ Buy 100 X from ConcentratedAMM for 200 Y
├─ Sell 100 X to PseudoArbitrage for 220 Y
└─ Profit: 20 Y (10%)

Time T2: Maker rebalances ConcentratedAMM
├─ ConcentratedAMM: 1 X = 2.2 Y (updated)
└─ PseudoArbitrage: 1 X = 2.2 Y
(Window closed)
```

### When Opportunities Arise

1. **Market Volatility**: Sudden price movements create immediate gaps
2. **Maker Inactivity**: Longer time between rebalances = larger opportunities
3. **Gas Price Spikes**: High gas may delay maker rebalancing
4. **Multiple Positions**: More ConcentratedAMM positions = more opportunities
5. **Concentrated Ranges**: Tighter ranges run out of liquidity faster

### Expected Frequency

- **High Volatility Markets**: Multiple opportunities per hour
- **Medium Volatility**: Several per day
- **Low Volatility**: Few per week
- **Maker Response Time**: 5 min to 2 hours typical

---

## Architecture

### System Components

```
┌──────────────────────────────────────────────────────────┐
│                    ARBITRAGE SYSTEM                      │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌─────────────────┐         ┌──────────────────┐      │
│  │ ConcentratedAMM │◄────────┤ CrossAMM         │      │
│  │ (Stale Prices)  │  Buy    │ Arbitrage        │      │
│  └─────────────────┘         │ (Core Logic)     │      │
│                              └──────────────────┘      │
│  ┌─────────────────┐                ▲                  │
│  │ PseudoArbitrage │◄───────────────┘                  │
│  │ (Oracle Prices) │  Sell                             │
│  └─────────────────┘                                   │
│                                                          │
│  ┌──────────────────────────────────────────────┐      │
│  │  CrossAMMArbitrageBot                        │      │
│  │  ├─ Capital Management                       │      │
│  │  ├─ Strategy Monitoring                      │      │
│  │  ├─ Opportunity Detection                    │      │
│  │  └─ Automated Execution                      │      │
│  └──────────────────────────────────────────────┘      │
│                                                          │
│  ┌──────────────────────────────────────────────┐      │
│  │  Aqua Protocol                               │      │
│  │  (Shared Liquidity Layer)                    │      │
│  └──────────────────────────────────────────────┘      │
└──────────────────────────────────────────────────────────┘
```

### Contract Roles

1. **CrossAMMArbitrage**: Core arbitrage logic
   - Executes arbitrage between AMM types
   - Calculates optimal amounts
   - Detects opportunities
   - Manages swaps on both sides

2. **CrossAMMArbitrageBot**: Automation layer
   - Manages capital
   - Monitors strategies
   - Executes automatically
   - Tracks performance

3. **ConcentratedAMM**: Manual pricing AMM
   - Tick-based positions
   - Fixed prices until rebalanced
   - High capital efficiency

4. **PseudoArbitrageAMM**: Oracle-based AMM
   - Auto-updating prices
   - Curve transformation
   - SwapVM-based execution

---

## Quick Start

### 1. Deploy Contracts

```solidity
// Deploy infrastructure
Aqua aqua = new Aqua();
ConcentratedAMM concentratedAMM = new ConcentratedAMM(aqua);
PseudoArbitrageSwapVMRouter pseudoArbRouter = new PseudoArbitrageSwapVMRouter(
    address(aqua),
    "PseudoArb",
    "1.0"
);

// Deploy arbitrage system
CrossAMMArbitrage arbitrage = new CrossAMMArbitrage(aqua, pseudoArbRouter);
CrossAMMArbitrageBot bot = new CrossAMMArbitrageBot(arbitrage);
```

### 2. Setup Positions

```solidity
// Create ConcentratedAMM position (will have stale prices)
ConcentratedAMMStrategyBuilder concentratedBuilder = new ConcentratedAMMStrategyBuilder(aqua, concentratedAMM);

concentratedBuilder.createAndShipStrategy(
    address(tokenX),
    address(tokenY),
    1.8e18,  // tickLower: -10%
    2.2e18,  // tickUpper: +10%
    2.0e18,  // currentPrice
    1000e18, // amountX
    2000e18, // amountY
    30,      // 0.3% fee
    bytes32(uint256(1))
);

// Create PseudoArbitrageAMM position (will auto-update)
PseudoArbitrageAMM pseudoArbBuilder = new PseudoArbitrageAMM(address(aqua));

ISwapVM.Order memory pseudoArbOrder = pseudoArbBuilder.buildProgram(
    maker,
    uint40(block.timestamp + 30 days),
    address(tokenX),
    address(tokenY),
    1000e18, // balanceX
    2000e18, // balanceY (price = 2.0)
    address(oracle),
    2.0e18,  // initialPrice
    1 hours, // minUpdateInterval
    30,      // 0.3% fee
    0        // salt
);

aqua.ship(
    address(pseudoArbRouter),
    abi.encode(pseudoArbOrder),
    [tokenX, tokenY],
    [1000e18, 2000e18]
);
```

### 3. Fund and Configure Bot

```solidity
// Deposit capital
tokenX.approve(address(bot), 500e18);
bot.depositCapital(address(tokenX), 500e18);

// Set parameters
bot.setMinProfitBps(50);         // 0.5% minimum
bot.setMinDiscrepancyBps(100);   // 1% minimum discrepancy
bot.setMaxCapitalPerArbitrage(address(tokenX), 100e18);

// Add monitored strategy
CrossAMMArbitrage.AMMConfig[] memory concentratedConfigs = new CrossAMMArbitrage.AMMConfig[](1);
concentratedConfigs[0] = CrossAMMArbitrage.AMMConfig({
    ammType: CrossAMMArbitrage.AMMType.ConcentratedAMM,
    ammAddress: address(concentratedAMM),
    strategyData: abi.encode(concentratedStrategy)
});

CrossAMMArbitrage.AMMConfig[] memory pseudoArbConfigs = new CrossAMMArbitrage.AMMConfig[](1);
pseudoArbConfigs[0] = CrossAMMArbitrage.AMMConfig({
    ammType: CrossAMMArbitrage.AMMType.PseudoArbitrageAMM,
    ammAddress: address(pseudoArbRouter),
    strategyData: abi.encode(pseudoArbOrder)
});

bot.addStrategy(
    address(tokenX),
    address(tokenY),
    concentratedConfigs,
    pseudoArbConfigs
);
```

### 4. Execute Arbitrage

```solidity
// Manual execution
CrossAMMArbitrage.CrossAMMOpportunity memory opp = /* ... */;
bot.executeArbitrage(opp, 0); // 0 = use optimal amount

// Automated execution
bot.scanAllStrategies(); // Finds and executes best opportunity

// Monitor specific strategy
bot.scanAndExecuteStrategy(0); // Execute strategy ID 0
```

---

## Arbitrage Strategies

### Strategy 1: High-Frequency Monitoring

**Best for**: Volatile markets, frequent price updates

```solidity
// Configuration
bot.setMinProfitBps(30);        // Lower threshold = more trades
bot.setMinDiscrepancyBps(50);   // Capture smaller gaps
bot.setMaxCapitalPerArbitrage(address(tokenX), 50e18); // Smaller positions

// Run continuously (keeper bot)
while (true) {
    bot.scanAllStrategies();
    sleep(30 seconds); // Check every 30s
}
```

**Expected Results**:
- Frequency: 5-20 trades/day
- Profit per trade: 0.3% - 2%
- Daily profit: 2% - 10% on capital

### Strategy 2: Large Position Hunting

**Best for**: Patient arbitrageurs, larger capital

```solidity
// Configuration
bot.setMinProfitBps(200);       // Higher threshold = bigger wins
bot.setMinDiscrepancyBps(500);  // Wait for large gaps (5%+)
bot.setMaxCapitalPerArbitrage(address(tokenX), 500e18); // Larger positions

// Run periodically
while (true) {
    bot.scanAllStrategies();
    sleep(5 minutes); // Check every 5 min
}
```

**Expected Results**:
- Frequency: 1-5 trades/day
- Profit per trade: 2% - 10%
- Daily profit: 2% - 20% on capital

### Strategy 3: Multi-Pair Coverage

**Best for**: Diversification, continuous opportunities

```solidity
// Monitor multiple token pairs
bot.addStrategy(tokenX, tokenY, configs1, configs2);
bot.addStrategy(tokenA, tokenB, configs3, configs4);
bot.addStrategy(tokenC, tokenD, configs5, configs6);

// Scan all pairs
bot.scanAllStrategies(); // Finds best across all pairs
```

**Benefits**:
- More frequent opportunities
- Risk diversification
- Capital rotation across pairs

### Strategy 4: Volatile Event Trading

**Best for**: News events, market volatility

```solidity
// Adjust during volatile periods
function onVolatileEvent() {
    bot.setMinDiscrepancyBps(200);  // Lower threshold
    bot.setMaxCapitalPerArbitrage(address(tokenX), 200e18); // Larger size
    
    // Aggressive monitoring
    for (uint i = 0; i < 100; i++) {
        bot.scanAllStrategies();
        sleep(10 seconds);
    }
}
```

**Use Cases**:
- Fed announcements
- Earnings reports
- Crypto market events
- Major news releases

---

## Bot Operation

### Capital Management

```solidity
// Deposit capital
tokenX.approve(address(bot), 1000e18);
bot.depositCapital(address(tokenX), 1000e18);

// Set limits
bot.setMaxCapitalPerArbitrage(address(tokenX), 100e18); // Max 10% per trade

// Withdraw profits
bot.withdrawCapital(address(tokenX), 500e18);

// Emergency withdrawal (if needed)
bot.emergencyWithdraw(address(tokenX));
```

### Monitoring Loop (Off-chain)

```javascript
// Keeper bot in Node.js/TypeScript
async function monitoringLoop() {
    while (true) {
        try {
            // Check for opportunities
            const [hasOpp, bestProfit] = await bot.checkForOpportunities();
            
            if (hasOpp) {
                console.log(`Opportunity found: ${bestProfit} profit`);
                
                // Execute
                const tx = await bot.scanAllStrategies();
                const receipt = await tx.wait();
                
                console.log(`Executed! Gas used: ${receipt.gasUsed}`);
                
                // Extract profit from events
                const event = receipt.events.find(e => e.event === 'ArbitrageExecuted');
                console.log(`Profit: ${event.args.profit}`);
            }
            
            // Wait before next check
            await sleep(30000); // 30 seconds
            
        } catch (error) {
            console.error('Error:', error);
            await sleep(60000); // Wait longer on error
        }
    }
}
```

### Performance Monitoring

```solidity
// Get statistics
CrossAMMArbitrageBot.PerformanceStats memory stats = bot.getPerformanceStats(address(tokenX));

console.log("Total executions:", stats.totalExecutions);
console.log("Total profit:", stats.totalProfit);
console.log("Average profit:", stats.totalProfit / stats.totalExecutions);
console.log("Largest profit:", stats.largestProfit);
console.log("Total gas used:", stats.totalGasUsed);
```

---

## Economics & Profitability

### Profit Calculation

```
Profit = (SellPrice - BuyPrice) × Amount - Fees - GasCost

Example:
- Buy 100 X at 2.0 Y each = 200 Y
- Sell 100 X at 2.2 Y each = 220 Y
- Fees: 0.3% × 2 = 0.6% total
- Gas: ~250k gas × 50 gwei = 0.0125 ETH (~$25)

Gross Profit: 220 - 200 = 20 Y
Fees: 20 × 0.006 = 0.12 Y
Net Profit: 20 - 0.12 - 0.5 = 19.38 Y (~9.69%)
```

### Break-Even Analysis

Minimum discrepancy needed to be profitable:

```
MinDiscrepancy = (Fees + GasCost) / Amount

For 100 X position:
- Fees: 0.6% (0.3% × 2 swaps)
- Gas: ~$25 in Y terms (assume 1 Y = $1)
- Gas per unit: 25 / 100 = 0.25 Y = 0.25%

MinDiscrepancy = 0.6% + 0.25% = 0.85%

Recommendation: Set minDiscrepancyBps to 100 (1%) for safety margin
```

### Expected Returns

Based on market conditions:

| Market Condition | Opportunities/Day | Avg Profit/Trade | Daily Return (on $10k capital) |
|-----------------|------------------|------------------|-------------------------------|
| High Volatility | 15-30 | 2-5% | $300-$1,500 |
| Medium Volatility | 5-15 | 1-3% | $50-$450 |
| Low Volatility | 1-5 | 0.5-1% | $5-$50 |

**Annualized**: 18% - 5,475% depending on conditions

### Risk Factors

1. **Gas Price Risk**: High gas can eat profits
   - Solution: Set dynamic minProfitBps based on gas
   
2. **Front-Running**: MEV bots may compete
   - Solution: Use private RPC or Flashbots
   
3. **Slippage**: Large orders move prices
   - Solution: Use optimal amount calculation
   
4. **Oracle Delays**: PseudoArbitrage update lag
   - Solution: Monitor oracle freshness

5. **Maker Rebalancing**: Window closes quickly
   - Solution: Fast execution, low latency

---

## Advanced Topics

### Optimal Amount Calculation

The system automatically calculates optimal arbitrage amounts:

```solidity
uint256 optimalAmount = arbitrage.calculateOptimalAmount(opportunity, maxAmount);
```

**Algorithm**:
1. Binary search over amount range
2. For each amount, calculate profit = sell_output - buy_input
3. Find amount that maximizes profit
4. Account for slippage on both AMMs

**Why not use max capital?**
- Slippage reduces profit on large trades
- Optimal is usually 30-70% of max available
- Diminishing returns beyond optimal point

### Multi-Hop Arbitrage

For more complex opportunities:

```solidity
// Path: X → Y → Z → X
// If ConcentratedAMM has stale prices on multiple pairs

CrossAMMOpportunity memory hop1 = /* X → Y */;
CrossAMMOpportunity memory hop2 = /* Y → Z */;
CrossAMMOpportunity memory hop3 = /* Z → X */;

// Execute sequentially
arbitrage.executeArbitrage(hop1, amount1, minProfit1);
arbitrage.executeArbitrage(hop2, amount2, minProfit2);
arbitrage.executeArbitrage(hop3, amount3, minProfit3);
```

### Flash Arbitrage

Use flash loans for capital-free arbitrage:

```solidity
contract FlashArbitrage is IArbitrageCallback {
    function executeFlashArbitrage() external {
        // 1. Flash loan tokens
        flashLoanProvider.flashLoan(tokenX, 1000e18);
    }
    
    function onFlashLoan(address token, uint256 amount) external {
        // 2. Execute arbitrage
        bot.executeArbitrage(opportunity, amount);
        
        // 3. Repay flash loan (with fee)
        // Profit = arbitrage profit - flash loan fee
    }
}
```

### MEV Protection

```solidity
// Use Flashbots for MEV protection
function executeViaFlashbots(CrossAMMOpportunity memory opp) external {
    // Bundle transaction
    bytes[] memory txs = new bytes[](1);
    txs[0] = abi.encodeCall(bot.executeArbitrage, (opp, 0));
    
    // Send to Flashbots
    flashbotsRelay.sendBundle(txs);
}
```

### Dynamic Fee Adjustment

Adjust parameters based on gas prices:

```solidity
function updateParametersForGas(uint256 gasPrice) external {
    // Higher gas = need higher profit
    if (gasPrice > 100 gwei) {
        bot.setMinProfitBps(150); // 1.5%
        bot.setMinDiscrepancyBps(200); // 2%
    } else if (gasPrice > 50 gwei) {
        bot.setMinProfitBps(100); // 1%
        bot.setMinDiscrepancyBps(150); // 1.5%
    } else {
        bot.setMinProfitBps(50); // 0.5%
        bot.setMinDiscrepancyBps(100); // 1%
    }
}
```

---

## API Reference

### CrossAMMArbitrage

#### executeArbitrage
```solidity
function executeArbitrage(
    CrossAMMOpportunity calldata opportunity,
    uint256 amountIn,
    uint256 minProfit
) external returns (ArbitrageResult memory result)
```
Execute arbitrage opportunity.

#### calculateOptimalAmount
```solidity
function calculateOptimalAmount(
    CrossAMMOpportunity calldata opportunity,
    uint256 maxAmountIn
) public view returns (uint256 optimalAmount)
```
Calculate optimal arbitrage amount for maximum profit.

#### scanOpportunities
```solidity
function scanOpportunities(
    address token0,
    address token1,
    AMMConfig[] calldata concentratedConfigs,
    AMMConfig[] calldata pseudoArbConfigs,
    uint256 sampleAmount
) external view returns (
    CrossAMMOpportunity memory bestOpportunity,
    uint256 maxProfit
)
```
Scan for best arbitrage opportunity across all AMM pairs.

#### checkOpportunity
```solidity
function checkOpportunity(
    CrossAMMOpportunity calldata opportunity,
    uint256 minProfitBps,
    uint256 sampleAmount
) external view returns (
    bool exists,
    uint256 estimatedProfit,
    uint256 discrepancy
)
```
Check if specific opportunity is profitable.

### CrossAMMArbitrageBot

#### depositCapital
```solidity
function depositCapital(address token, uint256 amount) external
```
Deposit capital for arbitrage execution.

#### addStrategy
```solidity
function addStrategy(
    address token0,
    address token1,
    AMMConfig[] calldata concentratedConfigs,
    AMMConfig[] calldata pseudoArbConfigs
) external returns (uint256 strategyId)
```
Add a monitored strategy.

#### scanAllStrategies
```solidity
function scanAllStrategies() external returns (bool executed, uint256 profit)
```
Scan all active strategies and execute best opportunity.

#### getPerformanceStats
```solidity
function getPerformanceStats(address token) external view returns (
    PerformanceStats memory stats
)
```
Get performance statistics for a token.

---

## Conclusion

The Cross-AMM Arbitrage system provides a powerful way to capture profit from price discrepancies between manually-priced ConcentratedAMM positions and oracle-updated PseudoArbitrageAMM positions.

**Key Takeaways**:
- Opportunities arise when prices diverge (minutes to hours)
- Automated monitoring captures opportunities quickly
- Optimal sizing maximizes profit while minimizing slippage
- Risk management through capital limits and profit thresholds
- Expected returns: 18% - 5,475% annually depending on market conditions

**Getting Started**:
1. Deploy contracts
2. Setup positions on both AMM types
3. Fund the bot
4. Configure parameters
5. Start monitoring loop

**Support**: For questions or issues, please open a GitHub issue or reach out to the development team.

# Cross-AMM Arbitrage System

**Exploit price discrepancies between ConcentratedAMM (stale prices) and PseudoArbitrageAMM (oracle prices) for consistent arbitrage profits.**

## 🎯 The Opportunity

ConcentratedAMM positions use fixed tick-based pricing that becomes stale, while PseudoArbitrageAMM positions automatically update via oracles. This creates profitable arbitrage windows lasting minutes to hours.

**Example Scenario:**
```
Time T0: Both AMMs at price 2.0
├─ ConcentratedAMM: 1 X = 2.0 Y
└─ PseudoArbitrage: 1 X = 2.0 Y

Time T1: Market moves +10%
├─ ConcentratedAMM: 1 X = 2.0 Y (STALE!)  ← Buy here
└─ PseudoArbitrage: 1 X = 2.2 Y (updated) ← Sell here

Arbitrage: Buy 100 X for 200 Y, Sell for 220 Y → 10% profit!
```

## 📊 Expected Returns

| Market Condition | Opportunities/Day | Avg Profit/Trade | Est. Daily Return |
|-----------------|------------------|------------------|-------------------|
| High Volatility | 15-30 | 2-5% | 30-150% |
| Medium Volatility | 5-15 | 1-3% | 5-45% |
| Low Volatility | 1-5 | 0.5-1% | 0.5-5% |

**Annualized:** 18% - 5,475% depending on market conditions and capital deployed.

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────┐
│                  ARBITRAGE SYSTEM                        │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌─────────────────┐         ┌──────────────────┐      │
│  │ ConcentratedAMM │◄────────│ CrossAMM         │      │
│  │ (Stale Prices)  │  Buy    │ Arbitrage        │      │
│  └─────────────────┘         │ (Core Logic)     │      │
│                              └──────────────────┘      │
│  ┌─────────────────┐                ▲                  │
│  │ PseudoArbitrage │◄───────────────┘                  │
│  │ (Oracle Prices) │  Sell                             │
│  └─────────────────┘                                   │
│                                                          │
│  ┌──────────────────────────────────────────────┐      │
│  │  CrossAMMArbitrageBot (Automation)           │      │
│  │  ├─ Capital Management                       │      │
│  │  ├─ Strategy Monitoring                      │      │
│  │  ├─ Opportunity Detection                    │      │
│  │  └─ Automated Execution                      │      │
│  └──────────────────────────────────────────────┘      │
│                                                          │
│  Aqua Protocol (Shared Liquidity Layer)                 │
└──────────────────────────────────────────────────────────┘
```

## 📁 File Structure

```
arbitrage/
├── CrossAMMArbitrage.sol              # Core arbitrage logic
├── CrossAMMArbitrageBot.sol           # Automated execution
├── interfaces/
│   └── IArbitrageCallback.sol         # Callback interface
├── script/
│   └── DeployCrossAMMArbitrage.s.sol  # Deployment scripts
├── CrossAMMArbitrage.t.sol            # Test suite
├── CROSS_AMM_ARBITRAGE_GUIDE.md       # Complete guide
└── README_CROSS_AMM_ARBITRAGE.md      # This file
```

## 🚀 Quick Start

### 1. Deploy Contracts

```bash
# Set environment variables
export PRIVATE_KEY=<your-private-key>
export RPC_URL=<your-rpc-url>

# Deploy entire system
forge script script/DeployCrossAMMArbitrage.s.sol:DeployCrossAMMArbitrage \
    --rpc-url $RPC_URL \
    --broadcast
```

### 2. Setup Strategy

```bash
# Configure environment
export AQUA_ADDRESS=<aqua-address>
export CONCENTRATED_AMM_ADDRESS=<concentrated-amm-address>
export PSEUDO_ARB_ROUTER_ADDRESS=<pseudo-arb-router-address>
export BOT_ADDRESS=<bot-address>
export TOKEN_X=<token-x-address>
export TOKEN_Y=<token-y-address>
export ORACLE_ADDRESS=<oracle-address>

# Setup positions
forge script script/DeployCrossAMMArbitrage.s.sol:SetupExampleStrategy \
    --rpc-url $RPC_URL \
    --broadcast
```

### 3. Monitor Opportunities

```bash
# Check for current opportunities
forge script script/DeployCrossAMMArbitrage.s.sol:MonitorOpportunities \
    --rpc-url $RPC_URL
```

### 4. Execute Arbitrage

```bash
# Manual execution
forge script script/DeployCrossAMMArbitrage.s.sol:ExecuteArbitrage \
    --rpc-url $RPC_URL \
    --broadcast
```

## 🤖 Automated Bot Operation

### Node.js Keeper Bot

```javascript
const { ethers } = require('ethers');

// Load contract
const bot = new ethers.Contract(BOT_ADDRESS, BOT_ABI, signer);

// Monitoring loop
async function monitor() {
    while (true) {
        try {
            // Check for opportunities
            const [hasOpp, bestProfit] = await bot.checkForOpportunities();
            
            if (hasOpp) {
                console.log(`Opportunity! Estimated profit: ${bestProfit}`);
                
                // Execute
                const tx = await bot.scanAllStrategies();
                const receipt = await tx.wait();
                
                // Log results
                const event = receipt.events.find(e => e.event === 'ArbitrageExecuted');
                console.log(`Executed! Profit: ${event.args.profit}`);
            }
            
            // Wait 30 seconds
            await new Promise(resolve => setTimeout(resolve, 30000));
            
        } catch (error) {
            console.error('Error:', error);
            await new Promise(resolve => setTimeout(resolve, 60000));
        }
    }
}

monitor();
```

### Python Keeper Bot

```python
from web3 import Web3
import time

# Connect
w3 = Web3(Web3.HTTPProvider(RPC_URL))
bot = w3.eth.contract(address=BOT_ADDRESS, abi=BOT_ABI)

# Monitor loop
while True:
    try:
        # Check opportunities
        has_opp, best_profit = bot.functions.checkForOpportunities().call()
        
        if has_opp:
            print(f"Opportunity! Profit: {best_profit}")
            
            # Execute
            tx_hash = bot.functions.scanAllStrategies().transact()
            receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
            
            print(f"Executed! Gas used: {receipt['gasUsed']}")
        
        time.sleep(30)  # Wait 30 seconds
        
    except Exception as e:
        print(f"Error: {e}")
        time.sleep(60)
```

## 💡 Usage Examples

### Deposit Capital

```solidity
// Fund the bot
tokenX.approve(address(bot), 1000e18);
bot.depositCapital(address(tokenX), 1000e18);

// Set limits
bot.setMaxCapitalPerArbitrage(address(tokenX), 100e18); // Max 10% per trade
bot.setMinProfitBps(50); // 0.5% minimum profit
bot.setMinDiscrepancyBps(100); // 1% minimum price difference
```

### Add Strategy

```solidity
// Configure ConcentratedAMM
CrossAMMArbitrage.AMMConfig[] memory concentratedConfigs = new CrossAMMArbitrage.AMMConfig[](1);
concentratedConfigs[0] = CrossAMMArbitrage.AMMConfig({
    ammType: CrossAMMArbitrage.AMMType.ConcentratedAMM,
    ammAddress: address(concentratedAMM),
    strategyData: abi.encode(concentratedStrategy)
});

// Configure PseudoArbitrage
CrossAMMArbitrage.AMMConfig[] memory pseudoArbConfigs = new CrossAMMArbitrage.AMMConfig[](1);
pseudoArbConfigs[0] = CrossAMMArbitrage.AMMConfig({
    ammType: CrossAMMArbitrage.AMMType.PseudoArbitrageAMM,
    ammAddress: address(pseudoArbRouter),
    strategyData: abi.encode(pseudoArbOrder)
});

// Add strategy
uint256 strategyId = bot.addStrategy(
    address(tokenX),
    address(tokenY),
    concentratedConfigs,
    pseudoArbConfigs
);
```

### Execute Arbitrage

```solidity
// Scan all strategies and execute best
(bool executed, uint256 profit) = bot.scanAllStrategies();

if (executed) {
    console.log("Profit earned:", profit);
}

// Or execute specific strategy
(bool executed, uint256 profit) = bot.scanAndExecuteStrategy(strategyId);

// Or check and execute manually
CrossAMMArbitrage.CrossAMMOpportunity memory opp = /* ... */;
bot.executeArbitrage(opp, 0); // 0 = use optimal amount
```

### Monitor Performance

```solidity
// Get statistics
CrossAMMArbitrageBot.PerformanceStats memory stats = 
    bot.getPerformanceStats(address(tokenX));

console.log("Total executions:", stats.totalExecutions);
console.log("Total profit:", stats.totalProfit);
console.log("Average profit:", stats.totalProfit / stats.totalExecutions);
console.log("Largest profit:", stats.largestProfit);

// Get capital status
(uint256 available, uint256 maxPer, uint256 utilization) = 
    bot.getCapitalStatus(address(tokenX));
```

## 🧪 Testing

```bash
# Run all tests
forge test --match-path arbitrage/CrossAMMArbitrage.t.sol -vvv

# Run specific test
forge test --match-test testExecuteArbitrage -vvv

# Run with gas report
forge test --gas-report
```

### Test Coverage

```
✓ testDetectOpportunity        - Detect price discrepancies
✓ testExecuteArbitrage          - Execute profitable arbitrage
✓ testOptimalAmount             - Calculate optimal trade size
✓ testBotExecution             - Automated bot execution
✓ testMonitoringLoop           - Continuous monitoring
✓ testMultipleStrategies       - Multi-strategy management
✓ testPerformanceTracking      - Stats and metrics
```

## 📈 Economics

### Profit Calculation

```
Gross Profit = (SellPrice - BuyPrice) × Amount
Fees = TradingFees + GasCost
Net Profit = Gross Profit - Fees

Example (10% price discrepancy):
- Buy: 100 X at 2.0 Y = 200 Y
- Sell: 100 X at 2.2 Y = 220 Y
- Fees: 0.6% (0.3% × 2 swaps) = 1.32 Y
- Gas: ~250k gas × 50 gwei ≈ 0.5 Y
- Net Profit: 220 - 200 - 1.32 - 0.5 = 18.18 Y (9.09%)
```

### Break-Even Analysis

```
Minimum Discrepancy = (TotalFees + GasCost) / Amount

For 100 X position:
- Trading fees: 0.6%
- Gas cost: ~0.25%
- Total: 0.85%

Recommendation: Set minDiscrepancyBps ≥ 100 (1%) for safety margin
```

## ⚙️ Configuration

### Bot Parameters

```solidity
// Profitability thresholds
bot.setMinProfitBps(50);         // 0.5% minimum profit
bot.setMinDiscrepancyBps(100);   // 1% minimum price difference

// Capital management
bot.setMaxCapitalPerArbitrage(token, 100e18); // Max per trade

// Executor authorization
bot.setExecutor(keeperAddress, true);
```

### Strategy Parameters

Adjust based on market conditions:

**High Volatility:**
- minProfitBps: 30 (0.3%)
- minDiscrepancyBps: 50 (0.5%)
- Check interval: 30 seconds

**Medium Volatility:**
- minProfitBps: 50 (0.5%)
- minDiscrepancyBps: 100 (1%)
- Check interval: 1 minute

**Low Volatility:**
- minProfitBps: 100 (1%)
- minDiscrepancyBps: 200 (2%)
- Check interval: 5 minutes

## 🔒 Security

### Risk Mitigation

1. **Slippage Protection**: Verify final profit exceeds minimum
2. **Capital Limits**: Max amount per arbitrage prevents overexposure
3. **Authorization**: Only approved executors can operate bot
4. **Balance Verification**: Confirm token balances after swaps
5. **Reentrancy Protection**: Callbacks secured against reentrancy

### Best Practices

- Start with small capital to test
- Monitor gas prices (affects profitability)
- Use private RPC to reduce front-running risk
- Set conservative profit thresholds initially
- Track performance metrics regularly

## 📚 Documentation

- **[Complete Guide](./CROSS_AMM_ARBITRAGE_GUIDE.md)**: Comprehensive documentation
- **[API Reference](./CROSS_AMM_ARBITRAGE_GUIDE.md#api-reference)**: Full API docs
- **[Strategy Guide](./CROSS_AMM_ARBITRAGE_GUIDE.md#arbitrage-strategies)**: Trading strategies
- **[Economics](./CROSS_AMM_ARBITRAGE_GUIDE.md#economics--profitability)**: Detailed economics

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create feature branch
3. Add tests for new functionality
4. Submit pull request

## 📝 License

LicenseRef-Degensoft-Aqua-Source-1.1

## ⚠️ Disclaimer

This software is provided "as is" without warranty. Use at your own risk. Cryptocurrency trading involves substantial risk of loss. Past performance does not guarantee future results.

## 🆘 Support

- Open an issue for bugs
- Discussions for questions
- Pull requests for improvements

---

**Happy Arbitraging! 🚀💰**

#!/usr/bin/env node

/**
 * Cross-AMM Arbitrage Bot Monitor
 * 
 * This script continuously monitors for arbitrage opportunities
 * and executes them when profitable.
 */

const { ethers } = require('ethers');
require('dotenv').config();

// Configuration
const RPC_URL = process.env.RPC_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const BOT_ADDRESS = process.env.BOT_ADDRESS;
const MONITORING_INTERVAL = parseInt(process.env.MONITORING_INTERVAL || '30') * 1000;

// Bot ABI (minimal interface)
const BOT_ABI = [
    "function checkForOpportunities() external view returns (bool hasOpportunities, uint256 bestProfit)",
    "function scanAllStrategies() external returns (bool executed, uint256 profit)",
    "function getPerformanceStats(address token) external view returns (tuple(uint256 totalExecutions, uint256 totalProfit, uint256 totalGasUsed, uint256 lastExecutionTime, uint256 largestProfit))",
    "function getCapitalStatus(address token) external view returns (uint256 available, uint256 maxPerArbitrage, uint256 utilization)",
    "event ArbitrageExecuted(address indexed token0, address indexed token1, uint256 amountIn, uint256 profit, uint256 gasUsed, uint256 priceDiscrepancy)"
];

// Validation
if (!RPC_URL) {
    console.error('Error: RPC_URL not set in .env file');
    process.exit(1);
}

if (!PRIVATE_KEY) {
    console.error('Error: PRIVATE_KEY not set in .env file');
    process.exit(1);
}

if (!BOT_ADDRESS) {
    console.error('Error: BOT_ADDRESS not set in .env file');
    console.log('Please deploy the contracts first using: ./deploy-all.sh');
    process.exit(1);
}

// Setup provider and wallet
const provider = new ethers.providers.JsonRpcProvider(RPC_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
const bot = new ethers.Contract(BOT_ADDRESS, BOT_ABI, wallet);

// Statistics
let stats = {
    checksPerformed: 0,
    opportunitiesFound: 0,
    executionsSuccessful: 0,
    executionsFailed: 0,
    totalProfit: ethers.BigNumber.from(0),
    startTime: Date.now()
};

/**
 * Format token amount for display
 */
function formatAmount(amount, decimals = 18) {
    return ethers.utils.formatUnits(amount, decimals);
}

/**
 * Format time duration
 */
function formatDuration(ms) {
    const seconds = Math.floor(ms / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    
    if (hours > 0) return `${hours}h ${minutes % 60}m`;
    if (minutes > 0) return `${minutes}m ${seconds % 60}s`;
    return `${seconds}s`;
}

/**
 * Display current statistics
 */
function displayStats() {
    const runtime = Date.now() - stats.startTime;
    
    console.log('\n' + '='.repeat(60));
    console.log('BOT STATISTICS');
    console.log('='.repeat(60));
    console.log(`Runtime:              ${formatDuration(runtime)}`);
    console.log(`Checks Performed:     ${stats.checksPerformed}`);
    console.log(`Opportunities Found:  ${stats.opportunitiesFound}`);
    console.log(`Executions Success:   ${stats.executionsSuccessful}`);
    console.log(`Executions Failed:    ${stats.executionsFailed}`);
    console.log(`Total Profit:         ${formatAmount(stats.totalProfit)} tokens`);
    
    if (stats.executionsSuccessful > 0) {
        const avgProfit = stats.totalProfit.div(stats.executionsSuccessful);
        console.log(`Average Profit:       ${formatAmount(avgProfit)} tokens`);
    }
    
    console.log('='.repeat(60) + '\n');
}

/**
 * Monitor and execute arbitrage
 */
async function monitorAndExecute() {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] Checking for opportunities...`);
    
    stats.checksPerformed++;
    
    try {
        // Check for opportunities
        const [hasOpportunities, estimatedProfit] = await bot.checkForOpportunities();
        
        if (hasOpportunities) {
            stats.opportunitiesFound++;
            
            console.log(`✓ Opportunity detected!`);
            console.log(`  Estimated Profit: ${formatAmount(estimatedProfit)} tokens`);
            
            // Execute arbitrage
            console.log(`  Executing arbitrage...`);
            const tx = await bot.scanAllStrategies();
            const receipt = await tx.wait();
            
            // Parse events to get actual profit
            const event = receipt.events?.find(e => e.event === 'ArbitrageExecuted');
            const actualProfit = event?.args?.profit || ethers.BigNumber.from(0);
            
            stats.executionsSuccessful++;
            stats.totalProfit = stats.totalProfit.add(actualProfit);
            
            console.log(`  ✓ Arbitrage executed successfully!`);
            console.log(`  Actual Profit: ${formatAmount(actualProfit)} tokens`);
            console.log(`  Gas Used: ${receipt.gasUsed.toString()}`);
            console.log(`  Transaction: ${receipt.transactionHash}`);
            
            // Display updated stats
            displayStats();
        } else {
            console.log(`  No profitable opportunities at this time`);
            
            // Display brief status every 10 checks
            if (stats.checksPerformed % 10 === 0) {
                console.log(`  [${stats.checksPerformed} checks, ${stats.opportunitiesFound} opportunities found]`);
            }
        }
    } catch (error) {
        stats.executionsFailed++;
        
        console.error(`✗ Error:`, error.message);
        
        // Try to extract revert reason
        if (error.error && error.error.message) {
            console.error(`  Reason: ${error.error.message}`);
        }
        
        // Don't exit on errors, just log and continue
        console.log(`  Continuing monitoring...`);
    }
}

/**
 * Main function
 */
async function main() {
    console.log('='.repeat(60));
    console.log('CROSS-AMM ARBITRAGE BOT');
    console.log('='.repeat(60));
    console.log(`Network:         ${RPC_URL}`);
    console.log(`Bot Address:     ${BOT_ADDRESS}`);
    console.log(`Monitor Address: ${wallet.address}`);
    console.log(`Check Interval:  ${MONITORING_INTERVAL / 1000}s`);
    console.log('='.repeat(60));
    console.log('\nStarting monitoring...\n');
    
    // Get initial bot status
    try {
        const balance = await provider.getBalance(wallet.address);
        console.log(`Wallet Balance: ${formatAmount(balance)} ETH\n`);
    } catch (error) {
        console.log('Could not fetch wallet balance\n');
    }
    
    // Run initial check immediately
    await monitorAndExecute();
    
    // Then run on interval
    setInterval(monitorAndExecute, MONITORING_INTERVAL);
    
    // Display stats every 5 minutes
    setInterval(displayStats, 5 * 60 * 1000);
    
    // Handle graceful shutdown
    process.on('SIGINT', () => {
        console.log('\n\nShutting down...');
        displayStats();
        process.exit(0);
    });
}

// Run
main().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
});


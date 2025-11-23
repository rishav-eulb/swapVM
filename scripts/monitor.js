#!/usr/bin/env node

/**
 * AMM System Monitor
 * 
 * This script monitors the deployed AMM contracts for activity,
 * liquidity levels, and overall system health.
 */

const { ethers } = require('ethers');
require('dotenv').config();

// Configuration
const RPC_URL = process.env.RPC_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const CONCENTRATED_AMM_ADDRESS = process.env.CONCENTRATED_AMM_ADDRESS;
const PSEUDO_ARB_AMM_ADDRESS = process.env.PSEUDO_ARB_AMM_ADDRESS;
const MONITORING_INTERVAL = parseInt(process.env.MONITORING_INTERVAL || '30') * 1000;

// AMM ABI (minimal interface)
const AMM_ABI = [
    "function getTotalLiquidity() external view returns (uint256)",
    "function getCurrentPrice() external view returns (uint256)",
    "function aqua() external view returns (address)",
    "event Swap(address indexed sender, address indexed recipient, uint256 amount0, uint256 amount1)",
    "event LiquidityAdded(address indexed provider, uint256 amount0, uint256 amount1)"
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

if (!CONCENTRATED_AMM_ADDRESS && !PSEUDO_ARB_AMM_ADDRESS) {
    console.error('Error: No AMM addresses set in .env file');
    console.log('Please deploy the contracts first using: ./deploy-all.sh');
    console.log('Then run: source .env.deployed');
    process.exit(1);
}

// Setup provider and wallet
const provider = new ethers.providers.JsonRpcProvider(RPC_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

// Setup contracts
const concentratedAMM = CONCENTRATED_AMM_ADDRESS ? 
    new ethers.Contract(CONCENTRATED_AMM_ADDRESS, AMM_ABI, provider) : null;
const pseudoArbAMM = PSEUDO_ARB_AMM_ADDRESS ? 
    new ethers.Contract(PSEUDO_ARB_AMM_ADDRESS, AMM_ABI, provider) : null;

// Statistics
let stats = {
    checksPerformed: 0,
    swapsDetected: 0,
    liquidityEvents: 0,
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
    console.log('AMM MONITORING STATISTICS');
    console.log('='.repeat(60));
    console.log(`Runtime:              ${formatDuration(runtime)}`);
    console.log(`Checks Performed:     ${stats.checksPerformed}`);
    console.log(`Swaps Detected:       ${stats.swapsDetected}`);
    console.log(`Liquidity Events:     ${stats.liquidityEvents}`);
    console.log('='.repeat(60) + '\n');
}

/**
 * Monitor AMM status
 */
async function monitorAMMs() {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] Checking AMM status...`);
    
    stats.checksPerformed++;
    
    try {
        // Check Concentrated AMM
        if (concentratedAMM) {
            console.log('\nConcentrated AMM:');
            try {
                const liquidity = await concentratedAMM.getTotalLiquidity();
                console.log(`  Total Liquidity: ${formatAmount(liquidity)} tokens`);
                
                const aqua = await concentratedAMM.aqua();
                console.log(`  Aqua Address: ${aqua}`);
            } catch (err) {
                console.log(`  Status: ${err.message}`);
            }
        }
        
        // Check Pseudo-Arbitrage AMM
        if (pseudoArbAMM) {
            console.log('\nPseudo-Arbitrage AMM:');
            try {
                const price = await pseudoArbAMM.getCurrentPrice();
                console.log(`  Current Price: ${formatAmount(price, 8)}`);
                
                const aqua = await pseudoArbAMM.aqua();
                console.log(`  Aqua Address: ${aqua}`);
            } catch (err) {
                console.log(`  Status: ${err.message}`);
            }
        }
        
        // Display brief status every 10 checks
        if (stats.checksPerformed % 10 === 0) {
            console.log(`\n[${stats.checksPerformed} checks completed]`);
        }
        
    } catch (error) {
        console.error(`✗ Error:`, error.message);
        console.log(`  Continuing monitoring...`);
    }
}

/**
 * Main function
 */
async function main() {
    console.log('='.repeat(60));
    console.log('AMM SYSTEM MONITOR');
    console.log('='.repeat(60));
    console.log(`Network:              ${RPC_URL}`);
    if (CONCENTRATED_AMM_ADDRESS) {
        console.log(`Concentrated AMM:     ${CONCENTRATED_AMM_ADDRESS}`);
    }
    if (PSEUDO_ARB_AMM_ADDRESS) {
        console.log(`Pseudo-Arb AMM:       ${PSEUDO_ARB_AMM_ADDRESS}`);
    }
    console.log(`Check Interval:       ${MONITORING_INTERVAL / 1000}s`);
    console.log('='.repeat(60));
    console.log('\nStarting monitoring...\n');
    
    // Get initial wallet status
    try {
        const balance = await provider.getBalance(wallet.address);
        console.log(`Monitor Wallet: ${wallet.address}`);
        console.log(`Wallet Balance: ${formatAmount(balance)} ETH\n`);
    } catch (error) {
        console.log('Could not fetch wallet balance\n');
    }
    
    // Run initial check immediately
    await monitorAMMs();
    
    // Then run on interval
    setInterval(monitorAMMs, MONITORING_INTERVAL);
    
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


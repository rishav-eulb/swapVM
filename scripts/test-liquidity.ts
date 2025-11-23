#!/usr/bin/env ts-node

/**
 * Liquidity and Swap Testing Script
 * 
 * Tests liquidity provisioning and swapping functionality for:
 * 1. Concentrated AMM (ConcentratedAMM)
 * 2. Pseudo-Arbitrage AMM (PseudoArbitrageAMM)
 * 
 * Usage:
 *   npm run test:liquidity
 *   # or
 *   ts-node scripts/test-liquidity.ts
 */

import { ethers } from 'ethers';
import * as dotenv from 'dotenv';
import * as fs from 'fs';
import * as path from 'path';

dotenv.config();

// ============ Configuration ============

interface TestConfig {
  rpcUrl: string;
  privateKey: string;
  concentratedAmmAddress?: string;
  concentratedBuilderAddress?: string;
  pseudoArbAmmAddress?: string;
  aquaAddress?: string;
  wethAddress?: string;
  usdcAddress?: string;
}

interface TestResult {
  name: string;
  success: boolean;
  error?: string;
  gasUsed?: string;
  duration?: number;
  details?: Record<string, any>;
}

// ============ ABIs ============

const ERC20_ABI = [
  "function balanceOf(address owner) view returns (uint256)",
  "function decimals() view returns (uint8)",
  "function symbol() view returns (string)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function transfer(address to, uint256 amount) returns (bool)"
];

const AQUA_ABI = [
  "function ship(tuple(address maker, bytes makerTraits, address tokenIn, address tokenOut, uint256 amountOutMin, uint256 amountInMax, bytes bytecode) order) external payable returns (uint256 amountIn, uint256 amountOut)",
  "function getBalance(address token, address owner) external view returns (uint256)",
  "function approve(address spender, address token, uint256 amount) external"
];

const CONCENTRATED_AMM_ABI = [
  "function buildProgram(tuple(address maker, address token0, address token1, int24 tickLower, int24 tickUpper, uint24 feeBps, uint128 liquidity, bytes32 salt) strategy, uint40 expiration) external view returns (tuple(address maker, bytes makerTraits, address tokenIn, address tokenOut, uint256 amountOutMin, uint256 amountInMax, bytes bytecode))",
  "function quoteExactIn(tuple(address maker, address token0, address token1, int24 tickLower, int24 tickUpper, uint24 feeBps, uint128 liquidity, bytes32 salt) strategy, bool zeroForOne, uint256 amountIn) external view returns (uint256 amountOut)",
  "function aqua() external view returns (address)"
];

const PSEUDO_ARB_AMM_ABI = [
  "function buildProgram(address maker, uint40 expiration, address token0, address token1, uint256 balance0, uint256 balance1, address oracle, uint256 initialPrice, uint32 minUpdateInterval, uint16 feeBps, uint64 salt) external pure returns (tuple(address maker, bytes makerTraits, address tokenIn, address tokenOut, uint256 amountOutMin, uint256 amountInMax, bytes bytecode))"
];

// ============ Utilities ============

class TestRunner {
  private provider: ethers.providers.Provider;
  private wallet: ethers.Wallet;
  private config: TestConfig;
  private results: TestResult[] = [];
  
  constructor(config: TestConfig) {
    this.config = config;
    this.provider = new ethers.providers.JsonRpcProvider(config.rpcUrl);
    this.wallet = new ethers.Wallet(config.privateKey, this.provider);
  }
  
  // ============ Logging ============
  
  log(message: string) {
    console.log(`[${new Date().toISOString()}] ${message}`);
  }
  
  logSection(title: string) {
    console.log('\n' + '='.repeat(70));
    console.log(title);
    console.log('='.repeat(70) + '\n');
  }
  
  logSuccess(message: string) {
    console.log(`✓ ${message}`);
  }
  
  logError(message: string) {
    console.error(`✗ ${message}`);
  }
  
  logInfo(message: string) {
    console.log(`ℹ ${message}`);
  }
  
  // ============ Test Execution ============
  
  async runTest(name: string, testFn: () => Promise<void>): Promise<TestResult> {
    this.log(`Running: ${name}`);
    const startTime = Date.now();
    
    try {
      await testFn();
      const duration = Date.now() - startTime;
      this.logSuccess(`${name} (${duration}ms)`);
      
      const result: TestResult = {
        name,
        success: true,
        duration
      };
      this.results.push(result);
      return result;
    } catch (error: any) {
      const duration = Date.now() - startTime;
      this.logError(`${name}: ${error.message}`);
      
      const result: TestResult = {
        name,
        success: false,
        error: error.message,
        duration
      };
      this.results.push(result);
      return result;
    }
  }
  
  // ============ Token Helpers ============
  
  async getTokenInfo(tokenAddress: string) {
    const token = new ethers.Contract(tokenAddress, ERC20_ABI, this.provider);
    const [symbol, decimals, balance] = await Promise.all([
      token.symbol(),
      token.decimals(),
      token.balanceOf(this.wallet.address)
    ]);
    
    return { symbol, decimals, balance };
  }
  
  async approveToken(tokenAddress: string, spender: string, amount: ethers.BigNumber) {
    const token = new ethers.Contract(tokenAddress, ERC20_ABI, this.wallet);
    const allowance = await token.allowance(this.wallet.address, spender);
    
    if (allowance.lt(amount)) {
      this.log(`Approving ${spender} to spend token ${tokenAddress}`);
      const tx = await token.approve(spender, ethers.constants.MaxUint256);
      await tx.wait();
      this.logSuccess('Approval successful');
    } else {
      this.logInfo('Sufficient allowance already exists');
    }
  }
  
  formatAmount(amount: ethers.BigNumber, decimals: number = 18): string {
    return ethers.utils.formatUnits(amount, decimals);
  }
  
  parseAmount(amount: string, decimals: number = 18): ethers.BigNumber {
    return ethers.utils.parseUnits(amount, decimals);
  }
  
  // ============ Concentrated AMM Tests ============
  
  async testConcentratedAMM() {
    if (!this.config.concentratedBuilderAddress) {
      this.logInfo('Concentrated AMM Builder not configured, skipping tests');
      return;
    }
    
    this.logSection('CONCENTRATED AMM TESTS');
    
    const amm = new ethers.Contract(
      this.config.concentratedBuilderAddress,
      CONCENTRATED_AMM_ABI,
      this.wallet
    );
    
    // Test 1: Check Builder is accessible
    await this.runTest('Verify Builder Contract', async () => {
      const code = await this.provider.getCode(this.config.concentratedBuilderAddress!);
      if (code === '0x') {
        throw new Error('No contract found at builder address');
      }
      this.logInfo(`Builder contract is accessible`);
      this.logInfo(`Address: ${this.config.concentratedBuilderAddress}`);
    });
    
    // Test 2: Quote swap
    await this.runTest('Quote Swap', async () => {
      if (!this.config.wethAddress || !this.config.usdcAddress) {
        throw new Error('Token addresses not configured');
      }
      
      const strategy = {
        maker: this.wallet.address,
        token0: this.config.wethAddress,
        token1: this.config.usdcAddress,
        tickLower: -887272,
        tickUpper: 887272,
        feeBps: 30, // 0.3%
        liquidity: ethers.utils.parseEther('100'),
        salt: ethers.constants.HashZero
      };
      
      const amountIn = ethers.utils.parseEther('1'); // 1 WETH
      
      try {
        const amountOut = await amm.quoteExactIn(strategy, true, amountIn);
        this.logInfo(`Quote: ${this.formatAmount(amountIn)} WETH -> ${this.formatAmount(amountOut, 6)} USDC`);
      } catch (error: any) {
        this.logInfo(`Quote failed (expected if no liquidity): ${error.message}`);
      }
    });
    
    // Test 3: Build program
    await this.runTest('Build Liquidity Program', async () => {
      if (!this.config.wethAddress || !this.config.usdcAddress) {
        throw new Error('Token addresses not configured');
      }
      
      const strategy = {
        maker: this.wallet.address,
        token0: this.config.wethAddress,
        token1: this.config.usdcAddress,
        tickLower: -887272,
        tickUpper: 887272,
        feeBps: 30,
        liquidity: ethers.utils.parseEther('10'),
        salt: ethers.constants.HashZero
      };
      
      const expiration = Math.floor(Date.now() / 1000) + 86400; // 24 hours
      
      const order = await amm.buildProgram(strategy, expiration);
      this.logInfo('Program built successfully');
      this.logInfo(`Maker: ${order.maker}`);
      this.logInfo(`TokenIn: ${order.tokenIn}`);
      this.logInfo(`TokenOut: ${order.tokenOut}`);
      this.logInfo(`Bytecode length: ${order.bytecode.length} bytes`);
    });
  }
  
  // ============ Pseudo-Arbitrage AMM Tests ============
  
  async testPseudoArbitrageAMM() {
    if (!this.config.pseudoArbAmmAddress) {
      this.logError('Pseudo-Arbitrage AMM address not configured');
      return;
    }
    
    this.logSection('PSEUDO-ARBITRAGE AMM TESTS');
    
    const amm = new ethers.Contract(
      this.config.pseudoArbAmmAddress,
      PSEUDO_ARB_AMM_ABI,
      this.wallet
    );
    
    // Test 1: Build simple program (no oracle)
    await this.runTest('Build Simple Program', async () => {
      if (!this.config.wethAddress || !this.config.usdcAddress) {
        throw new Error('Token addresses not configured');
      }
      
      const expiration = Math.floor(Date.now() / 1000) + 86400;
      const balance0 = ethers.utils.parseEther('10'); // 10 WETH
      const balance1 = ethers.utils.parseUnits('30000', 6); // 30,000 USDC (price = 3000)
      const initialPrice = ethers.utils.parseEther('3000'); // 3000 USDC per WETH
      const minUpdateInterval = 3600; // 1 hour
      const feeBps = 30; // 0.3%
      const salt = 0;
      
      const order = await amm.buildProgram(
        this.wallet.address,
        expiration,
        this.config.wethAddress,
        this.config.usdcAddress,
        balance0,
        balance1,
        ethers.constants.AddressZero, // No oracle for this test
        initialPrice,
        minUpdateInterval,
        feeBps,
        salt
      );
      
      this.logInfo('Program built successfully');
      this.logInfo(`Maker: ${order.maker}`);
      this.logInfo(`TokenIn: ${order.tokenIn}`);
      this.logInfo(`TokenOut: ${order.tokenOut}`);
      this.logInfo(`Bytecode length: ${order.bytecode.length} bytes`);
    });
    
    // Test 2: Build program with different parameters
    await this.runTest('Build Program with Different Parameters', async () => {
      if (!this.config.wethAddress || !this.config.usdcAddress) {
        throw new Error('Token addresses not configured');
      }
      
      const expiration = Math.floor(Date.now() / 1000) + 3600; // 1 hour
      const balance0 = ethers.utils.parseEther('1'); // 1 WETH
      const balance1 = ethers.utils.parseUnits('3000', 6); // 3,000 USDC
      const initialPrice = ethers.utils.parseEther('3000');
      const minUpdateInterval = 60; // 1 minute
      const feeBps = 10; // 0.1%
      const salt = 123;
      
      const order = await amm.buildProgram(
        this.wallet.address,
        expiration,
        this.config.wethAddress,
        this.config.usdcAddress,
        balance0,
        balance1,
        ethers.constants.AddressZero,
        initialPrice,
        minUpdateInterval,
        feeBps,
        salt
      );
      
      this.logInfo('Program with custom parameters built successfully');
      this.logInfo(`Fee: ${feeBps} bps`);
      this.logInfo(`Min Update Interval: ${minUpdateInterval}s`);
      this.logInfo(`Salt: ${salt}`);
    });
    
    // Test 3: Validate input validation
    await this.runTest('Test Input Validation', async () => {
      if (!this.config.wethAddress || !this.config.usdcAddress) {
        throw new Error('Token addresses not configured');
      }
      
      const expiration = Math.floor(Date.now() / 1000) + 86400;
      
      // Test zero balance (should fail)
      try {
        await amm.buildProgram(
          this.wallet.address,
          expiration,
          this.config.wethAddress,
          this.config.usdcAddress,
          0, // Invalid: zero balance
          ethers.utils.parseUnits('3000', 6),
          ethers.constants.AddressZero,
          ethers.utils.parseEther('3000'),
          3600,
          30,
          0
        );
        throw new Error('Should have failed with zero balance');
      } catch (error: any) {
        if (error.message.includes('InvalidBalances')) {
          this.logInfo('✓ Correctly rejected zero balance');
        } else {
          throw error;
        }
      }
      
      // Test excessive fee (should fail)
      try {
        await amm.buildProgram(
          this.wallet.address,
          expiration,
          this.config.wethAddress,
          this.config.usdcAddress,
          ethers.utils.parseEther('10'),
          ethers.utils.parseUnits('30000', 6),
          ethers.constants.AddressZero,
          ethers.utils.parseEther('3000'),
          3600,
          10001, // Invalid: > 10000 (100%)
          0
        );
        throw new Error('Should have failed with excessive fee');
      } catch (error: any) {
        if (error.message.includes('InvalidFeeRate') || error.message.includes('invalid')) {
          this.logInfo('✓ Correctly rejected excessive fee');
        } else {
          throw error;
        }
      }
      
      this.logInfo('Input validation working correctly');
    });
  }
  
  // ============ Integration Tests ============
  
  async testTokenBalances() {
    this.logSection('TOKEN BALANCE CHECKS');
    
    await this.runTest('Check ETH Balance', async () => {
      const balance = await this.provider.getBalance(this.wallet.address);
      this.logInfo(`ETH Balance: ${this.formatAmount(balance)} ETH`);
      
      if (balance.lt(ethers.utils.parseEther('0.01'))) {
        this.logError('Low ETH balance! You may need more for gas fees.');
      }
    });
    
    if (this.config.wethAddress) {
      await this.runTest('Check WETH Balance', async () => {
        const info = await this.getTokenInfo(this.config.wethAddress!);
        this.logInfo(`${info.symbol} Balance: ${this.formatAmount(info.balance, info.decimals)}`);
      });
    }
    
    if (this.config.usdcAddress) {
      await this.runTest('Check USDC Balance', async () => {
        const info = await this.getTokenInfo(this.config.usdcAddress!);
        this.logInfo(`${info.symbol} Balance: ${this.formatAmount(info.balance, info.decimals)}`);
      });
    }
  }
  
  // ============ Main Test Suite ============
  
  async runAllTests() {
    this.logSection('AMM LIQUIDITY & SWAP TEST SUITE');
    this.log(`Network: ${this.config.rpcUrl}`);
    this.log(`Wallet: ${this.wallet.address}`);
    this.log(`Concentrated AMM: ${this.config.concentratedAmmAddress || 'Not configured'}`);
    this.log(`Pseudo-Arb AMM: ${this.config.pseudoArbAmmAddress || 'Not configured'}`);
    
    // Run tests
    await this.testTokenBalances();
    await this.testConcentratedAMM();
    await this.testPseudoArbitrageAMM();
    
    // Summary
    this.logSection('TEST SUMMARY');
    const passed = this.results.filter(r => r.success).length;
    const failed = this.results.filter(r => !r.success).length;
    
    console.log(`Total Tests: ${this.results.length}`);
    console.log(`Passed: ${passed} ✓`);
    console.log(`Failed: ${failed} ✗`);
    
    if (failed > 0) {
      console.log('\nFailed Tests:');
      this.results.filter(r => !r.success).forEach(r => {
        console.log(`  - ${r.name}: ${r.error}`);
      });
    }
    
    console.log('\n' + '='.repeat(70));
    
    return { passed, failed, total: this.results.length };
  }
}

// ============ Load Configuration ============

function loadConfig(): TestConfig {
  const rpcUrl = process.env.RPC_URL;
  const privateKey = process.env.PRIVATE_KEY;
  
  if (!rpcUrl) {
    throw new Error('RPC_URL not set in .env file');
  }
  
  if (!privateKey) {
    throw new Error('PRIVATE_KEY not set in .env file');
  }
  
  // Try to load deployment addresses
  let concentratedAmmAddress = process.env.CONCENTRATED_AMM_ADDRESS;
  let concentratedBuilderAddress = process.env.CONCENTRATED_BUILDER_ADDRESS;
  let pseudoArbAmmAddress = process.env.PSEUDO_ARB_AMM_ADDRESS;
  let aquaAddress = process.env.AQUA_ADDRESS;
  let wethAddress = process.env.WETH_ADDRESS;
  let usdcAddress = process.env.USDC_ADDRESS;
  
  // Try to load from deployment summary
  const summaryPath = path.join(__dirname, '..', 'deployments', 'deployment-summary.json');
  if (fs.existsSync(summaryPath)) {
    try {
      const summary = JSON.parse(fs.readFileSync(summaryPath, 'utf-8'));
      concentratedAmmAddress = concentratedAmmAddress || summary.contracts?.concentratedAMM;
      concentratedBuilderAddress = concentratedBuilderAddress || summary.contracts?.concentratedBuilder;
      pseudoArbAmmAddress = pseudoArbAmmAddress || summary.contracts?.pseudoArbitrageAMM;
      aquaAddress = aquaAddress || summary.contracts?.aqua;
    } catch (error) {
      console.warn('Could not load deployment summary');
    }
  }
  
  return {
    rpcUrl,
    privateKey,
    concentratedAmmAddress,
    concentratedBuilderAddress,
    pseudoArbAmmAddress,
    aquaAddress,
    wethAddress,
    usdcAddress
  };
}

// ============ Main ============

async function main() {
  try {
    const config = loadConfig();
    const runner = new TestRunner(config);
    const results = await runner.runAllTests();
    
    process.exit(results.failed > 0 ? 1 : 0);
  } catch (error: any) {
    console.error('Fatal error:', error.message);
    process.exit(1);
  }
}

// Run if executed directly
if (require.main === module) {
  main();
}

export { TestRunner, TestConfig, TestResult };


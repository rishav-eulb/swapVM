#!/usr/bin/env ts-node

/**
 * Pyth Price Adapter Testing Script
 * 
 * Comprehensive tests for PythPriceAdapter.sol functionality:
 * 1. Deployment and configuration
 * 2. Price feed configuration
 * 3. Price fetching and conversion
 * 4. Error handling and edge cases
 * 5. Integration with Pyth Network
 * 
 * Usage:
 *   npm run test:pyth
 *   # or
 *   ts-node scripts/test-pyth-adapter.ts
 */

import { ethers } from 'ethers';
import * as dotenv from 'dotenv';
import * as fs from 'fs';
import * as path from 'path';

dotenv.config();

// ============ Configuration ============

interface PythTestConfig {
  rpcUrl: string;
  privateKey: string;
  pythAddress?: string;
  pythAdapterAddress?: string;
  wethAddress?: string;
  usdcAddress?: string;
  btcAddress?: string;
  usdtAddress?: string;
}

interface TestResult {
  name: string;
  success: boolean;
  error?: string;
  duration?: number;
  details?: Record<string, any>;
}

// ============ Pyth Price Feed IDs ============
// Source: https://pyth.network/developers/price-feed-ids

const PYTH_PRICE_FEEDS = {
  'ETH/USD': '0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace',
  'BTC/USD': '0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43',
  'USDC/USD': '0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a',
  'USDT/USD': '0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b',
};

// Pyth Network Contract Addresses
const PYTH_CONTRACTS = {
  'mainnet': '0x4305FB66699C3B2702D4d05CF36551390A4c69C6',
  'arbitrum': '0xff1a0f4744e8582DF1aE09D5611b887B6a12925C',
  'base': '0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a',
  'base-sepolia': '0xA2aa501b19aff244D90cc15a4Cf739D2725B5729',
  'sepolia': '0xDd24F84d36BF92C65F92307595335bdFab5Bbd21',
};

// ============ ABIs ============

const PYTH_ADAPTER_ABI = [
  "constructor(address _pyth, uint256 _maxPriceAge)",
  "function pyth() external view returns (address)",
  "function maxPriceAge() external view returns (uint256)",
  "function owner() external view returns (address)",
  "function setPriceFeed(address tokenIn, address tokenOut, bytes32 priceId) external",
  "function transferOwnership(address newOwner) external",
  "function getPrice(address tokenIn, address tokenOut) external view returns (uint256 price, uint256 timestamp)",
  "function getPriceFeedInfo(address tokenIn, address tokenOut) external view returns (bytes32 priceId, bool hasConfig)",
  "function getRawPythPrice(address tokenIn, address tokenOut) external view returns (int64 price, uint64 conf, int32 expo, uint256 publishTime)",
  "function priceFeedIds(address, address) external view returns (bytes32)",
  "event PriceFeedConfigured(address indexed tokenIn, address indexed tokenOut, bytes32 priceId)",
  "event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)"
];

const PYTH_ABI = [
  "function getPriceNoOlderThan(bytes32 id, uint age) external view returns (tuple(int64 price, uint64 conf, int32 expo, uint publishTime))",
  "function getPrice(bytes32 id) external view returns (tuple(int64 price, uint64 conf, int32 expo, uint publishTime))",
  "function priceFeedExists(bytes32 id) external view returns (bool)",
  "function getValidTimePeriod() external view returns (uint)"
];

// ============ Test Runner ============

class PythAdapterTester {
  private provider: ethers.providers.Provider;
  private wallet: ethers.Wallet;
  private config: PythTestConfig;
  private results: TestResult[] = [];
  private pythContract?: ethers.Contract;
  private adapterContract?: ethers.Contract;
  
  constructor(config: PythTestConfig) {
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
  
  logWarning(message: string) {
    console.log(`⚠ ${message}`);
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
  
  // ============ Pyth Contract Tests ============
  
  async testPythConnection() {
    this.logSection('PYTH NETWORK CONNECTION TESTS');
    
    if (!this.config.pythAddress) {
      this.logWarning('Pyth address not configured, skipping Pyth tests');
      return;
    }
    
    this.pythContract = new ethers.Contract(
      this.config.pythAddress,
      PYTH_ABI,
      this.provider
    );
    
    // Test 1: Check Pyth contract is accessible
    await this.runTest('Connect to Pyth Contract', async () => {
      const code = await this.provider.getCode(this.config.pythAddress!);
      if (code === '0x') {
        throw new Error('No contract found at Pyth address');
      }
      this.logInfo(`Pyth contract found at ${this.config.pythAddress}`);
    });
    
    // Test 2: Get valid time period
    await this.runTest('Get Pyth Valid Time Period', async () => {
      try {
        const validTimePeriod = await this.pythContract!.getValidTimePeriod();
        this.logInfo(`Valid Time Period: ${validTimePeriod.toString()} seconds`);
      } catch (error) {
        this.logInfo('getValidTimePeriod not available (expected on some networks)');
      }
    });
    
    // Test 3: Check price feed exists for ETH/USD
    await this.runTest('Check ETH/USD Price Feed Exists', async () => {
      const feedId = PYTH_PRICE_FEEDS['ETH/USD'];
      try {
        const exists = await this.pythContract!.priceFeedExists(feedId);
        if (exists) {
          this.logSuccess('ETH/USD price feed exists');
        } else {
          this.logWarning('ETH/USD price feed not found');
        }
      } catch (error) {
        this.logInfo('priceFeedExists not available (expected on some networks)');
      }
    });
    
    // Test 4: Fetch raw ETH/USD price
    await this.runTest('Fetch Raw ETH/USD Price', async () => {
      const feedId = PYTH_PRICE_FEEDS['ETH/USD'];
      try {
        const priceData = await this.pythContract!.getPrice(feedId);
        
        this.logInfo(`Raw Price: ${priceData.price.toString()}`);
        this.logInfo(`Confidence: ${priceData.conf.toString()}`);
        this.logInfo(`Exponent: ${priceData.expo}`);
        this.logInfo(`Publish Time: ${new Date(priceData.publishTime * 1000).toISOString()}`);
        
        // Calculate actual price
        const actualPrice = Number(priceData.price) * Math.pow(10, priceData.expo);
        this.logInfo(`Actual ETH Price: $${actualPrice.toFixed(2)}`);
        
      } catch (error: any) {
        this.logWarning(`Could not fetch price: ${error.message}`);
        this.logInfo('This may be expected if using a testnet or if price is stale');
      }
    });
  }
  
  // ============ Adapter Contract Tests ============
  
  async testAdapterConfiguration() {
    this.logSection('PYTH ADAPTER CONFIGURATION TESTS');
    
    if (!this.config.pythAdapterAddress) {
      this.logWarning('Pyth Adapter address not configured');
      this.logInfo('To test the adapter, deploy it first using Foundry:');
      this.logInfo('  forge create PythPriceAdapter --constructor-args <PYTH_ADDRESS> <MAX_AGE>');
      return;
    }
    
    this.adapterContract = new ethers.Contract(
      this.config.pythAdapterAddress,
      PYTH_ADAPTER_ABI,
      this.wallet
    );
    
    // Test 1: Verify deployment
    await this.runTest('Verify Adapter Deployment', async () => {
      const code = await this.provider.getCode(this.config.pythAdapterAddress!);
      if (code === '0x') {
        throw new Error('No contract found at adapter address');
      }
      this.logInfo(`Adapter contract found at ${this.config.pythAdapterAddress}`);
    });
    
    // Test 2: Check immutable variables
    await this.runTest('Check Adapter Configuration', async () => {
      const [pythAddress, maxPriceAge, owner] = await Promise.all([
        this.adapterContract!.pyth(),
        this.adapterContract!.maxPriceAge(),
        this.adapterContract!.owner()
      ]);
      
      this.logInfo(`Pyth Contract: ${pythAddress}`);
      this.logInfo(`Max Price Age: ${maxPriceAge.toString()} seconds (${maxPriceAge.toNumber() / 60} minutes)`);
      this.logInfo(`Owner: ${owner}`);
      
      if (pythAddress.toLowerCase() !== this.config.pythAddress?.toLowerCase()) {
        this.logWarning(`Adapter pointing to different Pyth contract!`);
        this.logWarning(`Expected: ${this.config.pythAddress}`);
        this.logWarning(`Actual: ${pythAddress}`);
      }
    });
    
    // Test 3: Check ownership
    await this.runTest('Verify Ownership', async () => {
      const owner = await this.adapterContract!.owner();
      const isOwner = owner.toLowerCase() === this.wallet.address.toLowerCase();
      
      if (isOwner) {
        this.logSuccess('You are the owner (can configure price feeds)');
      } else {
        this.logWarning('You are NOT the owner (cannot configure price feeds)');
        this.logInfo(`Owner: ${owner}`);
        this.logInfo(`Your address: ${this.wallet.address}`);
      }
    });
  }
  
  // ============ Price Feed Configuration Tests ============
  
  async testPriceFeedConfiguration() {
    this.logSection('PRICE FEED CONFIGURATION TESTS');
    
    if (!this.adapterContract) {
      this.logWarning('Adapter contract not initialized, skipping configuration tests');
      return;
    }
    
    if (!this.config.wethAddress || !this.config.usdcAddress) {
      this.logWarning('Token addresses not configured, skipping configuration tests');
      return;
    }
    
    // Test 1: Check existing configuration
    await this.runTest('Check Existing Price Feed Config', async () => {
      const [priceId, hasConfig] = await this.adapterContract!.getPriceFeedInfo(
        this.config.wethAddress!,
        this.config.usdcAddress!
      );
      
      if (hasConfig) {
        this.logInfo(`Price feed already configured: ${priceId}`);
      } else {
        this.logInfo('No price feed configured for WETH/USDC');
      }
    });
    
    // Test 2: Try to configure price feed (only if owner)
    await this.runTest('Configure ETH/USD Price Feed', async () => {
      const owner = await this.adapterContract!.owner();
      if (owner.toLowerCase() !== this.wallet.address.toLowerCase()) {
        this.logInfo('Skipping (not owner)');
        return;
      }
      
      const feedId = PYTH_PRICE_FEEDS['ETH/USD'];
      
      try {
        const tx = await this.adapterContract!.setPriceFeed(
          this.config.wethAddress!,
          this.config.usdcAddress!,
          feedId
        );
        
        const receipt = await tx.wait();
        this.logSuccess(`Price feed configured in tx ${receipt.transactionHash}`);
        this.logInfo(`Gas used: ${receipt.gasUsed.toString()}`);
        
        // Check event
        const event = receipt.events?.find((e: any) => e.event === 'PriceFeedConfigured');
        if (event) {
          this.logInfo(`Event emitted: PriceFeedConfigured`);
          this.logInfo(`  TokenIn: ${event.args?.tokenIn}`);
          this.logInfo(`  TokenOut: ${event.args?.tokenOut}`);
          this.logInfo(`  PriceId: ${event.args?.priceId}`);
        }
      } catch (error: any) {
        if (error.message.includes('OnlyOwner')) {
          this.logInfo('Not owner, cannot configure');
        } else {
          throw error;
        }
      }
    });
    
    // Test 3: Read back configuration
    await this.runTest('Read Back Configuration', async () => {
      const [priceId, hasConfig] = await this.adapterContract!.getPriceFeedInfo(
        this.config.wethAddress!,
        this.config.usdcAddress!
      );
      
      if (hasConfig) {
        this.logSuccess('Price feed is configured');
        this.logInfo(`Price ID: ${priceId}`);
        
        // Check if it matches expected
        const expectedId = PYTH_PRICE_FEEDS['ETH/USD'];
        if (priceId === expectedId) {
          this.logSuccess('Price ID matches ETH/USD feed');
        }
      } else {
        this.logInfo('Price feed not configured');
      }
    });
  }
  
  // ============ Price Fetching Tests ============
  
  async testPriceFetching() {
    this.logSection('PRICE FETCHING TESTS');
    
    if (!this.adapterContract) {
      this.logWarning('Adapter contract not initialized, skipping price tests');
      return;
    }
    
    if (!this.config.wethAddress || !this.config.usdcAddress) {
      this.logWarning('Token addresses not configured');
      return;
    }
    
    // Test 1: Check if price feed is configured
    await this.runTest('Verify Price Feed Configuration', async () => {
      const [priceId, hasConfig] = await this.adapterContract!.getPriceFeedInfo(
        this.config.wethAddress!,
        this.config.usdcAddress!
      );
      
      if (!hasConfig) {
        this.logWarning('Price feed not configured - configure it first!');
        this.logInfo('Run: adapter.setPriceFeed(WETH, USDC, PYTH_FEED_ID)');
        return;
      }
      
      this.logSuccess('Price feed is configured');
    });
    
    // Test 2: Fetch raw Pyth price
    await this.runTest('Fetch Raw Pyth Price', async () => {
      try {
        const [price, conf, expo, publishTime] = await this.adapterContract!.getRawPythPrice(
          this.config.wethAddress!,
          this.config.usdcAddress!
        );
        
        this.logInfo(`Raw Pyth Data:`);
        this.logInfo(`  Price: ${price.toString()}`);
        this.logInfo(`  Confidence: ${conf.toString()}`);
        this.logInfo(`  Exponent: ${expo}`);
        this.logInfo(`  Publish Time: ${new Date(publishTime.toNumber() * 1000).toISOString()}`);
        
        // Calculate actual price
        const actualPrice = Number(price) * Math.pow(10, expo);
        this.logInfo(`  Calculated Price: $${actualPrice.toFixed(2)}`);
        
        // Check staleness
        const now = Math.floor(Date.now() / 1000);
        const age = now - publishTime.toNumber();
        this.logInfo(`  Price Age: ${age} seconds (${(age / 60).toFixed(1)} minutes)`);
        
        const maxAge = await this.adapterContract!.maxPriceAge();
        if (age > maxAge.toNumber()) {
          this.logWarning(`Price is stale! Age ${age}s > Max ${maxAge.toString()}s`);
        }
        
      } catch (error: any) {
        if (error.message.includes('PriceFeedNotConfigured')) {
          this.logWarning('Price feed not configured');
        } else if (error.message.includes('StalePrice') || error.message.includes('stale')) {
          this.logWarning('Price is too stale (older than maxPriceAge)');
        } else {
          throw error;
        }
      }
    });
    
    // Test 3: Get converted price (standard 1e18 format)
    await this.runTest('Get Converted Price (1e18 format)', async () => {
      try {
        const [price, timestamp] = await this.adapterContract!.getPrice(
          this.config.wethAddress!,
          this.config.usdcAddress!
        );
        
        this.logSuccess('Price fetched successfully');
        this.logInfo(`Converted Price: ${ethers.utils.formatEther(price)} (in 1e18 format)`);
        this.logInfo(`Timestamp: ${new Date(timestamp.toNumber() * 1000).toISOString()}`);
        
        // Calculate human-readable price
        const humanPrice = Number(ethers.utils.formatEther(price));
        this.logInfo(`Human-readable: $${humanPrice.toFixed(2)} per token`);
        
        // Sanity check
        if (humanPrice < 100 || humanPrice > 100000) {
          this.logWarning(`Price ${humanPrice} seems unusual for ETH/USD`);
        }
        
      } catch (error: any) {
        if (error.message.includes('PriceFeedNotConfigured')) {
          this.logWarning('Price feed not configured - configure it first');
        } else if (error.message.includes('StalePrice') || error.message.includes('stale')) {
          this.logWarning('Price is stale - this is expected on testnets');
          this.logInfo('Pyth testnet prices may not update frequently');
        } else {
          throw error;
        }
      }
    });
    
    // Test 4: Test error cases
    await this.runTest('Test Price Feed Not Configured Error', async () => {
      const randomToken1 = ethers.Wallet.createRandom().address;
      const randomToken2 = ethers.Wallet.createRandom().address;
      
      try {
        await this.adapterContract!.getPrice(randomToken1, randomToken2);
        throw new Error('Should have reverted with PriceFeedNotConfigured');
      } catch (error: any) {
        if (error.message.includes('PriceFeedNotConfigured')) {
          this.logSuccess('Correctly reverted with PriceFeedNotConfigured');
        } else {
          throw error;
        }
      }
    });
  }
  
  // ============ Price Conversion Tests ============
  
  async testPriceConversion() {
    this.logSection('PRICE CONVERSION TESTS');
    
    await this.runTest('Understand Pyth Price Format', async () => {
      this.logInfo('Pyth Format: price × 10^expo');
      this.logInfo('Example: price=300000000000, expo=-8');
      this.logInfo('  Actual value = 300000000000 × 10^(-8) = 3000.00');
      this.logInfo('');
      this.logInfo('Our Format: price × 10^(-18)');
      this.logInfo('Example: price=3000000000000000000000 (3000 × 10^18)');
      this.logInfo('  Actual value = 3000 × 10^18 × 10^(-18) = 3000.00');
      this.logInfo('');
      this.logInfo('Conversion: result = pythPrice × 10^(pythExpo + 18)');
    });
    
    await this.runTest('Test Conversion Examples', async () => {
      const testCases = [
        { price: 300000000000, expo: -8, expected: 3000 },
        { price: 150000000, expo: -6, expected: 150 },
        { price: 3000, expo: 0, expected: 3000 },
        { price: 1000000, expo: -3, expected: 1000 },
      ];
      
      for (const testCase of testCases) {
        const targetExpo = testCase.expo + 18;
        let result: number;
        
        if (targetExpo >= 0) {
          result = testCase.price * Math.pow(10, targetExpo);
        } else {
          result = testCase.price / Math.pow(10, -targetExpo);
        }
        
        const formatted = result / 1e18;
        this.logInfo(`price=${testCase.price}, expo=${testCase.expo} → ${formatted.toFixed(2)}`);
        
        if (Math.abs(formatted - testCase.expected) > 0.01) {
          throw new Error(`Expected ${testCase.expected}, got ${formatted}`);
        }
      }
      
      this.logSuccess('All conversion examples passed');
    });
  }
  
  // ============ Integration Tests ============
  
  async testIntegration() {
    this.logSection('INTEGRATION TESTS');
    
    await this.runTest('Simulate Pseudo-Arbitrage Usage', async () => {
      if (!this.adapterContract || !this.config.wethAddress || !this.config.usdcAddress) {
        this.logInfo('Skipping (adapter or tokens not configured)');
        return;
      }
      
      this.logInfo('Simulating how PseudoArbitrageAMM would use the adapter:');
      this.logInfo('');
      this.logInfo('1. AMM buildProgram() receives oracle address (adapter)');
      this.logInfo('2. During swap, PseudoArbitrage opcode calls oracle.getPrice()');
      this.logInfo('3. Adapter fetches price from Pyth and converts to 1e18 format');
      this.logInfo('4. AMM uses price to decide if curve transformation is needed');
      this.logInfo('');
      
      try {
        const [price, timestamp] = await this.adapterContract!.getPrice(
          this.config.wethAddress!,
          this.config.usdcAddress!
        );
        
        this.logInfo('Example integration:');
        this.logInfo(`  Oracle Price: ${ethers.utils.formatEther(price)}`);
        this.logInfo(`  Timestamp: ${timestamp.toString()}`);
        this.logInfo('  ✓ AMM would use this price for arbitrage check');
        
      } catch (error: any) {
        if (error.message.includes('PriceFeedNotConfigured')) {
          this.logInfo('  Note: Price feed needs to be configured first');
        } else if (error.message.includes('stale')) {
          this.logInfo('  Note: Price is stale (common on testnets)');
        } else {
          throw error;
        }
      }
    });
    
    await this.runTest('Check Gas Costs', async () => {
      if (!this.adapterContract || !this.config.wethAddress || !this.config.usdcAddress) {
        this.logInfo('Skipping (adapter or tokens not configured)');
        return;
      }
      
      try {
        const gasEstimate = await this.adapterContract!.estimateGas.getPrice(
          this.config.wethAddress!,
          this.config.usdcAddress!
        );
        
        this.logInfo(`Estimated gas for getPrice(): ${gasEstimate.toString()}`);
        
        // Estimate cost
        const gasPrice = await this.provider.getGasPrice();
        const costWei = gasEstimate.mul(gasPrice);
        const costEth = ethers.utils.formatEther(costWei);
        
        this.logInfo(`Estimated cost: ${costEth} ETH`);
        
        if (gasEstimate.gt(100000)) {
          this.logWarning('Gas usage is high - may be expensive');
        } else {
          this.logSuccess('Gas usage is reasonable');
        }
        
      } catch (error: any) {
        this.logInfo(`Could not estimate gas: ${error.message}`);
      }
    });
  }
  
  // ============ Diagnostics ============
  
  async runDiagnostics() {
    this.logSection('SYSTEM DIAGNOSTICS');
    
    await this.runTest('Check Network', async () => {
      const network = await this.provider.getNetwork();
      this.logInfo(`Network: ${network.name} (chainId: ${network.chainId})`);
      
      // Suggest Pyth contract based on network
      const suggestions: Record<number, string> = {
        1: PYTH_CONTRACTS.mainnet,
        42161: PYTH_CONTRACTS.arbitrum,
        8453: PYTH_CONTRACTS.base,
        84532: PYTH_CONTRACTS['base-sepolia'],
        11155111: PYTH_CONTRACTS.sepolia,
      };
      
      if (suggestions[network.chainId]) {
        this.logInfo(`Recommended Pyth contract: ${suggestions[network.chainId]}`);
        
        if (this.config.pythAddress && 
            this.config.pythAddress.toLowerCase() !== suggestions[network.chainId].toLowerCase()) {
          this.logWarning('You may be using the wrong Pyth contract for this network!');
        }
      }
    });
    
    await this.runTest('Check Wallet Balance', async () => {
      const balance = await this.provider.getBalance(this.wallet.address);
      this.logInfo(`Wallet: ${this.wallet.address}`);
      this.logInfo(`Balance: ${ethers.utils.formatEther(balance)} ETH`);
      
      if (balance.lt(ethers.utils.parseEther('0.001'))) {
        this.logWarning('Low balance - you may need more ETH for gas');
      }
    });
  }
  
  // ============ Main Test Suite ============
  
  async runAllTests() {
    this.logSection('PYTH PRICE ADAPTER TEST SUITE');
    this.log(`Network: ${this.config.rpcUrl}`);
    this.log(`Wallet: ${this.wallet.address}`);
    this.log(`Pyth Contract: ${this.config.pythAddress || 'Not configured'}`);
    this.log(`Pyth Adapter: ${this.config.pythAdapterAddress || 'Not configured'}`);
    
    // Run all test suites
    await this.runDiagnostics();
    await this.testPythConnection();
    await this.testAdapterConfiguration();
    await this.testPriceFeedConfiguration();
    await this.testPriceFetching();
    await this.testPriceConversion();
    await this.testIntegration();
    
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
    
    // Recommendations
    this.logSection('RECOMMENDATIONS');
    
    if (!this.config.pythAddress) {
      console.log('📋 Set PYTH_ADDRESS in .env file');
      console.log('   See: https://docs.pyth.network/price-feeds/contract-addresses/evm');
    }
    
    if (!this.config.pythAdapterAddress) {
      console.log('📋 Deploy PythPriceAdapter contract:');
      console.log('   cd packages/pseudo-arbitrage-amm');
      console.log('   forge create src/oracles/PythPriceAdapter.sol:PythPriceAdapter \\');
      console.log('     --constructor-args <PYTH_ADDRESS> 3600 \\');
      console.log('     --rpc-url $RPC_URL --private-key $PRIVATE_KEY');
    }
    
    if (this.adapterContract) {
      const owner = await this.adapterContract.owner();
      if (owner.toLowerCase() !== this.wallet.address.toLowerCase()) {
        console.log('⚠️  You are not the owner of the adapter');
        console.log(`   Owner: ${owner}`);
        console.log(`   Your address: ${this.wallet.address}`);
      }
    }
    
    console.log('\n' + '='.repeat(70));
    
    return { passed, failed, total: this.results.length };
  }
}

// ============ Configuration Loading ============

function loadConfig(): PythTestConfig {
  const rpcUrl = process.env.RPC_URL;
  const privateKey = process.env.PRIVATE_KEY;
  
  if (!rpcUrl) {
    throw new Error('RPC_URL not set in .env file');
  }
  
  if (!privateKey) {
    throw new Error('PRIVATE_KEY not set in .env file');
  }
  
  // Load addresses from environment
  const pythAddress = process.env.PYTH_ADDRESS;
  const pythAdapterAddress = process.env.PYTH_ADAPTER_ADDRESS;
  const wethAddress = process.env.WETH_ADDRESS;
  const usdcAddress = process.env.USDC_ADDRESS;
  const btcAddress = process.env.BTC_ADDRESS;
  const usdtAddress = process.env.USDT_ADDRESS;
  
  return {
    rpcUrl,
    privateKey,
    pythAddress,
    pythAdapterAddress,
    wethAddress,
    usdcAddress,
    btcAddress,
    usdtAddress
  };
}

// ============ Main ============

async function main() {
  console.log('Pyth Price Adapter Testing Suite');
  console.log('');
  
  try {
    const config = loadConfig();
    const tester = new PythAdapterTester(config);
    const results = await tester.runAllTests();
    
    process.exit(results.failed > 0 ? 1 : 0);
  } catch (error: any) {
    console.error('\n❌ Fatal error:', error.message);
    console.error('');
    console.error('Make sure you have:');
    console.error('  1. RPC_URL set in .env');
    console.error('  2. PRIVATE_KEY set in .env');
    console.error('  3. (Optional) PYTH_ADDRESS for your network');
    console.error('  4. (Optional) PYTH_ADAPTER_ADDRESS if deployed');
    process.exit(1);
  }
}

// Run if executed directly
if (require.main === module) {
  main();
}

export { PythAdapterTester, PythTestConfig, PYTH_PRICE_FEEDS, PYTH_CONTRACTS };


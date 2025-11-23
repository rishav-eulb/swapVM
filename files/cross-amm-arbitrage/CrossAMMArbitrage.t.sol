// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { Aqua } from "aqua/Aqua.sol";
import { ConcentratedAMM } from "../concentrated-amm/ConcentratedAMM.sol";
import { ConcentratedAMMStrategyBuilder } from "../concentrated-amm/ConcentratedAMMStrategyBuilder.sol";
import { CrossAMMArbitrage } from "./CrossAMMArbitrage.sol";
import { CrossAMMArbitrageBot } from "./CrossAMMArbitrageBot.sol";
import { IArbitrageCallback } from "./interfaces/IArbitrageCallback.sol";
import { IConcentratedAMMCallback } from "../concentrated-amm/interfaces/IConcentratedAMMCallback.sol";
import { PseudoArbitrageSwapVMRouter } from "../pseudo-arbitrage-amm/src/routers/PseudoArbitrageSwapVMRouter.sol";
import { PseudoArbitrageAMM } from "../pseudo-arbitrage-amm/src/strategies/PseudoArbitrageAMM.sol";
import { ISwapVM } from "swap-vm/interfaces/ISwapVM.sol";

// Mock ERC20
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Mock Oracle for testing
contract MockOracle {
    uint256 public price;
    
    constructor(uint256 initialPrice) {
        price = initialPrice;
    }
    
    function setPrice(uint256 newPrice) external {
        price = newPrice;
    }
    
    function getPrice(address /* tokenIn */, address /* tokenOut */) external view returns (uint256) {
        return price;
    }
}

// Simple arbitrageur
contract SimpleArbitrageur is IArbitrageCallback, IConcentratedAMMCallback {
    Aqua public aqua;
    
    constructor(Aqua aqua_) {
        aqua = aqua_;
    }
    
    function borrowForArbitrage(
        address token,
        uint256 amount,
        bytes calldata /* data */
    ) external override {
        IERC20(token).transfer(msg.sender, amount);
    }
    
    function concentratedAMMCallback(
        address tokenIn,
        address /* tokenOut */,
        uint256 amountIn,
        uint256 /* amountOut */,
        address maker,
        address app,
        bytes32 strategyHash,
        bytes calldata /* takerData */
    ) external override {
        IERC20(tokenIn).approve(address(aqua), amountIn);
        aqua.push(maker, app, strategyHash, tokenIn, amountIn);
    }
}

contract CrossAMMArbitrageTest is Test {
    Aqua public aqua;
    ConcentratedAMM public concentratedAMM;
    ConcentratedAMMStrategyBuilder public concentratedBuilder;
    PseudoArbitrageSwapVMRouter public pseudoArbRouter;
    PseudoArbitrageAMM public pseudoArbBuilder;
    CrossAMMArbitrage public arbitrage;
    CrossAMMArbitrageBot public bot;
    SimpleArbitrageur public arbitrageur;
    MockOracle public oracle;
    
    MockERC20 public tokenX;
    MockERC20 public tokenY;
    
    address public maker1 = address(0x1);
    address public maker2 = address(0x2);
    address public keeper = address(0x3);
    
    uint256 constant INITIAL_LIQUIDITY = 10_000e18;
    uint256 constant INITIAL_PRICE = 2e18;
    uint256 constant UPDATED_PRICE = 2.2e18; // 10% increase
    
    ConcentratedAMM.Strategy public concentratedStrategy;
    ISwapVM.Order public pseudoArbOrder;
    
    function setUp() public {
        // Deploy infrastructure
        aqua = new Aqua();
        concentratedAMM = new ConcentratedAMM(aqua);
        concentratedBuilder = new ConcentratedAMMStrategyBuilder(aqua, concentratedAMM);
        
        // Deploy tokens
        tokenX = new MockERC20("TokenX", "X");
        tokenY = new MockERC20("TokenY", "Y");
        if (address(tokenX) > address(tokenY)) {
            (tokenX, tokenY) = (tokenY, tokenX);
        }
        
        // Deploy oracle
        oracle = new MockOracle(INITIAL_PRICE);
        
        // Deploy PseudoArbitrage
        pseudoArbRouter = new PseudoArbitrageSwapVMRouter(address(aqua), "PseudoArb", "1.0");
        pseudoArbBuilder = new PseudoArbitrageAMM(address(aqua));
        
        // Deploy arbitrage system
        arbitrage = new CrossAMMArbitrage(aqua, pseudoArbRouter);
        bot = new CrossAMMArbitrageBot(arbitrage);
        arbitrageur = new SimpleArbitrageur(aqua);
        
        // Mint tokens
        tokenX.mint(maker1, INITIAL_LIQUIDITY * 4);
        tokenY.mint(maker1, INITIAL_LIQUIDITY * 4);
        tokenX.mint(maker2, INITIAL_LIQUIDITY * 4);
        tokenY.mint(maker2, INITIAL_LIQUIDITY * 4);
        tokenX.mint(address(arbitrageur), 1000e18);
        tokenY.mint(address(arbitrageur), 2000e18);
        tokenX.mint(keeper, 1000e18);
        
        // Setup approvals for makers
        vm.startPrank(maker1);
        tokenX.approve(address(concentratedBuilder), type(uint256).max);
        tokenY.approve(address(concentratedBuilder), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(maker2);
        tokenX.approve(address(aqua), type(uint256).max);
        tokenY.approve(address(aqua), type(uint256).max);
        vm.stopPrank();
        
        // Setup arbitrageur approvals
        vm.startPrank(address(arbitrageur));
        tokenX.approve(address(arbitrage), type(uint256).max);
        tokenY.approve(address(arbitrage), type(uint256).max);
        tokenX.approve(address(concentratedAMM), type(uint256).max);
        tokenY.approve(address(concentratedAMM), type(uint256).max);
        tokenX.approve(address(pseudoArbRouter), type(uint256).max);
        tokenY.approve(address(pseudoArbRouter), type(uint256).max);
        vm.stopPrank();
        
        // Create ConcentratedAMM position
        vm.prank(maker1);
        concentratedBuilder.createAndShipStrategy(
            address(tokenX),
            address(tokenY),
            INITIAL_PRICE * 9 / 10,  // -10%
            INITIAL_PRICE * 11 / 10, // +10%
            INITIAL_PRICE,
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY * 2,
            30,
            bytes32(uint256(1))
        );
        
        // Build concentrated strategy
        concentratedStrategy = _buildConcentratedStrategy();
        
        // Create PseudoArbitrage position
        pseudoArbOrder = pseudoArbBuilder.buildProgram(
            maker2,
            uint40(block.timestamp + 30 days),
            address(tokenX),
            address(tokenY),
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY * 2,
            address(oracle),
            INITIAL_PRICE,
            1 hours,
            30,
            0
        );
        
        vm.prank(maker2);
        aqua.ship(
            address(pseudoArbRouter),
            abi.encode(pseudoArbOrder),
            [address(tokenX), address(tokenY)],
            [INITIAL_LIQUIDITY, INITIAL_LIQUIDITY * 2]
        );
    }
    
    /// @notice Test detecting arbitrage opportunity
    function testDetectOpportunity() public {
        console.log("=== Testing Opportunity Detection ===");
        
        // Initially, no opportunity (both at same price)
        CrossAMMArbitrage.CrossAMMOpportunity memory opp = _buildOpportunity();
        
        (bool exists1, uint256 profit1, uint256 discrepancy1) = 
            arbitrage.checkOpportunity(opp, 50, 100e18);
        
        console.log("Before price update:");
        console.log("  Opportunity exists:", exists1);
        console.log("  Estimated profit:", profit1);
        console.log("  Discrepancy:", discrepancy1);
        
        // Update oracle price (PseudoArbitrage will update, Concentrated won't)
        oracle.setPrice(UPDATED_PRICE);
        
        // Now there should be opportunity!
        (bool exists2, uint256 profit2, uint256 discrepancy2) = 
            arbitrage.checkOpportunity(opp, 50, 100e18);
        
        console.log("\nAfter price update:");
        console.log("  Opportunity exists:", exists2);
        console.log("  Estimated profit:", profit2);
        console.log("  Discrepancy:", discrepancy2);
        
        assertTrue(exists2, "Opportunity should exist after price update");
        assertTrue(profit2 > 0, "Should have positive profit");
        assertTrue(discrepancy2 > 100, "Should have >1% discrepancy");
    }
    
    /// @notice Test executing cross-AMM arbitrage
    function testExecuteArbitrage() public {
        console.log("=== Testing Arbitrage Execution ===");
        
        // Update oracle to create opportunity
        oracle.setPrice(UPDATED_PRICE);
        
        CrossAMMArbitrage.CrossAMMOpportunity memory opp = _buildOpportunity();
        
        // Check opportunity
        (bool exists, uint256 estimatedProfit, uint256 discrepancy) = 
            arbitrage.checkOpportunity(opp, 50, 100e18);
        
        console.log("Opportunity check:");
        console.log("  Exists:", exists);
        console.log("  Estimated profit:", estimatedProfit);
        console.log("  Discrepancy:", discrepancy, "bps");
        
        assertTrue(exists, "Opportunity should exist");
        
        // Execute arbitrage
        uint256 balanceBefore = tokenX.balanceOf(address(arbitrageur));
        
        vm.prank(address(arbitrageur));
        CrossAMMArbitrage.ArbitrageResult memory result = arbitrage.executeArbitrage(
            opp,
            100e18,
            0
        );
        
        uint256 balanceAfter = tokenX.balanceOf(address(arbitrageur));
        
        console.log("\nArbitrage result:");
        console.log("  Amount in:", result.amountIn);
        console.log("  Amount out:", result.amountOut);
        console.log("  Profit:", result.profit);
        console.log("  Discrepancy:", result.priceDiscrepancyBps, "bps");
        console.log("  Gas used:", result.gasUsed);
        
        assertTrue(result.profit > 0, "Should have profit");
        assertEq(balanceAfter, balanceBefore + result.profit, "Balance should increase by profit");
    }
    
    /// @notice Test optimal amount calculation
    function testOptimalAmount() public {
        console.log("=== Testing Optimal Amount Calculation ===");
        
        // Create large price discrepancy
        oracle.setPrice(UPDATED_PRICE * 12 / 10); // 20% higher
        
        CrossAMMArbitrage.CrossAMMOpportunity memory opp = _buildOpportunity();
        
        uint256 maxAmount = 500e18;
        uint256 optimalAmount = arbitrage.calculateOptimalAmount(opp, maxAmount);
        
        console.log("Max amount:", maxAmount);
        console.log("Optimal amount:", optimalAmount);
        console.log("Optimal %:", (optimalAmount * 100) / maxAmount, "%");
        
        // Verify optimal amount is reasonable
        assertTrue(optimalAmount > 0, "Should have optimal amount");
        assertTrue(optimalAmount <= maxAmount, "Should not exceed max");
        
        // Test that we can execute with optimal amount (indirect test of profitability)
        (bool exists, uint256 estimatedProfit, ) = arbitrage.checkOpportunity(opp, 50, optimalAmount);
        assertTrue(exists, "Opportunity should exist at optimal amount");
        assertTrue(estimatedProfit > 0, "Should have positive profit at optimal amount");
    }
    
    /// @notice Test bot execution
    function testBotExecution() public {
        console.log("=== Testing Bot Execution ===");
        
        // Fund bot
        vm.startPrank(keeper);
        tokenX.approve(address(bot), type(uint256).max);
        bot.depositCapital(address(tokenX), 500e18);
        bot.setMinProfitBps(30); // 0.3%
        vm.stopPrank();
        
        // Update price
        oracle.setPrice(UPDATED_PRICE);
        
        // Add strategy
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
        
        vm.prank(keeper);
        uint256 strategyId = bot.addStrategy(
            address(tokenX),
            address(tokenY),
            concentratedConfigs,
            pseudoArbConfigs
        );
        
        console.log("Strategy added:", strategyId);
        
        // Execute via bot
        uint256 capitalBefore = bot.availableCapital(address(tokenX));
        
        vm.prank(keeper);
        (bool executed, uint256 profit) = bot.scanAndExecuteStrategy(strategyId);
        
        uint256 capitalAfter = bot.availableCapital(address(tokenX));
        
        console.log("Executed:", executed);
        console.log("Profit:", profit);
        console.log("Capital before:", capitalBefore);
        console.log("Capital after:", capitalAfter);
        
        assertTrue(executed, "Should execute arbitrage");
        assertTrue(profit > 0, "Should have profit");
        assertTrue(capitalAfter > capitalBefore, "Capital should increase");
    }
    
    /// @notice Test monitoring and auto-execution
    function testMonitoringLoop() public {
        console.log("=== Testing Monitoring Loop ===");
        
        // Setup bot
        vm.startPrank(keeper);
        tokenX.approve(address(bot), type(uint256).max);
        bot.depositCapital(address(tokenX), 500e18);
        bot.setMinProfitBps(30);
        vm.stopPrank();
        
        // Add strategy
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
        
        vm.prank(keeper);
        bot.addStrategy(address(tokenX), address(tokenY), concentratedConfigs, pseudoArbConfigs);
        
        // Simulate monitoring loop
        uint256 totalProfit = 0;
        
        for (uint256 i = 0; i < 5; i++) {
            console.log("\n--- Iteration", i + 1, "---");
            
            // Update price to create opportunity
            uint256 newPrice = INITIAL_PRICE + (i * 0.1e18); // Increase by 0.1 each time
            oracle.setPrice(newPrice);
            console.log("Oracle price:", newPrice);
            
            // Check for opportunities
            (bool hasOpp, uint256 bestProfit) = bot.checkForOpportunities();
            console.log("Has opportunity:", hasOpp);
            console.log("Best profit:", bestProfit);
            
            if (hasOpp) {
                // Execute
                vm.prank(keeper);
                (bool executed, uint256 profit) = bot.scanAllStrategies();
                
                if (executed) {
                    console.log("Executed! Profit:", profit);
                    totalProfit += profit;
                }
            }
            
            // Simulate time passing
            vm.warp(block.timestamp + 1 hours);
        }
        
        console.log("\n=== Final Results ===");
        console.log("Total profit:", totalProfit);
        
        // Get performance stats
        CrossAMMArbitrageBot.PerformanceStats memory stats = bot.getPerformanceStats(address(tokenX));
        console.log("Total executions:", stats.totalExecutions);
        console.log("Largest profit:", stats.largestProfit);
    }
    
    /// @notice Test multiple strategies
    function testMultipleStrategies() public {
        console.log("=== Testing Multiple Strategies ===");
        
        // Setup bot
        vm.startPrank(keeper);
        tokenX.approve(address(bot), type(uint256).max);
        bot.depositCapital(address(tokenX), 1000e18);
        vm.stopPrank();
        
        // Add multiple strategies with different AMM configs
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
        
        vm.startPrank(keeper);
        uint256 strategy1 = bot.addStrategy(address(tokenX), address(tokenY), concentratedConfigs, pseudoArbConfigs);
        // Could add more strategies here for different pairs
        vm.stopPrank();
        
        console.log("Added strategies:", strategy1 + 1);
        
        // Update price
        oracle.setPrice(UPDATED_PRICE);
        
        // Scan all strategies
        vm.prank(keeper);
        (bool executed, uint256 profit) = bot.scanAllStrategies();
        
        console.log("Scan all strategies:");
        console.log("  Executed:", executed);
        console.log("  Profit:", profit);
        
        assertTrue(executed, "Should execute");
        assertTrue(profit > 0, "Should have profit");
    }
    
    /// @notice Test performance tracking
    function testPerformanceTracking() public view {
        console.log("=== Testing Performance Tracking ===");
        
        CrossAMMArbitrageBot.PerformanceStats memory stats = bot.getPerformanceStats(address(tokenX));
        
        console.log("Performance stats:");
        console.log("  Total executions:", stats.totalExecutions);
        console.log("  Total profit:", stats.totalProfit);
        console.log("  Total gas used:", stats.totalGasUsed);
        console.log("  Largest profit:", stats.largestProfit);
        console.log("  Last execution:", stats.lastExecutionTime);
    }
    
    /// ============ Helper Functions ============
    
    function _buildConcentratedStrategy() internal view returns (ConcentratedAMM.Strategy memory) {
        int24 tickLower = concentratedBuilder.priceToTick(INITIAL_PRICE * 9 / 10);
        int24 tickUpper = concentratedBuilder.priceToTick(INITIAL_PRICE * 11 / 10);
        
        uint128 liquidity = concentratedBuilder.calculateLiquidityFromAmounts(
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY * 2,
            INITIAL_PRICE * 9 / 10,
            INITIAL_PRICE * 11 / 10,
            INITIAL_PRICE
        );
        
        return ConcentratedAMM.Strategy({
            maker: maker1,
            token0: address(tokenX),
            token1: address(tokenY),
            tickLower: tickLower,
            tickUpper: tickUpper,
            feeBps: 30,
            liquidity: liquidity,
            salt: bytes32(uint256(1))
        });
    }
    
    function _buildOpportunity() internal view returns (CrossAMMArbitrage.CrossAMMOpportunity memory) {
        return CrossAMMArbitrage.CrossAMMOpportunity({
            token0: address(tokenX),
            token1: address(tokenY),
            cheapAMM: CrossAMMArbitrage.AMMConfig({
                ammType: CrossAMMArbitrage.AMMType.ConcentratedAMM,
                ammAddress: address(concentratedAMM),
                strategyData: abi.encode(concentratedStrategy)
            }),
            expensiveAMM: CrossAMMArbitrage.AMMConfig({
                ammType: CrossAMMArbitrage.AMMType.PseudoArbitrageAMM,
                ammAddress: address(pseudoArbRouter),
                strategyData: abi.encode(pseudoArbOrder)
            }),
            minProfitBps: 50
        });
    }
}

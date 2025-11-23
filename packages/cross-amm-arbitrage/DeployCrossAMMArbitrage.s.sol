// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Aqua } from "aqua/Aqua.sol";
import { ConcentratedAMM } from "concentrated-amm/ConcentratedAMM.sol";
import { ConcentratedAMMStrategyBuilder } from "concentrated-amm/ConcentratedAMMStrategyBuilder.sol";
import { PseudoArbitrageSwapVMRouter } from "pseudo-arbitrage-amm/src/routers/PseudoArbitrageSwapVMRouter.sol";
import { PseudoArbitrageAMM } from "pseudo-arbitrage-amm/src/strategies/PseudoArbitrageAMM.sol";
import { ISwapVM } from "swap-vm/interfaces/ISwapVM.sol";
import { CrossAMMArbitrage } from "./CrossAMMArbitrage.sol";
import { CrossAMMArbitrageBot } from "./CrossAMMArbitrageBot.sol";

/**
 * @title DeployCrossAMMArbitrage
 * @notice Deployment script for Cross-AMM Arbitrage system
 * 
 * Usage:
 *   forge script script/DeployCrossAMMArbitrage.s.sol:DeployCrossAMMArbitrage --rpc-url $RPC_URL --broadcast
 */
contract DeployCrossAMMArbitrage is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Aqua (if not already deployed)
        Aqua aqua = new Aqua();
        console.log("Aqua deployed at:", address(aqua));

        // 2. Deploy ConcentratedAMM infrastructure
        ConcentratedAMM concentratedAMM = new ConcentratedAMM(aqua);
        console.log("ConcentratedAMM deployed at:", address(concentratedAMM));

        ConcentratedAMMStrategyBuilder concentratedBuilder = new ConcentratedAMMStrategyBuilder(
            aqua,
            concentratedAMM
        );
        console.log("ConcentratedAMMStrategyBuilder deployed at:", address(concentratedBuilder));

        // 3. Deploy PseudoArbitrage infrastructure
        PseudoArbitrageSwapVMRouter pseudoArbRouter = new PseudoArbitrageSwapVMRouter(
            address(aqua),
            "CrossAMMPseudoArb",
            "1.0"
        );
        console.log("PseudoArbitrageSwapVMRouter deployed at:", address(pseudoArbRouter));

        PseudoArbitrageAMM pseudoArbBuilder = new PseudoArbitrageAMM(address(aqua));
        console.log("PseudoArbitrageAMM deployed at:", address(pseudoArbBuilder));

        // 4. Deploy arbitrage system
        CrossAMMArbitrage arbitrage = new CrossAMMArbitrage(aqua, pseudoArbRouter);
        console.log("CrossAMMArbitrage deployed at:", address(arbitrage));

        CrossAMMArbitrageBot bot = new CrossAMMArbitrageBot(arbitrage);
        console.log("CrossAMMArbitrageBot deployed at:", address(bot));

        vm.stopBroadcast();

        // Output deployment info
        console.log("\n=== Deployment Complete ===");
        console.log("Aqua:", address(aqua));
        console.log("ConcentratedAMM:", address(concentratedAMM));
        console.log("ConcentratedBuilder:", address(concentratedBuilder));
        console.log("PseudoArbRouter:", address(pseudoArbRouter));
        console.log("PseudoArbBuilder:", address(pseudoArbBuilder));
        console.log("Arbitrage:", address(arbitrage));
        console.log("Bot:", address(bot));
    }
}

/**
 * @title SetupExampleStrategy
 * @notice Setup example arbitrage strategy
 * 
 * Usage:
 *   forge script script/DeployCrossAMMArbitrage.s.sol:SetupExampleStrategy --rpc-url $RPC_URL --broadcast
 */
contract SetupExampleStrategy is Script {
    function run() external {
        // Load environment variables
        address aquaAddress = vm.envAddress("AQUA_ADDRESS");
        address concentratedAMMAddress = vm.envAddress("CONCENTRATED_AMM_ADDRESS");
        address pseudoArbRouterAddress = vm.envAddress("PSEUDO_ARB_ROUTER_ADDRESS");
        address botAddress = vm.envAddress("BOT_ADDRESS");
        address tokenX = vm.envAddress("TOKEN_X");
        address tokenY = vm.envAddress("TOKEN_Y");
        address oracle = vm.envAddress("ORACLE_ADDRESS");

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        // Load contracts
        Aqua aqua = Aqua(aquaAddress);
        ConcentratedAMM concentratedAMM = ConcentratedAMM(concentratedAMMAddress);
        PseudoArbitrageSwapVMRouter pseudoArbRouter = PseudoArbitrageSwapVMRouter(pseudoArbRouterAddress);
        CrossAMMArbitrageBot bot = CrossAMMArbitrageBot(botAddress);

        // 1. Create ConcentratedAMM position
        ConcentratedAMMStrategyBuilder concentratedBuilder = new ConcentratedAMMStrategyBuilder(aqua, concentratedAMM);
        
        uint256 initialPrice = 2e18; // 1 X = 2 Y
        uint256 liquidity = 10000e18;

        concentratedBuilder.createAndShipStrategy(
            tokenX,
            tokenY,
            initialPrice * 9 / 10,  // -10%
            initialPrice * 11 / 10, // +10%
            initialPrice,
            liquidity,
            liquidity * 2,
            30, // 0.3% fee
            bytes32(uint256(1))
        );

        console.log("ConcentratedAMM position created");

        // 2. Create PseudoArbitrage position
        PseudoArbitrageAMM pseudoArbBuilder = new PseudoArbitrageAMM(address(aqua));

        ISwapVM.Order memory order = pseudoArbBuilder.buildProgram(
            msg.sender, // maker
            uint40(block.timestamp + 30 days),
            tokenX,
            tokenY,
            liquidity,
            liquidity * 2,
            oracle,
            initialPrice,
            1 hours, // min update interval
            30, // 0.3% fee
            0 // no salt
        );

        aqua.ship(
            address(pseudoArbRouter),
            abi.encode(order),
            [tokenX, tokenY],
            [liquidity, liquidity * 2]
        );

        console.log("PseudoArbitrage position created");

        // 3. Fund and configure bot
        IERC20(tokenX).approve(address(bot), 500e18);
        bot.depositCapital(tokenX, 500e18);
        
        bot.setMinProfitBps(50); // 0.5%
        bot.setMinDiscrepancyBps(100); // 1%
        bot.setMaxCapitalPerArbitrage(tokenX, 100e18);

        console.log("Bot funded and configured");

        vm.stopBroadcast();

        console.log("\n=== Setup Complete ===");
        console.log("Ready to monitor for arbitrage opportunities!");
    }
}

/**
 * @title MonitorOpportunities
 * @notice Check for current arbitrage opportunities
 * 
 * Usage:
 *   forge script script/DeployCrossAMMArbitrage.s.sol:MonitorOpportunities --rpc-url $RPC_URL
 */
contract MonitorOpportunities is Script {
    function run() external view {
        address botAddress = vm.envAddress("BOT_ADDRESS");
        CrossAMMArbitrageBot bot = CrossAMMArbitrageBot(botAddress);

        console.log("=== Monitoring Opportunities ===\n");

        // Check for opportunities
        (bool hasOpportunities, uint256 bestProfit) = bot.checkForOpportunities();

        console.log("Has Opportunities:", hasOpportunities);
        console.log("Best Estimated Profit:", bestProfit);

        // Get bot status
        address tokenX = vm.envAddress("TOKEN_X");
        (uint256 available, uint256 maxPer, uint256 utilization) = bot.getCapitalStatus(tokenX);

        console.log("\nBot Capital Status:");
        console.log("  Available:", available);
        console.log("  Max per arbitrage:", maxPer);
        console.log("  Utilization:", utilization, "bps");

        // Get performance
        CrossAMMArbitrageBot.PerformanceStats memory stats = bot.getPerformanceStats(tokenX);

        console.log("\nPerformance Stats:");
        console.log("  Total Executions:", stats.totalExecutions);
        console.log("  Total Profit:", stats.totalProfit);
        console.log("  Largest Profit:", stats.largestProfit);
        console.log("  Total Gas Used:", stats.totalGasUsed);

        if (stats.totalExecutions > 0) {
            console.log("  Average Profit:", stats.totalProfit / stats.totalExecutions);
            console.log("  Average Gas:", stats.totalGasUsed / stats.totalExecutions);
        }
    }
}

/**
 * @title ExecuteArbitrage
 * @notice Execute arbitrage if opportunity exists
 * 
 * Usage:
 *   forge script script/DeployCrossAMMArbitrage.s.sol:ExecuteArbitrage --rpc-url $RPC_URL --broadcast
 */
contract ExecuteArbitrage is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address botAddress = vm.envAddress("BOT_ADDRESS");
        
        vm.startBroadcast(privateKey);

        CrossAMMArbitrageBot bot = CrossAMMArbitrageBot(botAddress);

        console.log("=== Attempting Arbitrage Execution ===\n");

        // Scan and execute
        (bool executed, uint256 profit) = bot.scanAllStrategies();

        if (executed) {
            console.log("✓ Arbitrage executed successfully!");
            console.log("  Profit:", profit);
        } else {
            console.log("✗ No profitable opportunities found");
        }

        vm.stopBroadcast();
    }
}

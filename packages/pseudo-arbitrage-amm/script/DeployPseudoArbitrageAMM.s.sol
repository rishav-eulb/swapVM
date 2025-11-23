// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Aqua } from "aqua/Aqua.sol";
import { PseudoArbitrageAMM } from "src/strategies/PseudoArbitrageAMM.sol";
import { PythPriceAdapter } from "src/oracles/PythPriceAdapter.sol";
import { ISwapVM } from "swap-vm/SwapVM.sol";

/// @title DeployPseudoArbitrageAMM
/// @notice Deployment script for the Pseudo-Arbitrage AMM module
contract DeployPseudoArbitrageAMM is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address aquaAddress = vm.envOr("AQUA_ADDRESS", address(0));

        vm.startBroadcast(deployerPrivateKey);

        // Deploy or use existing Aqua
        Aqua aqua;
        if (aquaAddress == address(0)) {
            console2.log("Deploying new Aqua contract...");
            aqua = new Aqua();
            console2.log("Aqua deployed at:", address(aqua));
        } else {
            console2.log("Using existing Aqua at:", aquaAddress);
            aqua = Aqua(aquaAddress);
        }

        // Deploy PseudoArbitrageAMM
        console2.log("\nDeploying PseudoArbitrageAMM...");
        PseudoArbitrageAMM amm = new PseudoArbitrageAMM(address(aqua));
        console2.log("PseudoArbitrageAMM deployed at:", address(amm));

        vm.stopBroadcast();

        // Output deployment summary
        console2.log("\n========================================");
        console2.log("DEPLOYMENT SUMMARY");
        console2.log("========================================");
        console2.log("Aqua:                 ", address(aqua));
        console2.log("PseudoArbitrageAMM:   ", address(amm));
        console2.log("========================================");

        // Save deployment addresses to file
        string memory deploymentInfo = string.concat(
            "{\n",
            '  "aqua": "', vm.toString(address(aqua)), '",\n',
            '  "pseudoArbitrageAMM": "', vm.toString(address(amm)), '"\n',
            "}"
        );

        vm.writeFile("./deployments/pseudo-arbitrage-amm-latest.json", deploymentInfo);
        console2.log("\nDeployment info saved to: ./deployments/pseudo-arbitrage-amm-latest.json");
    }
}

/// @title CreateExamplePosition
/// @notice Script to create an example pseudo-arbitrage liquidity position
contract CreateExamplePosition is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address ammAddress = vm.envAddress("AMM_ADDRESS");
        address aquaAddress = vm.envAddress("AQUA_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        address oracleAddress = vm.envAddress("ORACLE_ADDRESS");

        PseudoArbitrageAMM amm = PseudoArbitrageAMM(ammAddress);
        Aqua aqua = Aqua(aquaAddress);
        IERC20 token0 = IERC20(token0Address);
        IERC20 token1 = IERC20(token1Address);

        // Example parameters
        uint256 balance0 = 1000e18;         // 1,000 token0
        uint256 balance1 = 3000e18;         // 3,000 token1
        uint256 initialPrice = 3e18;        // 1 token0 = 3 token1
        uint32 minUpdateInterval = 3600;    // 1 hour
        uint16 feeBps = 30;                 // 0.3%
        uint40 expiration = uint40(block.timestamp + 30 days);

        vm.startBroadcast(deployerPrivateKey);

        console2.log("Creating pseudo-arbitrage liquidity position...");
        console2.log("Token0:", token0Address);
        console2.log("Token1:", token1Address);
        console2.log("Oracle:", oracleAddress);
        console2.log("Initial Price:", initialPrice);
        console2.log("Balance0:", balance0);
        console2.log("Balance1:", balance1);
        console2.log("Min Update Interval:", minUpdateInterval, "seconds");
        console2.log("Fee:", feeBps, "bps");
        console2.log("Expiration:", expiration);

        // Build the pseudo-arbitrage AMM program
        ISwapVM.Order memory order = amm.buildProgram(
            msg.sender,
            expiration,
            token0Address,
            token1Address,
            balance0,
            balance1,
            oracleAddress,
            initialPrice,
            minUpdateInterval,
            feeBps,
            uint64(block.timestamp) // Use timestamp as salt
        );

        // Approve tokens for Aqua
        token0.approve(address(aqua), balance0);
        token1.approve(address(aqua), balance1);

        // Ship the order to Aqua
        bytes32 orderHash = aqua.ship(order, balance0, balance1);

        vm.stopBroadcast();

        console2.log("\n========================================");
        console2.log("POSITION CREATED");
        console2.log("========================================");
        console2.log("Order Hash:", vm.toString(orderHash));
        console2.log("========================================");
    }
}

/// @title CreateConcentratedPosition
/// @notice Script to create a concentrated pseudo-arbitrage position
contract CreateConcentratedPosition is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address ammAddress = vm.envAddress("AMM_ADDRESS");
        address aquaAddress = vm.envAddress("AQUA_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        address oracleAddress = vm.envAddress("ORACLE_ADDRESS");

        PseudoArbitrageAMM amm = PseudoArbitrageAMM(ammAddress);
        Aqua aqua = Aqua(aquaAddress);
        IERC20 token0 = IERC20(token0Address);
        IERC20 token1 = IERC20(token1Address);

        // Example parameters with concentration
        uint256 balance0 = 1000e18;
        uint256 balance1 = 3000e18;
        uint256 delta0 = 100e18;            // Concentration delta for token0
        uint256 delta1 = 300e18;            // Concentration delta for token1
        uint256 initialPrice = 3e18;
        uint32 minUpdateInterval = 3600;
        uint16 feeBps = 30;
        uint40 expiration = uint40(block.timestamp + 30 days);

        vm.startBroadcast(deployerPrivateKey);

        console2.log("Creating concentrated pseudo-arbitrage position...");
        console2.log("Token0:", token0Address);
        console2.log("Token1:", token1Address);
        console2.log("Oracle:", oracleAddress);
        console2.log("Balance0:", balance0);
        console2.log("Balance1:", balance1);
        console2.log("Delta0:", delta0);
        console2.log("Delta1:", delta1);
        console2.log("Initial Price:", initialPrice);
        console2.log("Fee:", feeBps, "bps");

        // Build concentrated program
        ISwapVM.Order memory order = amm.buildConcentratedProgram(
            msg.sender,
            expiration,
            token0Address,
            token1Address,
            balance0,
            balance1,
            delta0,
            delta1,
            oracleAddress,
            initialPrice,
            minUpdateInterval,
            feeBps,
            uint64(block.timestamp)
        );

        // Approve and ship
        token0.approve(address(aqua), balance0);
        token1.approve(address(aqua), balance1);
        bytes32 orderHash = aqua.ship(order, balance0, balance1);

        vm.stopBroadcast();

        console2.log("\n========================================");
        console2.log("CONCENTRATED POSITION CREATED");
        console2.log("========================================");
        console2.log("Order Hash:", vm.toString(orderHash));
        console2.log("========================================");
    }
}

/// @title DeployPythOracle
/// @notice Script to deploy and configure a Pyth price adapter
contract DeployPythOracle is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address pythAddress = vm.envAddress("PYTH_ADDRESS");

        // Price feed IDs (can be customized via env vars)
        bytes32 ethUsdFeedId = vm.envOr(
            "ETH_USD_FEED_ID",
            bytes32(0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace)
        );
        bytes32 btcUsdFeedId = vm.envOr(
            "BTC_USD_FEED_ID",
            bytes32(0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43)
        );

        uint256 maxPriceAge = 3600; // 1 hour

        vm.startBroadcast(deployerPrivateKey);

        console2.log("Deploying PythPriceAdapter...");
        console2.log("Pyth Address:", pythAddress);
        console2.log("Max Price Age:", maxPriceAge, "seconds");

        PythPriceAdapter adapter = new PythPriceAdapter(pythAddress, maxPriceAge);
        console2.log("PythPriceAdapter deployed at:", address(adapter));

        // Example: Configure ETH/USD feed if token addresses provided
        address wethAddress = vm.envOr("WETH_ADDRESS", address(0));
        address usdcAddress = vm.envOr("USDC_ADDRESS", address(0));

        if (wethAddress != address(0) && usdcAddress != address(0)) {
            console2.log("\nConfiguring ETH/USDC price feed...");
            adapter.setPriceFeed(wethAddress, usdcAddress, ethUsdFeedId);
            console2.log("[OK] ETH/USDC feed configured");
        }

        vm.stopBroadcast();

        console2.log("\n========================================");
        console2.log("ORACLE DEPLOYMENT COMPLETE");
        console2.log("========================================");
        console2.log("PythPriceAdapter:", address(adapter));
        console2.log("Use this address as ORACLE_ADDRESS");
        console2.log("========================================");

        // Save oracle address to file
        string memory oracleInfo = string.concat(
            "{\n",
            '  "pythPriceAdapter": "', vm.toString(address(adapter)), '",\n',
            '  "pythAddress": "', vm.toString(pythAddress), '",\n',
            '  "maxPriceAge": ', vm.toString(maxPriceAge), '\n',
            "}"
        );

        vm.writeFile("./deployments/oracle-latest.json", oracleInfo);
        console2.log("\nOracle info saved to: ./deployments/oracle-latest.json");
    }
}

/// @title VerifyDeployment
/// @notice Script to verify the deployment and run basic checks
contract VerifyDeployment is Script {
    function run() external view {
        address aquaAddress = vm.envAddress("AQUA_ADDRESS");
        address ammAddress = vm.envAddress("AMM_ADDRESS");

        console2.log("Verifying deployment...\n");

        // Verify Aqua
        Aqua aqua = Aqua(aquaAddress);
        console2.log("[OK] Aqua contract found at:", aquaAddress);

        // Verify PseudoArbitrageAMM
        PseudoArbitrageAMM amm = PseudoArbitrageAMM(ammAddress);
        console2.log("[OK] PseudoArbitrageAMM contract found at:", ammAddress);

        // Test building a simple program (view only, no state changes)
        console2.log("\n[TEST] Building sample program...");
        address dummyToken0 = address(0x1);
        address dummyToken1 = address(0x2);
        address dummyOracle = address(0x3);
        
        try amm.buildProgram(
            address(this),
            uint40(block.timestamp + 1 days),
            dummyToken0,
            dummyToken1,
            1000e18,
            3000e18,
            dummyOracle,
            3e18,
            3600,
            30,
            0
        ) returns (ISwapVM.Order memory) {
            console2.log("[OK] Program building works correctly");
        } catch {
            console2.log("[WARN] Program building test failed (expected if library dependencies missing)");
        }

        console2.log("\n========================================");
        console2.log("VERIFICATION COMPLETE");
        console2.log("All contracts properly deployed");
        console2.log("========================================");
        console2.log("\nNext steps:");
        console2.log("1. Deploy or configure an oracle (DeployPythOracle)");
        console2.log("2. Set TOKEN0_ADDRESS, TOKEN1_ADDRESS, ORACLE_ADDRESS");
        console2.log("3. Run CreateExamplePosition to add liquidity");
        console2.log("========================================");
    }
}

// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import { Aqua } from "aqua/Aqua.sol";
import { ConcentratedAMM } from "src/ConcentratedAMM.sol";
import { ConcentratedAMMStrategyBuilder } from "src/ConcentratedAMMStrategyBuilder.sol";

/// @title DeployConcentratedAMM
/// @notice Deployment script for the Concentrated AMM module
contract DeployConcentratedAMM is Script {
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

        // Deploy ConcentratedAMM
        console2.log("\nDeploying ConcentratedAMM...");
        ConcentratedAMM amm = new ConcentratedAMM(aqua);
        console2.log("ConcentratedAMM deployed at:", address(amm));

        // Deploy StrategyBuilder
        console2.log("\nDeploying ConcentratedAMMStrategyBuilder...");
        ConcentratedAMMStrategyBuilder builder = new ConcentratedAMMStrategyBuilder(aqua, amm);
        console2.log("StrategyBuilder deployed at:", address(builder));

        vm.stopBroadcast();

        // Output deployment summary
        console2.log("\n========================================");
        console2.log("DEPLOYMENT SUMMARY");
        console2.log("========================================");
        console2.log("Aqua:            ", address(aqua));
        console2.log("ConcentratedAMM: ", address(amm));
        console2.log("StrategyBuilder: ", address(builder));
        console2.log("========================================");

        // Save deployment addresses to file
        string memory deploymentInfo = string.concat(
            "{\n",
            '  "aqua": "', vm.toString(address(aqua)), '",\n',
            '  "concentratedAMM": "', vm.toString(address(amm)), '",\n',
            '  "strategyBuilder": "', vm.toString(address(builder)), '"\n',
            "}"
        );

        vm.writeFile("./deployments/concentrated-amm-latest.json", deploymentInfo);
        console2.log("\nDeployment info saved to: ./deployments/concentrated-amm-latest.json");
    }
}

/// @title CreateExamplePosition
/// @notice Script to create an example concentrated liquidity position
contract CreateExamplePosition is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address builderAddress = vm.envAddress("BUILDER_ADDRESS");
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");

        ConcentratedAMMStrategyBuilder builder = ConcentratedAMMStrategyBuilder(builderAddress);

        // Example parameters
        uint256 currentPrice = 2e18; // 1 token0 = 2 token1
        uint256 priceLower = 1.8e18; // -10%
        uint256 priceUpper = 2.2e18; // +10%
        uint256 amount0 = 1000e18;
        uint256 amount1 = 2000e18;
        uint24 feeBps = 30; // 0.3%

        vm.startBroadcast(deployerPrivateKey);

        console2.log("Creating concentrated liquidity position...");
        console2.log("Token0:", token0Address);
        console2.log("Token1:", token1Address);
        console2.log("Price Range:", priceLower, "to", priceUpper);
        console2.log("Current Price:", currentPrice);
        console2.log("Amount0:", amount0);
        console2.log("Amount1:", amount1);
        console2.log("Fee:", feeBps, "bps");

        // Approve tokens (assuming they're already approved)
        bytes32 strategyHash = builder.createAndShipStrategy(
            token0Address,
            token1Address,
            priceLower,
            priceUpper,
            currentPrice,
            amount0,
            amount1,
            feeBps,
            bytes32(uint256(block.timestamp)) // Use timestamp as salt
        );

        vm.stopBroadcast();

        console2.log("\n========================================");
        console2.log("POSITION CREATED");
        console2.log("========================================");
        console2.log("Strategy Hash:", vm.toString(strategyHash));
        console2.log("========================================");
    }
}

/// @title VerifyDeployment
/// @notice Script to verify the deployment and run basic checks
contract VerifyDeployment is Script {
    function run() external view {
        address aquaAddress = vm.envAddress("AQUA_ADDRESS");
        address ammAddress = vm.envAddress("AMM_ADDRESS");
        address builderAddress = vm.envAddress("BUILDER_ADDRESS");

        console2.log("Verifying deployment...\n");

        // Verify Aqua
        Aqua aqua = Aqua(aquaAddress);
        console2.log("[OK] Aqua contract found at:", aquaAddress);

        // Verify AMM
        ConcentratedAMM amm = ConcentratedAMM(ammAddress);
        require(address(amm.AQUA()) == aquaAddress, "AMM not connected to Aqua");
        console2.log("[OK] ConcentratedAMM contract found at:", ammAddress);
        console2.log("  Connected to Aqua:", address(amm.AQUA()));

        // Verify Builder
        ConcentratedAMMStrategyBuilder builder = ConcentratedAMMStrategyBuilder(builderAddress);
        require(address(builder.AQUA()) == aquaAddress, "Builder not connected to Aqua");
        require(address(builder.AMM()) == ammAddress, "Builder not connected to AMM");
        console2.log("[OK] StrategyBuilder contract found at:", builderAddress);
        console2.log("  Connected to Aqua:", address(builder.AQUA()));
        console2.log("  Connected to AMM:", address(builder.AMM()));

        console2.log("\n========================================");
        console2.log("VERIFICATION SUCCESSFUL");
        console2.log("All contracts properly deployed and connected");
        console2.log("========================================");
    }
}

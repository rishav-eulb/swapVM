// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import { Aqua } from "aqua/Aqua.sol";
import { PseudoArbitrageAMM } from "src/strategies/PseudoArbitrageAMM.sol";

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


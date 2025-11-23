// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import { Aqua } from "aqua/Aqua.sol";
import { PseudoArbitrageSwapVMRouter } from "pseudo-arbitrage-amm/src/routers/PseudoArbitrageSwapVMRouter.sol";
import { CrossAMMArbitrage } from "./CrossAMMArbitrage.sol";
import { CrossAMMArbitrageBot } from "./CrossAMMArbitrageBot.sol";

/**
 * @title DeployCrossAMMArbitrageSimple
 * @notice Simplified deployment using existing Aqua and AMM contracts
 */
contract DeployCrossAMMArbitrageSimple is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Get existing contract addresses from environment
        address aquaAddress = vm.envAddress("AQUA_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);

        console.log("Using existing Aqua at:", aquaAddress);
        Aqua aqua = Aqua(aquaAddress);

        // Deploy PseudoArbitrage Router
        PseudoArbitrageSwapVMRouter pseudoArbRouter = new PseudoArbitrageSwapVMRouter(
            aquaAddress,
            "CrossAMMPseudoArb",
            "1.0"
        );
        console.log("PseudoArbitrageSwapVMRouter deployed at:", address(pseudoArbRouter));

        // Deploy CrossAMMArbitrage
        CrossAMMArbitrage arbitrage = new CrossAMMArbitrage(aqua, pseudoArbRouter);
        console.log("CrossAMMArbitrage deployed at:", address(arbitrage));

        // Deploy Bot
        CrossAMMArbitrageBot bot = new CrossAMMArbitrageBot(arbitrage);
        console.log("CrossAMMArbitrageBot deployed at:", address(bot));

        vm.stopBroadcast();

        // Save deployment info
        string memory deploymentInfo = string.concat(
            "{\n",
            '  "aqua": "', vm.toString(aquaAddress), '",\n',
            '  "pseudoArbRouter": "', vm.toString(address(pseudoArbRouter)), '",\n',
            '  "crossAMMArbitrage": "', vm.toString(address(arbitrage)), '",\n',
            '  "crossAMMArbitrageBot": "', vm.toString(address(bot)), '"\n',
            "}"
        );

        vm.writeFile("./deployments/cross-amm-arbitrage-latest.json", deploymentInfo);
        console.log("\nDeployment info saved to: ./deployments/cross-amm-arbitrage-latest.json");
    }
}


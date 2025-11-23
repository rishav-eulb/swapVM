// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { MockERC20 } from "../packages/shared-utils/src/MockERC20.sol";

/// @title DeployMockTokens
/// @notice Deployment script for two mock ERC20 tokens for testing
contract DeployMockTokens is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Get token configurations from environment or use defaults
        string memory token0Name = vm.envOr("TOKEN0_NAME", string("Mock Token A"));
        string memory token0Symbol = vm.envOr("TOKEN0_SYMBOL", string("MTKA"));
        uint8 token0Decimals = uint8(vm.envOr("TOKEN0_DECIMALS", uint256(18)));
        uint256 token0InitialSupply = vm.envOr("TOKEN0_INITIAL_SUPPLY", uint256(1000000 * 10**18));

        string memory token1Name = vm.envOr("TOKEN1_NAME", string("Mock Token B"));
        string memory token1Symbol = vm.envOr("TOKEN1_SYMBOL", string("MTKB"));
        uint8 token1Decimals = uint8(vm.envOr("TOKEN1_DECIMALS", uint256(18)));
        uint256 token1InitialSupply = vm.envOr("TOKEN1_INITIAL_SUPPLY", uint256(1000000 * 10**18));

        vm.startBroadcast(deployerPrivateKey);

        console2.log("\n========================================");
        console2.log("DEPLOYING MOCK TOKENS");
        console2.log("========================================");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);

        // Deploy Token 0
        console2.log("\nDeploying Token 0...");
        console2.log("  Name:", token0Name);
        console2.log("  Symbol:", token0Symbol);
        console2.log("  Decimals:", uint256(token0Decimals));
        
        MockERC20 token0 = new MockERC20(token0Name, token0Symbol, token0Decimals);
        console2.log("  Address:", address(token0));

        // Mint initial supply for Token 0
        if (token0InitialSupply > 0) {
            token0.mint(deployer, token0InitialSupply);
            console2.log("  Minted:", token0InitialSupply, "to", deployer);
        }

        // Deploy Token 1
        console2.log("\nDeploying Token 1...");
        console2.log("  Name:", token1Name);
        console2.log("  Symbol:", token1Symbol);
        console2.log("  Decimals:", uint256(token1Decimals));
        
        MockERC20 token1 = new MockERC20(token1Name, token1Symbol, token1Decimals);
        console2.log("  Address:", address(token1));

        // Mint initial supply for Token 1
        if (token1InitialSupply > 0) {
            token1.mint(deployer, token1InitialSupply);
            console2.log("  Minted:", token1InitialSupply, "to", deployer);
        }

        vm.stopBroadcast();

        // Output deployment summary
        console2.log("\n========================================");
        console2.log("DEPLOYMENT SUMMARY");
        console2.log("========================================");
        console2.log("Token 0 (%s):", token0Symbol);
        console2.log("  Address:      ", address(token0));
        console2.log("  Total Supply: ", token0.totalSupply());
        console2.log("\nToken 1 (%s):", token1Symbol);
        console2.log("  Address:      ", address(token1));
        console2.log("  Total Supply: ", token1.totalSupply());
        console2.log("========================================");

        // Save deployment addresses to file
        string memory deploymentInfo = string.concat(
            "{\n",
            '  "chainId": ', vm.toString(block.chainid), ',\n',
            '  "deployer": "', vm.toString(deployer), '",\n',
            '  "token0": {\n',
            '    "name": "', token0Name, '",\n',
            '    "symbol": "', token0Symbol, '",\n',
            '    "decimals": ', vm.toString(uint256(token0Decimals)), ',\n',
            '    "address": "', vm.toString(address(token0)), '",\n',
            '    "totalSupply": "', vm.toString(token0.totalSupply()), '"\n',
            '  },\n',
            '  "token1": {\n',
            '    "name": "', token1Name, '",\n',
            '    "symbol": "', token1Symbol, '",\n',
            '    "decimals": ', vm.toString(uint256(token1Decimals)), ',\n',
            '    "address": "', vm.toString(address(token1)), '",\n',
            '    "totalSupply": "', vm.toString(token1.totalSupply()), '"\n',
            '  }\n',
            '}'
        );

        vm.writeFile("./deployments/mock-tokens-latest.json", deploymentInfo);
        console2.log("\nDeployment info saved to: ./deployments/mock-tokens-latest.json");

        // Print export commands for easy use
        console2.log("\n========================================");
        console2.log("EXPORT COMMANDS (Copy to .env)");
        console2.log("========================================");
        console2.log(string.concat("TOKEN0_ADDRESS=", vm.toString(address(token0))));
        console2.log(string.concat("TOKEN1_ADDRESS=", vm.toString(address(token1))));
        console2.log("========================================\n");
    }
}


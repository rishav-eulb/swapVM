// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {PythPriceAdapter} from "../src/oracles/PythPriceAdapter.sol";

/**
 * @title DeployPythAdapter
 * @notice Deployment script for PythPriceAdapter
 * 
 * Usage:
 *   forge script script/DeployPythAdapter.s.sol:DeployPythAdapter \
 *     --rpc-url $RPC_URL \
 *     --private-key $PRIVATE_KEY \
 *     --broadcast
 */
contract DeployPythAdapter is Script {
    
    // Base Sepolia Pyth address
    address constant PYTH_BASE_SEPOLIA = 0xA2aa501b19aff244D90cc15a4Cf739D2725B5729;
    
    // Max price age: 1 hour (3600 seconds)
    uint256 constant MAX_PRICE_AGE = 3600;
    
    function run() external {
        console2.log("=================================");
        console2.log("Deploying PythPriceAdapter");
        console2.log("=================================");
        console2.log("Pyth Contract:", PYTH_BASE_SEPOLIA);
        console2.log("Max Price Age:", MAX_PRICE_AGE, "seconds");
        console2.log("");
        
        vm.startBroadcast();
        
        PythPriceAdapter adapter = new PythPriceAdapter(
            PYTH_BASE_SEPOLIA,
            MAX_PRICE_AGE
        );
        
        vm.stopBroadcast();
        
        console2.log("=================================");
        console2.log("Deployment Successful!");
        console2.log("=================================");
        console2.log("PythPriceAdapter:", address(adapter));
        console2.log("Owner:", adapter.owner());
        console2.log("");
        console2.log("Add to .env:");
        console2.log("PYTH_ADAPTER_ADDRESS=", address(adapter));
    }
}


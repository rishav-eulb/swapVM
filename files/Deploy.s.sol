// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import "../src/routers/PseudoArbitrageSwapVMRouter.sol";
import "../src/strategies/PseudoArbitrageAMM.sol";

/**
 * @title Deploy Script for PseudoArbitrage Contracts
 * @notice Deploys the router and AMM builder
 * 
 * Usage:
 * forge script script/Deploy.s.sol:DeployScript --rpc-url $RPC_URL --broadcast --verify
 */
contract DeployScript is Script {
    // Configuration - Update these for your deployment
    address public constant AQUA_ADDRESS = address(0); // TODO: Set Aqua address
    string public constant ROUTER_NAME = "PseudoArbitrageSwapVM";
    string public constant ROUTER_VERSION = "1.0.0";

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Router
        console.log("Deploying PseudoArbitrageSwapVMRouter...");
        PseudoArbitrageSwapVMRouter router = new PseudoArbitrageSwapVMRouter(
            AQUA_ADDRESS,
            ROUTER_NAME,
            ROUTER_VERSION
        );
        console.log("Router deployed at:", address(router));

        // 2. Deploy AMM Builder
        console.log("Deploying PseudoArbitrageAMM Builder...");
        PseudoArbitrageAMM ammBuilder = new PseudoArbitrageAMM(AQUA_ADDRESS);
        console.log("AMM Builder deployed at:", address(ammBuilder));

        vm.stopBroadcast();

        // Output deployment addresses
        console.log("\n=== Deployment Summary ===");
        console.log("Network:", block.chainid);
        console.log("Router:", address(router));
        console.log("AMM Builder:", address(ammBuilder));
        
        // Save to file
        string memory deployment = string(abi.encodePacked(
            "{\n",
            '  "chainId": ', vm.toString(block.chainid), ",\n",
            '  "router": "', vm.toString(address(router)), '",\n',
            '  "ammBuilder": "', vm.toString(address(ammBuilder)), '"\n',
            "}"
        ));
        
        vm.writeFile("deployments/latest.json", deployment);
        console.log("\nDeployment info saved to deployments/latest.json");
    }
}

/**
 * @title Deploy with Mocks Script
 * @notice Deploys everything including mock tokens and oracle for testing
 */
contract DeployWithMocksScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Mock Tokens
        console.log("Deploying Mock Tokens...");
        MockERC20 tokenX = new MockERC20("Token X", "TOKX", 18);
        MockERC20 tokenY = new MockERC20("Token Y", "TOKY", 18);
        console.log("TokenX:", address(tokenX));
        console.log("TokenY:", address(tokenY));

        // 2. Deploy Mock Oracle
        console.log("Deploying Mock Oracle...");
        MockOracle oracle = new MockOracle();
        console.log("Oracle:", address(oracle));

        // 3. Deploy Mock Aqua (simplified version)
        console.log("Deploying Mock Aqua...");
        MockAqua aqua = new MockAqua();
        console.log("Aqua:", address(aqua));

        // 4. Deploy Router
        console.log("Deploying Router...");
        PseudoArbitrageSwapVMRouter router = new PseudoArbitrageSwapVMRouter(
            address(aqua),
            "TestPseudoArbitrageSwapVM",
            "1.0.0"
        );
        console.log("Router:", address(router));

        // 5. Deploy AMM Builder
        console.log("Deploying AMM Builder...");
        PseudoArbitrageAMM ammBuilder = new PseudoArbitrageAMM(address(aqua));
        console.log("AMM Builder:", address(ammBuilder));

        // 6. Setup: Mint tokens and set oracle price
        console.log("\nSetting up test environment...");
        tokenX.mint(deployer, 1000 ether);
        tokenY.mint(deployer, 3000 ether);
        
        // Set initial price: 1 TOKX = 3 TOKY
        oracle.setPrice(address(tokenX), address(tokenY), 3 ether);
        
        console.log("Minted 1000 TOKX and 3000 TOKY to deployer");
        console.log("Set oracle price: 1 TOKX = 3 TOKY");

        vm.stopBroadcast();

        // Output
        console.log("\n=== Test Deployment Summary ===");
        console.log("TokenX:", address(tokenX));
        console.log("TokenY:", address(tokenY));
        console.log("Oracle:", address(oracle));
        console.log("Aqua:", address(aqua));
        console.log("Router:", address(router));
        console.log("AMM Builder:", address(ammBuilder));
    }
}

// Mock contracts for testing
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

contract MockOracle {
    mapping(address => mapping(address => uint256)) public prices;
    mapping(address => mapping(address => uint256)) public lastUpdate;
    
    function setPrice(address tokenIn, address tokenOut, uint256 price) external {
        prices[tokenIn][tokenOut] = price;
        lastUpdate[tokenIn][tokenOut] = block.timestamp;
    }
    
    function getPrice(address tokenIn, address tokenOut) external view returns (uint256, uint256) {
        return (prices[tokenIn][tokenOut], lastUpdate[tokenIn][tokenOut]);
    }
}

contract MockAqua {
    // Simplified Aqua for testing
    function deposit(address token, uint256 amount) external {}
    function withdraw(address token, uint256 amount) external {}
}

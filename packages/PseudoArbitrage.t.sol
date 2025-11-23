// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../src/instructions/PseudoArbitrage.sol";

/**
 * @title PseudoArbitrage Unit Tests
 * @notice Comprehensive tests for the PseudoArbitrage instruction
 * 
 * Run with:
 * forge test --match-contract PseudoArbitrageTest -vv
 */
contract PseudoArbitrageTest is Test {
    PseudoArbitrage public pseudoArbitrage;
    MockOracle public oracle;
    
    address public tokenX;
    address public tokenY;
    address public maker;
    
    uint256 constant INITIAL_PRICE = 3 ether; // 1 X = 3 Y
    uint32 constant MIN_UPDATE_INTERVAL = 1 hours;
    
    function setUp() public {
        // Deploy contracts
        pseudoArbitrage = new PseudoArbitrage();
        oracle = new MockOracle();
        
        // Setup addresses
        tokenX = address(0x1);
        tokenY = address(0x2);
        maker = address(0x3);
        
        // Set initial oracle price
        oracle.setPrice(tokenX, tokenY, INITIAL_PRICE);
    }
    
    function test_Initialization() public {
        // Build args
        bytes memory args = PseudoArbitrageArgsBuilder.build(
            address(oracle),
            INITIAL_PRICE,
            MIN_UPDATE_INTERVAL
        );
        
        // Parse args to verify
        (address parsedOracle, uint256 parsedPrice, uint32 parsedInterval) = 
            PseudoArbitrageArgsBuilder.parse(args);
        
        assertEq(parsedOracle, address(oracle));
        assertEq(parsedPrice, INITIAL_PRICE);
        assertEq(parsedInterval, MIN_UPDATE_INTERVAL);
    }
    
    function test_FirstCallInitializesState() public {
        bytes32 orderHash = keccak256("test-order");
        
        // Create context
        Context memory ctx = _createContext(orderHash, 1000 ether, 3000 ether);
        
        // Build args
        bytes memory args = PseudoArbitrageArgsBuilder.build(
            address(oracle),
            INITIAL_PRICE,
            MIN_UPDATE_INTERVAL
        );
        
        // First call should initialize
        pseudoArbitrage._pseudoArbitrageXD(ctx, args);
        
        // Check state
        (
            int256 shiftX,
            int256 shiftY,
            uint256 excessX,
            uint256 excessY,
            uint256 lastPrice,
            uint256 lastUpdate,
            bool initialized
        ) = pseudoArbitrage.pseudoArbitrageStates(orderHash);
        
        assertTrue(initialized);
        assertEq(lastPrice, INITIAL_PRICE);
        assertEq(lastUpdate, block.timestamp);
        assertEq(shiftX, 0);
        assertEq(shiftY, 0);
        assertEq(excessX, 0);
        assertEq(excessY, 0);
    }
    
    function test_PriceIncreaseTransformation() public {
        bytes32 orderHash = keccak256("test-order");
        
        // Initialize
        Context memory ctx = _createContext(orderHash, 1000 ether, 3000 ether);
        bytes memory args = PseudoArbitrageArgsBuilder.build(
            address(oracle),
            INITIAL_PRICE,
            MIN_UPDATE_INTERVAL
        );
        pseudoArbitrage._pseudoArbitrageXD(ctx, args);
        
        // Move time forward
        vm.warp(block.timestamp + MIN_UPDATE_INTERVAL + 1);
        
        // Increase price: 1 X = 4 Y
        uint256 newPrice = 4 ether;
        oracle.setPrice(tokenX, tokenY, newPrice);
        
        // Execute transformation
        ctx = _createContext(orderHash, 1000 ether, 3000 ether);
        pseudoArbitrage._pseudoArbitrageXD(ctx, args);
        
        // Check state updated
        (
            int256 shiftX,
            int256 shiftY,
            uint256 excessX,
            uint256 excessY,
            uint256 lastPrice,
            ,
        ) = pseudoArbitrage.pseudoArbitrageStates(orderHash);
        
        assertEq(lastPrice, newPrice);
        assertTrue(shiftX < 0); // Negative shift in X
        assertTrue(shiftY > 0); // Positive shift in Y
        assertTrue(excessX > 0); // Excess X after price increase
        assertEq(excessY, 0);
    }
    
    function test_PriceDecreaseTransformation() public {
        bytes32 orderHash = keccak256("test-order");
        
        // Initialize
        Context memory ctx = _createContext(orderHash, 1000 ether, 3000 ether);
        bytes memory args = PseudoArbitrageArgsBuilder.build(
            address(oracle),
            INITIAL_PRICE,
            MIN_UPDATE_INTERVAL
        );
        pseudoArbitrage._pseudoArbitrageXD(ctx, args);
        
        // Move time forward
        vm.warp(block.timestamp + MIN_UPDATE_INTERVAL + 1);
        
        // Decrease price: 1 X = 2 Y
        uint256 newPrice = 2 ether;
        oracle.setPrice(tokenX, tokenY, newPrice);
        
        // Execute transformation
        ctx = _createContext(orderHash, 1000 ether, 3000 ether);
        pseudoArbitrage._pseudoArbitrageXD(ctx, args);
        
        // Check state updated
        (
            int256 shiftX,
            int256 shiftY,
            uint256 excessX,
            uint256 excessY,
            uint256 lastPrice,
            ,
        ) = pseudoArbitrage.pseudoArbitrageStates(orderHash);
        
        assertEq(lastPrice, newPrice);
        assertTrue(shiftX > 0); // Positive shift in X
        assertTrue(shiftY < 0); // Negative shift in Y
        assertEq(excessX, 0);
        assertTrue(excessY > 0); // Excess Y after price decrease
    }
    
    function test_RateLimitingPreventsFrequentUpdates() public {
        bytes32 orderHash = keccak256("test-order");
        
        // Initialize
        Context memory ctx = _createContext(orderHash, 1000 ether, 3000 ether);
        bytes memory args = PseudoArbitrageArgsBuilder.build(
            address(oracle),
            INITIAL_PRICE,
            MIN_UPDATE_INTERVAL
        );
        pseudoArbitrage._pseudoArbitrageXD(ctx, args);
        
        // Move time forward but not enough
        vm.warp(block.timestamp + MIN_UPDATE_INTERVAL / 2);
        
        // Change price
        oracle.setPrice(tokenX, tokenY, 4 ether);
        
        // Try to update - should skip
        ctx = _createContext(orderHash, 1000 ether, 3000 ether);
        pseudoArbitrage._pseudoArbitrageXD(ctx, args);
        
        // Check price hasn't updated
        (, , , , uint256 lastPrice, ,) = 
            pseudoArbitrage.pseudoArbitrageStates(orderHash);
        
        assertEq(lastPrice, INITIAL_PRICE); // Still original price
    }
    
    function testFail_MustBeCalledBeforeSwap() public {
        bytes32 orderHash = keccak256("test-order");
        
        // Create context with swap amounts already set
        Context memory ctx = _createContext(orderHash, 1000 ether, 3000 ether);
        ctx.swap.amountIn = 100 ether; // This should cause failure
        
        bytes memory args = PseudoArbitrageArgsBuilder.build(
            address(oracle),
            INITIAL_PRICE,
            MIN_UPDATE_INTERVAL
        );
        
        // Should revert
        pseudoArbitrage._pseudoArbitrageXD(ctx, args);
    }
    
    function test_ZeroPriceReverts() public {
        bytes32 orderHash = keccak256("test-order");
        
        // Set zero price
        oracle.setPrice(tokenX, tokenY, 0);
        
        Context memory ctx = _createContext(orderHash, 1000 ether, 3000 ether);
        bytes memory args = PseudoArbitrageArgsBuilder.build(
            address(oracle),
            INITIAL_PRICE,
            MIN_UPDATE_INTERVAL
        );
        
        // Initialize first
        pseudoArbitrage._pseudoArbitrageXD(ctx, args);
        
        vm.warp(block.timestamp + MIN_UPDATE_INTERVAL + 1);
        
        // Should revert on zero price
        vm.expectRevert();
        pseudoArbitrage._pseudoArbitrageXD(ctx, args);
    }
    
    function test_MultipleUpdatesAccumulate() public {
        bytes32 orderHash = keccak256("test-order");
        bytes memory args = PseudoArbitrageArgsBuilder.build(
            address(oracle),
            INITIAL_PRICE,
            MIN_UPDATE_INTERVAL
        );
        
        // Initialize
        Context memory ctx = _createContext(orderHash, 1000 ether, 3000 ether);
        pseudoArbitrage._pseudoArbitrageXD(ctx, args);
        
        // First update: price increase
        vm.warp(block.timestamp + MIN_UPDATE_INTERVAL + 1);
        oracle.setPrice(tokenX, tokenY, 4 ether);
        ctx = _createContext(orderHash, 1000 ether, 3000 ether);
        pseudoArbitrage._pseudoArbitrageXD(ctx, args);
        
        // Second update: price increase more
        vm.warp(block.timestamp + MIN_UPDATE_INTERVAL + 1);
        oracle.setPrice(tokenX, tokenY, 5 ether);
        ctx = _createContext(orderHash, 1000 ether, 3000 ether);
        pseudoArbitrage._pseudoArbitrageXD(ctx, args);
        
        // Check final state
        (, , , , uint256 lastPrice, ,) = 
            pseudoArbitrage.pseudoArbitrageStates(orderHash);
        
        assertEq(lastPrice, 5 ether);
    }
    
    // Helper function to create test context
    function _createContext(
        bytes32 orderHash,
        uint256 balanceIn,
        uint256 balanceOut
    ) internal view returns (Context memory) {
        Context memory ctx;
        ctx.query.orderHash = orderHash;
        ctx.query.tokenIn = tokenX;
        ctx.query.tokenOut = tokenY;
        ctx.swap.balanceIn = balanceIn;
        ctx.swap.balanceOut = balanceOut;
        ctx.swap.amountIn = 0;
        ctx.swap.amountOut = 0;
        return ctx;
    }
}

// Mock Oracle for testing
contract MockOracle {
    mapping(address => mapping(address => uint256)) public prices;
    mapping(address => mapping(address => uint256)) public timestamps;
    
    function setPrice(address tokenIn, address tokenOut, uint256 price) external {
        prices[tokenIn][tokenOut] = price;
        timestamps[tokenIn][tokenOut] = block.timestamp;
    }
    
    function getPrice(address tokenIn, address tokenOut) external view returns (uint256, uint256) {
        return (prices[tokenIn][tokenOut], timestamps[tokenIn][tokenOut]);
    }
}

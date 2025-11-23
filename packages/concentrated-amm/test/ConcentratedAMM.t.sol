// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { Aqua } from "aqua/Aqua.sol";
import { ConcentratedAMM } from "src/ConcentratedAMM.sol";
import { ConcentratedAMMStrategyBuilder } from "src/ConcentratedAMMStrategyBuilder.sol";
import { IConcentratedAMMCallback } from "src/interfaces/IConcentratedAMMCallback.sol";

// Mock ERC20 token
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Test contract that implements the callback
contract ConcentratedAMMTest is Test, IConcentratedAMMCallback {
    Aqua public aqua;
    ConcentratedAMM public amm;
    ConcentratedAMMStrategyBuilder public builder;
    MockERC20 public token0;
    MockERC20 public token1;

    address public maker = address(0x1);
    address public taker = address(0x2);

    uint256 constant INITIAL_AMOUNT0 = 1000e18;
    uint256 constant INITIAL_AMOUNT1 = 2000e18; // Price = 2.0
    uint24 constant FEE_BPS = 30; // 0.3% fee

    function setUp() public {
        // Deploy contracts
        aqua = new Aqua();
        amm = new ConcentratedAMM(aqua);
        builder = new ConcentratedAMMStrategyBuilder(aqua, amm);

        // Deploy mock tokens (ensure token0 < token1)
        token0 = new MockERC20("Token0", "TK0");
        token1 = new MockERC20("Token1", "TK1");

        // Ensure correct order
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }

        // Mint tokens
        token0.mint(maker, INITIAL_AMOUNT0 * 10);
        token1.mint(maker, INITIAL_AMOUNT1 * 10);
        token0.mint(taker, 10000e18);
        token1.mint(taker, 10000e18);

        // Setup approvals
        vm.startPrank(maker);
        token0.approve(address(aqua), type(uint256).max);
        token1.approve(address(aqua), type(uint256).max);
        token0.approve(address(builder), type(uint256).max);
        token1.approve(address(builder), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(taker);
        token0.approve(address(this), type(uint256).max);
        token1.approve(address(this), type(uint256).max);
        vm.stopPrank();
    }

    /// @notice Test creating a concentrated liquidity position
    function testCreateConcentratedPosition() public {
        uint256 currentPrice = 2e18; // 1 token0 = 2 token1
        uint256 priceLower = 1.5e18; // 50% below
        uint256 priceUpper = 2.5e18; // 25% above

        vm.prank(maker);
        bytes32 strategyHash = builder.createAndShipStrategy(
            address(token0),
            address(token1),
            priceLower,
            priceUpper,
            currentPrice,
            INITIAL_AMOUNT0,
            INITIAL_AMOUNT1,
            FEE_BPS,
            bytes32(uint256(1))
        );

        // Verify strategy was created
        assertTrue(strategyHash != bytes32(0), "Strategy should be created");

        // Check balances in Aqua
        (uint256 balance0, uint256 balance1) = aqua.safeBalances(
            maker,
            address(amm),
            strategyHash,
            address(token0),
            address(token1)
        );

        assertTrue(balance0 > 0, "Should have token0 balance");
        assertTrue(balance1 > 0, "Should have token1 balance");

        console.log("Position created with balance0:", balance0);
        console.log("Position created with balance1:", balance1);
    }

    /// @notice Test swapping within concentrated range
    function testSwapWithinRange() public {
        // Create position
        uint256 currentPrice = 2e18;
        uint256 priceLower = 1.5e18;
        uint256 priceUpper = 2.5e18;

        vm.prank(maker);
        bytes32 strategyHash = builder.createAndShipStrategy(
            address(token0),
            address(token1),
            priceLower,
            priceUpper,
            currentPrice,
            INITIAL_AMOUNT0,
            INITIAL_AMOUNT1,
            FEE_BPS,
            bytes32(uint256(2))
        );

        // Get strategy
        ConcentratedAMM.Strategy memory strategy = _buildStrategy(
            maker,
            priceLower,
            priceUpper,
            currentPrice,
            FEE_BPS,
            bytes32(uint256(2))
        );

        // Quote swap
        uint256 swapAmount = 100e18;
        uint256 expectedOut = amm.quoteExactIn(strategy, true, swapAmount);
        
        console.log("Swapping", swapAmount, "token0");
        console.log("Expected output:", expectedOut, "token1");

        // Execute swap
        vm.prank(taker);
        token0.transfer(address(this), swapAmount);
        token0.approve(address(amm), swapAmount);

        uint256 amountOut = amm.swapExactIn(
            strategy,
            true,
            swapAmount,
            expectedOut,
            address(this),
            ""
        );

        assertEq(amountOut, expectedOut, "Output should match quote");
        assertTrue(amountOut > 0, "Should receive output tokens");

        console.log("Actual output:", amountOut);
    }

    /// @notice Test multiple swaps and price movement
    function testMultipleSwapsAndPriceMovement() public {
        uint256 currentPrice = 2e18;
        uint256 priceLower = 1.5e18;
        uint256 priceUpper = 2.5e18;

        vm.prank(maker);
        bytes32 strategyHash = builder.createAndShipStrategy(
            address(token0),
            address(token1),
            priceLower,
            priceUpper,
            currentPrice,
            INITIAL_AMOUNT0,
            INITIAL_AMOUNT1,
            FEE_BPS,
            bytes32(uint256(3))
        );

        ConcentratedAMM.Strategy memory strategy = _buildStrategy(
            maker,
            priceLower,
            priceUpper,
            currentPrice,
            FEE_BPS,
            bytes32(uint256(3))
        );

        // Get initial price
        uint256 initialPrice = amm.getPrice(strategy);
        console.log("Initial price:", initialPrice);

        // Perform multiple swaps
        uint256 swapAmount = 50e18;
        
        for (uint i = 0; i < 3; i++) {
            vm.prank(taker);
            token0.transfer(address(this), swapAmount);
            token0.approve(address(amm), swapAmount);

            uint256 amountOut = amm.swapExactIn(
                strategy,
                true,
                swapAmount,
                0,
                address(this),
                ""
            );

            uint256 newPrice = amm.getPrice(strategy);
            // Split console.log to avoid type signature issues
            console.log("Swap", i + 1);
            console.log("Output:", amountOut);
            console.log("New price:", newPrice);
        }

        uint256 finalPrice = amm.getPrice(strategy);
        assertTrue(finalPrice < initialPrice, "Price should decrease after token0->token1 swaps");
    }

    /// @notice Test price impact calculation
    function testPriceImpact() public {
        uint256 currentPrice = 2e18;
        uint256 priceLower = 1.5e18;
        uint256 priceUpper = 2.5e18;

        vm.prank(maker);
        builder.createAndShipStrategy(
            address(token0),
            address(token1),
            priceLower,
            priceUpper,
            currentPrice,
            INITIAL_AMOUNT0,
            INITIAL_AMOUNT1,
            FEE_BPS,
            bytes32(uint256(4))
        );

        ConcentratedAMM.Strategy memory strategy = _buildStrategy(
            maker,
            priceLower,
            priceUpper,
            currentPrice,
            FEE_BPS,
            bytes32(uint256(4))
        );

        // Test small swap
        uint256 smallSwap = 10e18;
        uint256 smallImpact = builder.calculatePriceImpact(strategy, smallSwap, true);
        console.log("Small swap price impact:", smallImpact, "bps");

        // Test large swap
        uint256 largeSwap = 100e18;
        uint256 largeImpact = builder.calculatePriceImpact(strategy, largeSwap, true);
        console.log("Large swap price impact:", largeImpact, "bps");

        assertTrue(largeImpact > smallImpact, "Larger swaps should have more impact");
    }

    /// @notice Test liquidity calculations
    function testLiquidityCalculations() public {
        uint256 currentPrice = 2e18;
        uint256 priceLower = 1.5e18;
        uint256 priceUpper = 2.5e18;

        uint256 amount0 = 1000e18;
        uint256 amount1 = 2000e18;

        // Calculate liquidity from amounts
        uint128 liquidity = builder.calculateLiquidityFromAmounts(
            amount0,
            amount1,
            priceLower,
            priceUpper,
            currentPrice
        );

        console.log("Calculated liquidity:", liquidity);
        assertTrue(liquidity > 0, "Liquidity should be positive");

        // Calculate amounts back from liquidity
        (uint256 calcAmount0, uint256 calcAmount1) = builder.calculateAmountsFromLiquidity(
            liquidity,
            priceLower,
            priceUpper,
            currentPrice
        );

        console.log("Recalculated amount0:", calcAmount0);
        console.log("Recalculated amount1:", calcAmount1);

        // Should be approximately equal (within rounding)
        assertTrue(calcAmount0 <= amount0, "Amount0 should not exceed input");
        assertTrue(calcAmount1 <= amount1, "Amount1 should not exceed input");
    }

    /// @notice Test swapping with exact output
    function testSwapExactOutput() public {
        uint256 currentPrice = 2e18;
        uint256 priceLower = 1.5e18;
        uint256 priceUpper = 2.5e18;

        vm.prank(maker);
        builder.createAndShipStrategy(
            address(token0),
            address(token1),
            priceLower,
            priceUpper,
            currentPrice,
            INITIAL_AMOUNT0,
            INITIAL_AMOUNT1,
            FEE_BPS,
            bytes32(uint256(5))
        );

        ConcentratedAMM.Strategy memory strategy = _buildStrategy(
            maker,
            priceLower,
            priceUpper,
            currentPrice,
            FEE_BPS,
            bytes32(uint256(5))
        );

        // Want to receive exactly 100 token1
        uint256 desiredOut = 100e18;
        uint256 expectedIn = amm.quoteExactOut(strategy, true, desiredOut);

        console.log("To receive", desiredOut, "token1");
        console.log("Need", expectedIn, "token0");

        // Execute swap
        vm.prank(taker);
        token0.transfer(address(this), expectedIn + 1e18); // Extra for safety
        token0.approve(address(amm), expectedIn + 1e18);

        uint256 amountIn = amm.swapExactOut(
            strategy,
            true,
            desiredOut,
            expectedIn + 1e18,
            address(this),
            ""
        );

        assertEq(amountIn, expectedIn, "Input should match quote");
        console.log("Actual input used:", amountIn);
    }

    /// @notice Test optimal amounts calculation
    function testGetOptimalAmounts() public {
        uint256 currentPrice = 2e18;
        uint256 priceLower = 1.5e18;
        uint256 priceUpper = 2.5e18;

        uint256 amount0Max = 1000e18;
        uint256 amount1Max = 3000e18;

        (uint256 optimal0, uint256 optimal1, uint128 liquidity) = builder.getOptimalAmounts(
            priceLower,
            priceUpper,
            currentPrice,
            amount0Max,
            amount1Max
        );

        console.log("Optimal amount0:", optimal0);
        console.log("Optimal amount1:", optimal1);
        console.log("Resulting liquidity:", liquidity);

        assertTrue(optimal0 <= amount0Max, "Should not exceed max0");
        assertTrue(optimal1 <= amount1Max, "Should not exceed max1");
        assertTrue(liquidity > 0, "Should have positive liquidity");
    }

    /// @notice Test tick to price conversion
    function testTickPriceConversion() public view {
        // Test various ticks
        int24[] memory ticks = new int24[](5);
        ticks[0] = -1000;
        ticks[1] = -100;
        ticks[2] = 0;
        ticks[3] = 100;
        ticks[4] = 1000;

        console.log("Tick to Price conversions:");
        for (uint i = 0; i < ticks.length; i++) {
            uint256 price = builder.tickToPrice(ticks[i]);
            console.log("Tick", uint256(uint24(ticks[i])));
            console.log("-> Price:", price);
            
            // Convert back
            int24 backToTick = builder.priceToTick(price);
            console.log("Price", price);
            console.log("-> Tick:", uint256(uint24(backToTick)));
        }
    }

    /// @notice Test narrow range concentration
    function testNarrowRangeConcentration() public {
        uint256 currentPrice = 2e18;
        uint256 priceLower = 1.9e18; // Tight range: 5% below
        uint256 priceUpper = 2.1e18; // 5% above

        vm.prank(maker);
        builder.createAndShipStrategy(
            address(token0),
            address(token1),
            priceLower,
            priceUpper,
            currentPrice,
            INITIAL_AMOUNT0,
            INITIAL_AMOUNT1,
            FEE_BPS,
            bytes32(uint256(6))
        );

        ConcentratedAMM.Strategy memory strategy = _buildStrategy(
            maker,
            priceLower,
            priceUpper,
            currentPrice,
            FEE_BPS,
            bytes32(uint256(6))
        );

        // Small swap should have good rate due to concentration
        uint256 swapAmount = 10e18;
        uint256 output = amm.quoteExactIn(strategy, true, swapAmount);
        
        console.log("Narrow range - Input:", swapAmount);
        console.log("Narrow range - Output:", output);
        console.log("Narrow range - Rate:", (output * 1e18) / swapAmount);

        // Compare with wide range
        setUp(); // Reset
        uint256 wideRangeLower = 1e18;
        uint256 wideRangeUpper = 3e18;

        vm.prank(maker);
        builder.createAndShipStrategy(
            address(token0),
            address(token1),
            wideRangeLower,
            wideRangeUpper,
            currentPrice,
            INITIAL_AMOUNT0,
            INITIAL_AMOUNT1,
            FEE_BPS,
            bytes32(uint256(7))
        );

        ConcentratedAMM.Strategy memory wideStrategy = _buildStrategy(
            maker,
            wideRangeLower,
            wideRangeUpper,
            currentPrice,
            FEE_BPS,
            bytes32(uint256(7))
        );

        uint256 wideOutput = amm.quoteExactIn(wideStrategy, true, swapAmount);
        console.log("Wide range - Output:", wideOutput);
        console.log("Wide range - Rate:", (wideOutput * 1e18) / swapAmount);

        assertTrue(output >= wideOutput, "Narrow range should provide better rates");
    }

    /// @notice Test bidirectional swaps
    function testBidirectionalSwaps() public {
        uint256 currentPrice = 2e18;
        uint256 priceLower = 1.5e18;
        uint256 priceUpper = 2.5e18;

        vm.prank(maker);
        builder.createAndShipStrategy(
            address(token0),
            address(token1),
            priceLower,
            priceUpper,
            currentPrice,
            INITIAL_AMOUNT0,
            INITIAL_AMOUNT1,
            FEE_BPS,
            bytes32(uint256(8))
        );

        ConcentratedAMM.Strategy memory strategy = _buildStrategy(
            maker,
            priceLower,
            priceUpper,
            currentPrice,
            FEE_BPS,
            bytes32(uint256(8))
        );

        uint256 swapAmount = 50e18;

        // Swap token0 -> token1
        vm.prank(taker);
        token0.transfer(address(this), swapAmount);
        token0.approve(address(amm), swapAmount);

        uint256 token1Out = amm.swapExactIn(strategy, true, swapAmount, 0, address(this), "");
        console.log("Swap 0->1 Input:", swapAmount);
        console.log("Swap 0->1 Output:", token1Out);

        // Swap token1 -> token0
        token1.approve(address(amm), token1Out);

        uint256 token0Out = amm.swapExactIn(strategy, false, token1Out, 0, address(this), "");
        console.log("Swap 1->0 Input:", token1Out);
        console.log("Swap 1->0 Output:", token0Out);

        assertTrue(token0Out < swapAmount, "Should lose value to fees after round trip");
        console.log("Loss from fees:", swapAmount - token0Out);
    }

    /// ============ Helper Functions ============

    function _buildStrategy(
        address _maker,
        uint256 priceLower,
        uint256 priceUpper,
        uint256 currentPrice,
        uint24 feeBps,
        bytes32 salt
    ) internal view returns (ConcentratedAMM.Strategy memory) {
        int24 tickLower = builder.priceToTick(priceLower);
        int24 tickUpper = builder.priceToTick(priceUpper);
        
        uint128 liquidity = builder.calculateLiquidityFromAmounts(
            INITIAL_AMOUNT0,
            INITIAL_AMOUNT1,
            priceLower,
            priceUpper,
            currentPrice
        );

        return ConcentratedAMM.Strategy({
            maker: _maker,
            token0: address(token0),
            token1: address(token1),
            tickLower: tickLower,
            tickUpper: tickUpper,
            feeBps: feeBps,
            liquidity: liquidity,
            salt: salt
        });
    }

    /// @notice Callback implementation
    function concentratedAMMCallback(
        address tokenIn,
        address /* tokenOut */,
        uint256 amountIn,
        uint256 /* amountOut */,
        address _maker,
        address app,
        bytes32 strategyHash,
        bytes calldata /* takerData */
    ) external override {
        // Transfer input tokens to maker via Aqua
        IERC20(tokenIn).approve(address(aqua), amountIn);
        aqua.push(_maker, app, strategyHash, tokenIn, amountIn);
    }
}

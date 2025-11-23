// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity 0.8.30;

/// @title ConcentratedAMMStrategyBuilder
/// @notice Helper contract for building and managing concentrated liquidity strategies
/// @dev Provides utilities for calculating liquidity, token amounts, and tick ranges

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IAqua } from "aqua/interfaces/IAqua.sol";
import { ConcentratedAMM } from "./ConcentratedAMM.sol";

contract ConcentratedAMMStrategyBuilder {
    using Math for uint256;
    using SafeCast for uint256;

    error InvalidPriceRange(uint256 priceLower, uint256 priceUpper);
    error InvalidTokenOrder(address token0, address token1);
    error InsufficientTokenAmount(uint256 provided, uint256 required);

    IAqua public immutable AQUA;
    ConcentratedAMM public immutable AMM;

    uint256 internal constant PRICE_PRECISION = 1e18;
    uint256 internal constant Q96 = 0x1000000000000000000000000;

    constructor(IAqua aqua_, ConcentratedAMM amm_) {
        AQUA = aqua_;
        AMM = amm_;
    }

    /// @notice Calculate liquidity from token amounts
    /// @param amount0 Amount of token0
    /// @param amount1 Amount of token1
    /// @param priceLower Lower price bound (token1/token0 with 1e18 precision)
    /// @param priceUpper Upper price bound
    /// @param currentPrice Current price
    /// @return liquidity The calculated liquidity value
    function calculateLiquidityFromAmounts(
        uint256 amount0,
        uint256 amount1,
        uint256 priceLower,
        uint256 priceUpper,
        uint256 currentPrice
    ) public pure returns (uint128 liquidity) {
        require(priceLower < priceUpper, InvalidPriceRange(priceLower, priceUpper));
        require(currentPrice >= priceLower && currentPrice <= priceUpper, InvalidPriceRange(currentPrice, priceLower));

        // Simplified liquidity calculation: L = sqrt(x * y)
        // For a price range, we adjust based on position
        
        uint256 sqrtPriceLower = Math.sqrt(priceLower * PRICE_PRECISION);
        uint256 sqrtPriceUpper = Math.sqrt(priceUpper * PRICE_PRECISION);
        uint256 sqrtPriceCurrent = Math.sqrt(currentPrice * PRICE_PRECISION);

        uint256 liquidity0;
        uint256 liquidity1;

        if (currentPrice <= priceLower) {
            // All in token0
            liquidity0 = (amount0 * sqrtPriceLower * sqrtPriceUpper) / (sqrtPriceUpper - sqrtPriceLower) / PRICE_PRECISION;
            liquidity = liquidity0.toUint128();
        } else if (currentPrice >= priceUpper) {
            // All in token1
            liquidity1 = amount1 * PRICE_PRECISION / (sqrtPriceUpper - sqrtPriceLower);
            liquidity = liquidity1.toUint128();
        } else {
            // Mixed position
            liquidity0 = (amount0 * sqrtPriceCurrent * sqrtPriceUpper) / (sqrtPriceUpper - sqrtPriceCurrent) / PRICE_PRECISION;
            liquidity1 = amount1 * PRICE_PRECISION / (sqrtPriceCurrent - sqrtPriceLower);
            
            // Use minimum
            liquidity = uint128(Math.min(liquidity0, liquidity1));
        }

        return liquidity;
    }

    /// @notice Calculate token amounts from liquidity
    /// @param liquidityAmount The liquidity value
    /// @param priceLower Lower price bound
    /// @param priceUpper Upper price bound
    /// @param currentPrice Current price
    /// @return amount0 Required amount of token0
    /// @return amount1 Required amount of token1
    function calculateAmountsFromLiquidity(
        uint128 liquidityAmount,
        uint256 priceLower,
        uint256 priceUpper,
        uint256 currentPrice
    ) public pure returns (uint256 amount0, uint256 amount1) {
        require(priceLower < priceUpper, InvalidPriceRange(priceLower, priceUpper));

        uint256 sqrtPriceLower = Math.sqrt(priceLower * PRICE_PRECISION);
        uint256 sqrtPriceUpper = Math.sqrt(priceUpper * PRICE_PRECISION);
        uint256 sqrtPriceCurrent = Math.sqrt(currentPrice * PRICE_PRECISION);

        if (currentPrice <= priceLower) {
            // All in token0
            amount0 = uint256(liquidityAmount) * (sqrtPriceUpper - sqrtPriceLower) * PRICE_PRECISION / (sqrtPriceLower * sqrtPriceUpper);
            amount1 = 0;
        } else if (currentPrice >= priceUpper) {
            // All in token1
            amount0 = 0;
            amount1 = uint256(liquidityAmount) * (sqrtPriceUpper - sqrtPriceLower) / PRICE_PRECISION;
        } else {
            // Mixed position
            amount0 = uint256(liquidityAmount) * (sqrtPriceUpper - sqrtPriceCurrent) * PRICE_PRECISION / (sqrtPriceCurrent * sqrtPriceUpper);
            amount1 = uint256(liquidityAmount) * (sqrtPriceCurrent - sqrtPriceLower) / PRICE_PRECISION;
        }

        return (amount0, amount1);
    }

    /// @notice Convert price to tick
    /// @param price Price as token1/token0 with 1e18 precision
    /// @return tick The corresponding tick
    function priceToTick(uint256 price) public pure returns (int24 tick) {
        // Simplified: tick ≈ log_1.0001(price)
        // For demonstration, we use a linear approximation
        
        if (price == PRICE_PRECISION) {
            return 0;
        } else if (price > PRICE_PRECISION) {
            // Price > 1, positive tick
            uint256 ratio = (price * 10000) / PRICE_PRECISION;
            tick = int24(int256((ratio - 10000) * 2)); // Approximate conversion
        } else {
            // Price < 1, negative tick
            uint256 ratio = (PRICE_PRECISION * 10000) / price;
            tick = -int24(int256((ratio - 10000) * 2));
        }

        // Clamp to valid range
        if (tick < -887272) tick = -887272;
        if (tick > 887272) tick = 887272;

        return tick;
    }

    /// @notice Convert tick to price
    /// @param tick The tick value
    /// @return price Price as token1/token0 with 1e18 precision
    function tickToPrice(int24 tick) public pure returns (uint256 price) {
        // Simplified: price ≈ 1.0001^tick
        // For demonstration, we use a linear approximation
        
        if (tick == 0) {
            return PRICE_PRECISION;
        } else if (tick > 0) {
            uint256 absTick = uint256(uint24(tick));
            price = PRICE_PRECISION + (PRICE_PRECISION * absTick) / 20000;
        } else {
            uint256 absTick = uint256(uint24(-tick));
            price = PRICE_PRECISION - (PRICE_PRECISION * absTick) / 20000;
        }

        return price;
    }

    /// @notice Create and ship a concentrated liquidity strategy
    /// @param token0 First token (must be < token1)
    /// @param token1 Second token
    /// @param priceLower Lower price bound (token1/token0)
    /// @param priceUpper Upper price bound
    /// @param currentPrice Current market price
    /// @param amount0Desired Desired amount of token0
    /// @param amount1Desired Desired amount of token1
    /// @param feeBps Fee in basis points
    /// @param salt Unique identifier
    /// @return strategyHash The created strategy hash
    function createAndShipStrategy(
        address token0,
        address token1,
        uint256 priceLower,
        uint256 priceUpper,
        uint256 currentPrice,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint24 feeBps,
        bytes32 salt
    ) external returns (bytes32 strategyHash) {
        require(token0 < token1, InvalidTokenOrder(token0, token1));

        // Convert prices to ticks
        int24 tickLower = priceToTick(priceLower);
        int24 tickUpper = priceToTick(priceUpper);
        int24 tickCurrent = priceToTick(currentPrice);

        // Calculate liquidity
        uint128 liquidity = calculateLiquidityFromAmounts(
            amount0Desired,
            amount1Desired,
            priceLower,
            priceUpper,
            currentPrice
        );

        // Calculate actual amounts needed
        (uint256 amount0, uint256 amount1) = calculateAmountsFromLiquidity(
            liquidity,
            priceLower,
            priceUpper,
            currentPrice
        );

        require(amount0 <= amount0Desired, InsufficientTokenAmount(amount0Desired, amount0));
        require(amount1 <= amount1Desired, InsufficientTokenAmount(amount1Desired, amount1));

        // Build strategy
        ConcentratedAMM.Strategy memory strategy = ConcentratedAMM.Strategy({
            maker: msg.sender,
            token0: token0,
            token1: token1,
            tickLower: tickLower,
            tickUpper: tickUpper,
            feeBps: feeBps,
            liquidity: liquidity,
            salt: salt
        });

        // Encode and ship via Aqua
        bytes memory strategyEncoded = abi.encode(strategy);
        strategyHash = keccak256(strategyEncoded);

        address[] memory tokens = new address[](2);
        tokens[0] = token0;
        tokens[1] = token1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount0;
        amounts[1] = amount1;

        // Transfer tokens from sender
        IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        IERC20(token1).transferFrom(msg.sender, address(this), amount1);

        // Approve Aqua
        IERC20(token0).approve(address(AQUA), amount0);
        IERC20(token1).approve(address(AQUA), amount1);

        // Ship strategy
        AQUA.ship(address(AMM), strategyEncoded, tokens, amounts);

        // Initialize position in AMM
        AMM.initializePosition(strategy, tickCurrent);

        return strategyHash;
    }

    /// @notice Calculate price impact of a swap
    /// @param strategy The strategy to query
    /// @param amountIn Input amount
    /// @param zeroForOne Swap direction
    /// @return priceImpact Price impact in basis points (10000 = 100%)
    function calculatePriceImpact(
        ConcentratedAMM.Strategy calldata strategy,
        uint256 amountIn,
        bool zeroForOne
    ) external view returns (uint256 priceImpact) {
        bytes32 strategyHash = keccak256(abi.encode(strategy));
        
        // Get current balances
        (uint256 balance0, uint256 balance1) = AQUA.safeBalances(
            strategy.maker,
            address(AMM),
            strategyHash,
            strategy.token0,
            strategy.token1
        );

        uint256 priceBefore = (balance1 * PRICE_PRECISION) / balance0;

        // Calculate output
        uint256 amountOut = AMM.quoteExactIn(strategy, zeroForOne, amountIn);

        // Calculate price after
        uint256 newBalance0 = zeroForOne ? balance0 + amountIn : balance0 - amountOut;
        uint256 newBalance1 = zeroForOne ? balance1 - amountOut : balance1 + amountIn;
        uint256 priceAfter = (newBalance1 * PRICE_PRECISION) / newBalance0;

        // Calculate impact in bps
        if (priceAfter > priceBefore) {
            priceImpact = ((priceAfter - priceBefore) * 10000) / priceBefore;
        } else {
            priceImpact = ((priceBefore - priceAfter) * 10000) / priceBefore;
        }

        return priceImpact;
    }

    /// @notice Get optimal amounts for adding liquidity
    /// @param priceLower Lower price bound
    /// @param priceUpper Upper price bound
    /// @param currentPrice Current price
    /// @param amount0Max Maximum amount0 available
    /// @param amount1Max Maximum amount1 available
    /// @return amount0 Optimal amount0 to use
    /// @return amount1 Optimal amount1 to use
    /// @return liquidity Resulting liquidity
    function getOptimalAmounts(
        uint256 priceLower,
        uint256 priceUpper,
        uint256 currentPrice,
        uint256 amount0Max,
        uint256 amount1Max
    ) external pure returns (
        uint256 amount0,
        uint256 amount1,
        uint128 liquidity
    ) {
        // Calculate liquidity from both constraints
        uint128 liquidity0 = calculateLiquidityFromAmounts(
            amount0Max,
            0,
            priceLower,
            priceUpper,
            currentPrice
        );

        uint128 liquidity1 = calculateLiquidityFromAmounts(
            0,
            amount1Max,
            priceLower,
            priceUpper,
            currentPrice
        );

        // Use minimum
        liquidity = uint128(Math.min(liquidity0, liquidity1));

        // Calculate actual amounts
        (amount0, amount1) = calculateAmountsFromLiquidity(
            liquidity,
            priceLower,
            priceUpper,
            currentPrice
        );

        return (amount0, amount1, liquidity);
    }
}

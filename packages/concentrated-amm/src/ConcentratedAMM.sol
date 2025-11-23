// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity 0.8.30;

/// @title ConcentratedAMM - Tick-based concentrated liquidity AMM for Aqua
/// @notice Implements concentrated liquidity positions similar to Uniswap V3
/// @dev Uses simplified tick system with configurable ranges and fees

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IAqua } from "aqua/interfaces/IAqua.sol";
import { AquaApp } from "aqua/AquaApp.sol";
import { IConcentratedAMMCallback } from "./interfaces/IConcentratedAMMCallback.sol";

contract ConcentratedAMM is AquaApp {
    using Math for uint256;
    using SafeCast for uint256;

    error InsufficientOutputAmount(uint256 amountOut, uint256 amountOutMin);
    error ExcessiveInputAmount(uint256 amountIn, uint256 amountInMax);
    error PriceOutOfRange(uint256 currentPrice, uint256 minPrice, uint256 maxPrice);
    error InvalidTickRange(int24 tickLower, int24 tickUpper);
    error InsufficientLiquidity(uint256 available, uint256 required);
    error InvalidStrategy();

    /// @notice Strategy configuration for a concentrated liquidity position
    /// @param maker The liquidity provider's address
    /// @param token0 The first token (lower address)
    /// @param token1 The second token (higher address)
    /// @param tickLower Lower tick boundary (price = 1.0001^tick)
    /// @param tickUpper Upper tick boundary
    /// @param feeBps Fee in basis points (0-10000, where 10000 = 100%)
    /// @param liquidity Total liquidity for this position (L = sqrt(x * y))
    /// @param salt Unique identifier for the strategy
    struct Strategy {
        address maker;
        address token0;
        address token1;
        int24 tickLower;
        int24 tickUpper;
        uint24 feeBps;
        uint128 liquidity;
        bytes32 salt;
    }

    /// @notice Position state tracking
    /// @param liquidity Current active liquidity
    /// @param feeGrowthInside0 Accumulated fees per unit liquidity for token0
    /// @param feeGrowthInside1 Accumulated fees per unit liquidity for token1
    /// @param tokensOwed0 Uncollected fees in token0
    /// @param tokensOwed1 Uncollected fees in token1
    struct Position {
        uint128 liquidity;
        uint256 feeGrowthInside0;
        uint256 feeGrowthInside1;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    /// @notice Current price and tick state
    /// @param sqrtPriceX96 Current sqrt price in Q96 format
    /// @param tick Current tick
    /// @param feeGrowthGlobal0 Global fee growth for token0
    /// @param feeGrowthGlobal1 Global fee growth for token1
    struct PoolState {
        uint160 sqrtPriceX96;
        int24 tick;
        uint256 feeGrowthGlobal0;
        uint256 feeGrowthGlobal1;
    }

    uint256 internal constant BPS_BASE = 10_000;
    uint256 internal constant Q96 = 0x1000000000000000000000000; // 2^96
    int24 internal constant MIN_TICK = -887272; // Approximately 0 price
    int24 internal constant MAX_TICK = 887272; // Approximately infinity

    /// @notice Pool states indexed by strategy hash
    mapping(bytes32 => PoolState) public poolStates;

    /// @notice Position data indexed by strategy hash
    mapping(bytes32 => Position) public positions;

    constructor(IAqua aqua_) AquaApp(aqua_) {}

    /// ============ Quote Functions ============

    /// @notice Quote exact input swap amount
    /// @param strategy The concentrated liquidity strategy
    /// @param zeroForOne Direction of swap (true = token0 -> token1)
    /// @param amountIn Amount of input tokens
    /// @return amountOut Amount of output tokens
    function quoteExactIn(
        Strategy calldata strategy,
        bool zeroForOne,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        bytes32 strategyHash = keccak256(abi.encode(strategy));
        PoolState memory state = poolStates[strategyHash];
        
        // Get virtual balances from Aqua
        (uint256 balance0, uint256 balance1) = _getBalances(strategy, strategyHash);
        
        amountOut = _calculateSwapExactIn(
            state,
            strategy,
            balance0,
            balance1,
            amountIn,
            zeroForOne
        );
    }

    /// @notice Quote exact output swap amount
    /// @param strategy The concentrated liquidity strategy
    /// @param zeroForOne Direction of swap
    /// @param amountOut Desired amount of output tokens
    /// @return amountIn Required amount of input tokens
    function quoteExactOut(
        Strategy calldata strategy,
        bool zeroForOne,
        uint256 amountOut
    ) external view returns (uint256 amountIn) {
        bytes32 strategyHash = keccak256(abi.encode(strategy));
        PoolState memory state = poolStates[strategyHash];
        
        (uint256 balance0, uint256 balance1) = _getBalances(strategy, strategyHash);
        
        amountIn = _calculateSwapExactOut(
            state,
            strategy,
            balance0,
            balance1,
            amountOut,
            zeroForOne
        );
    }

    /// ============ Swap Functions ============

    /// @notice Execute exact input swap
    /// @param strategy The concentrated liquidity strategy
    /// @param zeroForOne Direction of swap
    /// @param amountIn Amount of input tokens
    /// @param amountOutMin Minimum acceptable output
    /// @param to Recipient address
    /// @param takerData Callback data
    /// @return amountOut Actual output amount
    function swapExactIn(
        Strategy calldata strategy,
        bool zeroForOne,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        bytes calldata takerData
    )
        external
        nonReentrantStrategy(keccak256(abi.encode(strategy)))
        returns (uint256 amountOut)
    {
        bytes32 strategyHash = keccak256(abi.encode(strategy));
        PoolState storage state = poolStates[strategyHash];

        (address tokenIn, address tokenOut) = zeroForOne 
            ? (strategy.token0, strategy.token1)
            : (strategy.token1, strategy.token0);

        (uint256 balance0, uint256 balance1) = _getBalances(strategy, strategyHash);
        uint256 balanceInBefore = zeroForOne ? balance0 : balance1;

        // Calculate swap
        amountOut = _calculateSwapExactIn(
            state,
            strategy,
            balance0,
            balance1,
            amountIn,
            zeroForOne
        );

        require(amountOut >= amountOutMin, InsufficientOutputAmount(amountOut, amountOutMin));

        // Update pool state
        _updatePoolState(state, strategy, amountIn, amountOut, zeroForOne);

        // Execute transfers via Aqua
        AQUA.pull(strategy.maker, strategyHash, tokenOut, amountOut, to);

        // Callback for taker to deposit
        IConcentratedAMMCallback(msg.sender).concentratedAMMCallback(
            tokenIn,
            tokenOut,
            amountIn,
            amountOut,
            strategy.maker,
            address(this),
            strategyHash,
            takerData
        );

        // Verify push
        _safeCheckAquaPush(strategy.maker, strategyHash, tokenIn, balanceInBefore + amountIn);

        return amountOut;
    }

    /// @notice Execute exact output swap
    /// @param strategy The concentrated liquidity strategy
    /// @param zeroForOne Direction of swap
    /// @param amountOut Desired output amount
    /// @param amountInMax Maximum acceptable input
    /// @param to Recipient address
    /// @param takerData Callback data
    /// @return amountIn Actual input amount
    function swapExactOut(
        Strategy calldata strategy,
        bool zeroForOne,
        uint256 amountOut,
        uint256 amountInMax,
        address to,
        bytes calldata takerData
    )
        external
        nonReentrantStrategy(keccak256(abi.encode(strategy)))
        returns (uint256 amountIn)
    {
        bytes32 strategyHash = keccak256(abi.encode(strategy));
        PoolState storage state = poolStates[strategyHash];

        (address tokenIn, address tokenOut) = zeroForOne 
            ? (strategy.token0, strategy.token1)
            : (strategy.token1, strategy.token0);

        (uint256 balance0, uint256 balance1) = _getBalances(strategy, strategyHash);
        uint256 balanceInBefore = zeroForOne ? balance0 : balance1;

        // Calculate swap
        amountIn = _calculateSwapExactOut(
            state,
            strategy,
            balance0,
            balance1,
            amountOut,
            zeroForOne
        );

        require(amountIn <= amountInMax, ExcessiveInputAmount(amountIn, amountInMax));

        // Update pool state
        _updatePoolState(state, strategy, amountIn, amountOut, zeroForOne);

        // Execute transfers via Aqua
        AQUA.pull(strategy.maker, strategyHash, tokenOut, amountOut, to);

        // Callback for taker to deposit
        IConcentratedAMMCallback(msg.sender).concentratedAMMCallback(
            tokenIn,
            tokenOut,
            amountIn,
            amountOut,
            strategy.maker,
            address(this),
            strategyHash,
            takerData
        );

        // Verify push
        _safeCheckAquaPush(strategy.maker, strategyHash, tokenIn, balanceInBefore + amountIn);

        return amountIn;
    }

    /// ============ Internal Calculation Functions ============

    /// @notice Calculate output for exact input swap
    function _calculateSwapExactIn(
        PoolState memory state,
        Strategy calldata strategy,
        uint256 balance0,
        uint256 balance1,
        uint256 amountIn,
        bool zeroForOne
    ) internal pure returns (uint256 amountOut) {
        // Verify we're within tick range
        require(
            state.tick >= strategy.tickLower && state.tick < strategy.tickUpper,
            PriceOutOfRange(uint256(uint24(state.tick)), uint256(uint24(strategy.tickLower)), uint256(uint24(strategy.tickUpper)))
        );

        // Apply fee
        uint256 amountInWithFee = amountIn * (BPS_BASE - strategy.feeBps) / BPS_BASE;

        // Use concentrated liquidity formula: x * y = L^2
        // For the range [Pa, Pb], liquidity is concentrated
        uint256 balanceIn = zeroForOne ? balance0 : balance1;
        uint256 balanceOut = zeroForOne ? balance1 : balance0;

        // Constant product within the range
        amountOut = (amountInWithFee * balanceOut) / (balanceIn + amountInWithFee);

        return amountOut;
    }

    /// @notice Calculate input for exact output swap
    function _calculateSwapExactOut(
        PoolState memory state,
        Strategy calldata strategy,
        uint256 balance0,
        uint256 balance1,
        uint256 amountOut,
        bool zeroForOne
    ) internal pure returns (uint256 amountIn) {
        // Verify we're within tick range
        require(
            state.tick >= strategy.tickLower && state.tick < strategy.tickUpper,
            PriceOutOfRange(uint256(uint24(state.tick)), uint256(uint24(strategy.tickLower)), uint256(uint24(strategy.tickUpper)))
        );

        uint256 balanceIn = zeroForOne ? balance0 : balance1;
        uint256 balanceOut = zeroForOne ? balance1 : balance0;

        // Calculate required input before fees
        uint256 amountInBeforeFee = (balanceIn * amountOut).ceilDiv(balanceOut - amountOut);

        // Add fee
        amountIn = (amountInBeforeFee * BPS_BASE).ceilDiv(BPS_BASE - strategy.feeBps);

        return amountIn;
    }

    /// @notice Update pool state after swap
    function _updatePoolState(
        PoolState storage state,
        Strategy calldata strategy,
        uint256 amountIn,
        uint256 amountOut,
        bool zeroForOne
    ) internal {
        // Update fee growth
        uint256 feeAmount = amountIn * strategy.feeBps / BPS_BASE;
        
        if (zeroForOne) {
            state.feeGrowthGlobal0 += (feeAmount * Q96) / uint256(strategy.liquidity);
        } else {
            state.feeGrowthGlobal1 += (feeAmount * Q96) / uint256(strategy.liquidity);
        }

        // Update tick (simplified - just track direction)
        if (zeroForOne) {
            state.tick -= 1; // Price decreasing
        } else {
            state.tick += 1; // Price increasing
        }

        // Ensure tick stays in range
        if (state.tick < strategy.tickLower) state.tick = strategy.tickLower;
        if (state.tick >= strategy.tickUpper) state.tick = strategy.tickUpper - 1;
    }

    /// @notice Get balances from Aqua
    function _getBalances(
        Strategy calldata strategy,
        bytes32 strategyHash
    ) internal view returns (uint256 balance0, uint256 balance1) {
        return AQUA.safeBalances(
            strategy.maker,
            address(this),
            strategyHash,
            strategy.token0,
            strategy.token1
        );
    }

    /// ============ Liquidity Management ============

    /// @notice Initialize a new concentrated liquidity position
    /// @dev Called via Aqua.ship()
    /// @param strategy The strategy configuration
    /// @param currentTick Initial tick (current price)
    function initializePosition(
        Strategy calldata strategy,
        int24 currentTick
    ) external {
        require(strategy.tickLower < strategy.tickUpper, InvalidTickRange(strategy.tickLower, strategy.tickUpper));
        require(currentTick >= strategy.tickLower && currentTick < strategy.tickUpper, PriceOutOfRange(uint256(uint24(currentTick)), uint256(uint24(strategy.tickLower)), uint256(uint24(strategy.tickUpper))));
        
        bytes32 strategyHash = keccak256(abi.encode(strategy));

        // Initialize pool state
        PoolState storage state = poolStates[strategyHash];
        require(state.sqrtPriceX96 == 0, InvalidStrategy()); // Ensure not initialized

        state.tick = currentTick;
        state.sqrtPriceX96 = _getSqrtPriceAtTick(currentTick);

        // Initialize position
        Position storage position = positions[strategyHash];
        position.liquidity = strategy.liquidity;
    }

    /// @notice Calculate sqrt price at tick
    /// @dev Simplified: price = 1.0001^tick, sqrtPrice = 1.0001^(tick/2)
    function _getSqrtPriceAtTick(int24 tick) internal pure returns (uint160) {
        // Simplified calculation for demonstration
        // In production, use proper fixed-point math
        uint256 absTick = tick < 0 ? uint256(uint24(-tick)) : uint256(uint24(tick));
        
        // Approximate: sqrt(1.0001^tick) ≈ Q96 * (1 + tick * 0.00005)
        uint256 sqrtPrice = Q96;
        
        if (tick > 0) {
            sqrtPrice = sqrtPrice + (sqrtPrice * absTick) / 20000;
        } else if (tick < 0) {
            sqrtPrice = sqrtPrice - (sqrtPrice * absTick) / 20000;
        }
        
        return uint160(sqrtPrice);
    }

    /// @notice Get current price in human-readable format
    /// @param strategy The strategy to query
    /// @return price Price as token1/token0 with 1e18 precision
    function getPrice(Strategy calldata strategy) external view returns (uint256 price) {
        bytes32 strategyHash = keccak256(abi.encode(strategy));
        PoolState memory state = poolStates[strategyHash];
        
        // price = (sqrtPrice / Q96)^2
        uint256 sqrtPrice = uint256(state.sqrtPriceX96);
        price = (sqrtPrice * sqrtPrice * 1e18) / (Q96 * Q96);
        
        return price;
    }

    /// @notice Get position information
    /// @param strategy The strategy to query
    /// @return liquidity Active liquidity
    /// @return tokensOwed0 Uncollected fees in token0
    /// @return tokensOwed1 Uncollected fees in token1
    function getPosition(Strategy calldata strategy) external view returns (
        uint128 liquidity,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    ) {
        bytes32 strategyHash = keccak256(abi.encode(strategy));
        Position memory position = positions[strategyHash];
        
        return (position.liquidity, position.tokensOwed0, position.tokensOwed1);
    }
}

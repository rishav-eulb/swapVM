// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

/// @custom:license-url https://github.com/1inch/swap-vm/blob/main/LICENSES/SwapVM-1.1.txt
/// @custom:copyright © 2025 Degensoft Ltd

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { Calldata } from "swap-vm/libs/Calldata.sol";
import { Context, ContextLib } from "swap-vm/libs/VM.sol";

library PseudoArbitrageArgsBuilder {
    using Calldata for bytes;
    using SafeCast for uint256;

    error PseudoArbitrageMissingOracleArg();
    error PseudoArbitrageMissingLastPriceArg();
    error PseudoArbitrageMissingMinIntervalArg();

    /// @notice Build args for pseudo-arbitrage instruction
    /// @param oracle Oracle address for price feeds
    /// @param lastMarketPrice Last known market price (scaled by 1e18)
    /// @param minUpdateInterval Minimum seconds between oracle updates
    function build(
        address oracle,
        uint256 lastMarketPrice,
        uint32 minUpdateInterval
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            oracle,
            lastMarketPrice,
            minUpdateInterval
        );
    }

    function parse(bytes calldata args) internal pure returns (
        address oracle,
        uint256 lastMarketPrice,
        uint32 minUpdateInterval
    ) {
        oracle = address(bytes20(args.slice(0, 20, PseudoArbitrageMissingOracleArg.selector)));
        lastMarketPrice = uint256(bytes32(args.slice(20, 52, PseudoArbitrageMissingLastPriceArg.selector)));
        minUpdateInterval = uint32(bytes4(args.slice(52, 56, PseudoArbitrageMissingMinIntervalArg.selector)));
    }
}

/**
 * @title PseudoArbitrage
 * @notice SwapVM instruction implementing pseudo-arbitrage strategy from Engel & Herlihy Section 6.1
 * @dev Transforms AMM curve when oracle reports valuation changes to eliminate divergence loss
 * 
 * Strategy Overview:
 * - Monitors oracle for market valuation changes
 * - When valuation shifts, transforms the bonding curve instead of allowing arbitrage
 * - Uses linear transformations: A' := (x, f(x - shiftX) - shiftY)
 * - Eliminates divergence loss for liquidity providers
 * - Integrates with SwapVM's instruction-based execution model
 * 
 * This instruction should be used BEFORE swap instructions (XYCSwap, LimitSwap, etc.) to:
 * 1. Check if oracle price has changed
 * 2. Transform curve if needed (adjust balances)
 * 3. Allow subsequent swap instruction to use transformed curve
 * 
 * Example program:
 * 1. _staticBalancesXD - Set initial balances
 * 2. _pseudoArbitrage - Check and transform curve
 * 3. _xycSwapXD - Execute swap with transformed balances
 * 4. _deadline - Ensure timely execution
 */
contract PseudoArbitrage {
    using Math for uint256;
    using SafeCast for uint256;
    using SafeCast for int256;
    using ContextLib for Context;

    error PseudoArbitrageShouldBeCalledBeforeSwap(uint256 amountIn, uint256 amountOut);
    error PseudoArbitrageUpdateTooFrequent(uint256 currentTime, uint256 lastUpdate, uint256 minInterval);
    error PseudoArbitrageInvalidPrice(uint256 price);
    error PseudoArbitrageOracleCallFailed();

    /// @notice State for pseudo-arbitrage transformations
    struct PseudoArbitrageState {
        int256 shiftX;              // Curve shift parameter X
        int256 shiftY;              // Curve shift parameter Y
        uint256 excessX;            // Inaccessible excess reserves X
        uint256 excessY;            // Inaccessible excess reserves Y
        uint256 lastMarketPrice;    // Last oracle price (scaled 1e18)
        uint256 lastUpdateTime;     // Last update timestamp
        bool initialized;           // Initialization flag
    }

    /// @notice Storage for pseudo-arbitrage state per order
    mapping(bytes32 orderHash => PseudoArbitrageState) public pseudoArbitrageStates;

    event PseudoArbitrageExecuted(
        bytes32 indexed orderHash,
        int256 shiftX,
        int256 shiftY,
        uint256 excessX,
        uint256 excessY,
        uint256 oldPrice,
        uint256 newPrice
    );

    uint256 constant PRICE_PRECISION = 1e18;

    /// @notice Execute pseudo-arbitrage transformation
    /// @dev This instruction must be called BEFORE swap instructions
    /// @param ctx Execution context with current balances
    /// @param args Packed: oracle (20) | lastMarketPrice (32) | minUpdateInterval (4)
    function _pseudoArbitrageXD(Context memory ctx, bytes calldata args) internal {
        // Must be called before swap amounts are computed
        require(
            ctx.swap.amountIn == 0 || ctx.swap.amountOut == 0,
            PseudoArbitrageShouldBeCalledBeforeSwap(ctx.swap.amountIn, ctx.swap.amountOut)
        );

        // Parse arguments
        (address oracle, uint256 configLastPrice, uint32 minUpdateInterval) = 
            PseudoArbitrageArgsBuilder.parse(args);

        // Get or initialize state
        PseudoArbitrageState storage state = pseudoArbitrageStates[ctx.query.orderHash];
        
        if (!state.initialized) {
            // First time - just initialize with current price
            state.lastMarketPrice = configLastPrice;
            state.lastUpdateTime = block.timestamp;
            state.initialized = true;
            return;
        }

        // Check if enough time has passed
        if (block.timestamp < state.lastUpdateTime + minUpdateInterval) {
            // Too soon - skip update, but apply existing transformations
            _applyTransformations(ctx, state);
            return;
        }

        // Get current price from oracle
        uint256 newMarketPrice = _getOraclePrice(oracle, ctx.query.tokenIn, ctx.query.tokenOut);
        
        if (newMarketPrice == 0) {
            revert PseudoArbitrageInvalidPrice(newMarketPrice);
        }

        // If price hasn't changed significantly, skip transformation
        if (newMarketPrice == state.lastMarketPrice) {
            _applyTransformations(ctx, state);
            return;
        }

        uint256 oldPrice = state.lastMarketPrice;

        // Calculate invariant k from current balances
        uint256 k = ctx.swap.balanceIn * ctx.swap.balanceOut;

        // Calculate stable points for old and new prices
        uint256 oldStableX = _sqrt((k * PRICE_PRECISION) / oldPrice);
        uint256 oldStableY = _sqrt(k * oldPrice) / 1e9; // Divide by 1e9 since sqrt(1e18)
        
        uint256 newStableX = _sqrt((k * PRICE_PRECISION) / newMarketPrice);
        uint256 newStableY = _sqrt(k * newMarketPrice) / 1e9;

        // Calculate curve shifts
        int256 newShiftX;
        int256 newShiftY;
        uint256 newExcessX;
        uint256 newExcessY;

        if (newStableX > oldStableX) {
            // Price increased: Y became more valuable, X less valuable
            // We'll have excess X after the shift
            newShiftX = -int256(newStableX - oldStableX); // Negative shift
            newExcessX = newStableX - oldStableX;
            newShiftY = int256(newStableY - oldStableY);  // Positive shift
            newExcessY = 0;
        } else {
            // Price decreased: X became more valuable, Y less valuable
            // We'll have excess Y after the shift
            newShiftX = int256(newStableX - oldStableX);  // Positive shift
            newExcessX = 0;
            newShiftY = -int256(oldStableY - newStableY); // Negative shift
            newExcessY = oldStableY - newStableY;
        }

        // Update state
        if (!ctx.vm.isStaticContext) {
            state.shiftX = newShiftX;
            state.shiftY = newShiftY;
            state.excessX = newExcessX;
            state.excessY = newExcessY;
            state.lastMarketPrice = newMarketPrice;
            state.lastUpdateTime = block.timestamp;

            emit PseudoArbitrageExecuted(
                ctx.query.orderHash,
                newShiftX,
                newShiftY,
                newExcessX,
                newExcessY,
                oldPrice,
                newMarketPrice
            );
        }

        // Apply transformations to current swap context
        _applyTransformationsFromValues(ctx, newShiftX, newShiftY);
    }

    /// @notice Apply stored transformations to context
    function _applyTransformations(Context memory ctx, PseudoArbitrageState storage state) private view {
        _applyTransformationsFromValues(ctx, state.shiftX, state.shiftY);
    }

    /// @notice Apply transformation values to context balances
    function _applyTransformationsFromValues(
        Context memory ctx,
        int256 shiftX,
        int256 shiftY
    ) private pure {
        // Transform balances: effective = actual - shift
        if (shiftX >= 0) {
            ctx.swap.balanceIn = ctx.swap.balanceIn - uint256(shiftX);
        } else {
            ctx.swap.balanceIn = ctx.swap.balanceIn + uint256(-shiftX);
        }

        if (shiftY >= 0) {
            ctx.swap.balanceOut = ctx.swap.balanceOut - uint256(shiftY);
        } else {
            ctx.swap.balanceOut = ctx.swap.balanceOut + uint256(-shiftY);
        }
    }

    /// @notice Get price from oracle
    /// @dev Override this for different oracle interfaces
    function _getOraclePrice(
        address oracle,
        address tokenIn,
        address tokenOut
    ) internal view returns (uint256 price) {
        // Try to call getPrice(tokenIn, tokenOut)
        (bool success, bytes memory data) = oracle.staticcall(
            abi.encodeWithSignature("getPrice(address,address)", tokenIn, tokenOut)
        );
        
        if (!success || data.length < 32) {
            revert PseudoArbitrageOracleCallFailed();
        }

        // Decode price (first return value)
        (price,) = abi.decode(data, (uint256, uint256));
        
        return price;
    }

    /// @notice Square root using Babylonian method
    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    /// @notice Withdraw excess reserves (separate function, not instruction)
    function withdrawExcess(bytes32 orderHash, address to) external {
        PseudoArbitrageState storage state = pseudoArbitrageStates[orderHash];
        
        require(state.initialized, "Not initialized");
        require(state.excessX > 0 || state.excessY > 0, "No excess");

        // This would need to integrate with actual token transfers
        // In a real implementation, this would pull from Aqua or transfer tokens
        
        uint256 excessX = state.excessX;
        uint256 excessY = state.excessY;
        
        state.excessX = 0;
        state.excessY = 0;

        // Emit event for tracking
        emit PseudoArbitrageExecuted(
            orderHash,
            state.shiftX,
            state.shiftY,
            0,
            0,
            state.lastMarketPrice,
            state.lastMarketPrice
        );
    }
}

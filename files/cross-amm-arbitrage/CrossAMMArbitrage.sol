// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity 0.8.30;

/// @title CrossAMMArbitrage - Exploit price differences between AMM types
/// @notice Arbitrage between ConcentratedAMM (stale prices) and PseudoArbitrageAMM (oracle prices)
/// @dev This is the killer app: when ConcentratedAMM has stale prices and PseudoArbitrage has updated,
///      we can capture the arbitrage before the ConcentratedAMM maker manually rebalances

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@1inch/solidity-utils/contracts/libraries/SafeERC20.sol";

import { IAqua } from "aqua/interfaces/IAqua.sol";
import { AquaApp } from "aqua/AquaApp.sol";
import { ConcentratedAMM } from "../concentrated-amm/ConcentratedAMM.sol";
import { IConcentratedAMMCallback } from "../concentrated-amm/interfaces/IConcentratedAMMCallback.sol";
import { PseudoArbitrageSwapVMRouter } from "../pseudo-arbitrage-amm/src/routers/PseudoArbitrageSwapVMRouter.sol";
import { ISwapVM } from "swap-vm/interfaces/ISwapVM.sol";
import { IArbitrageCallback } from "./interfaces/IArbitrageCallback.sol";

/**
 * @notice CrossAMMArbitrage exploits a powerful market inefficiency:
 * 
 * SCENARIO:
 * 1. ConcentratedAMM: Maker sets position at tick range (e.g., price = 2.0)
 * 2. PseudoArbitrageAMM: Oracle updates to new price (e.g., price = 2.2)
 * 3. ConcentratedAMM price is now STALE (still 2.0)
 * 4. Arbitrageur profits from the 10% discrepancy!
 * 
 * EXECUTION:
 * - Buy tokenX cheap from ConcentratedAMM at 2.0
 * - Sell tokenX expensive to PseudoArbitrageAMM at 2.2
 * - Pocket 10% profit instantly
 * 
 * WHY THIS WORKS:
 * - ConcentratedAMM makers set prices manually (via ticks)
 * - PseudoArbitrageAMM auto-updates via oracle
 * - Gap exists until ConcentratedAMM maker rebalances
 * - This gap can last minutes to hours!
 * 
 * CAPITAL EFFICIENCY:
 * - Use flash arbitrage pattern
 * - Borrow → Buy → Sell → Repay → Keep profit
 * - No upfront capital needed
 */
contract CrossAMMArbitrage is AquaApp, IConcentratedAMMCallback {
    using Math for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    error InsufficientProfit(uint256 profit, uint256 minProfit);
    error ArbitrageNotProfitable(uint256 amountIn, uint256 amountOut);
    error InvalidAMMTypes(string reason);
    error ArbitrageFailed(string reason);
    error PriceDiscrepancyTooLow(uint256 price1, uint256 price2);

    event CrossAMMArbitrageExecuted(
        address indexed executor,
        address indexed token0,
        address indexed token1,
        uint256 amountIn,
        uint256 profit,
        AMMType buyFrom,
        AMMType sellTo,
        uint256 priceDiscrepancy
    );

    event OpportunityDetected(
        address token0,
        address token1,
        uint256 concentratedPrice,
        uint256 pseudoArbPrice,
        uint256 discrepancyBps,
        uint256 estimatedProfit
    );

    /// @notice AMM type identifier
    enum AMMType {
        ConcentratedAMM,     // Tick-based, manual pricing
        PseudoArbitrageAMM   // Oracle-based, auto-updating
    }

    /// @notice Configuration for an AMM
    struct AMMConfig {
        AMMType ammType;
        address ammAddress;
        bytes strategyData;  // ConcentratedAMM.Strategy or ISwapVM.Order
    }

    /// @notice Arbitrage opportunity between two AMMs
    struct CrossAMMOpportunity {
        address token0;
        address token1;
        AMMConfig cheapAMM;      // Where to buy (lower price)
        AMMConfig expensiveAMM;  // Where to sell (higher price)
        uint256 minProfitBps;    // Minimum profit threshold
    }

    /// @notice Result of arbitrage execution
    struct ArbitrageResult {
        uint256 amountIn;
        uint256 amountOut;
        uint256 profit;
        uint256 priceDiscrepancyBps;
        uint256 gasUsed;
    }

    uint256 internal constant BPS_BASE = 10_000;
    uint256 internal constant PRICE_PRECISION = 1e18;

    /// @notice Reference to PseudoArbitrage router
    PseudoArbitrageSwapVMRouter public immutable pseudoArbRouter;

    /// @notice Track successful arbitrages
    mapping(address executor => uint256 totalProfit) public executorProfits;
    mapping(address executor => uint256 successCount) public executorSuccesses;

    // Temporary state for callback
    address internal _callbackToken;
    uint256 internal _callbackAmount;
    address internal _callbackMaker;
    address internal _callbackApp;
    bytes32 internal _callbackStrategyHash;

    constructor(
        IAqua aqua_,
        PseudoArbitrageSwapVMRouter pseudoArbRouter_
    ) AquaApp(aqua_) {
        pseudoArbRouter = pseudoArbRouter_;
    }

    /// ============ Main Arbitrage Execution ============

    /// @notice Execute cross-AMM arbitrage
    /// @param opportunity Arbitrage parameters
    /// @param amountIn Amount to arbitrage
    /// @param minProfit Minimum acceptable profit
    /// @return result Execution result
    function executeArbitrage(
        CrossAMMOpportunity calldata opportunity,
        uint256 amountIn,
        uint256 minProfit
    ) external returns (ArbitrageResult memory result) {
        uint256 gasStart = gasleft();

        // 1. Detect and validate opportunity
        uint256 estimatedProfit = _calculateProfit(opportunity, amountIn);
        require(estimatedProfit >= minProfit, InsufficientProfit(estimatedProfit, minProfit));

        uint256 priceDiscrepancy = _calculateDiscrepancy(opportunity, amountIn);
        
        emit OpportunityDetected(
            opportunity.token0,
            opportunity.token1,
            _getAMMPrice(opportunity.cheapAMM, opportunity.token0, opportunity.token1, amountIn),
            _getAMMPrice(opportunity.expensiveAMM, opportunity.token0, opportunity.token1, amountIn),
            priceDiscrepancy,
            estimatedProfit
        );

        // 2. Execute arbitrage loop
        result = _executeArbitrageLoop(opportunity, amountIn);

        // 3. Verify profitability
        require(result.profit >= minProfit, InsufficientProfit(result.profit, minProfit));

        // 4. Track metrics
        executorProfits[msg.sender] += result.profit;
        executorSuccesses[msg.sender]++;
        result.gasUsed = gasStart - gasleft();
        result.priceDiscrepancyBps = priceDiscrepancy;

        emit CrossAMMArbitrageExecuted(
            msg.sender,
            opportunity.token0,
            opportunity.token1,
            result.amountIn,
            result.profit,
            opportunity.cheapAMM.ammType,
            opportunity.expensiveAMM.ammType,
            priceDiscrepancy
        );

        return result;
    }

    /// @notice Execute with optimal amount calculation
    /// @param opportunity Arbitrage opportunity
    /// @param maxAmountIn Maximum amount to use
    /// @param minProfitBps Minimum profit in basis points
    /// @return result Execution result
    function executeOptimalArbitrage(
        CrossAMMOpportunity calldata opportunity,
        uint256 maxAmountIn,
        uint256 minProfitBps
    ) external returns (ArbitrageResult memory result) {
        // Calculate optimal amount
        uint256 optimalAmount = calculateOptimalAmount(opportunity, maxAmountIn);
        uint256 minProfit = (optimalAmount * minProfitBps) / BPS_BASE;

        return executeArbitrage(opportunity, optimalAmount, minProfit);
    }

    /// ============ Internal Execution Logic ============

    /// @notice Execute complete arbitrage loop
    function _executeArbitrageLoop(
        CrossAMMOpportunity calldata opportunity,
        uint256 amountIn
    ) internal returns (ArbitrageResult memory result) {
        result.amountIn = amountIn;

        // Step 1: Borrow tokens (user provides via callback)
        IArbitrageCallback(msg.sender).borrowForArbitrage(
            opportunity.token0,
            amountIn,
            ""
        );

        // Verify we received the tokens
        require(
            IERC20(opportunity.token0).balanceOf(address(this)) >= amountIn,
            "Insufficient capital received"
        );

        // Step 2: Buy from cheap AMM
        uint256 intermediateAmount = _buyFromAMM(
            opportunity.cheapAMM,
            opportunity.token0,
            opportunity.token1,
            amountIn
        );

        // Step 3: Sell to expensive AMM
        uint256 finalAmount = _sellToAMM(
            opportunity.expensiveAMM,
            opportunity.token1,
            opportunity.token0,
            intermediateAmount
        );

        result.amountOut = finalAmount;

        // Step 4: Calculate profit
        if (finalAmount > amountIn) {
            result.profit = finalAmount - amountIn;
        } else {
            revert ArbitrageNotProfitable(amountIn, finalAmount);
        }

        // Step 5: Repay and distribute profit (in one transfer)
        IERC20(opportunity.token0).safeTransfer(msg.sender, amountIn + result.profit);

        return result;
    }

    /// @notice Buy tokens from an AMM (cheaper one)
    function _buyFromAMM(
        AMMConfig calldata amm,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
        if (amm.ammType == AMMType.ConcentratedAMM) {
            // Swap on ConcentratedAMM
            ConcentratedAMM concentratedAMM = ConcentratedAMM(amm.ammAddress);
            ConcentratedAMM.Strategy memory strategy = abi.decode(
                amm.strategyData,
                (ConcentratedAMM.Strategy)
            );

            // Approve tokens
            IERC20(tokenIn).approve(address(concentratedAMM), amountIn);

            amountOut = concentratedAMM.swapExactIn(
                strategy,
                tokenIn < tokenOut, // zeroForOne
                amountIn,
                0, // No slippage check (we verify profit at end)
                address(this),
                ""
            );
        } else {
            // Swap on PseudoArbitrageAMM (SwapVM)
            ISwapVM.Order memory order = abi.decode(
                amm.strategyData,
                (ISwapVM.Order)
            );

            // Approve tokens
            IERC20(tokenIn).approve(address(pseudoArbRouter), amountIn);

            // Execute swap
            (uint256 actualAmountIn, uint256 actualAmountOut, ) = pseudoArbRouter.swap(
                order,
                tokenIn,
                tokenOut,
                amountIn,
                "" // takerTraitsAndData
            );

            amountOut = actualAmountOut;
        }

        return amountOut;
    }

    /// @notice Sell tokens to an AMM (expensive one)
    function _sellToAMM(
        AMMConfig calldata amm,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
        // Same logic as buy, but reversed direction
        return _buyFromAMM(amm, tokenIn, tokenOut, amountIn);
    }

    /// ============ Price & Profit Calculations ============

    /// @notice Calculate expected profit from arbitrage
    function _calculateProfit(
        CrossAMMOpportunity calldata opportunity,
        uint256 amountIn
    ) internal view returns (uint256 profit) {
        // Get quote from cheap AMM (buy)
        uint256 intermediateAmount = _getQuote(
            opportunity.cheapAMM,
            opportunity.token0,
            opportunity.token1,
            amountIn
        );

        // Get quote from expensive AMM (sell)
        uint256 finalAmount = _getQuote(
            opportunity.expensiveAMM,
            opportunity.token1,
            opportunity.token0,
            intermediateAmount
        );

        if (finalAmount > amountIn) {
            profit = finalAmount - amountIn;
        } else {
            profit = 0;
        }

        return profit;
    }

    /// @notice Get quote from an AMM
    function _getQuote(
        AMMConfig calldata amm,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        if (amm.ammType == AMMType.ConcentratedAMM) {
            ConcentratedAMM concentratedAMM = ConcentratedAMM(amm.ammAddress);
            ConcentratedAMM.Strategy memory strategy = abi.decode(
                amm.strategyData,
                (ConcentratedAMM.Strategy)
            );

            amountOut = concentratedAMM.quoteExactIn(
                strategy,
                tokenIn < tokenOut,
                amountIn
            );
        } else {
            ISwapVM.Order memory order = abi.decode(
                amm.strategyData,
                (ISwapVM.Order)
            );

            (uint256 actualAmountIn, uint256 actualAmountOut, ) = pseudoArbRouter.quote(
                order,
                tokenIn,
                tokenOut,
                amountIn,
                ""
            );

            amountOut = actualAmountOut;
        }

        return amountOut;
    }

    /// @notice Get effective price from an AMM
    function _getAMMPrice(
        AMMConfig calldata amm,
        address token0,
        address token1,
        uint256 sampleAmount
    ) internal view returns (uint256 price) {
        uint256 amountOut = _getQuote(amm, token0, token1, sampleAmount);
        
        if (amountOut > 0) {
            price = (amountOut * PRICE_PRECISION) / sampleAmount;
        } else {
            price = 0;
        }

        return price;
    }

    /// @notice Calculate price discrepancy between AMMs
    function _calculateDiscrepancy(
        CrossAMMOpportunity calldata opportunity,
        uint256 sampleAmount
    ) internal view returns (uint256 discrepancyBps) {
        uint256 cheapPrice = _getAMMPrice(
            opportunity.cheapAMM,
            opportunity.token0,
            opportunity.token1,
            sampleAmount
        );

        uint256 expensivePrice = _getAMMPrice(
            opportunity.expensiveAMM,
            opportunity.token0,
            opportunity.token1,
            sampleAmount
        );

        if (expensivePrice > cheapPrice && cheapPrice > 0) {
            discrepancyBps = ((expensivePrice - cheapPrice) * BPS_BASE) / cheapPrice;
        } else {
            discrepancyBps = 0;
        }

        return discrepancyBps;
    }

    /// ============ Optimal Amount Calculation ============

    /// @notice Calculate optimal arbitrage amount
    /// @param opportunity Arbitrage opportunity
    /// @param maxAmountIn Maximum amount to consider
    /// @return optimalAmount Optimal amount for maximum profit
    function calculateOptimalAmount(
        CrossAMMOpportunity calldata opportunity,
        uint256 maxAmountIn
    ) public view returns (uint256 optimalAmount) {
        // Binary search for optimal amount
        uint256 low = maxAmountIn / 100; // Start at 1%
        uint256 high = maxAmountIn;
        uint256 bestAmount = low;
        uint256 bestProfit = 0;

        for (uint256 i = 0; i < 20; i++) {
            uint256 mid = (low + high) / 2;
            
            uint256 profit = _calculateProfit(opportunity, mid);
            
            if (profit > bestProfit) {
                bestProfit = profit;
                bestAmount = mid;
            }

            // Check gradient
            uint256 profitAtMidPlus = _calculateProfit(opportunity, mid + mid / 10);
            
            if (profitAtMidPlus > profit) {
                low = mid;
            } else {
                high = mid;
            }
        }

        return bestAmount;
    }

    /// ============ Opportunity Detection ============

    /// @notice Scan for cross-AMM arbitrage opportunities
    /// @param token0 First token
    /// @param token1 Second token
    /// @param concentratedConfigs Array of ConcentratedAMM configs
    /// @param pseudoArbConfigs Array of PseudoArbitrage configs
    /// @param sampleAmount Sample amount for checking
    /// @return bestOpportunity Best opportunity found
    /// @return maxProfit Maximum profit available
    function scanOpportunities(
        address token0,
        address token1,
        AMMConfig[] calldata concentratedConfigs,
        AMMConfig[] calldata pseudoArbConfigs,
        uint256 sampleAmount
    ) external view returns (
        CrossAMMOpportunity memory bestOpportunity,
        uint256 maxProfit
    ) {
        maxProfit = 0;

        // Check all combinations
        for (uint256 i = 0; i < concentratedConfigs.length; i++) {
            for (uint256 j = 0; j < pseudoArbConfigs.length; j++) {
                // Try: buy from Concentrated, sell to PseudoArb
                CrossAMMOpportunity memory opp1 = CrossAMMOpportunity({
                    token0: token0,
                    token1: token1,
                    cheapAMM: concentratedConfigs[i],
                    expensiveAMM: pseudoArbConfigs[j],
                    minProfitBps: 0
                });

                uint256 profit1 = _calculateProfit(opp1, sampleAmount);
                if (profit1 > maxProfit) {
                    maxProfit = profit1;
                    bestOpportunity = opp1;
                }

                // Try: buy from PseudoArb, sell to Concentrated
                CrossAMMOpportunity memory opp2 = CrossAMMOpportunity({
                    token0: token0,
                    token1: token1,
                    cheapAMM: pseudoArbConfigs[j],
                    expensiveAMM: concentratedConfigs[i],
                    minProfitBps: 0
                });

                uint256 profit2 = _calculateProfit(opp2, sampleAmount);
                if (profit2 > maxProfit) {
                    maxProfit = profit2;
                    bestOpportunity = opp2;
                }
            }
        }

        return (bestOpportunity, maxProfit);
    }

    /// @notice Check if opportunity exists
    /// @param opportunity Opportunity to check
    /// @param minProfitBps Minimum profit threshold
    /// @param sampleAmount Sample amount
    /// @return exists Whether opportunity exists
    /// @return estimatedProfit Estimated profit
    /// @return discrepancy Price discrepancy in bps
    function checkOpportunity(
        CrossAMMOpportunity calldata opportunity,
        uint256 minProfitBps,
        uint256 sampleAmount
    ) external view returns (
        bool exists,
        uint256 estimatedProfit,
        uint256 discrepancy
    ) {
        estimatedProfit = _calculateProfit(opportunity, sampleAmount);
        discrepancy = _calculateDiscrepancy(opportunity, sampleAmount);
        
        uint256 minProfit = (sampleAmount * minProfitBps) / BPS_BASE;
        exists = estimatedProfit >= minProfit && discrepancy > 0;

        return (exists, estimatedProfit, discrepancy);
    }

    /// ============ ConcentratedAMM Callback ============

    /// @notice Callback for ConcentratedAMM swaps
    function concentratedAMMCallback(
        address tokenIn,
        address /* tokenOut */,
        uint256 amountIn,
        uint256 /* amountOut */,
        address maker,
        address app,
        bytes32 strategyHash,
        bytes calldata /* takerData */
    ) external override {
        // Store callback data
        _callbackToken = tokenIn;
        _callbackAmount = amountIn;
        _callbackMaker = maker;
        _callbackApp = app;
        _callbackStrategyHash = strategyHash;

        // Push tokens to Aqua
        IERC20(tokenIn).approve(address(AQUA), amountIn);
        AQUA.push(maker, app, strategyHash, tokenIn, amountIn);
    }

    /// ============ View Functions ============

    /// @notice Get executor statistics
    function getExecutorStats(address executor) external view returns (
        uint256 totalProfit,
        uint256 successCount,
        uint256 averageProfit
    ) {
        totalProfit = executorProfits[executor];
        successCount = executorSuccesses[executor];
        averageProfit = successCount > 0 ? totalProfit / successCount : 0;
    }

    /// @notice Estimate gas cost
    function estimateGas() external pure returns (uint256) {
        return 250_000; // Conservative estimate for cross-AMM arbitrage
    }
}

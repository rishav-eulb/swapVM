// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity 0.8.30;

/// @title CrossAMMArbitrageBot - Automated cross-AMM arbitrage execution
/// @notice Continuously monitors for price discrepancies and executes profitable trades
/// @dev Designed for keeper/bot operation to capture arbitrage as soon as it appears

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@1inch/solidity-utils/contracts/libraries/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { CrossAMMArbitrage } from "./CrossAMMArbitrage.sol";
import { IArbitrageCallback } from "./interfaces/IArbitrageCallback.sol";

contract CrossAMMArbitrageBot is IArbitrageCallback, Ownable {
    using SafeERC20 for IERC20;

    error InsufficientCapital(address token, uint256 required, uint256 available);
    error UnauthorizedCaller(address caller);
    error OpportunityNotProfitable(uint256 estimatedProfit, uint256 minProfit);
    error ExecutionFailed(string reason);

    event ArbitrageExecuted(
        address indexed token0,
        address indexed token1,
        uint256 amountIn,
        uint256 profit,
        uint256 gasUsed,
        uint256 priceDiscrepancy
    );

    event OpportunityMonitored(
        address indexed token0,
        address indexed token1,
        uint256 discrepancy,
        uint256 estimatedProfit,
        bool executed
    );

    event CapitalDeposited(address indexed token, uint256 amount);
    event CapitalWithdrawn(address indexed token, uint256 amount);
    event StrategyAdded(address indexed token0, address indexed token1, uint256 strategyId);

    CrossAMMArbitrage public immutable arbitrage;

    /// @notice Authorized executors (keepers/bots)
    mapping(address => bool) public isExecutor;

    /// @notice Available capital per token
    mapping(address => uint256) public availableCapital;

    /// @notice Maximum capital per arbitrage per token
    mapping(address => uint256) public maxCapitalPerArbitrage;

    /// @notice Minimum profit in basis points
    uint256 public minProfitBps = 50; // 0.5% default

    /// @notice Minimum price discrepancy to consider (bps)
    uint256 public minDiscrepancyBps = 100; // 1% default

    /// @notice Monitored strategies
    struct MonitoredStrategy {
        address token0;
        address token1;
        CrossAMMArbitrage.AMMConfig[] concentratedConfigs;
        CrossAMMArbitrage.AMMConfig[] pseudoArbConfigs;
        bool active;
    }

    /// @notice Strategy registry
    mapping(uint256 strategyId => MonitoredStrategy) public strategies;
    uint256 public strategyCount;

    /// @notice Performance tracking
    struct PerformanceStats {
        uint256 totalExecutions;
        uint256 totalProfit;
        uint256 totalGasUsed;
        uint256 lastExecutionTime;
        uint256 largestProfit;
    }

    mapping(address token => PerformanceStats) public performanceStats;

    modifier onlyExecutor() {
        require(isExecutor[msg.sender] || msg.sender == owner(), UnauthorizedCaller(msg.sender));
        _;
    }

    constructor(CrossAMMArbitrage arbitrage_) Ownable(msg.sender) {
        arbitrage = arbitrage_;
        isExecutor[msg.sender] = true;
    }

    /// ============ Capital Management ============

    /// @notice Deposit capital for arbitrage
    /// @param token Token to deposit
    /// @param amount Amount to deposit
    function depositCapital(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        availableCapital[token] += amount;

        // Set default max per arbitrage if not set
        if (maxCapitalPerArbitrage[token] == 0) {
            maxCapitalPerArbitrage[token] = amount / 4; // Use max 25% per trade
        }

        emit CapitalDeposited(token, amount);
    }

    /// @notice Withdraw capital
    /// @param token Token to withdraw
    /// @param amount Amount to withdraw
    function withdrawCapital(address token, uint256 amount) external onlyOwner {
        require(
            availableCapital[token] >= amount,
            InsufficientCapital(token, amount, availableCapital[token])
        );

        availableCapital[token] -= amount;
        IERC20(token).safeTransfer(msg.sender, amount);

        emit CapitalWithdrawn(token, amount);
    }

    /// @notice Set maximum capital per arbitrage
    /// @param token Token address
    /// @param maxAmount Maximum amount
    function setMaxCapitalPerArbitrage(address token, uint256 maxAmount) external onlyOwner {
        maxCapitalPerArbitrage[token] = maxAmount;
    }

    /// ============ Strategy Management ============

    /// @notice Add a monitored strategy
    /// @param token0 First token
    /// @param token1 Second token
    /// @param concentratedConfigs ConcentratedAMM configurations
    /// @param pseudoArbConfigs PseudoArbitrage configurations
    /// @return strategyId ID of the added strategy
    function addStrategy(
        address token0,
        address token1,
        CrossAMMArbitrage.AMMConfig[] calldata concentratedConfigs,
        CrossAMMArbitrage.AMMConfig[] calldata pseudoArbConfigs
    ) external onlyOwner returns (uint256 strategyId) {
        strategyId = strategyCount++;

        MonitoredStrategy storage strategy = strategies[strategyId];
        strategy.token0 = token0;
        strategy.token1 = token1;
        strategy.active = true;

        // Store configs
        for (uint256 i = 0; i < concentratedConfigs.length; i++) {
            strategy.concentratedConfigs.push(concentratedConfigs[i]);
        }
        for (uint256 i = 0; i < pseudoArbConfigs.length; i++) {
            strategy.pseudoArbConfigs.push(pseudoArbConfigs[i]);
        }

        emit StrategyAdded(token0, token1, strategyId);
        return strategyId;
    }

    /// @notice Toggle strategy active status
    /// @param strategyId Strategy ID
    /// @param active New active status
    function setStrategyActive(uint256 strategyId, bool active) external onlyOwner {
        strategies[strategyId].active = active;
    }

    /// ============ Execution Parameters ============

    /// @notice Set minimum profit threshold
    /// @param profitBps Minimum profit in basis points
    function setMinProfitBps(uint256 profitBps) external onlyOwner {
        minProfitBps = profitBps;
    }

    /// @notice Set minimum discrepancy threshold
    /// @param discrepancyBps Minimum discrepancy in basis points
    function setMinDiscrepancyBps(uint256 discrepancyBps) external onlyOwner {
        minDiscrepancyBps = discrepancyBps;
    }

    /// @notice Add/remove executor
    /// @param executor Address to modify
    /// @param status New authorization status
    function setExecutor(address executor, bool status) external onlyOwner {
        isExecutor[executor] = status;
    }

    /// ============ Arbitrage Execution ============

    /// @notice Execute specific arbitrage opportunity
    /// @param opportunity Opportunity to execute
    /// @param amountIn Amount to use (0 for optimal)
    /// @return result Execution result
    function executeArbitrage(
        CrossAMMArbitrage.CrossAMMOpportunity calldata opportunity,
        uint256 amountIn
    ) external onlyExecutor returns (CrossAMMArbitrage.ArbitrageResult memory result) {
        // Use optimal amount if not specified
        if (amountIn == 0) {
            uint256 maxAmount = maxCapitalPerArbitrage[opportunity.token0];
            amountIn = arbitrage.calculateOptimalAmount(opportunity, maxAmount);
        }

        // Verify capital
        require(
            availableCapital[opportunity.token0] >= amountIn,
            InsufficientCapital(opportunity.token0, amountIn, availableCapital[opportunity.token0])
        );

        // Calculate minimum profit
        uint256 minProfit = (amountIn * minProfitBps) / 10_000;

        // Approve arbitrage contract
        IERC20(opportunity.token0).approve(address(arbitrage), amountIn);

        // Execute
        uint256 gasStart = gasleft();
        result = arbitrage.executeArbitrage(opportunity, amountIn, minProfit);

        // Update capital (we get back original + profit)
        availableCapital[opportunity.token0] += result.profit;

        // Update stats
        _updateStats(opportunity.token0, result.profit, gasStart - gasleft());

        emit ArbitrageExecuted(
            opportunity.token0,
            opportunity.token1,
            result.amountIn,
            result.profit,
            result.gasUsed,
            result.priceDiscrepancyBps
        );

        return result;
    }

    /// @notice Monitor and execute if profitable
    /// @param opportunity Opportunity to check
    /// @return executed Whether executed
    /// @return profit Profit if executed
    function monitorAndExecute(
        CrossAMMArbitrage.CrossAMMOpportunity calldata opportunity
    ) external onlyExecutor returns (bool executed, uint256 profit) {
        uint256 sampleAmount = maxCapitalPerArbitrage[opportunity.token0];

        // Check opportunity
        (bool exists, uint256 estimatedProfit, uint256 discrepancy) = 
            arbitrage.checkOpportunity(opportunity, minProfitBps, sampleAmount);

        emit OpportunityMonitored(
            opportunity.token0,
            opportunity.token1,
            discrepancy,
            estimatedProfit,
            exists
        );

        if (!exists || discrepancy < minDiscrepancyBps) {
            return (false, 0);
        }

        // Execute
        try this.executeArbitrage(opportunity, 0) returns (
            CrossAMMArbitrage.ArbitrageResult memory result
        ) {
            return (true, result.profit);
        } catch Error(string memory reason) {
            revert ExecutionFailed(reason);
        }
    }

    /// @notice Scan and execute best opportunity for a strategy
    /// @param strategyId Strategy ID to scan
    /// @return executed Whether executed
    /// @return profit Profit if executed
    function scanAndExecuteStrategy(
        uint256 strategyId
    ) external onlyExecutor returns (bool executed, uint256 profit) {
        MonitoredStrategy storage strategy = strategies[strategyId];
        require(strategy.active, "Strategy not active");

        uint256 sampleAmount = maxCapitalPerArbitrage[strategy.token0];

        // Scan for best opportunity
        (
            CrossAMMArbitrage.CrossAMMOpportunity memory bestOpp,
            uint256 maxProfit
        ) = arbitrage.scanOpportunities(
            strategy.token0,
            strategy.token1,
            strategy.concentratedConfigs,
            strategy.pseudoArbConfigs,
            sampleAmount
        );

        // Check if profitable enough
        uint256 minProfit = (sampleAmount * minProfitBps) / 10_000;
        if (maxProfit < minProfit) {
            return (false, 0);
        }

        // Execute
        CrossAMMArbitrage.ArbitrageResult memory result = this.executeArbitrage(bestOpp, 0);
        return (true, result.profit);
    }

    /// @notice Scan all active strategies and execute best
    /// @return executed Whether any arbitrage was executed
    /// @return profit Total profit captured
    function scanAllStrategies() external onlyExecutor returns (bool executed, uint256 profit) {
        uint256 bestProfit = 0;
        uint256 bestStrategyId = 0;
        bool foundOpportunity = false;

        // Find best opportunity across all strategies
        for (uint256 i = 0; i < strategyCount; i++) {
            if (!strategies[i].active) continue;

            MonitoredStrategy storage strategy = strategies[i];
            uint256 sampleAmount = maxCapitalPerArbitrage[strategy.token0];

            (
                CrossAMMArbitrage.CrossAMMOpportunity memory opp,
                uint256 estimatedProfit
            ) = arbitrage.scanOpportunities(
                strategy.token0,
                strategy.token1,
                strategy.concentratedConfigs,
                strategy.pseudoArbConfigs,
                sampleAmount
            );

            if (estimatedProfit > bestProfit) {
                bestProfit = estimatedProfit;
                bestStrategyId = i;
                foundOpportunity = true;
            }
        }

        if (!foundOpportunity) {
            return (false, 0);
        }

        // Execute best opportunity
        return this.scanAndExecuteStrategy(bestStrategyId);
    }

    /// ============ Callback Implementation ============

    /// @notice Callback to provide capital for arbitrage
    function borrowForArbitrage(
        address token,
        uint256 amount,
        bytes calldata /* data */
    ) external override {
        require(msg.sender == address(arbitrage), UnauthorizedCaller(msg.sender));
        require(
            availableCapital[token] >= amount,
            InsufficientCapital(token, amount, availableCapital[token])
        );

        // Transfer tokens
        IERC20(token).safeTransfer(msg.sender, amount);

        // Temporarily reduce capital
        availableCapital[token] -= amount;
    }

    /// ============ Internal Functions ============

    /// @notice Update performance statistics
    function _updateStats(address token, uint256 profit, uint256 gasUsed) internal {
        PerformanceStats storage stats = performanceStats[token];
        stats.totalExecutions++;
        stats.totalProfit += profit;
        stats.totalGasUsed += gasUsed;
        stats.lastExecutionTime = block.timestamp;
        if (profit > stats.largestProfit) {
            stats.largestProfit = profit;
        }
    }

    /// ============ View Functions ============

    /// @notice Get strategy details
    /// @param strategyId Strategy ID
    /// @return token0 First token
    /// @return token1 Second token
    /// @return active Whether active
    /// @return concentratedCount Number of concentrated configs
    /// @return pseudoArbCount Number of pseudo-arb configs
    function getStrategy(uint256 strategyId) external view returns (
        address token0,
        address token1,
        bool active,
        uint256 concentratedCount,
        uint256 pseudoArbCount
    ) {
        MonitoredStrategy storage strategy = strategies[strategyId];
        return (
            strategy.token0,
            strategy.token1,
            strategy.active,
            strategy.concentratedConfigs.length,
            strategy.pseudoArbConfigs.length
        );
    }

    /// @notice Get performance statistics
    /// @param token Token address
    /// @return stats Performance statistics
    function getPerformanceStats(address token) external view returns (
        PerformanceStats memory stats
    ) {
        return performanceStats[token];
    }

    /// @notice Get capital status
    /// @param token Token address
    /// @return available Available capital
    /// @return maxPerArbitrage Max per arbitrage
    /// @return utilization Utilization percentage (basis points)
    function getCapitalStatus(address token) external view returns (
        uint256 available,
        uint256 maxPerArbitrage,
        uint256 utilization
    ) {
        available = availableCapital[token];
        maxPerArbitrage = maxCapitalPerArbitrage[token];
        
        if (maxPerArbitrage > 0) {
            utilization = (available * 10_000) / maxPerArbitrage;
        } else {
            utilization = 0;
        }
    }

    /// @notice Check if any opportunities exist
    /// @return hasOpportunities Whether opportunities exist
    /// @return bestProfit Best estimated profit
    function checkForOpportunities() external view returns (
        bool hasOpportunities,
        uint256 bestProfit
    ) {
        bestProfit = 0;

        for (uint256 i = 0; i < strategyCount; i++) {
            if (!strategies[i].active) continue;

            MonitoredStrategy storage strategy = strategies[i];
            uint256 sampleAmount = maxCapitalPerArbitrage[strategy.token0];

            (, uint256 profit) = arbitrage.scanOpportunities(
                strategy.token0,
                strategy.token1,
                strategy.concentratedConfigs,
                strategy.pseudoArbConfigs,
                sampleAmount
            );

            if (profit > bestProfit) {
                bestProfit = profit;
            }
        }

        uint256 minProfit = (maxCapitalPerArbitrage[address(0)] * minProfitBps) / 10_000;
        hasOpportunities = bestProfit >= minProfit;
    }

    /// @notice Emergency withdrawal
    /// @param token Token to withdraw
    function emergencyWithdraw(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).safeTransfer(owner(), balance);
            availableCapital[token] = 0;
        }
    }
}

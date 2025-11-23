// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity ^0.8.0;

/// @title IConcentratedAMMCallback
/// @notice Callback interface for ConcentratedAMM swaps
interface IConcentratedAMMCallback {
    /// @notice Called when a swap is executed
    /// @param tokenIn The input token address
    /// @param tokenOut The output token address
    /// @param amountIn Amount of input tokens required
    /// @param amountOut Amount of output tokens received
    /// @param maker The liquidity provider's address
    /// @param app The ConcentratedAMM app address
    /// @param strategyHash The strategy identifier
    /// @param takerData Additional data from the taker
    function concentratedAMMCallback(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address maker,
        address app,
        bytes32 strategyHash,
        bytes calldata takerData
    ) external;
}

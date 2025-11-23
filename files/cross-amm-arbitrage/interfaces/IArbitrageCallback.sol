// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity ^0.8.0;

/// @title IArbitrageCallback
/// @notice Callback interface for arbitrage capital provision
interface IArbitrageCallback {
    /// @notice Called when arbitrage needs capital
    /// @param token Token to borrow
    /// @param amount Amount to borrow
    /// @param data Additional callback data
    function borrowForArbitrage(
        address token,
        uint256 amount,
        bytes calldata data
    ) external;
}


// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockERC20
/// @notice Simple mock ERC20 token for testing and development
contract MockERC20 is ERC20 {
    uint8 private _decimals;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_
    ) ERC20(name, symbol) {
        _decimals = decimals_;
    }

    /// @notice Mint tokens to any address (unrestricted for testing)
    /// @param to Address to mint tokens to
    /// @param amount Amount of tokens to mint
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// @notice Override decimals to allow custom decimal places
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /// @notice Burn tokens from caller's balance
    /// @param amount Amount of tokens to burn
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}


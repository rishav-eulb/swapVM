// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

/// @custom:license-url https://github.com/1inch/swap-vm/blob/main/LICENSES/SwapVM-1.1.txt
/// @custom:copyright © 2025 Degensoft Ltd

import { Context } from "swap-vm/libs/VM.sol";

// Core instructions
import { Controls } from "swap-vm/instructions/Controls.sol";
import { Balances } from "swap-vm/instructions/Balances.sol";
import { XYCSwap } from "swap-vm/instructions/XYCSwap.sol";
import { XYCConcentrate } from "swap-vm/instructions/XYCConcentrate.sol";
import { Decay } from "swap-vm/instructions/Decay.sol";
import { LimitSwap } from "swap-vm/instructions/LimitSwap.sol";
import { MinRate } from "swap-vm/instructions/MinRate.sol";
import { DutchAuction } from "swap-vm/instructions/DutchAuction.sol";
import { BaseFeeAdjuster } from "swap-vm/instructions/BaseFeeAdjuster.sol";
import { Fee } from "swap-vm/instructions/Fee.sol";
import { Invalidators } from "swap-vm/instructions/Invalidators.sol";
import { Extruction } from "swap-vm/instructions/Extruction.sol";

// NEW: Pseudo-Arbitrage instruction
import { PseudoArbitrage } from "../instructions/PseudoArbitrage.sol";

contract PseudoArbitrageOpcodes is
    Controls,
    Balances,
    Invalidators,
    XYCSwap,
    XYCConcentrate,
    Decay,
    LimitSwap,
    MinRate,
    DutchAuction,
    BaseFeeAdjuster,
    Fee,
    Extruction,
    PseudoArbitrage  // Include our new instruction
{
    constructor(address aqua) Fee(aqua) {}

    function _notInstruction(Context memory /* ctx */, bytes calldata /* args */) internal view {}

    function _opcodes() internal pure virtual returns (function(Context memory, bytes calldata) internal[] memory result) {
        function(Context memory, bytes calldata) internal[45] memory instructions = [
            _notInstruction,
            // Debug - reserved for debugging utilities (core infrastructure)
            _notInstruction,
            _notInstruction,
            _notInstruction,
            _notInstruction,
            _notInstruction,
            _notInstruction,
            _notInstruction,
            _notInstruction,
            _notInstruction,
            _notInstruction,
            // Controls - control flow (core infrastructure)
            Controls._jump,
            Controls._jumpIfTokenIn,
            Controls._jumpIfTokenOut,
            Controls._deadline,
            Controls._onlyTakerTokenBalanceNonZero,
            Controls._onlyTakerTokenBalanceGte,
            Controls._onlyTakerTokenSupplyShareGte,
            // Balances - balance operations
            Balances._staticBalancesXD,
            Balances._dynamicBalancesXD,
            // Invalidators - order invalidation
            Invalidators._invalidateBit1D,
            Invalidators._invalidateTokenIn1D,
            Invalidators._invalidateTokenOut1D,
            // XYCSwap - basic swap
            XYCSwap._xycSwapXD,
            // XYCConcentrate - liquidity concentration
            XYCConcentrate._xycConcentrateGrowLiquidityXD,
            XYCConcentrate._xycConcentrateGrowLiquidity2D,
            // Decay - Decay AMM
            Decay._decayXD,
            // LimitSwap - limit orders
            LimitSwap._limitSwap1D,
            LimitSwap._limitSwapOnlyFull1D,
            // MinRate - minimum exchange rate
            MinRate._requireMinRate1D,
            MinRate._adjustMinRate1D,
            // DutchAuction - auction mechanism
            DutchAuction._dutchAuctionBalanceIn1D,
            DutchAuction._dutchAuctionBalanceOut1D,
            // BaseFeeAdjuster - gas-based pricing
            BaseFeeAdjuster._baseFeeAdjuster1D,
            // NEW: PseudoArbitrage - curve transformation
            PseudoArbitrage._pseudoArbitrageXD,
            // NOTE: Add new instructions here to maintain backward compatibility
            Extruction._extruction,
            Controls._salt,
            Fee._flatFeeAmountInXD,
            Fee._flatFeeAmountOutXD,
            Fee._progressiveFeeInXD,
            Fee._progressiveFeeOutXD,
            Fee._protocolFeeAmountOutXD,
            Fee._aquaProtocolFeeAmountOutXD
        ];

        // Efficiently turning static memory array into dynamic memory array
        uint256 instructionsArrayLength = instructions.length - 1;
        assembly ("memory-safe") {
            result := instructions
            mstore(result, instructionsArrayLength)
        }
    }
}

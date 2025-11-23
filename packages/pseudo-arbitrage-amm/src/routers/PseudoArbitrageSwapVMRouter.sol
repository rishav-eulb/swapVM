// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

/// @custom:license-url https://github.com/1inch/swap-vm/blob/main/LICENSES/SwapVM-1.1.txt
/// @custom:copyright © 2025 Degensoft Ltd

import { Context } from "swap-vm/libs/VM.sol";
import { Simulator } from "swap-vm/libs/Simulator.sol";
import { SwapVM } from "swap-vm/SwapVM.sol";
import { PseudoArbitrageOpcodes } from "../opcodes/PseudoArbitrageOpcodes.sol";

/**
 * @title PseudoArbitrageSwapVMRouter
 * @notice SwapVM router with pseudo-arbitrage instruction support
 * @dev This router includes all standard SwapVM instructions plus the PseudoArbitrage instruction
 * 
 * Deployment:
 * ```
 * PseudoArbitrageSwapVMRouter router = new PseudoArbitrageSwapVMRouter(
 *     aquaAddress,
 *     "PseudoArbitrageSwapVM",
 *     "1.0"
 * );
 * ```
 */
contract PseudoArbitrageSwapVMRouter is Simulator, SwapVM, PseudoArbitrageOpcodes {
    constructor(
        address aqua,
        string memory name,
        string memory version
    ) SwapVM(aqua, name, version) PseudoArbitrageOpcodes(aqua) {}

    function _instructions()
        internal
        pure
        override
        returns (function(Context memory, bytes calldata) internal[] memory result)
    {
        return _opcodes();
    }
}

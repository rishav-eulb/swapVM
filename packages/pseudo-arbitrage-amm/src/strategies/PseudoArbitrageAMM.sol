// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

/// @custom:license-url https://github.com/1inch/swap-vm/blob/main/LICENSES/SwapVM-1.1.txt
/// @custom:copyright © 2025 Degensoft Ltd

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { PseudoArbitrageOpcodes } from "../opcodes/PseudoArbitrageOpcodes.sol";
import { SwapVM, ISwapVM } from "swap-vm/SwapVM.sol";
import { MakerTraitsLib } from "swap-vm/libs/MakerTraits.sol";
import { ProgramBuilder, Program } from "shared-utils/ProgramBuilder.sol";

import { BalancesArgsBuilder } from "swap-vm/instructions/Balances.sol";
import { PseudoArbitrageArgsBuilder } from "../instructions/PseudoArbitrage.sol";
import { FeeArgsBuilder } from "swap-vm/instructions/Fee.sol";
import { ControlsArgsBuilder } from "swap-vm/instructions/Controls.sol";
import { XYCConcentrateArgsBuilder } from "swap-vm/instructions/XYCConcentrate.sol";

/**
 * @title PseudoArbitrageAMM
 * @notice Strategy builder for PseudoArbitrage AMM programs
 * @dev Creates SwapVM programs that implement the pseudo-arbitrage strategy
 * 
 * Program Structure:
 * 1. _staticBalancesXD - Set initial token balances
 * 2. _pseudoArbitrageXD - Check oracle and transform curve if needed
 * 3. _flatFeeAmountInXD - Apply trading fee (optional)
 * 4. _xycSwapXD - Execute swap with transformed balances
 * 5. _deadline - Ensure timely execution
 * 6. _salt - Unique order identifier (optional)
 * 
 * Example:
 * ```
 * PseudoArbitrageAMM builder = new PseudoArbitrageAMM(aqua);
 * 
 * ISwapVM.Order memory order = builder.buildProgram(
 *     maker,
 *     uint40(block.timestamp + 1 days),  // expiration
 *     address(tokenX),
 *     address(tokenY),
 *     1000 ether,                         // initial X balance
 *     3000 ether,                         // initial Y balance (price = 3)
 *     address(oracle),
 *     3 ether,                            // initial price (3 Y per 1 X)
 *     1 hours,                            // min update interval
 *     30,                                 // 0.3% fee
 *     0                                   // salt (optional)
 * );
 * ```
 */
contract PseudoArbitrageAMM is PseudoArbitrageOpcodes {
    using SafeCast for uint256;
    using ProgramBuilder for Program;

    error InvalidBalances(uint256 balanceX, uint256 balanceY);
    error InvalidPrice(uint256 price);
    error InvalidFeeRate(uint256 feeRate);

    uint256 constant MAX_FEE_RATE = 1000; // 10%

    constructor(address aqua) PseudoArbitrageOpcodes(aqua) {}

    /**
     * @notice Build a pseudo-arbitrage AMM program
     * @param maker Address of the liquidity provider
     * @param expiration Order expiration timestamp
     * @param token0 First token (conventionally X or token with lower address)
     * @param token1 Second token (conventionally Y)
     * @param balance0 Initial balance of token0
     * @param balance1 Initial balance of token1
     * @param oracle Oracle address for price feeds
     * @param initialPrice Initial market price (token1 per token0, scaled by 1e18)
     * @param minUpdateInterval Minimum seconds between oracle updates
     * @param feeBps Trading fee in basis points (e.g., 30 = 0.3%)
     * @param salt Unique identifier for the order (0 = no salt)
     * @return order Complete SwapVM order ready to be shipped to Aqua
     */
    function buildProgram(
        address maker,
        uint40 expiration,
        address token0,
        address token1,
        uint256 balance0,
        uint256 balance1,
        address oracle,
        uint256 initialPrice,
        uint32 minUpdateInterval,
        uint16 feeBps,
        uint64 salt
    ) external pure returns (ISwapVM.Order memory) {
        // Validate inputs
        if (balance0 == 0 || balance1 == 0) {
            revert InvalidBalances(balance0, balance1);
        }
        if (initialPrice == 0) {
            revert InvalidPrice(initialPrice);
        }
        if (feeBps > MAX_FEE_RATE) {
            revert InvalidFeeRate(feeBps);
        }

        // Initialize program builder
        Program memory program = ProgramBuilder.init(_opcodes());

        // Build token arrays for balances
        address[] memory tokens = new address[](2);
        tokens[0] = token0;
        tokens[1] = token1;

        uint256[] memory balances = new uint256[](2);
        balances[0] = balance0;
        balances[1] = balance1;

        // Build program bytecode
        bytes memory bytecode = bytes.concat(
            // 1. Set initial balances (required for all swaps)
            program.build(
                _staticBalancesXD,
                BalancesArgsBuilder.build(tokens, balances)
            ),
            
            // 2. Execute pseudo-arbitrage transformation
            //    This checks oracle and transforms curve if price changed
            program.build(
                _pseudoArbitrageXD,
                PseudoArbitrageArgsBuilder.build(
                    oracle,
                    initialPrice,
                    minUpdateInterval
                )
            ),
            
            // 3. Apply trading fee (if specified)
            feeBps > 0
                ? program.build(
                    _flatFeeAmountInXD,
                    FeeArgsBuilder.buildFlatFee(feeBps)
                )
                : bytes(""),
            
            // 4. Execute swap using XYC formula
            //    This uses the transformed balances from pseudo-arbitrage
            program.build(_xycSwapXD),
            
            // 5. Enforce deadline
            program.build(
                _deadline,
                ControlsArgsBuilder.buildDeadline(expiration)
            ),
            
            // 6. Optional salt for uniqueness
            salt > 0
                ? program.build(
                    _salt,
                    ControlsArgsBuilder.buildSalt(salt)
                )
                : bytes("")
        );

        // Build complete order
        return MakerTraitsLib.build(
            MakerTraitsLib.Args({
                maker: maker,
                shouldUnwrapWeth: false,
                useAquaInsteadOfSignature: true,
                allowZeroAmountIn: false,
                receiver: address(0),
                hasPreTransferInHook: false,
                hasPostTransferInHook: false,
                hasPreTransferOutHook: false,
                hasPostTransferOutHook: false,
                preTransferInTarget: address(0),
                preTransferInData: "",
                postTransferInTarget: address(0),
                postTransferInData: "",
                preTransferOutTarget: address(0),
                preTransferOutData: "",
                postTransferOutTarget: address(0),
                postTransferOutData: "",
                program: bytecode
            })
        );
    }

    /**
     * @notice Build a pseudo-arbitrage AMM program with concentration
     * @dev Adds XYC concentration for more efficient liquidity deployment
     * @param maker Address of the liquidity provider
     * @param expiration Order expiration timestamp
     * @param token0 First token
     * @param token1 Second token
     * @param balance0 Initial balance of token0
     * @param balance1 Initial balance of token1
     * @param delta0 Concentration delta for token0
     * @param delta1 Concentration delta for token1
     * @param oracle Oracle address
     * @param initialPrice Initial market price
     * @param minUpdateInterval Min seconds between updates
     * @param feeBps Trading fee in basis points
     * @param salt Unique identifier
     * @return order Complete SwapVM order
     */
    function buildConcentratedProgram(
        address maker,
        uint40 expiration,
        address token0,
        address token1,
        uint256 balance0,
        uint256 balance1,
        uint256 delta0,
        uint256 delta1,
        address oracle,
        uint256 initialPrice,
        uint32 minUpdateInterval,
        uint16 feeBps,
        uint64 salt
    ) external pure returns (ISwapVM.Order memory) {
        if (balance0 == 0 || balance1 == 0) {
            revert InvalidBalances(balance0, balance1);
        }
        if (initialPrice == 0) {
            revert InvalidPrice(initialPrice);
        }
        if (feeBps > MAX_FEE_RATE) {
            revert InvalidFeeRate(feeBps);
        }

        Program memory program = ProgramBuilder.init(_opcodes());

        address[] memory tokens = new address[](2);
        tokens[0] = token0;
        tokens[1] = token1;

        uint256[] memory balances = new uint256[](2);
        balances[0] = balance0;
        balances[1] = balance1;

        bytes memory bytecode = bytes.concat(
            // 1. Set initial balances
            program.build(
                _staticBalancesXD,
                BalancesArgsBuilder.build(tokens, balances)
            ),
            
            // 2. Apply concentration (if specified)
            (delta0 > 0 || delta1 > 0)
                ? program.build(
                    _xycConcentrateGrowLiquidity2D,
                    XYCConcentrateArgsBuilder.build2D(token0, token1, delta0, delta1)
                )
                : bytes(""),
            
            // 3. Pseudo-arbitrage transformation
            program.build(
                _pseudoArbitrageXD,
                PseudoArbitrageArgsBuilder.build(
                    oracle,
                    initialPrice,
                    minUpdateInterval
                )
            ),
            
            // 4. Trading fee
            feeBps > 0
                ? program.build(
                    _flatFeeAmountInXD,
                    FeeArgsBuilder.buildFlatFee(feeBps)
                )
                : bytes(""),
            
            // 5. Swap
            program.build(_xycSwapXD),
            
            // 6. Deadline
            program.build(
                _deadline,
                ControlsArgsBuilder.buildDeadline(expiration)
            ),
            
            // 7. Salt
            salt > 0
                ? program.build(
                    _salt,
                    ControlsArgsBuilder.buildSalt(salt)
                )
                : bytes("")
        );

        return MakerTraitsLib.build(
            MakerTraitsLib.Args({
                maker: maker,
                shouldUnwrapWeth: false,
                useAquaInsteadOfSignature: true,
                allowZeroAmountIn: false,
                receiver: address(0),
                hasPreTransferInHook: false,
                hasPostTransferInHook: false,
                hasPreTransferOutHook: false,
                hasPostTransferOutHook: false,
                preTransferInTarget: address(0),
                preTransferInData: "",
                postTransferInTarget: address(0),
                postTransferInData: "",
                preTransferOutTarget: address(0),
                preTransferOutData: "",
                postTransferOutTarget: address(0),
                postTransferOutData: "",
                program: bytecode
            })
        );
    }
}

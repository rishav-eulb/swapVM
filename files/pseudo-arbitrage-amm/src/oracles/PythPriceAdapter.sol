// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

/**
 * @title PythPriceAdapter
 * @notice Fetches current market prices from Pyth Network for Pseudo-Arbitrage AMM
 * @dev Implements getPrice(tokenIn, tokenOut) interface that PseudoArbitrage expects
 * 
 * Usage:
 * 1. Deploy this adapter with Pyth contract address
 * 2. Configure price feed IDs for your token pairs
 * 3. Use adapter address as 'oracle' parameter in PseudoArbitrageAMM.buildProgram()
 * 
 * Example:
 *   PythPriceAdapter adapter = new PythPriceAdapter(PYTH_ADDRESS, 3600);
 *   adapter.setPriceFeed(WETH, USDC, 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace);
 *   
 *   order = ammBuilder.buildProgram({
 *       oracle: address(adapter),  // Use this adapter as oracle
 *       ...
 *   });
 * 
 * Pyth Network Resources:
 * - Contract Addresses: https://docs.pyth.network/price-feeds/contract-addresses/evm
 * - Price Feed IDs: https://pyth.network/developers/price-feed-ids
 * - API Reference: https://api-reference.pyth.network/price-feeds/evm/getPriceNoOlderThan
 */
contract PythPriceAdapter {
    
    /// @notice Pyth oracle contract
    IPyth public immutable pyth;
    
    /// @notice Maximum age for price data (seconds)
    uint256 public immutable maxPriceAge;
    
    /// @notice Mapping from token pair to Pyth price feed ID
    /// @dev tokenIn => tokenOut => Pyth price feed ID
    mapping(address => mapping(address => bytes32)) public priceFeedIds;
    
    /// @notice Contract owner (for access control)
    address public owner;
    
    /// @notice Emitted when a price feed is configured
    event PriceFeedConfigured(address indexed tokenIn, address indexed tokenOut, bytes32 priceId);
    
    /// @notice Emitted when ownership is transferred
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    /// @notice Thrown when price feed is not configured for token pair
    error PriceFeedNotConfigured(address tokenIn, address tokenOut);
    
    /// @notice Thrown when price conversion fails
    error PriceConversionFailed(int64 price, int32 expo);
    
    /// @notice Thrown when caller is not owner
    error OnlyOwner();
    
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }
    
    /**
     * @notice Deploy adapter
     * @param _pyth Address of Pyth oracle contract
     *              See: https://docs.pyth.network/price-feeds/contract-addresses/evm
     *              Examples:
     *              - Ethereum: 0x4305FB66699C3B2702D4d05CF36551390A4c69C6
     *              - Arbitrum: 0xff1a0f4744e8582DF1aE09D5611b887B6a12925C
     *              - Base: 0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a
     * @param _maxPriceAge Maximum age for price data in seconds (e.g., 3600 = 1 hour)
     */
    constructor(address _pyth, uint256 _maxPriceAge) {
        pyth = IPyth(_pyth);
        maxPriceAge = _maxPriceAge;
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }
    
    /**
     * @notice Configure Pyth price feed for a token pair
     * @dev Only owner can configure price feeds
     * @param tokenIn Address of input token (e.g., WETH)
     * @param tokenOut Address of output token (e.g., USDC)
     * @param priceId Pyth price feed ID (see: https://pyth.network/developers/price-feed-ids)
     * 
     * Common Price Feeds:
     * - ETH/USD: 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace
     * - BTC/USD: 0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43
     * - USDC/USD: 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a
     * - USDT/USD: 0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b
     */
    function setPriceFeed(
        address tokenIn,
        address tokenOut,
        bytes32 priceId
    ) external onlyOwner {
        priceFeedIds[tokenIn][tokenOut] = priceId;
        
        emit PriceFeedConfigured(tokenIn, tokenOut, priceId);
    }
    
    /**
     * @notice Transfer ownership to a new address
     * @param newOwner Address of new owner
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    
    /**
     * @notice Get current market price for token pair
     * @dev This is the interface that PseudoArbitrage._getOraclePrice() expects
     * @param tokenIn Address of input token
     * @param tokenOut Address of output token
     * @return price Current market price scaled by 1e18 (tokenOut per tokenIn)
     * @return timestamp When the price was published (Unix timestamp)
     * 
     * Example: If ETH = $3000, returns (3000 * 1e18, timestamp)
     * 
     * Note: This function will revert if:
     * - Price feed is not configured
     * - Price is older than maxPriceAge
     * - Pyth contract returns invalid data
     */
    function getPrice(
        address tokenIn,
        address tokenOut
    ) external view returns (uint256 price, uint256 timestamp) {
        // Get configured price feed ID
        bytes32 priceId = priceFeedIds[tokenIn][tokenOut];
        
        if (priceId == bytes32(0)) {
            revert PriceFeedNotConfigured(tokenIn, tokenOut);
        }
        
        // Fetch current price from Pyth using getPriceNoOlderThan
        // This reverts if:
        // - Price is older than maxPriceAge (StalePrice error)
        // - Price feed doesn't exist (PriceFeedNotFound error)
        // See: https://api-reference.pyth.network/price-feeds/evm/getPriceNoOlderThan
        PythStructs.Price memory pythPrice = pyth.getPriceNoOlderThan(
            priceId,
            maxPriceAge
        );
        
        // Convert Pyth price format to our standard format (1e18)
        price = _convertPythPrice(pythPrice.price, pythPrice.expo);
        timestamp = pythPrice.publishTime;
        
        return (price, timestamp);
    }
    
    /**
     * @notice Convert Pyth price format to standard 1e18 format
     * @dev Pyth format: price * 10^expo
     *      Our format: price * 1e18
     * 
     * Example: Pyth ETH/USD might return:
     *   price = 300000000000 (represented as int64)
     *   expo = -8
     *   Actual value: 300000000000 * 10^(-8) = 3000.00000000
     *   Result: 3000.00000000 * 10^10 = 3000 * 1e18
     * 
     * @param pythPrice Price value from Pyth (can be negative in theory, but we validate)
     * @param pythExpo Exponent from Pyth (typically negative, e.g., -8)
     * @return Standard price scaled by 1e18
     */
    function _convertPythPrice(
        int64 pythPrice,
        int32 pythExpo
    ) internal pure returns (uint256) {
        // Ensure price is positive (prices should never be negative)
        if (pythPrice <= 0) {
            revert PriceConversionFailed(pythPrice, pythExpo);
        }
        
        uint256 price = uint256(int256(pythPrice));
        
        // Convert exponent to work with 1e18 scale
        // Target: price * 10^18
        // Current: price * 10^pythExpo
        // Need to adjust by: 10^(18 - pythExpo)
        //
        // If pythExpo = -8:
        //   targetExpo = 18 - (-8) = 26
        //   But we already have price * 10^(-8)
        //   So we multiply by 10^(18-(-8)) = 10^26? No.
        //   
        // Let's think differently:
        // Pyth gives us: pythPrice * 10^pythExpo = actual value
        // We want: result * 10^(-18) = actual value
        // So: result = actual value * 10^18
        //           = pythPrice * 10^pythExpo * 10^18
        //           = pythPrice * 10^(pythExpo + 18)
        
        int256 targetExpo = int256(pythExpo) + 18;
        
        if (targetExpo >= 0) {
            // Need to multiply by 10^targetExpo
            price = price * (10 ** uint256(targetExpo));
        } else {
            // Need to divide by 10^(-targetExpo)
            price = price / (10 ** uint256(-targetExpo));
        }
        
        return price;
    }
    
    /**
     * @notice Get Pyth price feed info (for debugging/verification)
     * @param tokenIn Input token
     * @param tokenOut Output token
     * @return priceId Configured Pyth price feed ID
     * @return hasConfig Whether price feed is configured
     */
    function getPriceFeedInfo(
        address tokenIn,
        address tokenOut
    ) external view returns (bytes32 priceId, bool hasConfig) {
        priceId = priceFeedIds[tokenIn][tokenOut];
        hasConfig = priceId != bytes32(0);
    }
    
    /**
     * @notice Get raw Pyth price data (for debugging)
     * @param tokenIn Input token
     * @param tokenOut Output token
     * @return price Raw Pyth price
     * @return conf Confidence interval
     * @return expo Exponent
     * @return publishTime Publish timestamp
     */
    function getRawPythPrice(
        address tokenIn,
        address tokenOut
    ) external view returns (
        int64 price,
        uint64 conf,
        int32 expo,
        uint256 publishTime
    ) {
        bytes32 priceId = priceFeedIds[tokenIn][tokenOut];
        
        if (priceId == bytes32(0)) {
            revert PriceFeedNotConfigured(tokenIn, tokenOut);
        }
        
        PythStructs.Price memory pythPrice = pyth.getPriceNoOlderThan(
            priceId,
            maxPriceAge
        );
        
        return (
            pythPrice.price,
            pythPrice.conf,
            pythPrice.expo,
            pythPrice.publishTime
        );
    }
}


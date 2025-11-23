// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../src/oracles/PythPriceAdapter.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

/**
 * @title PythPriceAdapterTest
 * @notice Tests for PythPriceAdapter contract
 * 
 * Run with:
 * forge test --match-contract PythPriceAdapterTest -vv
 */
contract PythPriceAdapterTest is Test {
    PythPriceAdapter public adapter;
    MockPyth public mockPyth;
    
    address public owner = address(this);
    address public user = address(0x1);
    address public WETH = address(0x10);
    address public USDC = address(0x20);
    
    // Sample Pyth price feed IDs (ETH/USD)
    bytes32 constant ETH_USD_PRICE_ID = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;
    
    uint256 constant MAX_PRICE_AGE = 3600; // 1 hour
    
    function setUp() public {
        // Deploy mock Pyth oracle
        mockPyth = new MockPyth();
        
        // Deploy adapter
        adapter = new PythPriceAdapter(address(mockPyth), MAX_PRICE_AGE);
        
        // Configure price feed
        adapter.setPriceFeed(WETH, USDC, ETH_USD_PRICE_ID);
    }
    
    function test_Deployment() public {
        assertEq(address(adapter.pyth()), address(mockPyth));
        assertEq(adapter.maxPriceAge(), MAX_PRICE_AGE);
        assertEq(adapter.owner(), owner);
    }
    
    function test_SetPriceFeed() public {
        bytes32 newPriceId = bytes32(uint256(0x123));
        
        vm.expectEmit(true, true, false, true);
        emit PriceFeedConfigured(WETH, USDC, newPriceId);
        
        adapter.setPriceFeed(WETH, USDC, newPriceId);
        
        (bytes32 priceId, bool hasConfig) = adapter.getPriceFeedInfo(WETH, USDC);
        assertEq(priceId, newPriceId);
        assertTrue(hasConfig);
    }
    
    function test_SetPriceFeed_OnlyOwner() public {
        vm.prank(user);
        vm.expectRevert(PythPriceAdapter.OnlyOwner.selector);
        adapter.setPriceFeed(WETH, USDC, bytes32(uint256(0x123)));
    }
    
    function test_TransferOwnership() public {
        address newOwner = address(0x999);
        
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(owner, newOwner);
        
        adapter.transferOwnership(newOwner);
        
        assertEq(adapter.owner(), newOwner);
    }
    
    function test_TransferOwnership_InvalidAddress() public {
        vm.expectRevert("Invalid address");
        adapter.transferOwnership(address(0));
    }
    
    function test_GetPrice_Success() public {
        // Mock Pyth price: $3000 with expo -8
        // Pyth format: 300000000000 * 10^(-8) = 3000
        int64 pythPrice = 300000000000;
        int32 pythExpo = -8;
        uint256 publishTime = block.timestamp;
        
        mockPyth.setPrice(
            ETH_USD_PRICE_ID,
            pythPrice,
            pythExpo,
            publishTime
        );
        
        (uint256 price, uint256 timestamp) = adapter.getPrice(WETH, USDC);
        
        // Expected: 3000 * 1e18
        assertEq(price, 3000 * 1e18);
        assertEq(timestamp, publishTime);
    }
    
    function test_GetPrice_DifferentExponents() public {
        // Test with expo = -6
        mockPyth.setPrice(ETH_USD_PRICE_ID, 3000000000, -6, block.timestamp);
        (uint256 price1,) = adapter.getPrice(WETH, USDC);
        assertEq(price1, 3000 * 1e18);
        
        // Test with expo = -10
        mockPyth.setPrice(ETH_USD_PRICE_ID, 30000000000000, -10, block.timestamp);
        (uint256 price2,) = adapter.getPrice(WETH, USDC);
        assertEq(price2, 3000 * 1e18);
        
        // Test with expo = -18
        mockPyth.setPrice(ETH_USD_PRICE_ID, 3000 * 1e18, -18, block.timestamp);
        (uint256 price3,) = adapter.getPrice(WETH, USDC);
        assertEq(price3, 3000 * 1e18);
    }
    
    function test_GetPrice_PriceFeedNotConfigured() public {
        address BTC = address(0x30);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                PythPriceAdapter.PriceFeedNotConfigured.selector,
                BTC,
                USDC
            )
        );
        adapter.getPrice(BTC, USDC);
    }
    
    function test_GetPrice_NegativePrice() public {
        // Set negative price (should revert)
        mockPyth.setPrice(ETH_USD_PRICE_ID, -300000000000, -8, block.timestamp);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                PythPriceAdapter.PriceConversionFailed.selector,
                -300000000000,
                -8
            )
        );
        adapter.getPrice(WETH, USDC);
    }
    
    function test_GetPrice_StalePrice() public {
        // Set price that's too old
        uint256 oldTime = block.timestamp - MAX_PRICE_AGE - 1;
        mockPyth.setPrice(ETH_USD_PRICE_ID, 300000000000, -8, oldTime);
        
        vm.expectRevert(); // MockPyth will revert with StalePrice
        adapter.getPrice(WETH, USDC);
    }
    
    function test_GetRawPythPrice() public {
        int64 pythPrice = 300000000000;
        int32 pythExpo = -8;
        uint64 conf = 100000000;
        uint256 publishTime = block.timestamp;
        
        mockPyth.setPrice(ETH_USD_PRICE_ID, pythPrice, pythExpo, publishTime);
        mockPyth.setConf(ETH_USD_PRICE_ID, conf);
        
        (
            int64 returnedPrice,
            uint64 returnedConf,
            int32 returnedExpo,
            uint256 returnedPublishTime
        ) = adapter.getRawPythPrice(WETH, USDC);
        
        assertEq(returnedPrice, pythPrice);
        assertEq(returnedConf, conf);
        assertEq(returnedExpo, pythExpo);
        assertEq(returnedPublishTime, publishTime);
    }
    
    function test_GetPriceFeedInfo() public {
        (bytes32 priceId, bool hasConfig) = adapter.getPriceFeedInfo(WETH, USDC);
        assertEq(priceId, ETH_USD_PRICE_ID);
        assertTrue(hasConfig);
        
        // Test unconfigured pair
        (bytes32 priceId2, bool hasConfig2) = adapter.getPriceFeedInfo(address(0x99), address(0x88));
        assertEq(priceId2, bytes32(0));
        assertFalse(hasConfig2);
    }
    
    // Events
    event PriceFeedConfigured(address indexed tokenIn, address indexed tokenOut, bytes32 priceId);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
}

/**
 * @title MockPyth
 * @notice Mock Pyth oracle for testing
 */
contract MockPyth is IPyth {
    struct MockPrice {
        int64 price;
        uint64 conf;
        int32 expo;
        uint256 publishTime;
    }
    
    mapping(bytes32 => MockPrice) public prices;
    
    function setPrice(
        bytes32 id,
        int64 price,
        int32 expo,
        uint256 publishTime
    ) external {
        prices[id] = MockPrice({
            price: price,
            conf: 0,
            expo: expo,
            publishTime: publishTime
        });
    }
    
    function setConf(bytes32 id, uint64 conf) external {
        prices[id].conf = conf;
    }
    
    function getPriceNoOlderThan(
        bytes32 id,
        uint256 age
    ) external view returns (PythStructs.Price memory) {
        MockPrice memory mockPrice = prices[id];
        
        // Check if price is too old
        if (block.timestamp - mockPrice.publishTime > age) {
            revert("StalePrice");
        }
        
        // Check if price exists
        if (mockPrice.publishTime == 0) {
            revert("PriceFeedNotFound");
        }
        
        return PythStructs.Price({
            price: mockPrice.price,
            conf: mockPrice.conf,
            expo: mockPrice.expo,
            publishTime: mockPrice.publishTime
        });
    }
    
    // Required IPyth functions (not used in tests but needed for interface)
    function getValidTimePeriod() external pure returns (uint) { return 60; }
    function getPrice(bytes32) external pure returns (PythStructs.Price memory) { revert("Not implemented"); }
    function getEmaPrice(bytes32) external pure returns (PythStructs.Price memory) { revert("Not implemented"); }
    function getPriceUnsafe(bytes32) external pure returns (PythStructs.Price memory) { revert("Not implemented"); }
    function getEmaPriceUnsafe(bytes32) external pure returns (PythStructs.Price memory) { revert("Not implemented"); }
    function getEmaPriceNoOlderThan(bytes32, uint256) external pure returns (PythStructs.Price memory) { revert("Not implemented"); }
    function updatePriceFeeds(bytes[] calldata) external payable { revert("Not implemented"); }
    function updatePriceFeedsIfNecessary(bytes[] calldata, bytes32[] calldata, uint64[] calldata) external payable { revert("Not implemented"); }
    function getUpdateFee(bytes[] calldata) external pure returns (uint) { return 0; }
    function parsePriceFeedUpdates(bytes[] calldata, bytes32[] calldata, uint64, uint64) external payable returns (PythStructs.PriceFeed[] memory) { revert("Not implemented"); }
    function parsePriceFeedUpdatesUnique(bytes[] calldata, bytes32[] calldata, uint64, uint64) external payable returns (PythStructs.PriceFeed[] memory) { revert("Not implemented"); }
}


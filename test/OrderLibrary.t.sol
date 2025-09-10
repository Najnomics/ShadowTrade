// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {FHE, euint128, euint64, euint8, euint32, ebool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";
import {OrderLibrary} from "../src/lib/OrderLibrary.sol";
import {MockFHE} from "./mocks/MockFHE.sol";

/// @title OrderLibrary Test Suite
/// @notice Comprehensive tests for the OrderLibrary functions
contract OrderLibraryTest is Test {
    MockFHE public mockFHE;
    
    // Test constants
    uint128 constant TRIGGER_PRICE = 2000e18;
    uint128 constant ORDER_SIZE = 10 ether;
    uint128 constant MIN_FILL_SIZE = 1 ether;
    uint64 constant FUTURE_TIME = 3600; // 1 hour from now
    
    function setUp() public {
        mockFHE = new MockFHE();
    }
    
    // ============ ORDER VALIDATION TESTS ============
    
    function testValidateOrderExecutionBuyOrder() public {
        // Create encrypted values for buy order (direction = 0)
        euint128 triggerPrice = mockFHE.mockEuint128(TRIGGER_PRICE);
        euint128 currentPrice = mockFHE.mockEuint128(TRIGGER_PRICE - 100e18); // Price dropped to trigger buy
        euint8 direction = mockFHE.mockEuint8(0); // Buy order
        ebool isActive = mockFHE.mockEbool(true);
        euint64 expirationTime = mockFHE.mockEuint64(uint64(block.timestamp + FUTURE_TIME));
        
        ebool shouldExecute = OrderLibrary.validateOrderExecution(
            triggerPrice,
            currentPrice,
            direction,
            isActive,
            expirationTime,
            block.timestamp
        );
        
        // For a buy order, should execute when current price <= trigger price
        // In a real FHE implementation, we'd decrypt this boolean
        // For testing, we know the logic should evaluate to true
        assertTrue(ebool.unwrap(shouldExecute) != 0); // Non-zero means true in our mock
    }
    
    function testValidateOrderExecutionSellOrder() public {
        euint128 triggerPrice = mockFHE.mockEuint128(TRIGGER_PRICE);
        euint128 currentPrice = mockFHE.mockEuint128(TRIGGER_PRICE + 100e18); // Price increased to trigger sell
        euint8 direction = mockFHE.mockEuint8(1); // Sell order
        ebool isActive = mockFHE.mockEbool(true);
        euint64 expirationTime = mockFHE.mockEuint64(uint64(block.timestamp + FUTURE_TIME));
        
        ebool shouldExecute = OrderLibrary.validateOrderExecution(
            triggerPrice,
            currentPrice,
            direction,
            isActive,
            expirationTime,
            block.timestamp
        );
        
        // For a sell order, should execute when current price >= trigger price
        assertTrue(ebool.unwrap(shouldExecute) != 0);
    }
    
    function testValidateOrderExecutionInactiveOrder() public {
        euint128 triggerPrice = mockFHE.mockEuint128(TRIGGER_PRICE);
        euint128 currentPrice = mockFHE.mockEuint128(TRIGGER_PRICE - 100e18);
        euint8 direction = mockFHE.mockEuint8(0);
        ebool isActive = mockFHE.mockEbool(false); // Order is inactive
        euint64 expirationTime = mockFHE.mockEuint64(uint64(block.timestamp + FUTURE_TIME));
        
        ebool shouldExecute = OrderLibrary.validateOrderExecution(
            triggerPrice,
            currentPrice,
            direction,
            isActive,
            expirationTime,
            block.timestamp
        );
        
        // Should not execute inactive order
        assertTrue(ebool.unwrap(shouldExecute) == 0); // Zero means false
    }
    
    function testValidateOrderExecutionExpiredOrder() public {
        euint128 triggerPrice = mockFHE.mockEuint128(TRIGGER_PRICE);
        euint128 currentPrice = mockFHE.mockEuint128(TRIGGER_PRICE - 100e18);
        euint8 direction = mockFHE.mockEuint8(0);
        ebool isActive = mockFHE.mockEbool(true);
        euint64 expirationTime = mockFHE.mockEuint64(uint64(block.timestamp - 1)); // Expired
        
        ebool shouldExecute = OrderLibrary.validateOrderExecution(
            triggerPrice,
            currentPrice,
            direction,
            isActive,
            expirationTime,
            block.timestamp
        );
        
        // Should not execute expired order
        assertTrue(ebool.unwrap(shouldExecute) == 0);
    }
    
    // ============ FILL CALCULATION TESTS ============
    
    function testCalculateOptimalFillPartialAllowed() public {
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        euint128 filledAmount = mockFHE.mockEuint128(3 ether); // Already filled 3 ETH
        euint128 minFillSize = mockFHE.mockEuint128(MIN_FILL_SIZE);
        euint128 availableLiquidity = mockFHE.mockEuint128(2 ether); // Only 2 ETH available
        ebool partialFillAllowed = mockFHE.mockEbool(true);
        
        euint128 fillAmount = OrderLibrary.calculateOptimalFill(
            orderSize,
            filledAmount,
            minFillSize,
            availableLiquidity,
            partialFillAllowed
        );
        
        // Should return the available liquidity (2 ETH) since partials are allowed
        // and it meets minimum fill size
        uint256 result = mockFHE.getValue(euint128.unwrap(fillAmount));
        assertEq(result, 2 ether);
    }
    
    function testCalculateOptimalFillPartialNotAllowed() public {
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        euint128 filledAmount = mockFHE.mockEuint128(0); // No fills yet
        euint128 minFillSize = mockFHE.mockEuint128(MIN_FILL_SIZE);
        euint128 availableLiquidity = mockFHE.mockEuint128(5 ether); // Less than remaining order
        ebool partialFillAllowed = mockFHE.mockEbool(false);
        
        euint128 fillAmount = OrderLibrary.calculateOptimalFill(
            orderSize,
            filledAmount,
            minFillSize,
            availableLiquidity,
            partialFillAllowed
        );
        
        // Should return 0 since partial fills not allowed and can't fill entire remaining amount
        uint256 result = mockFHE.getValue(euint128.unwrap(fillAmount));
        assertEq(result, 0);
    }
    
    function testCalculateOptimalFillFullFillPossible() public {
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        euint128 filledAmount = mockFHE.mockEuint128(2 ether);
        euint128 minFillSize = mockFHE.mockEuint128(MIN_FILL_SIZE);
        euint128 availableLiquidity = mockFHE.mockEuint128(20 ether); // More than needed
        ebool partialFillAllowed = mockFHE.mockEbool(false);
        
        euint128 fillAmount = OrderLibrary.calculateOptimalFill(
            orderSize,
            filledAmount,
            minFillSize,
            availableLiquidity,
            partialFillAllowed
        );
        
        // Should return remaining order size (8 ETH) since full fill is possible
        uint256 result = mockFHE.getValue(euint128.unwrap(fillAmount));
        assertEq(result, 8 ether);
    }
    
    function testCalculateOptimalFillBelowMinimum() public {
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        euint128 filledAmount = mockFHE.mockEuint128(9.5 ether); // Almost filled
        euint128 minFillSize = mockFHE.mockEuint128(MIN_FILL_SIZE);
        euint128 availableLiquidity = mockFHE.mockEuint128(0.5 ether); // Less than minimum
        ebool partialFillAllowed = mockFHE.mockEbool(true);
        
        euint128 fillAmount = OrderLibrary.calculateOptimalFill(
            orderSize,
            filledAmount,
            minFillSize,
            availableLiquidity,
            partialFillAllowed
        );
        
        // Should return 0 since available liquidity is below minimum fill size
        uint256 result = mockFHE.getValue(euint128.unwrap(fillAmount));
        assertEq(result, 0);
    }
    
    // ============ PRIORITY CALCULATION TESTS ============
    
    function testCalculateExecutionPriority() public {
        euint64 placementTime = mockFHE.mockEuint64(uint64(block.timestamp - 3600)); // 1 hour ago
        euint128 triggerPrice = mockFHE.mockEuint128(TRIGGER_PRICE);
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        euint32 orderType = mockFHE.mockEuint32(1); // Limit order type
        
        euint128 priorityScore = OrderLibrary.calculateExecutionPriority(
            placementTime,
            triggerPrice,
            orderSize,
            orderType
        );
        
        // Priority should be calculated (exact value depends on our formula)
        uint256 result = mockFHE.getValue(euint128.unwrap(priorityScore));
        assertGt(result, 0);
    }
    
    function testCalculateExecutionPriorityTimePreference() public {
        // Earlier order
        euint64 earlyTime = mockFHE.mockEuint64(uint64(block.timestamp - 7200)); // 2 hours ago
        euint128 triggerPrice = mockFHE.mockEuint128(TRIGGER_PRICE);
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        euint32 orderType = mockFHE.mockEuint32(1);
        
        euint128 earlyPriority = OrderLibrary.calculateExecutionPriority(
            earlyTime,
            triggerPrice,
            orderSize,
            orderType
        );
        
        // Later order
        euint64 lateTime = mockFHE.mockEuint64(uint64(block.timestamp - 1800)); // 30 minutes ago
        euint128 latePriority = OrderLibrary.calculateExecutionPriority(
            lateTime,
            triggerPrice,
            orderSize,
            orderType
        );
        
        // Earlier order should have higher priority
        uint256 earlyResult = mockFHE.getValue(euint128.unwrap(earlyPriority));
        uint256 lateResult = mockFHE.getValue(euint128.unwrap(latePriority));
        assertGt(earlyResult, lateResult);
    }
    
    // ============ VOLUME-WEIGHTED PRICE TESTS ============
    
    function testUpdateVolumeWeightedPriceFirstFill() public {
        euint128 currentTotal = mockFHE.mockEuint128(0); // First fill
        euint128 currentAvgPrice = mockFHE.mockEuint128(0); // No previous average
        euint128 newFillAmount = mockFHE.mockEuint128(5 ether);
        euint128 newFillPrice = mockFHE.mockEuint128(2000e18);
        
        euint128 newAverage = OrderLibrary.updateVolumeWeightedPrice(
            currentTotal,
            currentAvgPrice,
            newFillAmount,
            newFillPrice
        );
        
        // For first fill, average price should equal fill price
        uint256 result = mockFHE.getValue(euint128.unwrap(newAverage));
        assertEq(result, 2000e18);
    }
    
    function testUpdateVolumeWeightedPriceSubsequentFill() public {
        euint128 currentTotal = mockFHE.mockEuint128(3 ether);
        euint128 currentAvgPrice = mockFHE.mockEuint128(1900e18); // Previous average
        euint128 newFillAmount = mockFHE.mockEuint128(2 ether);
        euint128 newFillPrice = mockFHE.mockEuint128(2100e18); // Higher price
        
        euint128 newAverage = OrderLibrary.updateVolumeWeightedPrice(
            currentTotal,
            currentAvgPrice,
            newFillAmount,
            newFillPrice
        );
        
        // Should calculate weighted average: (3 * 1900 + 2 * 2100) / 5 = 1980
        uint256 result = mockFHE.getValue(euint128.unwrap(newAverage));
        // Note: Due to FHE arithmetic precision, we check for approximate equality
        assertApproxEqAbs(result, 1980e18, 1e18); // Within 1 token precision
    }
    
    // ============ SLIPPAGE PROTECTION TESTS ============
    
    function testApplySlippageProtectionAcceptable() public {
        euint128 fillAmount = mockFHE.mockEuint128(5 ether);
        euint128 currentPrice = mockFHE.mockEuint128(2020e18); // 1% above trigger
        euint128 triggerPrice = mockFHE.mockEuint128(2000e18);
        euint128 maxSlippage = mockFHE.mockEuint128(200); // 2% max slippage (200 basis points)
        
        euint128 adjustedFill = OrderLibrary.applySlippageProtection(
            fillAmount,
            currentPrice,
            triggerPrice,
            maxSlippage
        );
        
        // Should return full fill amount since slippage is within tolerance
        uint256 result = mockFHE.getValue(euint128.unwrap(adjustedFill));
        assertEq(result, 5 ether);
    }
    
    function testApplySlippageProtectionExcessive() public {
        euint128 fillAmount = mockFHE.mockEuint128(5 ether);
        euint128 currentPrice = mockFHE.mockEuint128(2100e18); // 5% above trigger
        euint128 triggerPrice = mockFHE.mockEuint128(2000e18);
        euint128 maxSlippage = mockFHE.mockEuint128(200); // 2% max slippage
        
        euint128 adjustedFill = OrderLibrary.applySlippageProtection(
            fillAmount,
            currentPrice,
            triggerPrice,
            maxSlippage
        );
        
        // Should return zero since slippage exceeds tolerance
        uint256 result = mockFHE.getValue(euint128.unwrap(adjustedFill));
        assertEq(result, 0);
    }
    
    // ============ ORDER SIZE VALIDATION TESTS ============
    
    function testValidateOrderSizeValid() public {
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        euint128 minOrderSize = mockFHE.mockEuint128(1 ether);
        
        ebool isValidSize = OrderLibrary.validateOrderSize(orderSize, minOrderSize);
        
        uint256 result = mockFHE.getValue(ebool.unwrap(isValidSize));
        assertTrue(result != 0); // Should be valid
    }
    
    function testValidateOrderSizeInvalid() public {
        euint128 orderSize = mockFHE.mockEuint128(0.5 ether);
        euint128 minOrderSize = mockFHE.mockEuint128(1 ether);
        
        ebool isValidSize = OrderLibrary.validateOrderSize(orderSize, minOrderSize);
        
        uint256 result = mockFHE.getValue(ebool.unwrap(isValidSize));
        assertTrue(result == 0); // Should be invalid
    }
    
    // ============ PRICE IMPACT TESTS ============
    
    function testCalculatePriceImpactSmallOrder() public {
        euint128 fillAmount = mockFHE.mockEuint128(1 ether);
        euint128 availableLiquidity = mockFHE.mockEuint128(100 ether);
        
        euint128 priceImpact = OrderLibrary.calculatePriceImpact(fillAmount, availableLiquidity);
        
        // Should be 1% (100 basis points): (1/100) * 10000 = 100
        uint256 result = mockFHE.getValue(euint128.unwrap(priceImpact));
        assertEq(result, 100);
    }
    
    function testCalculatePriceImpactLargeOrder() public {
        euint128 fillAmount = mockFHE.mockEuint128(20 ether);
        euint128 availableLiquidity = mockFHE.mockEuint128(100 ether);
        
        euint128 priceImpact = OrderLibrary.calculatePriceImpact(fillAmount, availableLiquidity);
        
        // Should be 20% (2000 basis points): (20/100) * 10000 = 2000
        uint256 result = mockFHE.getValue(euint128.unwrap(priceImpact));
        assertEq(result, 2000);
    }
    
    // ============ PARAMETER VALIDATION TESTS ============
    
    function testValidateOrderParametersValid() public {
        euint128 triggerPrice = mockFHE.mockEuint128(TRIGGER_PRICE);
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        euint64 expirationTime = mockFHE.mockEuint64(uint64(block.timestamp + FUTURE_TIME));
        euint128 minFillSize = mockFHE.mockEuint128(MIN_FILL_SIZE);
        
        ebool isValid = OrderLibrary.validateOrderParameters(
            triggerPrice,
            orderSize,
            expirationTime,
            minFillSize,
            block.timestamp
        );
        
        uint256 result = mockFHE.getValue(ebool.unwrap(isValid));
        assertTrue(result != 0); // Should be valid
    }
    
    function testValidateOrderParametersZeroPrice() public {
        euint128 triggerPrice = mockFHE.mockEuint128(0); // Invalid
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        euint64 expirationTime = mockFHE.mockEuint64(uint64(block.timestamp + FUTURE_TIME));
        euint128 minFillSize = mockFHE.mockEuint128(MIN_FILL_SIZE);
        
        ebool isValid = OrderLibrary.validateOrderParameters(
            triggerPrice,
            orderSize,
            expirationTime,
            minFillSize,
            block.timestamp
        );
        
        uint256 result = mockFHE.getValue(ebool.unwrap(isValid));
        assertTrue(result == 0); // Should be invalid
    }
    
    function testValidateOrderParametersMinFillTooLarge() public {
        euint128 triggerPrice = mockFHE.mockEuint128(TRIGGER_PRICE);
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        euint64 expirationTime = mockFHE.mockEuint64(uint64(block.timestamp + FUTURE_TIME));
        euint128 minFillSize = mockFHE.mockEuint128(ORDER_SIZE + 1 ether); // Larger than order
        
        ebool isValid = OrderLibrary.validateOrderParameters(
            triggerPrice,
            orderSize,
            expirationTime,
            minFillSize,
            block.timestamp
        );
        
        uint256 result = mockFHE.getValue(ebool.unwrap(isValid));
        assertTrue(result == 0); // Should be invalid
    }
    
    // ============ EXPIRATION TESTS ============
    
    function testIsOrderExpiredFalse() public {
        euint64 expirationTime = mockFHE.mockEuint64(uint64(block.timestamp + FUTURE_TIME));
        
        ebool hasExpired = OrderLibrary.isOrderExpired(expirationTime, block.timestamp);
        
        uint256 result = mockFHE.getValue(ebool.unwrap(hasExpired));
        assertTrue(result == 0); // Should not be expired
    }
    
    function testIsOrderExpiredTrue() public {
        euint64 expirationTime = mockFHE.mockEuint64(uint64(block.timestamp - 1));
        
        ebool hasExpired = OrderLibrary.isOrderExpired(expirationTime, block.timestamp);
        
        uint256 result = mockFHE.getValue(ebool.unwrap(hasExpired));
        assertTrue(result != 0); // Should be expired
    }
    
    // ============ FUZZ TESTING ============
    
    function testFuzzCalculateOptimalFill(
        uint128 orderSize,
        uint128 filledAmount,
        uint128 minFillSize,
        uint128 availableLiquidity,
        bool partialFillAllowed
    ) public {
        // Bound inputs to reasonable ranges
        orderSize = uint128(bound(orderSize, 1 ether, 1000 ether));
        filledAmount = uint128(bound(filledAmount, 0, orderSize));
        minFillSize = uint128(bound(minFillSize, 0.1 ether, orderSize));
        availableLiquidity = uint128(bound(availableLiquidity, 0, 1000 ether));
        
        euint128 encOrderSize = mockFHE.mockEuint128(orderSize);
        euint128 encFilledAmount = mockFHE.mockEuint128(filledAmount);
        euint128 encMinFillSize = mockFHE.mockEuint128(minFillSize);
        euint128 encAvailableLiquidity = mockFHE.mockEuint128(availableLiquidity);
        ebool encPartialFillAllowed = mockFHE.mockEbool(partialFillAllowed);
        
        euint128 fillAmount = OrderLibrary.calculateOptimalFill(
            encOrderSize,
            encFilledAmount,
            encMinFillSize,
            encAvailableLiquidity,
            encPartialFillAllowed
        );
        
        uint256 result = mockFHE.getValue(euint128.unwrap(fillAmount));
        
        // Basic invariants
        assertLe(result, availableLiquidity); // Never fill more than available
        assertLe(result, orderSize - filledAmount); // Never fill more than remaining
        
        if (result > 0) {
            // If filling, must meet minimum size OR be full remaining amount
            assertTrue(result >= minFillSize || result == orderSize - filledAmount);
        }
    }
    
    function testFuzzPriceImpactCalculation(
        uint128 fillAmount,
        uint128 availableLiquidity
    ) public {
        fillAmount = uint128(bound(fillAmount, 1, 1000 ether));
        availableLiquidity = uint128(bound(availableLiquidity, 1 ether, 10000 ether));
        
        euint128 encFillAmount = mockFHE.mockEuint128(fillAmount);
        euint128 encAvailableLiquidity = mockFHE.mockEuint128(availableLiquidity);
        
        euint128 priceImpact = OrderLibrary.calculatePriceImpact(
            encFillAmount,
            encAvailableLiquidity
        );
        
        uint256 result = mockFHE.getValue(euint128.unwrap(priceImpact));
        
        // Price impact should be proportional: (fillAmount / availableLiquidity) * 10000
        uint256 expectedImpact = (uint256(fillAmount) * 10000) / availableLiquidity;
        assertEq(result, expectedImpact);
    }
}
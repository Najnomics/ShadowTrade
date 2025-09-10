// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {PartialFillManager} from "../src/lib/PartialFillManager.sol";
import {MockFHE} from "./mocks/MockFHE.sol";
import {FHE, euint128, euint64, euint32, ebool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

/// @title PartialFillManager Test Suite
/// @notice Tests for partial fill tracking and management
contract PartialFillManagerTest is Test {
    PartialFillManager public fillManager;
    MockFHE public mockFHE;
    
    // Test constants
    bytes32 constant ORDER_ID_1 = keccak256("order1");
    bytes32 constant ORDER_ID_2 = keccak256("order2");
    uint128 constant ORDER_SIZE = 10 ether;
    uint128 constant FILL_AMOUNT_1 = 3 ether;
    uint128 constant FILL_AMOUNT_2 = 2 ether;
    uint128 constant FILL_PRICE_1 = 2000e18;
    uint128 constant FILL_PRICE_2 = 2050e18;
    uint128 constant MIN_FILL_SIZE = 1 ether;
    
    event PartialFillExecuted(
        bytes32 indexed orderId,
        euint128 fillAmount,
        euint128 fillPrice,
        euint128 remainingAmount
    );
    
    event OrderFullyFilled(
        bytes32 indexed orderId,
        euint128 totalFilled,
        euint128 averagePrice
    );
    
    function setUp() public {
        fillManager = new PartialFillManager();
        mockFHE = new MockFHE();
    }
    
    // ============ BASIC PARTIAL FILL TESTS ============
    
    function testExecuteFirstPartialFill() public {
        euint128 fillAmount = mockFHE.mockEuint128(FILL_AMOUNT_1);
        euint128 fillPrice = mockFHE.mockEuint128(FILL_PRICE_1);
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        
        vm.expectEmit(true, false, false, false);
        emit PartialFillExecuted(ORDER_ID_1, fillAmount, fillPrice, mockFHE.mockEuint128(ORDER_SIZE - FILL_AMOUNT_1));
        
        ebool isFullyFilled = fillManager.executePartialFill(
            ORDER_ID_1,
            fillAmount,
            fillPrice,
            orderSize
        );
        
        // Should not be fully filled yet
        uint256 isFullyFilledResult = mockFHE.getValue(ebool.unwrap(isFullyFilled));
        assertEq(isFullyFilledResult, 0);
        
        // Check fill state
        PartialFillManager.PartialFillState memory state = fillManager.getPartialFillState(ORDER_ID_1);
        uint256 totalFilled = mockFHE.getValue(euint128.unwrap(state.totalFilled));
        uint256 avgPrice = mockFHE.getValue(euint128.unwrap(state.averageFillPrice));
        uint256 fillCount = mockFHE.getValue(euint32.unwrap(state.fillCount));
        
        assertEq(totalFilled, FILL_AMOUNT_1);
        assertEq(avgPrice, FILL_PRICE_1); // First fill, so average equals fill price
        assertEq(fillCount, 1);
    }
    
    function testExecuteMultiplePartialFills() public {
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        
        // First fill
        euint128 fillAmount1 = mockFHE.mockEuint128(FILL_AMOUNT_1);
        euint128 fillPrice1 = mockFHE.mockEuint128(FILL_PRICE_1);
        
        fillManager.executePartialFill(ORDER_ID_1, fillAmount1, fillPrice1, orderSize);
        
        // Second fill
        euint128 fillAmount2 = mockFHE.mockEuint128(FILL_AMOUNT_2);
        euint128 fillPrice2 = mockFHE.mockEuint128(FILL_PRICE_2);
        
        fillManager.executePartialFill(ORDER_ID_1, fillAmount2, fillPrice2, orderSize);
        
        // Check updated state
        PartialFillManager.PartialFillState memory state = fillManager.getPartialFillState(ORDER_ID_1);
        uint256 totalFilled = mockFHE.getValue(euint128.unwrap(state.totalFilled));
        uint256 fillCount = mockFHE.getValue(euint32.unwrap(state.fillCount));
        
        assertEq(totalFilled, FILL_AMOUNT_1 + FILL_AMOUNT_2);
        assertEq(fillCount, 2);
        
        // Check volume-weighted average price calculation
        // Expected: (3 * 2000 + 2 * 2050) / 5 = 2020
        uint256 avgPrice = mockFHE.getValue(euint128.unwrap(state.averageFillPrice));
        assertApproxEqAbs(avgPrice, 2020e18, 1e18);
    }
    
    function testExecutePartialFillToCompletion() public {
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        
        // Fill most of the order
        euint128 fillAmount1 = mockFHE.mockEuint128(8 ether);
        euint128 fillPrice1 = mockFHE.mockEuint128(FILL_PRICE_1);
        
        fillManager.executePartialFill(ORDER_ID_1, fillAmount1, fillPrice1, orderSize);
        
        // Complete the order
        euint128 fillAmount2 = mockFHE.mockEuint128(2 ether);
        euint128 fillPrice2 = mockFHE.mockEuint128(FILL_PRICE_2);
        
        ebool isFullyFilled = fillManager.executePartialFill(ORDER_ID_1, fillAmount2, fillPrice2, orderSize);
        
        // Should be fully filled now
        uint256 isFullyFilledResult = mockFHE.getValue(ebool.unwrap(isFullyFilled));
        assertTrue(isFullyFilledResult != 0);
        
        // Check final state
        PartialFillManager.PartialFillState memory state = fillManager.getPartialFillState(ORDER_ID_1);
        uint256 totalFilled = mockFHE.getValue(euint128.unwrap(state.totalFilled));
        assertEq(totalFilled, ORDER_SIZE);
    }
    
    // ============ FILL HISTORY TESTS ============
    
    function testFillHistoryTracking() public {
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        
        // Execute multiple fills
        euint128 fillAmount1 = mockFHE.mockEuint128(FILL_AMOUNT_1);
        euint128 fillPrice1 = mockFHE.mockEuint128(FILL_PRICE_1);
        fillManager.executePartialFill(ORDER_ID_1, fillAmount1, fillPrice1, orderSize);
        
        euint128 fillAmount2 = mockFHE.mockEuint128(FILL_AMOUNT_2);
        euint128 fillPrice2 = mockFHE.mockEuint128(FILL_PRICE_2);
        fillManager.executePartialFill(ORDER_ID_1, fillAmount2, fillPrice2, orderSize);
        
        // Check fill history
        PartialFillManager.Fill[] memory history = fillManager.getFillHistory(ORDER_ID_1);
        assertEq(history.length, 2);
        
        // Verify first fill
        uint256 fill1Amount = mockFHE.getValue(euint128.unwrap(history[0].fillAmount));
        uint256 fill1Price = mockFHE.getValue(euint128.unwrap(history[0].fillPrice));
        uint256 fill1Index = mockFHE.getValue(euint32.unwrap(history[0].fillIndex));
        
        assertEq(fill1Amount, FILL_AMOUNT_1);
        assertEq(fill1Price, FILL_PRICE_1);
        assertEq(fill1Index, 1);
        
        // Verify second fill
        uint256 fill2Amount = mockFHE.getValue(euint128.unwrap(history[1].fillAmount));
        uint256 fill2Price = mockFHE.getValue(euint128.unwrap(history[1].fillPrice));
        uint256 fill2Index = mockFHE.getValue(euint32.unwrap(history[1].fillIndex));
        
        assertEq(fill2Amount, FILL_AMOUNT_2);
        assertEq(fill2Price, FILL_PRICE_2);
        assertEq(fill2Index, 2);
    }
    
    // ============ REMAINING AMOUNT TESTS ============
    
    function testGetRemainingAmountUnfilled() public {
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        
        euint128 remaining = fillManager.getRemainingAmount(ORDER_ID_1, orderSize);
        uint256 remainingValue = mockFHE.getValue(euint128.unwrap(remaining));
        
        assertEq(remainingValue, ORDER_SIZE); // Nothing filled yet
    }
    
    function testGetRemainingAmountPartiallyFilled() public {
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        
        // Fill part of the order
        euint128 fillAmount = mockFHE.mockEuint128(FILL_AMOUNT_1);
        euint128 fillPrice = mockFHE.mockEuint128(FILL_PRICE_1);
        fillManager.executePartialFill(ORDER_ID_1, fillAmount, fillPrice, orderSize);
        
        euint128 remaining = fillManager.getRemainingAmount(ORDER_ID_1, orderSize);
        uint256 remainingValue = mockFHE.getValue(euint128.unwrap(remaining));
        
        assertEq(remainingValue, ORDER_SIZE - FILL_AMOUNT_1);
    }
    
    function testGetRemainingAmountFullyFilled() public {
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        
        // Fill entire order
        euint128 fillAmount = mockFHE.mockEuint128(ORDER_SIZE);
        euint128 fillPrice = mockFHE.mockEuint128(FILL_PRICE_1);
        fillManager.executePartialFill(ORDER_ID_1, fillAmount, fillPrice, orderSize);
        
        euint128 remaining = fillManager.getRemainingAmount(ORDER_ID_1, orderSize);
        uint256 remainingValue = mockFHE.getValue(euint128.unwrap(remaining));
        
        assertEq(remainingValue, 0);
    }
    
    // ============ MINIMUM FILL REQUIREMENT TESTS ============
    
    function testMeetsMinimumFillRequirementSufficient() public {
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        euint128 minFillSize = mockFHE.mockEuint128(MIN_FILL_SIZE);
        euint128 proposedFill = mockFHE.mockEuint128(2 ether); // Above minimum
        
        ebool meetsRequirement = fillManager.meetsMinimumFillRequirement(
            ORDER_ID_1,
            minFillSize,
            orderSize,
            proposedFill
        );
        
        uint256 result = mockFHE.getValue(ebool.unwrap(meetsRequirement));
        assertTrue(result != 0);
    }
    
    function testMeetsMinimumFillRequirementInsufficient() public {
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        euint128 minFillSize = mockFHE.mockEuint128(MIN_FILL_SIZE);
        euint128 proposedFill = mockFHE.mockEuint128(0.5 ether); // Below minimum
        
        ebool meetsRequirement = fillManager.meetsMinimumFillRequirement(
            ORDER_ID_1,
            minFillSize,
            orderSize,
            proposedFill
        );
        
        uint256 result = mockFHE.getValue(ebool.unwrap(meetsRequirement));
        assertEq(result, 0);
    }
    
    function testMeetsMinimumFillRequirementFillsRemaining() public {
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        euint128 minFillSize = mockFHE.mockEuint128(MIN_FILL_SIZE);
        
        // Partially fill the order first
        euint128 fillAmount = mockFHE.mockEuint128(9.5 ether);
        euint128 fillPrice = mockFHE.mockEuint128(FILL_PRICE_1);
        fillManager.executePartialFill(ORDER_ID_1, fillAmount, fillPrice, orderSize);
        
        // Propose fill that's below minimum but fills remaining amount
        euint128 proposedFill = mockFHE.mockEuint128(0.5 ether); // Below 1 ETH minimum but fills remaining
        
        ebool meetsRequirement = fillManager.meetsMinimumFillRequirement(
            ORDER_ID_1,
            minFillSize,
            orderSize,
            proposedFill
        );
        
        uint256 result = mockFHE.getValue(ebool.unwrap(meetsRequirement));
        assertTrue(result != 0); // Should be allowed since it fills remaining amount
    }
    
    // ============ FILL EFFICIENCY TESTS ============
    
    function testCalculateFillEfficiencyPerfectPrice() public {
        euint128 targetPrice = mockFHE.mockEuint128(2000e18);
        
        // Execute fill at exact target price
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        euint128 fillAmount = mockFHE.mockEuint128(FILL_AMOUNT_1);
        euint128 fillPrice = mockFHE.mockEuint128(2000e18); // Exact target
        fillManager.executePartialFill(ORDER_ID_1, fillAmount, fillPrice, orderSize);
        
        euint128 efficiency = fillManager.calculateFillEfficiency(ORDER_ID_1, targetPrice);
        uint256 efficiencyValue = mockFHE.getValue(euint128.unwrap(efficiency));
        
        // Should be high efficiency (perfect price)
        assertGt(efficiencyValue, 9000); // > 90% efficiency
    }
    
    function testCalculateFillEfficiencyWorsePrice() public {
        euint128 targetPrice = mockFHE.mockEuint128(2000e18);
        
        // Execute fill at worse price
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        euint128 fillAmount = mockFHE.mockEuint128(FILL_AMOUNT_1);
        euint128 fillPrice = mockFHE.mockEuint128(2200e18); // 10% worse than target
        fillManager.executePartialFill(ORDER_ID_1, fillAmount, fillPrice, orderSize);
        
        euint128 efficiency = fillManager.calculateFillEfficiency(ORDER_ID_1, targetPrice);
        uint256 efficiencyValue = mockFHE.getValue(euint128.unwrap(efficiency));
        
        // Should be lower efficiency
        assertLt(efficiencyValue, 9000); // < 90% efficiency
    }
    
    function testCalculateFillEfficiencyMultipleFills() public {
        euint128 targetPrice = mockFHE.mockEuint128(2000e18);
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        
        // Multiple fills create fragmentation penalty
        for (uint i = 0; i < 5; i++) {
            euint128 fillAmount = mockFHE.mockEuint128(1 ether);
            euint128 fillPrice = mockFHE.mockEuint128(2000e18);
            fillManager.executePartialFill(ORDER_ID_1, fillAmount, fillPrice, orderSize);
        }
        
        euint128 efficiency = fillManager.calculateFillEfficiency(ORDER_ID_1, targetPrice);
        uint256 efficiencyValue = mockFHE.getValue(euint128.unwrap(efficiency));
        
        // Should be lower due to fragmentation penalty (5 fills * 50 penalty = 250)
        assertLt(efficiencyValue, 9750); // Should be reduced by penalty
    }
    
    // ============ STATE RESET TESTS ============
    
    function testResetPartialFillState() public {
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        
        // Execute some fills first
        euint128 fillAmount = mockFHE.mockEuint128(FILL_AMOUNT_1);
        euint128 fillPrice = mockFHE.mockEuint128(FILL_PRICE_1);
        fillManager.executePartialFill(ORDER_ID_1, fillAmount, fillPrice, orderSize);
        
        // Verify state exists
        PartialFillManager.PartialFillState memory stateBefore = fillManager.getPartialFillState(ORDER_ID_1);
        uint256 totalFilledBefore = mockFHE.getValue(euint128.unwrap(stateBefore.totalFilled));
        assertGt(totalFilledBefore, 0);
        
        // Reset state
        fillManager.resetPartialFillState(ORDER_ID_1);
        
        // Verify state is cleared
        PartialFillManager.PartialFillState memory stateAfter = fillManager.getPartialFillState(ORDER_ID_1);
        uint256 totalFilledAfter = mockFHE.getValue(euint128.unwrap(stateAfter.totalFilled));
        assertEq(totalFilledAfter, 0);
        
        // Verify fill history is cleared
        PartialFillManager.Fill[] memory historyAfter = fillManager.getFillHistory(ORDER_ID_1);
        assertEq(historyAfter.length, 0);
    }
    
    // ============ MULTIPLE ORDER TESTS ============
    
    function testMultipleOrdersIndependent() public {
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        
        // Fill order 1
        euint128 fillAmount1 = mockFHE.mockEuint128(FILL_AMOUNT_1);
        euint128 fillPrice1 = mockFHE.mockEuint128(FILL_PRICE_1);
        fillManager.executePartialFill(ORDER_ID_1, fillAmount1, fillPrice1, orderSize);
        
        // Fill order 2 with different amounts
        euint128 fillAmount2 = mockFHE.mockEuint128(FILL_AMOUNT_2);
        euint128 fillPrice2 = mockFHE.mockEuint128(FILL_PRICE_2);
        fillManager.executePartialFill(ORDER_ID_2, fillAmount2, fillPrice2, orderSize);
        
        // Verify orders are independent
        PartialFillManager.PartialFillState memory state1 = fillManager.getPartialFillState(ORDER_ID_1);
        PartialFillManager.PartialFillState memory state2 = fillManager.getPartialFillState(ORDER_ID_2);
        
        uint256 totalFilled1 = mockFHE.getValue(euint128.unwrap(state1.totalFilled));
        uint256 totalFilled2 = mockFHE.getValue(euint128.unwrap(state2.totalFilled));
        
        assertEq(totalFilled1, FILL_AMOUNT_1);
        assertEq(totalFilled2, FILL_AMOUNT_2);
        assertNotEq(totalFilled1, totalFilled2);
    }
    
    // ============ EDGE CASES ============
    
    function testZeroFillAmount() public {
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        euint128 fillAmount = mockFHE.mockEuint128(0); // Zero fill
        euint128 fillPrice = mockFHE.mockEuint128(FILL_PRICE_1);
        
        fillManager.executePartialFill(ORDER_ID_1, fillAmount, fillPrice, orderSize);
        
        // State should reflect zero fill
        PartialFillManager.PartialFillState memory state = fillManager.getPartialFillState(ORDER_ID_1);
        uint256 totalFilled = mockFHE.getValue(euint128.unwrap(state.totalFilled));
        assertEq(totalFilled, 0);
    }
    
    function testMaxUintValues() public {
        // Test with maximum values to check for overflows
        euint128 maxOrderSize = mockFHE.mockEuint128(type(uint128).max);
        euint128 largeFillAmount = mockFHE.mockEuint128(type(uint128).max / 2);
        euint128 fillPrice = mockFHE.mockEuint128(type(uint128).max / 4);
        
        // Should handle large values without reverting
        fillManager.executePartialFill(ORDER_ID_1, largeFillAmount, fillPrice, maxOrderSize);
        
        PartialFillManager.PartialFillState memory state = fillManager.getPartialFillState(ORDER_ID_1);
        // Verify state was updated (exact values depend on FHE arithmetic)
        assertTrue(euint128.unwrap(state.totalFilled) != 0);
    }
    
    // ============ FUZZ TESTING ============
    
    function testFuzzExecutePartialFill(
        uint128 orderSize,
        uint128 fillAmount,
        uint128 fillPrice,
        bytes32 orderId
    ) public {
        // Bound inputs to reasonable ranges
        orderSize = uint128(bound(orderSize, 1 ether, 1000 ether));
        fillAmount = uint128(bound(fillAmount, 0, orderSize));
        fillPrice = uint128(bound(fillPrice, 1e18, 10000e18)); // $1 to $10,000
        
        euint128 encOrderSize = mockFHE.mockEuint128(orderSize);
        euint128 encFillAmount = mockFHE.mockEuint128(fillAmount);
        euint128 encFillPrice = mockFHE.mockEuint128(fillPrice);
        
        ebool isFullyFilled = fillManager.executePartialFill(
            orderId,
            encFillAmount,
            encFillPrice,
            encOrderSize
        );
        
        // Verify basic invariants
        PartialFillManager.PartialFillState memory state = fillManager.getPartialFillState(orderId);
        uint256 totalFilled = mockFHE.getValue(euint128.unwrap(state.totalFilled));
        
        // Total filled should not exceed order size
        assertLe(totalFilled, orderSize);
        
        // If fully filled flag is set, total should equal order size
        uint256 isFullyFilledResult = mockFHE.getValue(ebool.unwrap(isFullyFilled));
        if (isFullyFilledResult != 0) {
            assertEq(totalFilled, orderSize);
        }
    }
    
    // ============ GAS OPTIMIZATION TESTS ============
    
    function testGasUsagePartialFill() public {
        euint128 orderSize = mockFHE.mockEuint128(ORDER_SIZE);
        euint128 fillAmount = mockFHE.mockEuint128(FILL_AMOUNT_1);
        euint128 fillPrice = mockFHE.mockEuint128(FILL_PRICE_1);
        
        uint256 gasBefore = gasleft();
        fillManager.executePartialFill(ORDER_ID_1, fillAmount, fillPrice, orderSize);
        uint256 gasUsed = gasBefore - gasleft();
        
        console2.log("Gas used for first partial fill:", gasUsed);
        
        // Second fill should use less gas (state already exists)
        euint128 fillAmount2 = mockFHE.mockEuint128(FILL_AMOUNT_2);
        euint128 fillPrice2 = mockFHE.mockEuint128(FILL_PRICE_2);
        
        uint256 gasBefore2 = gasleft();
        fillManager.executePartialFill(ORDER_ID_1, fillAmount2, fillPrice2, orderSize);
        uint256 gasUsed2 = gasBefore2 - gasleft();
        
        console2.log("Gas used for second partial fill:", gasUsed2);
        
        // Set reasonable gas limits
        assertLt(gasUsed, 300000); // First fill
        assertLt(gasUsed2, 200000); // Subsequent fills should be cheaper
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {FHE, euint128, euint64, euint8, euint32, ebool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

/// @title PartialFillManager
/// @notice Manages partial filling of shadow limit orders
contract PartialFillManager {
    
    struct PartialFillState {
        euint128 totalFilled;        // Total amount filled so far
        euint128 averageFillPrice;   // Volume-weighted average fill price
        euint64 lastFillTime;        // Timestamp of last fill
        euint32 fillCount;           // Number of partial fills
        ebool hasPartialFills;       // Whether order has partial fills
    }
    
    // Fill state for each order
    mapping(bytes32 => PartialFillState) public partialFillStates;
    
    // Fill history for detailed tracking
    mapping(bytes32 => Fill[]) public fillHistory;
    
    struct Fill {
        euint128 fillAmount;
        euint128 fillPrice;
        euint64 fillTime;
        euint32 fillIndex;
    }
    
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
    
    /// @notice Execute a partial fill for an order
    /// @param orderId Order identifier
    /// @param fillAmount Amount to fill
    /// @param fillPrice Price of the fill
    /// @param orderSize Total order size
    /// @return isFullyFilled Whether order is now fully filled
    function executePartialFill(
        bytes32 orderId,
        euint128 fillAmount,
        euint128 fillPrice,
        euint128 orderSize
    ) external returns (ebool isFullyFilled) {
        PartialFillState storage state = partialFillStates[orderId];
        
        // Update total filled amount
        euint128 newTotalFilled = FHE.add(state.totalFilled, fillAmount);
        
        // Update volume-weighted average price
        euint128 newAveragePrice = _calculateNewAveragePrice(
            state.totalFilled,
            state.averageFillPrice,
            fillAmount,
            fillPrice
        );
        
        // Update state
        state.totalFilled = newTotalFilled;
        state.averageFillPrice = newAveragePrice;
        state.lastFillTime = FHE.asEuint64(block.timestamp);
        state.fillCount = FHE.add(state.fillCount, FHE.asEuint32(1));
        state.hasPartialFills = FHE.asEbool(true);
        
        // Record fill in history
        fillHistory[orderId].push(Fill({
            fillAmount: fillAmount,
            fillPrice: fillPrice,
            fillTime: FHE.asEuint64(block.timestamp),
            fillIndex: state.fillCount
        }));
        
        // Check if order is fully filled
        isFullyFilled = FHE.gte(newTotalFilled, orderSize);
        
        euint128 remainingAmount = FHE.sub(orderSize, newTotalFilled);
        
        emit PartialFillExecuted(orderId, fillAmount, fillPrice, remainingAmount);
        
        // Emit fully filled event if applicable
        // Note: In production, properly evaluate encrypted boolean
        // For now, simplified logic
        
        return isFullyFilled;
    }
    
    /// @notice Get partial fill state for an order
    /// @param orderId Order identifier
    /// @return Partial fill state
    function getPartialFillState(bytes32 orderId) external returns (PartialFillState memory) {
        return partialFillStates[orderId];
    }
    
    /// @notice Get fill history for an order
    /// @param orderId Order identifier
    /// @return Array of fills
    function getFillHistory(bytes32 orderId) external returns (Fill[] memory) {
        return fillHistory[orderId];
    }
    
    /// @notice Calculate remaining amount for an order
    /// @param orderId Order identifier
    /// @param orderSize Total order size
    /// @return Remaining unfilled amount
    function getRemainingAmount(bytes32 orderId, euint128 orderSize) external returns (euint128) {
        PartialFillState storage state = partialFillStates[orderId];
        return FHE.sub(orderSize, state.totalFilled);
    }
    
    /// @notice Check if order meets minimum fill requirements for next fill
    /// @param orderId Order identifier
    /// @param minFillSize Minimum fill size
    /// @param orderSize Total order size
    /// @param proposedFillAmount Proposed fill amount
    /// @return Whether the fill meets requirements
    function meetsMinimumFillRequirement(
        bytes32 orderId,
        euint128 minFillSize,
        euint128 orderSize,
        euint128 proposedFillAmount
    ) external returns (ebool) {
        PartialFillState storage state = partialFillStates[orderId];
        euint128 remainingAmount = FHE.sub(orderSize, state.totalFilled);
        
        // Either the proposed fill meets minimum size OR it fills the entire remaining amount
        ebool meetsMinimum = FHE.gte(proposedFillAmount, minFillSize);
        ebool fillsRemaining = FHE.gte(proposedFillAmount, remainingAmount);
        
        return FHE.or(meetsMinimum, fillsRemaining);
    }
    
    /// @notice Calculate fill efficiency metrics
    /// @param orderId Order identifier
    /// @param targetPrice Target/trigger price
    /// @return Fill efficiency score (higher is better)
    function calculateFillEfficiency(
        bytes32 orderId,
        euint128 targetPrice
    ) external returns (euint128) {
        PartialFillState storage state = partialFillStates[orderId];
        
        // Calculate price efficiency (how close average fill price is to target)
        euint128 priceDifference = FHE.select(
            FHE.gte(state.averageFillPrice, targetPrice),
            FHE.sub(state.averageFillPrice, targetPrice),
            FHE.sub(targetPrice, state.averageFillPrice)
        );
        
        // Efficiency = 10000 - (price_diff / target_price * 10000)
        euint128 priceEfficiency = FHE.sub(
            FHE.asEuint128(10000),
            FHE.div(FHE.mul(priceDifference, FHE.asEuint128(10000)), targetPrice)
        );
        
        // Bonus for fewer fills (less fragmentation)
        euint128 fillCountPenalty = FHE.mul(FHE.asEuint128(state.fillCount), FHE.asEuint128(50));
        
        return FHE.select(
            FHE.gte(priceEfficiency, fillCountPenalty),
            FHE.sub(priceEfficiency, fillCountPenalty),
            FHE.asEuint128(0)
        );
    }
    
    /// @notice Reset partial fill state (when order is cancelled or expired)
    /// @param orderId Order identifier
    function resetPartialFillState(bytes32 orderId) external {
        delete partialFillStates[orderId];
        delete fillHistory[orderId];
    }
    
    /// @notice Calculate new volume-weighted average price
    /// @param currentTotal Current total filled amount
    /// @param currentAvgPrice Current average price
    /// @param newFillAmount New fill amount
    /// @param newFillPrice New fill price
    /// @return New volume-weighted average price
    function _calculateNewAveragePrice(
        euint128 currentTotal,
        euint128 currentAvgPrice,
        euint128 newFillAmount,
        euint128 newFillPrice
    ) internal returns (euint128) {
        // Handle first fill
        ebool isFirstFill = FHE.eq(currentTotal, FHE.asEuint128(0));
        
        // For first fill, average price is just the fill price
        // For subsequent fills: (current_total * current_avg + new_amount * new_price) / (current_total + new_amount)
        euint128 totalValue = FHE.add(
            FHE.mul(currentTotal, currentAvgPrice),
            FHE.mul(newFillAmount, newFillPrice)
        );
        
        euint128 newTotal = FHE.add(currentTotal, newFillAmount);
        
        euint128 calculatedAverage = FHE.div(totalValue, newTotal);
        
        return FHE.select(isFirstFill, newFillPrice, calculatedAverage);
    }
}
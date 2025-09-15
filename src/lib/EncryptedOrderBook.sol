// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {FHE, euint128, euint64, euint8, euint32, ebool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

struct ShadowLimitOrder {
    euint128 triggerPrice;
    euint128 orderSize;
    euint8 direction;
    euint128 filledAmount;
    euint64 expirationTime;
    euint32 orderType;
    euint128 minFillSize;
    ebool isActive;
    ebool partialFillAllowed;
    address owner;
}

/// @title EncryptedOrderBook
/// @notice Manages encrypted limit orders in an order book structure
contract EncryptedOrderBook {
    // Order storage
    bytes32[] public activeOrderIds;
    mapping(bytes32 => uint256) public orderIndex;
    
    // Encrypted aggregates
    euint128 public totalBuyVolume;
    euint128 public totalSellVolume;
    euint128 public weightedMidPrice;
    
    /// @notice Add a new order to the book
    /// @param orderId Unique order identifier
    /// @param order The shadow limit order
    function addOrder(bytes32 orderId, ShadowLimitOrder memory order) external {
        activeOrderIds.push(orderId);
        orderIndex[orderId] = activeOrderIds.length - 1;
        
        // Update encrypted aggregates
        _updateAggregates(order, true);
    }
    
    /// @notice Remove an order from the book
    /// @param orderId Order to remove
    function removeOrder(bytes32 orderId, ShadowLimitOrder memory order) external {
        uint256 index = orderIndex[orderId];
        require(index < activeOrderIds.length, "Order not found");
        
        // Move last element to deleted spot to maintain density
        bytes32 lastOrderId = activeOrderIds[activeOrderIds.length - 1];
        activeOrderIds[index] = lastOrderId;
        orderIndex[lastOrderId] = index;
        
        // Remove the last element
        activeOrderIds.pop();
        delete orderIndex[orderId];
        
        // Update encrypted aggregates
        _updateAggregates(order, false);
    }
    
    /// @notice Check for immediate execution opportunities
    /// @param currentPrice Current market price
    function checkImmediateExecution(uint256 currentPrice) external view {
        // In a real implementation, this would check all orders
        // against the current price using FHE operations
        // For now, this is a placeholder
    }
    
    /// @notice Process all limit orders for potential execution
    /// @param currentPrice Current market price
    /// @param hookAddress Address of the calling hook
    function processLimitOrders(uint256 currentPrice, address hookAddress) external {
        // In a real implementation, this would:
        // 1. Convert currentPrice to encrypted form
        // 2. Check each order's trigger conditions using FHE
        // 3. Execute valid orders
        // For now, this is a placeholder
    }
    
    /// @notice Get the number of active orders
    /// @return Number of active orders
    function getActiveOrderCount() external view returns (uint256) {
        return activeOrderIds.length;
    }
    
    /// @notice Get all active order IDs
    /// @return Array of active order IDs
    function getActiveOrderIds() external view returns (bytes32[] memory) {
        return activeOrderIds;
    }
    
    /// @notice Update encrypted aggregates when adding/removing orders
    /// @param order The order being added or removed
    /// @param isAdding True if adding, false if removing
    function _updateAggregates(ShadowLimitOrder memory order, bool isAdding) internal {
        // Update volume aggregates based on direction
        if (isAdding) {
            // Adding order - increase relevant volume
            totalBuyVolume = FHE.add(
                totalBuyVolume,
                FHE.select(
                    FHE.eq(order.direction, FHE.asEuint8(0)), // Buy order
                    order.orderSize,
                    FHE.asEuint128(0)
                )
            );
            
            totalSellVolume = FHE.add(
                totalSellVolume,
                FHE.select(
                    FHE.eq(order.direction, FHE.asEuint8(1)), // Sell order
                    order.orderSize,
                    FHE.asEuint128(0)
                )
            );
        } else {
            // Removing order - decrease relevant volume
            totalBuyVolume = FHE.sub(
                totalBuyVolume,
                FHE.select(
                    FHE.eq(order.direction, FHE.asEuint8(0)), // Buy order
                    order.orderSize,
                    FHE.asEuint128(0)
                )
            );
            
            totalSellVolume = FHE.sub(
                totalSellVolume,
                FHE.select(
                    FHE.eq(order.direction, FHE.asEuint8(1)), // Sell order
                    order.orderSize,
                    FHE.asEuint128(0)
                )
            );
        }
    }
}
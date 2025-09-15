// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {FHE, euint128, euint64, euint8, euint32, ebool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";

/// @title OrderExecutionEngine
/// @notice Advanced execution logic for shadow limit orders
contract OrderExecutionEngine {
    
    struct ExecutionContext {
        euint128 availableLiquidity;
        euint128 currentPrice;
        euint128 priceImpact;
        euint32 executionPriority;
        euint128 maxSlippage;
        euint64 timestamp;
    }
    
    struct OrderPriority {
        euint64 timestamp;      // Order placement time
        euint128 triggerPrice;  // Better prices get priority
        euint128 orderSize;     // Larger orders get priority in ties
        euint32 orderType;      // Order type priority
    }
    
    event OrderExecuted(
        bytes32 indexed orderId,
        euint128 fillAmount,
        euint128 executionPrice,
        euint128 priceImpact
    );
    
    /// @notice Calculate optimal fill amount considering liquidity and constraints
    /// @param triggerPrice Order trigger price
    /// @param orderSize Total order size
    /// @param filledAmount Already filled amount
    /// @param minFillSize Minimum fill size
    /// @param partialFillAllowed Whether partial fills are allowed
    /// @param context Execution context with market conditions
    /// @return Fill amount to execute
    function calculateOptimalFill(
        euint128 triggerPrice,
        euint128 orderSize,
        euint128 filledAmount,
        euint128 minFillSize,
        ebool partialFillAllowed,
        ExecutionContext memory context
    ) external returns (euint128) {
        // Calculate remaining order size
        euint128 remainingSize = FHE.sub(orderSize, filledAmount);
        
        // Apply liquidity constraints
        euint128 liquidityConstrainedFill = FHE.min(
            remainingSize,
            context.availableLiquidity
        );
        
        // Apply slippage constraints
        euint128 slippageConstrainedFill = _applySlippageConstraints(
            liquidityConstrainedFill,
            context.currentPrice,
            triggerPrice,
            context.maxSlippage
        );
        
        // Check if minimum fill size is met
        ebool meetsMinFill = FHE.gte(slippageConstrainedFill, minFillSize);
        
        // Return fill amount based on partial fill settings
        return FHE.select(
            FHE.and(meetsMinFill, partialFillAllowed),
            slippageConstrainedFill,
            FHE.select(
                FHE.gte(slippageConstrainedFill, remainingSize),
                remainingSize, // Full fill possible
                FHE.asEuint128(0) // No fill if conditions not met
            )
        );
    }
    
    /// @notice Calculate execution priority score for order
    /// @param priority Order priority data
    /// @return Priority score (higher is better)
    function calculatePriorityScore(OrderPriority memory priority) external returns (euint128) {
        // Time priority (earlier orders get higher score)
        euint128 timeScore = FHE.sub(
            FHE.asEuint128(type(uint64).max),
            FHE.asEuint128(priority.timestamp)
        );
        
        // Price priority (better prices get bonus)
        euint128 priceBonus = FHE.div(priority.triggerPrice, FHE.asEuint128(1000));
        
        // Size priority (larger orders get small bonus)
        euint128 sizeBonus = FHE.div(priority.orderSize, FHE.asEuint128(10000));
        
        // Combine scores with weights
        return FHE.add(
            FHE.add(FHE.mul(timeScore, FHE.asEuint128(100)), priceBonus),
            sizeBonus
        );
    }
    
    /// @notice Execute a batch of orders efficiently
    /// @param orderIds Array of order IDs to execute
    /// @param fillAmounts Corresponding fill amounts
    /// @param context Execution context
    /// @return totalFilled Total amount filled across all orders
    function batchExecuteOrders(
        bytes32[] memory orderIds,
        euint128[] memory fillAmounts,
        ExecutionContext memory context
    ) external returns (euint128 totalFilled) {
        require(orderIds.length == fillAmounts.length, "Array length mismatch");
        
        totalFilled = FHE.asEuint128(0);
        
        for (uint256 i = 0; i < orderIds.length; i++) {
            // Verify sufficient liquidity remaining
            ebool canFill = FHE.lte(fillAmounts[i], context.availableLiquidity);
            
            euint128 actualFill = FHE.select(canFill, fillAmounts[i], FHE.asEuint128(0));
            
            // Update running totals
            totalFilled = FHE.add(totalFilled, actualFill);
            context.availableLiquidity = FHE.sub(context.availableLiquidity, actualFill);
            
            emit OrderExecuted(orderIds[i], actualFill, context.currentPrice, context.priceImpact);
        }
    }
    
    /// @notice Check if order should be executed based on current conditions
    /// @param triggerPrice Order trigger price
    /// @param direction Order direction (0=buy, 1=sell)
    /// @param currentPrice Current market price
    /// @param isActive Order active status
    /// @param expirationTime Order expiration
    /// @return Whether order should execute
    function shouldExecuteOrder(
        euint128 triggerPrice,
        euint8 direction,
        euint128 currentPrice,
        ebool isActive,
        euint64 expirationTime
    ) external returns (ebool) {
        // Check if order is active
        ebool orderActive = isActive;
        
        // Check if order hasn't expired
        ebool notExpired = FHE.lte(
            FHE.asEuint64(block.timestamp),
            expirationTime
        );
        
        // Check price conditions based on direction
        ebool priceConditionMet = FHE.select(
            FHE.eq(direction, FHE.asEuint8(0)), // Buy order
            FHE.lte(currentPrice, triggerPrice), // Buy when price <= trigger
            FHE.gte(currentPrice, triggerPrice)  // Sell when price >= trigger
        );
        
        // All conditions must be true
        return FHE.and(
            FHE.and(orderActive, notExpired),
            priceConditionMet
        );
    }
    
    /// @notice Apply slippage constraints to fill amount
    /// @param fillAmount Desired fill amount
    /// @param currentPrice Current market price
    /// @param triggerPrice Order trigger price
    /// @param maxSlippage Maximum allowed slippage
    /// @return Slippage-constrained fill amount
    function _applySlippageConstraints(
        euint128 fillAmount,
        euint128 currentPrice,
        euint128 triggerPrice,
        euint128 maxSlippage
    ) internal returns (euint128) {
        // Calculate price difference
        euint128 priceDiff = FHE.select(
            FHE.gte(currentPrice, triggerPrice),
            FHE.sub(currentPrice, triggerPrice),
            FHE.sub(triggerPrice, currentPrice)
        );
        
        // Calculate slippage percentage (basis points)
        euint128 slippagePercent = FHE.div(
            FHE.mul(priceDiff, FHE.asEuint128(10000)),
            triggerPrice
        );
        
        // Check if slippage is acceptable
        ebool acceptableSlippage = FHE.lte(slippagePercent, maxSlippage);
        
        // Return full amount if acceptable, zero otherwise
        return FHE.select(acceptableSlippage, fillAmount, FHE.asEuint128(0));
    }
    
    /// @notice Calculate price impact from execution
    /// @param fillAmount Amount to fill
    /// @param availableLiquidity Available liquidity
    /// @return Price impact in basis points
    function calculatePriceImpact(
        euint128 fillAmount,
        euint128 availableLiquidity
    ) external returns (euint128) {
        // Simple linear price impact model
        // impact = (fillAmount / availableLiquidity) * 10000 (basis points)
        return FHE.div(
            FHE.mul(fillAmount, FHE.asEuint128(10000)),
            availableLiquidity
        );
    }
}
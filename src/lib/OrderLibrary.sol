// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {FHE, euint128, euint64, euint8, euint32, ebool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

/// @title OrderLibrary
/// @notice Library for encrypted limit order operations and utilities
library OrderLibrary {
    /// @notice Validate if a limit order should be executed
    /// @param triggerPrice Encrypted trigger price
    /// @param currentPrice Encrypted current market price
    /// @param direction Encrypted order direction (0=buy, 1=sell)
    /// @param isActive Encrypted order active status
    /// @param expirationTime Encrypted expiration time
    /// @param currentTime Current block timestamp
    /// @return shouldExecute Whether the order should be executed
    function validateOrderExecution(
        euint128 triggerPrice,
        euint128 currentPrice,
        euint8 direction,
        ebool isActive,
        euint64 expirationTime,
        uint256 currentTime
    ) internal returns (ebool shouldExecute) {
        euint64 encCurrentTime = FHE.asEuint64(currentTime);
        
        // Check if order is active
        ebool orderActive = isActive;
        
        // Check if order hasn't expired
        ebool notExpired = FHE.lte(encCurrentTime, expirationTime);
        
        // Check price conditions based on direction
        ebool priceConditionMet = FHE.select(
            FHE.eq(direction, FHE.asEuint8(0)), // Buy order
            FHE.lte(currentPrice, triggerPrice), // Buy when current price <= trigger price
            FHE.gte(currentPrice, triggerPrice)  // Sell when current price >= trigger price
        );
        
        // All conditions must be true for execution
        shouldExecute = FHE.and(
            FHE.and(orderActive, notExpired),
            priceConditionMet
        );
    }

    /// @notice Calculate optimal fill amount for an order
    /// @param orderSize Encrypted total order size
    /// @param filledAmount Encrypted already filled amount
    /// @param minFillSize Encrypted minimum fill size
    /// @param availableLiquidity Encrypted available liquidity
    /// @param partialFillAllowed Encrypted partial fill setting
    /// @return fillAmount Optimal fill amount
    function calculateOptimalFill(
        euint128 orderSize,
        euint128 filledAmount,
        euint128 minFillSize,
        euint128 availableLiquidity,
        ebool partialFillAllowed
    ) internal returns (euint128 fillAmount) {
        // Calculate remaining order size
        euint128 remainingSize = FHE.sub(orderSize, filledAmount);
        
        // Apply liquidity constraints
        euint128 liquidityConstrainedFill = FHE.min(remainingSize, availableLiquidity);
        
        // Check if minimum fill size is met
        ebool meetsMinFill = FHE.gte(liquidityConstrainedFill, minFillSize);
        
        // Return fill amount based on partial fill settings
        fillAmount = FHE.select(
            FHE.and(meetsMinFill, partialFillAllowed),
            liquidityConstrainedFill, // Use constrained fill if partials allowed
            FHE.select(
                FHE.gte(liquidityConstrainedFill, remainingSize),
                remainingSize, // Full fill possible
                FHE.asEuint128(0) // No fill if conditions not met
            )
        );
    }

    /// @notice Calculate execution priority for order sorting
    /// @param placementTime Encrypted order placement timestamp
    /// @param triggerPrice Encrypted trigger price
    /// @param orderSize Encrypted order size
    /// @param orderType Encrypted order type
    /// @return priorityScore Higher score means higher priority
    function calculateExecutionPriority(
        euint64 placementTime,
        euint128 triggerPrice,
        euint128 orderSize,
        euint32 orderType
    ) internal returns (euint128 priorityScore) {
        // Time priority (earlier orders get higher score)
        euint128 timeScore = FHE.sub(
            FHE.asEuint128(type(uint64).max),
            FHE.asEuint128(placementTime)
        );
        
        // Price priority (better prices get bonus)
        euint128 priceBonus = FHE.div(triggerPrice, FHE.asEuint128(1000));
        
        // Size priority (larger orders get small bonus)
        euint128 sizeBonus = FHE.div(orderSize, FHE.asEuint128(10000));
        
        // Order type priority
        euint128 typeBonus = FHE.mul(FHE.asEuint128(orderType), FHE.asEuint128(100));
        
        // Combine scores with weights
        priorityScore = FHE.add(
            FHE.add(
                FHE.mul(timeScore, FHE.asEuint128(100)), // Time weight: 100
                priceBonus // Price weight: 1
            ),
            FHE.add(sizeBonus, typeBonus) // Size and type bonuses
        );
    }

    /// @notice Update volume-weighted average price
    /// @param currentTotal Encrypted current total filled amount
    /// @param currentAvgPrice Encrypted current average price
    /// @param newFillAmount Encrypted new fill amount
    /// @param newFillPrice Encrypted new fill price
    /// @return newAveragePrice Updated volume-weighted average price
    function updateVolumeWeightedPrice(
        euint128 currentTotal,
        euint128 currentAvgPrice,
        euint128 newFillAmount,
        euint128 newFillPrice
    ) internal returns (euint128 newAveragePrice) {
        // Handle first fill
        ebool isFirstFill = FHE.eq(currentTotal, FHE.asEuint128(0));
        
        // Calculate weighted average
        euint128 totalValue = FHE.add(
            FHE.mul(currentTotal, currentAvgPrice),
            FHE.mul(newFillAmount, newFillPrice)
        );
        
        euint128 newTotal = FHE.add(currentTotal, newFillAmount);
        euint128 calculatedAverage = FHE.div(totalValue, newTotal);
        
        newAveragePrice = FHE.select(isFirstFill, newFillPrice, calculatedAverage);
    }

    /// @notice Calculate slippage-adjusted fill amount
    /// @param fillAmount Encrypted desired fill amount
    /// @param currentPrice Encrypted current price
    /// @param triggerPrice Encrypted trigger price
    /// @param maxSlippage Encrypted maximum allowed slippage (in basis points)
    /// @return adjustedFillAmount Slippage-adjusted fill amount
    function applySlippageProtection(
        euint128 fillAmount,
        euint128 currentPrice,
        euint128 triggerPrice,
        euint128 maxSlippage
    ) internal returns (euint128 adjustedFillAmount) {
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
        adjustedFillAmount = FHE.select(acceptableSlippage, fillAmount, FHE.asEuint128(0));
    }

    /// @notice Check if order meets minimum size requirements
    /// @param orderSize Encrypted order size
    /// @param minOrderSize Encrypted minimum order size
    /// @return isValidSize Whether order meets minimum size
    function validateOrderSize(
        euint128 orderSize,
        euint128 minOrderSize
    ) internal returns (ebool isValidSize) {
        isValidSize = FHE.gte(orderSize, minOrderSize);
    }

    /// @notice Calculate price impact of execution
    /// @param fillAmount Encrypted fill amount
    /// @param availableLiquidity Encrypted available liquidity
    /// @return priceImpact Price impact in basis points
    function calculatePriceImpact(
        euint128 fillAmount,
        euint128 availableLiquidity
    ) internal returns (euint128 priceImpact) {
        // Simple linear price impact model
        // impact = (fillAmount / availableLiquidity) * 10000 (basis points)
        priceImpact = FHE.div(
            FHE.mul(fillAmount, FHE.asEuint128(10000)),
            availableLiquidity
        );
    }

    /// @notice Validate order parameters during creation
    /// @param triggerPrice Encrypted trigger price
    /// @param orderSize Encrypted order size
    /// @param expirationTime Encrypted expiration time
    /// @param minFillSize Encrypted minimum fill size
    /// @param currentTime Current timestamp
    /// @return isValid Whether all parameters are valid
    function validateOrderParameters(
        euint128 triggerPrice,
        euint128 orderSize,
        euint64 expirationTime,
        euint128 minFillSize,
        uint256 currentTime
    ) internal returns (ebool isValid) {
        euint64 encCurrentTime = FHE.asEuint64(currentTime);
        
        // Check if trigger price is valid (non-zero)
        ebool validPrice = FHE.gt(triggerPrice, FHE.asEuint128(0));
        
        // Check if order size is valid (non-zero)
        ebool validSize = FHE.gt(orderSize, FHE.asEuint128(0));
        
        // Check if expiration is in the future
        ebool validExpiration = FHE.gt(expirationTime, encCurrentTime);
        
        // Check if min fill size is not larger than order size
        ebool validMinFill = FHE.lte(minFillSize, orderSize);
        
        // All validations must pass
        isValid = FHE.and(
            FHE.and(validPrice, validSize),
            FHE.and(validExpiration, validMinFill)
        );
    }

    /// @notice Check if order has expired
    /// @param expirationTime Encrypted expiration time
    /// @param currentTime Current timestamp
    /// @return hasExpired Whether order has expired
    function isOrderExpired(
        euint64 expirationTime,
        uint256 currentTime
    ) internal returns (ebool hasExpired) {
        euint64 encCurrentTime = FHE.asEuint64(currentTime);
        hasExpired = FHE.gt(encCurrentTime, expirationTime);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {FHE, euint128, euint64, euint8, euint32, ebool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

/// @title FHE Permission Management Library for Shadow Limit Orders
/// @notice Centralizes FHE.allow() calls for consistent access control
/// @dev Implements the critical "Define Access" step in Fhenix's 3-step CoFHE pattern
library FHEPermissions {
    /// @notice Grant comprehensive permissions for limit order creation
    /// @param triggerPrice Encrypted trigger price
    /// @param orderSize Encrypted order size
    /// @param direction Encrypted order direction
    /// @param expirationTime Encrypted expiration time
    /// @param minFillSize Encrypted minimum fill size
    /// @param orderOwner Address of the order owner
    /// @param currency0 Address of currency0
    /// @param currency1 Address of currency1
    function grantOrderCreationPermissions(
        euint128 triggerPrice,
        euint128 orderSize,
        euint8 direction,
        euint64 expirationTime,
        euint128 minFillSize,
        address orderOwner,
        address currency0,
        address currency1,
        address /* hookContract */
    ) internal {
        // Owner permissions - owner needs access to view their order parameters
        FHE.allow(triggerPrice, orderOwner);
        FHE.allow(orderSize, orderOwner);
        FHE.allow(direction, orderOwner);
        FHE.allow(expirationTime, orderOwner);
        FHE.allow(minFillSize, orderOwner);

        // Contract permissions - hook contract needs access for calculations
        FHE.allowThis(triggerPrice);
        FHE.allowThis(orderSize);
        FHE.allowThis(direction);
        FHE.allowThis(expirationTime);
        FHE.allowThis(minFillSize);

        // Currency permissions - currencies need access for potential transfers
        FHE.allow(orderSize, currency0);
        FHE.allow(orderSize, currency1);
    }

    /// @notice Grant permissions for order execution operations
    /// @param fillAmount Encrypted fill amount
    /// @param executionPrice Encrypted execution price
    /// @param remainingAmount Encrypted remaining amount
    /// @param orderOwner Address of the order owner
    /// @param currency0 Address of currency0
    /// @param currency1 Address of currency1
    function grantOrderExecutionPermissions(
        euint128 fillAmount,
        euint128 executionPrice,
        euint128 remainingAmount,
        address orderOwner,
        address currency0,
        address currency1,
        address /* hookContract */
    ) internal {
        // Owner permissions - owner needs access to execution data
        FHE.allow(fillAmount, orderOwner);
        FHE.allow(executionPrice, orderOwner);
        FHE.allow(remainingAmount, orderOwner);

        // Contract permissions - hook contract needs access for validation and storage
        FHE.allowThis(fillAmount);
        FHE.allowThis(executionPrice);
        FHE.allowThis(remainingAmount);

        // Currency permissions - currencies need access for encrypted transfers
        FHE.allow(fillAmount, currency0);
        FHE.allow(fillAmount, currency1);
    }

    /// @notice Grant permissions for partial fill operations
    /// @param fillAmount Encrypted fill amount
    /// @param totalFilled Encrypted total filled amount
    /// @param averagePrice Encrypted average fill price
    /// @param orderOwner Address of the order owner
    function grantPartialFillPermissions(
        euint128 fillAmount,
        euint128 totalFilled,
        euint128 averagePrice,
        address orderOwner,
        address /* hookContract */
    ) internal {
        // Owner permissions - owner needs access to their fill data
        FHE.allow(fillAmount, orderOwner);
        FHE.allow(totalFilled, orderOwner);
        FHE.allow(averagePrice, orderOwner);

        // Contract permissions - hook contract needs access for calculations
        FHE.allowThis(fillAmount);
        FHE.allowThis(totalFilled);
        FHE.allowThis(averagePrice);
    }

    /// @notice Grant permissions for swap validation operations
    /// @param swapAmount Encrypted swap amount
    /// @param orderLimit Encrypted order limit
    /// @param isValid Encrypted validation result
    /// @param swapper Address of the swapper
    function grantSwapValidationPermissions(
        euint128 swapAmount,
        euint128 orderLimit,
        ebool isValid,
        address swapper,
        address /* hookContract */
    ) internal {
        // Swapper permissions - swapper needs access to validation result
        FHE.allow(isValid, swapper);

        // Contract permissions - hook contract needs access for validation
        FHE.allowThis(swapAmount);
        FHE.allowThis(orderLimit);
        FHE.allowThis(isValid);
    }

    /// @notice Grant permissions for order book operations
    /// @param totalBuyVolume Encrypted total buy volume
    /// @param totalSellVolume Encrypted total sell volume
    /// @param weightedMidPrice Encrypted weighted mid price
    function grantOrderBookPermissions(
        euint128 totalBuyVolume,
        euint128 totalSellVolume,
        euint128 weightedMidPrice,
        address /* hookContract */
    ) internal {
        // Contract permissions - hook contract needs access for order book management
        FHE.allowThis(totalBuyVolume);
        FHE.allowThis(totalSellVolume);
        FHE.allowThis(weightedMidPrice);
    }

    /// @notice Grant permissions for time-based operations
    /// @param expirationTime Encrypted expiration time
    /// @param currentTime Encrypted current time
    /// @param orderOwner Address of the order owner
    function grantTimePermissions(
        euint64 expirationTime,
        euint64 currentTime,
        address orderOwner,
        address /* hookContract */
    ) internal {
        // Owner permissions
        FHE.allow(expirationTime, orderOwner);

        // Contract permissions
        FHE.allowThis(expirationTime);
        FHE.allowThis(currentTime);
    }

    /// @notice Grant permissions for boolean operations
    /// @param boolValue Encrypted boolean value
    /// @param user Address of the user
    function grantBoolPermissions(
        ebool boolValue, 
        address user, 
        address /* hookContract */
    ) internal {
        FHE.allow(boolValue, user);
        FHE.allowThis(boolValue);
    }

    /// @notice Grant comprehensive permissions for price comparison operations
    /// @param currentPrice Encrypted current price
    /// @param triggerPrice Encrypted trigger price
    /// @param priceComparison Encrypted comparison result
    /// @param orderOwner Address of the order owner
    function grantPriceComparisonPermissions(
        euint128 currentPrice,
        euint128 triggerPrice,
        ebool priceComparison,
        address orderOwner,
        address /* hookContract */
    ) internal {
        // Owner permissions - owner needs access to price comparison results
        FHE.allow(priceComparison, orderOwner);

        // Contract permissions - hook contract needs access for price calculations
        FHE.allowThis(currentPrice);
        FHE.allowThis(triggerPrice);
        FHE.allowThis(priceComparison);
    }

    /// @notice Grant permissions for order priority calculations
    /// @param priorityScore Encrypted priority score
    /// @param timestamp Encrypted timestamp
    /// @param orderSize Encrypted order size
    function grantPriorityPermissions(
        euint128 priorityScore,
        euint64 timestamp,
        euint128 orderSize,
        address /* hookContract */
    ) internal {
        // Contract permissions - hook contract needs access for priority calculations
        FHE.allowThis(priorityScore);
        FHE.allowThis(timestamp);
        FHE.allowThis(orderSize);
    }
}
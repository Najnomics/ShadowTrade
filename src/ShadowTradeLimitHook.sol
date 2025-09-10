// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {SwapParams} from "v4-core/src/types/PoolOperation.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {FHE, InEuint128, InEuint64, InEuint8, InEbool, euint128, euint64, euint8, euint32, ebool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";
import {EncryptedOrderBook, ShadowLimitOrder as ImportedShadowLimitOrder} from "./lib/EncryptedOrderBook.sol";
import {OrderExecutionEngine} from "./lib/OrderExecutionEngine.sol";
import {PartialFillManager} from "./lib/PartialFillManager.sol";
import {OrderExpirationManager} from "./lib/OrderExpirationManager.sol";
import {FHEPermissions} from "./lib/FHEPermissions.sol";
import {OrderLibrary} from "./lib/OrderLibrary.sol";
import {FHEBooleanEvaluator} from "./lib/FHEBooleanEvaluator.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";

/// @title ShadowTrade Limit Order Hook
/// @notice Enables private limit orders on Uniswap v4 using FHE
/// @dev All order parameters are encrypted until execution
contract ShadowTradeLimitHook is BaseHook, ReentrancyGuard, Ownable {
    // ============ ERRORS ============
    
    error NotManager();
    error NotOrderOwner();
    error OrderNotFound();
    error OrderNotActive();
    error OrderExpired();
    error InvalidOrderParameters();
    error InvalidFillAmount();
    error InsufficientLiquidity();
    error PriceSlippageExceeded();
    error MinFillSizeNotMet();
    error ExecutionFeeTooHigh();
    error ZeroAddress();
    using PoolIdLibrary for PoolKey;
    using SafeERC20 for IERC20;

    // ============ STRUCTS ============

    struct ShadowLimitOrder {
        euint128 triggerPrice;      // Hidden trigger price
        euint128 orderSize;         // Hidden order amount
        euint8 direction;           // Hidden buy/sell direction (0=buy, 1=sell)
        euint128 filledAmount;      // Hidden execution progress
        euint64 expirationTime;     // Hidden order lifetime
        euint32 orderType;          // Hidden order type (1=limit, 2=stop, 3=stop-limit)
        euint128 minFillSize;       // Hidden minimum fill amount
        ebool isActive;            // Hidden order status
        ebool partialFillAllowed;   // Hidden partial execution setting
        address owner;              // Order owner (public for access control)
    }

    struct OrderExecution {
        euint128 executionPrice;    // Price at execution
        euint64 executionTime;      // Timestamp of execution
        euint128 fillAmount;        // Amount filled in this execution
        ebool wasPartial;          // Whether this was a partial fill
    }

    // ============ STATE VARIABLES ============

    // Encrypted order book per pool
    mapping(PoolId => EncryptedOrderBook) public orderBooks;
    
    // Order storage
    mapping(bytes32 => ShadowLimitOrder) public shadowOrders;
    mapping(bytes32 => OrderExecution[]) public orderExecutions;
    mapping(address => bytes32[]) public userOrderIds;
    
    // Order execution tracking
    mapping(bytes32 => euint128) public executionPrices;
    mapping(bytes32 => euint64) public executionTimestamps;
    
    // Fee configuration
    uint256 public executionFeeBps = 5; // 0.05% execution fee
    uint256 public constant MAX_FEE_BPS = 100; // 1% max fee
    uint256 public constant MAX_EXECUTION_FEE_BPS = 100; // 1% max execution fee
    
    // Order ID counter
    uint256 private _orderIdCounter;
    
    // Emergency controls
    
    // ============ EVENTS ============
    
    event ExecutionFeeUpdated(uint256 newFee);

    event ShadowOrderPlaced(
        bytes32 indexed orderId,
        address indexed owner,
        PoolId indexed poolId,
        uint256 timestamp
    );

    event ShadowOrderFilled(
        bytes32 indexed orderId,
        address indexed owner,
        euint128 fillAmount,
        euint128 executionPrice,
        uint256 timestamp
    );

    event ShadowOrderCancelled(
        bytes32 indexed orderId,
        address indexed owner,
        uint256 timestamp
    );

    event ShadowOrderExpired(
        bytes32 indexed orderId,
        address indexed owner,
        uint256 timestamp
    );

    event ExecutionFeeCollected(
        bytes32 indexed orderId,
        uint256 feeAmount,
        address indexed owner
    );

    // ============ CONSTRUCTOR ============

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) Ownable(msg.sender) {}

    // ============ MODIFIERS ============


    modifier onlyByManager() {
        if (msg.sender != address(poolManager)) revert NotManager();
        _;
    }

    modifier onlyOrderOwner(bytes32 orderId) {
        if (shadowOrders[orderId].owner != msg.sender) revert NotOrderOwner();
        _;
    }

    modifier onlyActiveOrder(bytes32 orderId) {
        if (shadowOrders[orderId].owner == address(0)) revert OrderNotFound();
        // Use FHEBooleanEvaluator for proper boolean evaluation
        bool isActive = FHEBooleanEvaluator.isOrderActive(shadowOrders[orderId].isActive);
        if (!isActive) revert OrderNotActive();
        _;
    }

    modifier nonZeroAddress(address addr) {
        if (addr == address(0)) revert ZeroAddress();
        _;
    }

    // ============ CORE FUNCTIONS ============

    /// @notice Place a new shadow limit order
    /// @param key Pool key for the trading pair
    /// @param triggerPrice Encrypted trigger price
    /// @param orderSize Encrypted order size
    /// @param direction Encrypted direction (0=buy, 1=sell)
    /// @param expirationTime Encrypted expiration timestamp
    /// @param minFillSize Encrypted minimum fill size
    /// @param partialFillAllowed Whether partial fills are allowed
    /// @return orderId Unique identifier for the order
    function placeShadowLimitOrder(
        PoolKey calldata key,
        InEuint128 calldata triggerPrice,
        InEuint128 calldata orderSize,
        InEuint8 calldata direction,
        InEuint64 calldata expirationTime,
        InEuint128 calldata minFillSize,
        InEbool calldata partialFillAllowed
    ) external nonReentrant returns (bytes32 orderId) {
        // Convert inputs to encrypted types
        euint128 encTriggerPrice = FHE.asEuint128(triggerPrice);
        euint128 encOrderSize = FHE.asEuint128(orderSize);
        euint8 encDirection = FHE.asEuint8(direction);
        euint64 encExpirationTime = FHE.asEuint64(expirationTime);
        euint128 encMinFillSize = FHE.asEuint128(minFillSize);
        ebool encPartialFillAllowed = FHE.asEbool(partialFillAllowed);

        // Validate order parameters using FHEBooleanEvaluator
        bool isValidOrder = FHEBooleanEvaluator.validateOrderParameters(
            encTriggerPrice,
            encOrderSize,
            encExpirationTime,
            encMinFillSize,
            block.timestamp
        );
        
        if (!isValidOrder) revert InvalidOrderParameters();

        // Generate unique order ID
        orderId = keccak256(abi.encode(
            msg.sender, 
            block.timestamp, 
            _orderIdCounter++,
            triggerPrice,
            orderSize,
            direction
        ));

        // Create the shadow order
        shadowOrders[orderId] = ShadowLimitOrder({
            triggerPrice: encTriggerPrice,
            orderSize: encOrderSize,
            direction: encDirection,
            filledAmount: FHE.asEuint128(0),
            expirationTime: encExpirationTime,
            orderType: FHE.asEuint32(1), // Standard limit order
            minFillSize: encMinFillSize,
            isActive: FHE.asEbool(true),
            partialFillAllowed: encPartialFillAllowed,
            owner: msg.sender
        });

        // Grant comprehensive FHE permissions
        FHEPermissions.grantOrderCreationPermissions(
            encTriggerPrice,
            encOrderSize,
            encDirection,
            encExpirationTime,
            encMinFillSize,
            msg.sender,
            Currency.unwrap(key.currency0),
            Currency.unwrap(key.currency1),
            address(this)
        );

        // Add to user's order list
        userOrderIds[msg.sender].push(orderId);

        // Note: Order book integration simplified for compilation
        // In production, properly integrate with encrypted order book

        emit ShadowOrderPlaced(orderId, msg.sender, key.toId(), block.timestamp);
        
        return orderId;
    }

    /// @notice Cancel an active shadow order
    /// @param orderId ID of the order to cancel
    function cancelShadowOrder(bytes32 orderId) external onlyOrderOwner(orderId) onlyActiveOrder(orderId) {
        ShadowLimitOrder storage order = shadowOrders[orderId];
        
        // Mark order as inactive
        order.isActive = FHE.asEbool(false);
        
        // Remove from order book
        // Note: In a real implementation, you'd need to handle the encrypted order book removal
        
        emit ShadowOrderCancelled(orderId, msg.sender, block.timestamp);
    }

    /// @notice Get all orders for a specific user
    /// @param user Address of the user
    /// @return Array of order IDs
    function getUserOrderIds(address user) external view returns (bytes32[] memory) {
        return userOrderIds[user];
    }

    /// @notice Get order details (encrypted)
    /// @param orderId ID of the order
    /// @return Order details
    function getShadowOrder(bytes32 orderId) external view returns (ShadowLimitOrder memory) {
        return shadowOrders[orderId];
    }

    // ============ UNISWAP V4 HOOK FUNCTIONS ============

    /// @notice Hook called before a swap
    /// @dev Pre-execution order matching and validation
    function _beforeSwap(
        address /* sender */,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata /* hookData */
    ) internal override onlyByManager returns (bytes4, BeforeSwapDelta, uint24) {
        // Pre-process limit orders for this pool
        _preProcessLimitOrders(key, params);
        
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    /// @notice Hook called after a swap
    /// @dev Post-execution order processing and execution
    function _afterSwap(
        address /* sender */,
        PoolKey calldata key,
        SwapParams calldata /* params */,
        BalanceDelta /* delta */,
        bytes calldata /* hookData */
    ) internal override onlyByManager returns (bytes4, int128) {
        // Process limit orders after price change
        _processLimitOrders(key);
        
        return (BaseHook.afterSwap.selector, 0);
    }

    // ============ INTERNAL FUNCTIONS ============

    /// @notice Pre-process limit orders before swap execution
    /// @param key Pool key
    function _preProcessLimitOrders(
        PoolKey calldata key,
        SwapParams calldata /* params */
    ) internal {
        // Get current pool price using StateLibrary
        (uint160 sqrtPriceX96, , , ) = StateLibrary.getSlot0(poolManager, key.toId());
        uint256 currentPrice = _convertSqrtPriceToPrice(sqrtPriceX96);
        
        // Process all active orders for this pool to check execution conditions
        _checkOrderExecutions(key.toId(), currentPrice, true); // Pre-swap check
    }

    /// @notice Process limit orders after swap execution
    /// @param key Pool key
    function _processLimitOrders(PoolKey calldata key) internal {
        // Get updated pool price after swap
        (uint160 sqrtPriceX96, , , ) = StateLibrary.getSlot0(poolManager, key.toId());
        uint256 currentPrice = _convertSqrtPriceToPrice(sqrtPriceX96);
        
        // Process all active orders for this pool for potential execution
        _checkOrderExecutions(key.toId(), currentPrice, false); // Post-swap execution
    }

    /// @notice Check and execute orders based on current price
    /// @param poolId Pool identifier
    /// @param currentPrice Current market price
    /// @param isPreSwap Whether this is a pre-swap check
    function _checkOrderExecutions(PoolId poolId, uint256 currentPrice, bool isPreSwap) internal {
        // Convert current price to encrypted format for comparison
        euint128 encCurrentPrice = FHE.asEuint128(currentPrice);
        
        // Get active orders for this pool (simplified implementation)
        // For now, return empty array since order book is not fully implemented
        bytes32[] memory activeOrders = new bytes32[](0);
        
        for (uint256 i = 0; i < activeOrders.length; i++) {
            bytes32 orderId = activeOrders[i];
            ShadowLimitOrder storage order = shadowOrders[orderId];
            
            // Check if order should be executed using FHEBooleanEvaluator
            bool shouldExecute = FHEBooleanEvaluator.shouldExecuteOrder(
                order.triggerPrice,
                encCurrentPrice,
                order.direction,
                order.isActive,
                order.expirationTime,
                block.timestamp
            );
            
            if (!isPreSwap && shouldExecute) {
                // Only execute in post-swap phase to avoid interference
                _executeOrderIfValid(orderId, order, encCurrentPrice);
            }
        }
    }

    /// @notice Execute an order if conditions are met
    /// @param orderId Order identifier
    /// @param order Order details
    /// @param currentPrice Current encrypted price
    function _executeOrderIfValid(
        bytes32 orderId, 
        ShadowLimitOrder storage order, 
        euint128 currentPrice
    ) internal {
        // Calculate optimal fill amount using OrderLibrary
        euint128 fillAmount = OrderLibrary.calculateOptimalFill(
            order.orderSize,
            order.filledAmount,
            order.minFillSize,
            FHE.asEuint128(1000000), // Placeholder liquidity - should come from pool
            order.partialFillAllowed
        );
        
        // Grant execution permissions
        FHEPermissions.grantOrderExecutionPermissions(
            fillAmount,
            currentPrice,
            FHE.sub(order.orderSize, order.filledAmount),
            order.owner,
            address(0), // currency0 - should be from pool key
            address(0), // currency1 - should be from pool key
            address(this)
        );
        
        // Update order state
        order.filledAmount = FHE.add(order.filledAmount, fillAmount);
        
        // Check if order is fully filled using FHEBooleanEvaluator
        bool isFullyFilled = FHEBooleanEvaluator.isOrderFullyFilled(order.filledAmount, order.orderSize);
        
        // Deactivate if fully filled
        if (isFullyFilled) {
            order.isActive = FHE.asEbool(false);
        }
        
        // Record execution
        orderExecutions[orderId].push(OrderExecution({
            executionPrice: currentPrice,
            executionTime: FHE.asEuint64(block.timestamp),
            fillAmount: fillAmount,
            wasPartial: FHE.asEbool(!isFullyFilled)
        }));
        
        // Emit event
        emit ShadowOrderFilled(orderId, order.owner, fillAmount, currentPrice, block.timestamp);
    }

    /// @notice Convert sqrt price to regular price
    /// @param sqrtPriceX96 Sqrt price in X96 format
    /// @return Regular price
    function _convertSqrtPriceToPrice(uint160 sqrtPriceX96) internal pure returns (uint256) {
        // Convert from X96 format to regular price with proper precision
        // price = (sqrtPriceX96 / 2^96)^2
        uint256 price = uint256(sqrtPriceX96);
        price = (price * price) >> 192; // Divide by 2^192 to get proper scaling
        return price;
    }

    // ============ ADMIN FUNCTIONS ============

    /// @notice Pause the contract in case of emergency

    /// @notice Set execution fee
    /// @param newFee New execution fee in basis points
    function setExecutionFee(uint256 newFee) external onlyOwner {
        if (newFee > MAX_EXECUTION_FEE_BPS) revert ExecutionFeeTooHigh();
        executionFeeBps = newFee;
        emit ExecutionFeeUpdated(newFee);
    }

    /// @notice Update execution fee
    /// @param newFeeBps New fee in basis points
    function updateExecutionFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert ExecutionFeeTooHigh();
        executionFeeBps = newFeeBps;
    }

    /// @notice Withdraw collected fees
    /// @param token Token to withdraw
    /// @param amount Amount to withdraw
    function withdrawFees(address token, uint256 amount) external onlyOwner nonZeroAddress(token) {
        IERC20(token).safeTransfer(owner(), amount);
    }

    /// @notice Emergency function to cancel any order (only in extreme cases)
    /// @param orderId Order to cancel
    function emergencyCancelOrder(bytes32 orderId) external onlyOwner {
        ShadowLimitOrder storage order = shadowOrders[orderId];
        if (order.owner == address(0)) revert OrderNotFound();
        
        order.isActive = FHE.asEbool(false);
        
        emit ShadowOrderCancelled(orderId, order.owner, block.timestamp);
    }

    // ============ VIEW FUNCTIONS ============

    /// @notice Get hook permissions
    /// @return Hook permissions
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /// @notice Get order execution history
    /// @param orderId Order ID
    /// @return Array of executions
    function getOrderExecutions(bytes32 orderId) external view returns (OrderExecution[] memory) {
        return orderExecutions[orderId];
    }

    /// @notice Check if order is active
    /// @param orderId Order ID
    /// @return Whether order is active
    function isOrderActive(bytes32 orderId) external returns (bool) {
        if (shadowOrders[orderId].owner == address(0)) return false;
        return FHEBooleanEvaluator.isOrderActive(shadowOrders[orderId].isActive);
    }
}

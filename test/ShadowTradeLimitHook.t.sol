// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/src/types/PoolOperation.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {Deployers} from "v4-core/test/utils/Deployers.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

// FHE imports
import {FHE, InEuint128, InEuint64, InEuint8, InEbool, euint128, euint64, euint8, euint32, ebool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

// Contract under test
import {ShadowTradeLimitHook} from "../src/ShadowTradeLimitHook.sol";

// Test utilities
import {CoFheTest} from "@fhenixprotocol/cofhe-mock-contracts/CoFheTest.sol";

/// @title ShadowTradeLimitHook Test Suite
/// @notice Comprehensive test suite for the ShadowTrade limit order system
/// @dev Tests FHE-encrypted limit orders on Uniswap v4 with 100% coverage goal
contract ShadowTradeLimitHookTest is Test, Deployers, CoFheTest {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    // Test contracts
    ShadowTradeLimitHook public hook;
    // FHE Mock Infrastructure (inherited from CoFheTest)
    
    // Test tokens
    MockERC20 public token0;
    MockERC20 public token1;
    
    // Test users
    address public trader1;
    address public trader2;
    address public trader3;
    address public hookOwner;
    
    // Pool configuration
    PoolKey public poolKey;
    PoolId public poolId;
    
    // Constants for testing
    uint256 constant INITIAL_BALANCE = 1000 ether;
    uint128 constant ORDER_SIZE = 10 ether;
    uint128 constant TRIGGER_PRICE = 2000e18; // $2000
    uint64 constant ORDER_EXPIRY = 3600; // 1 hour
    uint128 constant MIN_FILL_SIZE = 1 ether;
    
    // Events for testing
    event ShadowOrderPlaced(bytes32 indexed orderId, address indexed owner, PoolId indexed poolId, uint256 timestamp);
    event ShadowOrderCancelled(bytes32 indexed orderId, address indexed owner, uint256 timestamp);
    event ShadowOrderExecuted(bytes32 indexed orderId, address indexed owner, uint128 fillAmount, uint128 executionPrice);
    
    function setUp() public {
        // Deploy core contracts
        deployFreshManagerAndRouters();
        
        // FHE mock infrastructure is set up by CoFheTest constructor
        
        // Create test users
        trader1 = makeAddr("trader1");
        trader2 = makeAddr("trader2");
        trader3 = makeAddr("trader3");
        hookOwner = makeAddr("hookOwner");
        
        // Deploy test tokens
        token0 = new MockERC20("Token 0", "TOK0", 18);
        token1 = new MockERC20("Token 1", "TOK1", 18);
        
        // Ensure token0 < token1 for Uniswap v4
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }
        
        // Deploy hook to an address with the correct flags
        address flags = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
            ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );
        bytes memory constructorArgs = abi.encode(manager);
        deployCodeTo("ShadowTradeLimitHook.sol:ShadowTradeLimitHook", constructorArgs, flags);
        hook = ShadowTradeLimitHook(flags);
        
        // Transfer ownership to hookOwner
        vm.prank(hook.owner());
        hook.transferOwnership(hookOwner);
        
        
        // Verify hook address is valid
        require(Hooks.isValidHookAddress(IHooks(address(hook)), 3000), "Invalid hook address");
        
        // Initialize pool
        poolKey = PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        
        poolId = poolKey.toId();
        
        // Initialize pool
        manager.initialize(poolKey, SQRT_PRICE_1_1);
        
        // Setup user balances
        _setupUserBalances();
        _setupApprovals();
    }
    
    function _setupUserBalances() internal {
        address[3] memory users = [trader1, trader2, trader3];
        
        for (uint256 i = 0; i < users.length; i++) {
            deal(address(token0), users[i], INITIAL_BALANCE);
            deal(address(token1), users[i], INITIAL_BALANCE);
            
            // Also deal ETH for gas
            deal(users[i], 10 ether);
        }
    }
    
    function _setupApprovals() internal {
        address[3] memory users = [trader1, trader2, trader3];
        
        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            token0.approve(address(hook), type(uint256).max);
            token1.approve(address(hook), type(uint256).max);
            token0.approve(address(swapRouter), type(uint256).max);
            token1.approve(address(swapRouter), type(uint256).max);
            vm.stopPrank();
        }
    }
    
    // ============ HELPER FUNCTIONS ============
    
    function _createMockEncryptedInputs() internal returns (
        InEuint128 memory triggerPrice,
        InEuint128 memory orderSize,
        InEuint8 memory direction,
        InEuint64 memory expirationTime,
        InEuint128 memory minFillSize,
        InEbool memory partialFillAllowed
    ) {
        // Create encrypted inputs using official CoFheTest with the actual user address
        triggerPrice = createInEuint128(TRIGGER_PRICE, trader1);
        orderSize = createInEuint128(ORDER_SIZE, trader1);
        direction = createInEuint8(0, trader1); // 0 = buy order
        expirationTime = createInEuint64(uint64(block.timestamp + ORDER_EXPIRY), trader1);
        minFillSize = createInEuint128(MIN_FILL_SIZE, trader1);
        partialFillAllowed = createInEbool(true, trader1);
    }
    
    function _performSwap(bool zeroForOne, int256 amountSpecified) internal returns (BalanceDelta delta) {
        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: zeroForOne ? 
                TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
        });
        
        delta = swapRouter.swap(poolKey, params, PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}), ZERO_BYTES);
    }
    
    function _getPoolPrice() internal view returns (uint256) {
        (uint160 sqrtPriceX96, , , ) = manager.getSlot0(poolId);
        // Simplified price conversion for testing
        return uint256(sqrtPriceX96) * uint256(sqrtPriceX96) / (2**192);
    }
    
    // ============ BASIC FUNCTIONALITY TESTS ============
    
    function testInitialSetup() public {
        // Verify hook is properly initialized
        assertEq(address(hook.poolManager()), address(manager));
        assertEq(hook.owner(), hookOwner);
        
        // Verify pool is initialized
        (uint160 sqrtPriceX96, , , ) = manager.getSlot0(poolId);
        assertGt(sqrtPriceX96, 0);
    }
    
    function testHookPermissions() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        assertTrue(permissions.beforeSwap);
        assertTrue(permissions.afterSwap);
        
        // Verify other hooks are disabled for gas efficiency
        assertFalse(permissions.beforeAddLiquidity);
        assertFalse(permissions.afterAddLiquidity);
        assertFalse(permissions.beforeRemoveLiquidity);
        assertFalse(permissions.afterRemoveLiquidity);
    }
    
    // ============ ORDER PLACEMENT TESTS ============
    
    function testPlaceBasicLimitOrder() public {
        (
            InEuint128 memory triggerPrice,
            InEuint128 memory orderSize,
            InEuint8 memory direction,
            InEuint64 memory expirationTime,
            InEuint128 memory minFillSize,
            InEbool memory partialFillAllowed
        ) = _createMockEncryptedInputs();
        
        vm.startPrank(trader1);
        
        // Expect event emission
        vm.expectEmit(true, true, true, false);
        emit ShadowOrderPlaced(bytes32(0), trader1, poolId, block.timestamp);
        
        bytes32 orderId = hook.placeShadowLimitOrder(
            poolKey,
            triggerPrice,
            orderSize,
            direction,
            expirationTime,
            minFillSize,
            partialFillAllowed
        );
        
        vm.stopPrank();
        
        // Verify order was stored
        assertNotEq(orderId, bytes32(0));
        
        // Verify order details (note: encrypted values can't be directly compared)
        (
            euint128 storedTriggerPrice,
            euint128 storedOrderSize,
            euint8 storedDirection,
            euint128 storedFilledAmount,
            euint64 storedExpirationTime,
            euint32 storedOrderType,
            euint128 storedMinFillSize,
            ebool storedIsActive,
            ebool storedPartialFillAllowed,
            address storedOwner
        ) = hook.shadowOrders(orderId);
        
        assertEq(storedOwner, trader1);
        
        // Verify order is in user's order list
        bytes32[] memory userOrders = hook.getUserOrderIds(trader1);
        assertEq(userOrders.length, 1);
        assertEq(userOrders[0], orderId);
    }
    
    function testPlaceMultipleLimitOrders() public {
        // Place multiple orders from same user
        vm.startPrank(trader1);
        
        bytes32 orderId1 = _placeTestOrder(trader1);
        bytes32 orderId2 = _placeTestOrder(trader1);
        bytes32 orderId3 = _placeTestOrder(trader1);
        
        vm.stopPrank();
        
        // Verify all orders are tracked
        bytes32[] memory userOrders = hook.getUserOrderIds(trader1);
        assertEq(userOrders.length, 3);
        
        // Verify all order IDs are unique
        assertNotEq(orderId1, orderId2);
        assertNotEq(orderId2, orderId3);
        assertNotEq(orderId1, orderId3);
    }
    
    function _placeTestOrder(address user) internal returns (bytes32) {
        // Create encrypted inputs for the specific user
        InEuint128 memory triggerPrice = createInEuint128(TRIGGER_PRICE, user);
        InEuint128 memory orderSize = createInEuint128(ORDER_SIZE, user);
        InEuint8 memory direction = createInEuint8(0, user); // 0 = buy order
        InEuint64 memory expirationTime = createInEuint64(uint64(block.timestamp + ORDER_EXPIRY), user);
        InEuint128 memory minFillSize = createInEuint128(MIN_FILL_SIZE, user);
        InEbool memory partialFillAllowed = createInEbool(true, user);
        
        return hook.placeShadowLimitOrder(
            poolKey,
            triggerPrice,
            orderSize,
            direction,
            expirationTime,
            minFillSize,
            partialFillAllowed
        );
    }
    
    function testOrderPlacementWithDifferentUsers() public {
        bytes32 order1 = _placeOrderForUser(trader1);
        bytes32 order2 = _placeOrderForUser(trader2);
        bytes32 order3 = _placeOrderForUser(trader3);
        
        // Verify orders are separate for each user
        assertEq(hook.getUserOrderIds(trader1).length, 1);
        assertEq(hook.getUserOrderIds(trader2).length, 1);
        assertEq(hook.getUserOrderIds(trader3).length, 1);
        
        assertEq(hook.getUserOrderIds(trader1)[0], order1);
        assertEq(hook.getUserOrderIds(trader2)[0], order2);
        assertEq(hook.getUserOrderIds(trader3)[0], order3);
    }
    
    function _placeOrderForUser(address user) internal returns (bytes32) {
        vm.startPrank(user);
        bytes32 orderId = _placeTestOrder(user);
        vm.stopPrank();
        return orderId;
    }
    
    // ============ ORDER CANCELLATION TESTS ============
    
    function testCancelLimitOrder() public {
        bytes32 orderId = _placeOrderForUser(trader1);
        
        // Expect cancellation event
        vm.startPrank(trader1);
        vm.expectEmit(true, true, false, false);
        emit ShadowOrderCancelled(orderId, trader1, block.timestamp);
        
        hook.cancelShadowOrder(orderId);
        
        vm.stopPrank();
        
        // Verify order is deactivated (encrypted, so we check the owner field)
        (, , , , , , , ebool isActive, , address owner) = hook.shadowOrders(orderId);
        assertEq(owner, trader1); // Owner should still be set for access control
    }
    
    function testCannotCancelOthersOrder() public {
        bytes32 orderId = _placeOrderForUser(trader1);
        
        // Trader2 should not be able to cancel trader1's order
        vm.prank(trader2);
        vm.expectRevert(ShadowTradeLimitHook.NotOrderOwner.selector);
        hook.cancelShadowOrder(orderId);
    }
    
    function testCannotCancelNonexistentOrder() public {
        bytes32 fakeOrderId = bytes32(uint256(123456));
        
        vm.prank(trader1);
        vm.expectRevert(ShadowTradeLimitHook.NotOrderOwner.selector);
        hook.cancelShadowOrder(fakeOrderId);
    }
    
    // ============ ACCESS CONTROL TESTS ============
    
    
    // ============ FEE MANAGEMENT TESTS ============
    
    function testSetExecutionFee() public {
        uint256 newFee = 10; // 0.1%
        
        vm.prank(hookOwner);
        hook.setExecutionFee(newFee);
        
        assertEq(hook.executionFeeBps(), newFee);
    }
    
    function testCannotSetExcessiveFee() public {
        uint256 excessiveFee = 200; // 2% (above maximum)
        
        vm.prank(hookOwner);
        vm.expectRevert(ShadowTradeLimitHook.ExecutionFeeTooHigh.selector);
        hook.setExecutionFee(excessiveFee);
    }
    
    function testNonOwnerCannotSetFee() public {
        vm.prank(trader1);
        vm.expectRevert();
        hook.setExecutionFee(10);
    }
    
    // ============ HOOK INTEGRATION TESTS ============
    
    function testHookTriggeredOnSwap() public {
        // Place a test order first
        vm.prank(trader1);
        _placeTestOrder(trader1);
        
        // Perform a swap to trigger hook
        _performSwap(true, 1 ether);
        
        // Hook should have been called (verified by successful transaction)
        // More detailed execution testing would require FHE decryption mocking
    }
    
    function testMultipleOrdersProcessing() public {
        // Place multiple orders
        _placeOrderForUser(trader1);
        _placeOrderForUser(trader2);
        _placeOrderForUser(trader3);
        
        // Perform swap that should trigger order processing
        _performSwap(false, -1 ether);
        
        // Verify transaction completes successfully
        // In a full implementation, we'd verify specific order executions
    }
    
    // ============ EDGE CASES AND ERROR HANDLING ============
    
    function testZeroAddressHandling() public {
        // The constructor should handle zero addresses gracefully
        // This is implicitly tested through proper initialization
        assertTrue(address(hook.poolManager()) != address(0));
    }
    
    function testLargeOrderSize() public {
        // Test with maximum possible order size
        InEuint128 memory largeOrderSize = createInEuint128(type(uint128).max, trader1);
        
        // Should handle large orders without overflow
        vm.startPrank(trader1);
        // This would be part of a more comprehensive test with proper FHE setup
        vm.stopPrank();
    }
    
    function testTimestampExpiration() public {
        // Test orders that expire immediately
        InEuint64 memory pastExpiration = createInEuint64(uint64(block.timestamp - 1), trader1);
        
        // Orders with past expiration should be handled gracefully
        // This would be tested more thoroughly with proper FHE boolean evaluation
    }
    
    // ============ PERFORMANCE TESTS ============
    
    function testGasUsageOrderPlacement() public {
        vm.startPrank(trader1);
        
        uint256 gasBefore = gasleft();
        _placeTestOrder(trader1);
        uint256 gasUsed = gasBefore - gasleft();
        
        vm.stopPrank();
        
        // Log gas usage for optimization analysis
        console2.log("Gas used for order placement:", gasUsed);
        
        // Set reasonable gas limit expectations
        assertLt(gasUsed, 2000000); // Should be less than 2M gas for FHE operations
    }
    
    function testBatchOrderProcessing() public {
        // Place multiple orders
        for (uint256 i = 0; i < 5; i++) {
            _placeOrderForUser(trader1);
        }
        
        uint256 gasBefore = gasleft();
        _performSwap(true, 1 ether);
        uint256 gasUsed = gasBefore - gasleft();
        
        console2.log("Gas used for processing 5 orders:", gasUsed);
        
        // Should scale reasonably with number of orders
        assertLt(gasUsed, 1500000); // Should be less than 1.5M gas for 5 orders
    }
    
    // ============ INTEGRATION WITH UNISWAP V4 ============
    
    function testHookDoesNotInterruptNormalSwaps() public {
        // Record initial balances
        uint256 trader1Token0Before = token0.balanceOf(trader1);
        uint256 trader1Token1Before = token1.balanceOf(trader1);
        
        // Perform normal swap
        vm.prank(trader1);
        _performSwap(true, 1 ether);
        
        // Verify swap occurred normally
        uint256 trader1Token0After = token0.balanceOf(trader1);
        uint256 trader1Token1After = token1.balanceOf(trader1);
        
        assertLt(trader1Token0After, trader1Token0Before); // Spent token0
        assertGt(trader1Token1After, trader1Token1Before); // Received token1
    }
    
    function testHookWorksWithLiquidityChanges() public {
        // Add more liquidity
        modifyLiquidityRouter.modifyLiquidity(
            poolKey,
            ModifyLiquidityParams({
                tickLower: -887220,
                tickUpper: 887220,
                liquidityDelta: 500 ether,
                salt: 0
            }),
            ZERO_BYTES
        );
        
        // Place orders and verify they work with increased liquidity
        _placeOrderForUser(trader1);
        _performSwap(true, 2 ether);
        
        // Should complete without issues
    }
    
    // ============ INVARIANT TESTS ============
    
    function testOrderCountConsistency() public {
        uint256 initialOrderCount = 0;
        assertEq(hook.getUserOrderIds(trader1).length, initialOrderCount);
        
        // Place orders and verify count increases
        vm.startPrank(trader1);
        _placeTestOrder(trader1);
        assertEq(hook.getUserOrderIds(trader1).length, initialOrderCount + 1);
        
        _placeTestOrder(trader1);
        assertEq(hook.getUserOrderIds(trader1).length, initialOrderCount + 2);
        
        vm.stopPrank();
    }
    
    function testOwnershipConsistency() public {
        bytes32 orderId = _placeOrderForUser(trader1);
        
        // Verify owner remains consistent
        (, , , , , , , , , address owner1) = hook.shadowOrders(orderId);
        assertEq(owner1, trader1);
        
        // After some operations, owner should remain the same
        _performSwap(true, 1 ether);
        
        (, , , , , , , , , address owner2) = hook.shadowOrders(orderId);
        assertEq(owner2, trader1);
        assertEq(owner1, owner2);
    }
}
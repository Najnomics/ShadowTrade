# ShadowTrade API Reference

Complete API documentation for ShadowTrade contracts.

## ShadowTradeLimitHook

Main hook contract for private limit orders on Uniswap v4.

### Core Functions

#### Order Management

```solidity
function placeLimitOrder(
    PoolId poolId,
    InEuint128 memory triggerPrice,
    InEuint128 memory orderSize,
    InEuint8 memory direction,
    InEuint64 memory expiration
) external returns (bytes32 orderId)
```

**Parameters:**
- `poolId`: Uniswap v4 pool identifier
- `triggerPrice`: Encrypted price at which order executes
- `orderSize`: Encrypted size of the order
- `direction`: Encrypted direction (0 = sell, 1 = buy)
- `expiration`: Encrypted expiration timestamp

**Returns:**
- `orderId`: Unique identifier for the order

#### Order Cancellation

```solidity
function cancelLimitOrder(bytes32 orderId) external
```

**Parameters:**
- `orderId`: Order identifier to cancel

**Requirements:**
- Only order owner can cancel
- Order must be active

#### Emergency Functions

```solidity
function emergencyCancelOrder(bytes32 orderId) external
function pause() external
function unpause() external
```

**Access Control:**
- Only contract owner can call emergency functions

### View Functions

#### Order Information

```solidity
function getShadowOrder(bytes32 orderId) external view returns (ShadowOrder memory)
function getUserOrderIds(address user) external view returns (bytes32[] memory)
function isOrderActive(bytes32 orderId) external view returns (bool)
```

#### System Information

```solidity
function getExecutionFee() external view returns (uint256)
function getTotalOrders() external view returns (uint256)
function getOrderCount(address user) external view returns (uint256)
```

### Events

```solidity
event LimitOrderPlaced(
    bytes32 indexed orderId,
    address indexed user,
    PoolId indexed poolId,
    InEuint128 triggerPrice,
    InEuint128 orderSize,
    InEuint8 direction,
    InEuint64 expiration
);

event LimitOrderCancelled(
    bytes32 indexed orderId,
    address indexed user
);

event OrderExecuted(
    bytes32 indexed orderId,
    address indexed user,
    uint256 fillAmount,
    uint256 executionPrice
);
```

## HybridFHERC20

FHE-enabled ERC20 token with encrypted operations.

### Core Functions

#### Standard ERC20

```solidity
function mint(address to, uint256 amount) external
function burn(address from, uint256 amount) external
function transfer(address to, uint256 amount) external returns (bool)
function approve(address spender, uint256 amount) external returns (bool)
```

#### Encrypted Operations

```solidity
function mintEncrypted(address user, InEuint128 memory amount) external
function burnEncrypted(address user, InEuint128 memory amount) external
function transferFromEncrypted(
    address from,
    address to,
    InEuint128 memory amount
) external returns (euint128)
```

#### Balance Management

```solidity
function decryptBalance(address user) external
function getDecryptBalanceResult(address user) external view returns (uint128)
function getDecryptBalanceResultSafe(address user) external view returns (uint128, bool)
```

#### Wrap/Unwrap

```solidity
function wrap(address user, uint128 amount) external
function requestUnwrap(address user, InEuint128 memory amount) external returns (euint128)
function getUnwrapResult(address user, euint128 burnAmount) external returns (uint128)
```

### Events

```solidity
event EncryptedMint(address indexed user, InEuint128 amount);
event EncryptedBurn(address indexed user, InEuint128 amount);
event EncryptedTransfer(
    address indexed from,
    address indexed to,
    InEuint128 amount
);
```

## Library Contracts

### OrderLibrary

Utility functions for order processing.

```solidity
function validateOrderExecution(
    InEuint128 memory triggerPrice,
    InEuint128 memory currentPrice,
    InEuint8 memory direction,
    InEuint64 memory expiration
) external pure returns (ebool);

function calculateOptimalFill(
    InEuint128 memory orderSize,
    InEuint128 memory availableLiquidity,
    InEuint128 memory maxSlippage
) external pure returns (euint128);
```

### FHEPermissions

Access control for FHE operations.

```solidity
function hasFHEPermission(address user) external view returns (bool);
function grantFHEPermission(address user) external;
function revokeFHEPermission(address user) external;
```

### EncryptedOrderBook

Order book management with encrypted data.

```solidity
function addOrder(bytes32 orderId, ShadowOrder memory order) external;
function removeOrder(bytes32 orderId) external;
function getOrder(bytes32 orderId) external view returns (ShadowOrder memory);
```

## Error Codes

### ShadowTradeLimitHook Errors

- `OrderNotFound()`: Order does not exist
- `OrderNotActive()`: Order is not active
- `NotOrderOwner()`: Caller is not order owner
- `NotManager()`: Caller is not pool manager
- `ExcessiveFee()`: Fee exceeds maximum allowed
- `OrderExpired()`: Order has expired
- `InvalidOrderParameters()`: Order parameters are invalid

### HybridFHERC20 Errors

- `InsufficientBalance()`: Insufficient balance for operation
- `InvalidAddress()`: Invalid address provided
- `TransferFailed()`: Transfer operation failed
- `DecryptionFailed()`: Balance decryption failed

## Usage Examples

### Placing a Private Limit Order

```solidity
// Create encrypted order parameters
InEuint128 memory triggerPrice = createInEuint128(1000e18, user);
InEuint128 memory orderSize = createInEuint128(100e18, user);
InEuint8 memory direction = createInEuint8(1, user); // 1 = buy
InEuint64 memory expiration = createInEuint64(block.timestamp + 86400, user);

// Place the order
bytes32 orderId = hook.placeLimitOrder(
    poolId,
    triggerPrice,
    orderSize,
    direction,
    expiration
);
```

### Checking Order Status

```solidity
// Get order information
ShadowOrder memory order = hook.getShadowOrder(orderId);

// Check if order is active
bool isActive = hook.isOrderActive(orderId);

// Get user's orders
bytes32[] memory userOrders = hook.getUserOrderIds(user);
```

### Encrypted Token Operations

```solidity
// Mint encrypted tokens
InEuint128 memory amount = createInEuint128(1000e18, user);
token.mintEncrypted(user, amount);

// Transfer encrypted tokens
InEuint128 memory transferAmount = createInEuint128(100e18, user);
token.transferFromEncrypted(from, to, transferAmount);

// Decrypt balance
token.decryptBalance(user);
uint128 balance = token.getDecryptBalanceResult(user);
```

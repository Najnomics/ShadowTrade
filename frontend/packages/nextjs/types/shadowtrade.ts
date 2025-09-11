/**
 * ShadowTrade TypeScript Types
 * Defines the core types for FHE-enabled private limit orders
 */

import { Address } from "viem";

// FHE Encrypted Types (represents encrypted data on-chain)
export interface EncryptedOrder {
  encryptedTriggerPrice: bigint; // euint128
  encryptedOrderSize: bigint;    // euint128
  encryptedDirection: bigint;    // euint8 (0=buy, 1=sell)
  encryptedExpirationTime: bigint; // euint64
  encryptedMinFillSize: bigint;  // euint128
  encryptedPartialFillAllowed: bigint; // ebool
  encryptedIsActive: bigint;     // ebool
}

// Client-side decrypted order data
export interface DecryptedOrder {
  triggerPrice: bigint;
  orderSize: bigint;
  direction: OrderDirection;
  expirationTime: bigint;
  minFillSize: bigint;
  partialFillAllowed: boolean;
  isActive: boolean;
}

// Order status and metadata
export interface OrderInfo {
  orderId: string;
  owner: Address;
  poolId: string;
  currency0: Address;
  currency1: Address;
  createdAt: bigint;
  lastUpdated: bigint;
  status: OrderStatus;
  
  // Fill information
  totalFilled: bigint;
  remainingSize: bigint;
  averageExecutionPrice: bigint;
  fillCount: number;
  
  // Encrypted order parameters
  encrypted: EncryptedOrder;
  
  // Decrypted parameters (only available to order owner)
  decrypted?: DecryptedOrder;
}

// Order execution fill event
export interface OrderFill {
  orderId: string;
  fillAmount: bigint;
  executionPrice: bigint;
  timestamp: bigint;
  transactionHash: string;
  gasUsed: bigint;
}

// Enums
export enum OrderDirection {
  BUY = 0,
  SELL = 1
}

export enum OrderStatus {
  ACTIVE = "active",
  PARTIALLY_FILLED = "partially_filled", 
  COMPLETED = "completed",
  EXPIRED = "expired",
  CANCELLED = "cancelled"
}

// Form input types for creating orders
export interface OrderFormData {
  triggerPrice: string;
  orderSize: string;
  direction: OrderDirection;
  expirationHours: number;
  minFillSize: string;
  partialFillAllowed: boolean;
  slippageTolerance: number;
}

// FHE encryption inputs (for contract interaction)
export interface EncryptedOrderInputs {
  triggerPrice: {
    data: Uint8Array;
    utype: number;
  };
  orderSize: {
    data: Uint8Array;
    utype: number;
  };
  direction: {
    data: Uint8Array;
    utype: number;
  };
  expirationTime: {
    data: Uint8Array;
    utype: number;
  };
  minFillSize: {
    data: Uint8Array;
    utype: number;
  };
  partialFillAllowed: {
    data: Uint8Array;
    utype: number;
  };
}

// Trading pair information
export interface TradingPair {
  name: string;
  currency0: Address;
  currency1: Address;
  currency0Symbol: string;
  currency1Symbol: string;
  currency0Decimals: number;
  currency1Decimals: number;
  poolId: string;
  currentPrice?: bigint;
  priceChange24h?: number;
  volume24h?: bigint;
}

// Portfolio tracking
export interface PortfolioData {
  totalValue: bigint;
  totalPnL: bigint;
  totalPnLPercentage: number;
  activeOrders: number;
  completedOrders: number;
  totalTradingVolume: bigint;
  positions: TokenPosition[];
}

export interface TokenPosition {
  token: Address;
  symbol: string;
  decimals: number;
  balance: bigint;
  value: bigint;
  pnl: bigint;
  pnlPercentage: number;
}

// Hook return types
export interface UseOrdersReturn {
  orders: OrderInfo[];
  activeOrders: OrderInfo[];
  completedOrders: OrderInfo[];
  loading: boolean;
  error: string | null;
  refetch: () => Promise<void>;
}

export interface UsePlaceOrderReturn {
  placeOrder: (orderData: OrderFormData, tradingPair: TradingPair) => Promise<string>;
  isLoading: boolean;
  error: string | null;
  reset: () => void;
}

export interface UseCancelOrderReturn {
  cancelOrder: (orderId: string) => Promise<void>;
  isLoading: boolean;
  error: string | null;
}

// Market data types
export interface PriceData {
  timestamp: number;
  price: number;
  volume: number;
}

export interface MarketStats {
  currentPrice: bigint;
  priceChange24h: number;
  high24h: bigint;
  low24h: bigint;
  volume24h: bigint;
  marketCap?: bigint;
}

// Configuration
export interface ShadowTradeConfig {
  hookAddress: Address;
  supportedPairs: TradingPair[];
  maxOrderDuration: number; // in seconds
  minOrderSize: bigint;
  executionFee: bigint;
  emergencyPaused: boolean;
}

// Event types for real-time monitoring
export interface ShadowTradeEvent {
  type: 'ORDER_PLACED' | 'ORDER_FILLED' | 'ORDER_CANCELLED' | 'ORDER_EXPIRED';
  orderId: string;
  data: any;
  timestamp: number;
  blockNumber: bigint;
  transactionHash: string;
}

// Notification types
export interface NotificationData {
  id: string;
  type: 'success' | 'error' | 'warning' | 'info';
  title: string;
  message: string;
  timestamp: number;
  read: boolean;
  actionUrl?: string;
}

// FHE Permission management
export interface FHEPermission {
  user: Address;
  contract: Address;
  dataType: 'euint8' | 'euint32' | 'euint64' | 'euint128' | 'ebool';
  allowed: boolean;
  grantedAt: bigint;
}

export interface FHEPermissionRequest {
  address: Address;
  signature: string;
  publicKey: string;
  timestamp: number;
}
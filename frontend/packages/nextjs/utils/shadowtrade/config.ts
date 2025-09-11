/**
 * ShadowTrade Configuration
 * Central configuration for the ShadowTrade application
 */

import { Address } from "viem";
import { TradingPair, ShadowTradeConfig } from "~~/types/shadowtrade";

// Contract addresses (will be updated after deployment)
export const SHADOWTRADE_ADDRESSES = {
  // Local/Development
  localhost: {
    hookAddress: "0x0000000000000000000000000000000000000000" as Address,
    poolManager: "0x0000000000000000000000000000000000000000" as Address,
  },
  // Fhenix Testnet
  fhenix: {
    hookAddress: "0x0000000000000000000000000000000000000000" as Address,
    poolManager: "0x0000000000000000000000000000000000000000" as Address,
  },
  // Ethereum Mainnet (future)
  mainnet: {
    hookAddress: "0x0000000000000000000000000000000000000000" as Address,
    poolManager: "0x0000000000000000000000000000000000000000" as Address,
  }
} as const;

// Common token addresses
export const TOKEN_ADDRESSES = {
  localhost: {
    WETH: "0x0000000000000000000000000000000000000000" as Address,
    USDC: "0x0000000000000000000000000000000000000000" as Address,
    WBTC: "0x0000000000000000000000000000000000000000" as Address,
    DAI: "0x0000000000000000000000000000000000000000" as Address,
  },
  fhenix: {
    WETH: "0x0000000000000000000000000000000000000000" as Address,
    USDC: "0x0000000000000000000000000000000000000000" as Address,
    WBTC: "0x0000000000000000000000000000000000000000" as Address,
    DAI: "0x0000000000000000000000000000000000000000" as Address,
  },
  mainnet: {
    WETH: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2" as Address,
    USDC: "0xA0b86a33E6417Af9Ce3ee3b4e3b12FaD21dd0a04" as Address,
    WBTC: "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599" as Address,
    DAI: "0x6B175474E89094C44Da98b954EedeAC495271d0F" as Address,
  }
} as const;

// Supported trading pairs
export const createTradingPairs = (network: keyof typeof TOKEN_ADDRESSES): TradingPair[] => {
  const tokens = TOKEN_ADDRESSES[network];
  
  return [
    {
      name: "ETH/USDC",
      currency0: tokens.WETH,
      currency1: tokens.USDC,
      currency0Symbol: "ETH",
      currency1Symbol: "USDC",
      currency0Decimals: 18,
      currency1Decimals: 6,
      poolId: "0x0000000000000000000000000000000000000000000000000000000000000000",
    },
    {
      name: "WBTC/USDC",
      currency0: tokens.WBTC,
      currency1: tokens.USDC,
      currency0Symbol: "WBTC",
      currency1Symbol: "USDC",
      currency0Decimals: 8,
      currency1Decimals: 6,
      poolId: "0x0000000000000000000000000000000000000000000000000000000000000000",
    },
    {
      name: "ETH/DAI",
      currency0: tokens.WETH,
      currency1: tokens.DAI,
      currency0Symbol: "ETH",
      currency1Symbol: "DAI",
      currency0Decimals: 18,
      currency1Decimals: 18,
      poolId: "0x0000000000000000000000000000000000000000000000000000000000000000",
    }
  ];
};

// Application configuration
export const SHADOWTRADE_CONFIG: Record<string, ShadowTradeConfig> = {
  localhost: {
    hookAddress: SHADOWTRADE_ADDRESSES.localhost.hookAddress,
    supportedPairs: createTradingPairs("localhost"),
    maxOrderDuration: 7 * 24 * 60 * 60, // 7 days in seconds
    minOrderSize: BigInt("1000000000000000"), // 0.001 ETH
    executionFee: BigInt("100000000000000"), // 0.0001 ETH
    emergencyPaused: false,
  },
  fhenix: {
    hookAddress: SHADOWTRADE_ADDRESSES.fhenix.hookAddress,
    supportedPairs: createTradingPairs("fhenix"),
    maxOrderDuration: 7 * 24 * 60 * 60, // 7 days in seconds
    minOrderSize: BigInt("1000000000000000"), // 0.001 ETH
    executionFee: BigInt("100000000000000"), // 0.0001 ETH
    emergencyPaused: false,
  },
  mainnet: {
    hookAddress: SHADOWTRADE_ADDRESSES.mainnet.hookAddress,
    supportedPairs: createTradingPairs("mainnet"),
    maxOrderDuration: 30 * 24 * 60 * 60, // 30 days in seconds
    minOrderSize: BigInt("10000000000000000"), // 0.01 ETH
    executionFee: BigInt("1000000000000000"), // 0.001 ETH
    emergencyPaused: false,
  }
};

// Default trading configuration
export const DEFAULT_TRADING_CONFIG = {
  slippageTolerance: 0.5, // 0.5%
  minOrderDurationMinutes: 5,
  maxOrderDurationDays: 30,
  defaultExpirationHours: 24,
  priceUpdateIntervalMs: 5000, // 5 seconds
  orderRefreshIntervalMs: 10000, // 10 seconds
};

// FHE configuration
export const FHE_CONFIG = {
  keySize: 4096,
  cipherTextSize: 512,
  maxPlaintextValue: BigInt("340282366920938463463374607431768211455"), // 2^128 - 1
  defaultGasLimit: 5000000,
};

// UI configuration
export const UI_CONFIG = {
  theme: {
    primary: "#6366F1", // Indigo
    secondary: "#8B5CF6", // Violet
    accent: "#06B6D4", // Cyan
    neutral: "#374151", // Gray-700
    base: "#F9FAFB", // Gray-50
    info: "#3B82F6", // Blue
    success: "#10B981", // Emerald
    warning: "#F59E0B", // Amber
    error: "#EF4444", // Red
  },
  animations: {
    duration: {
      fast: "150ms",
      normal: "300ms",
      slow: "500ms",
    },
    easing: {
      linear: "linear",
      ease: "ease",
      easeIn: "ease-in",
      easeOut: "ease-out",
      easeInOut: "ease-in-out",
    },
  },
  breakpoints: {
    sm: "640px",
    md: "768px",
    lg: "1024px",
    xl: "1280px",
    "2xl": "1536px",
  },
};

// Error messages
export const ERROR_MESSAGES = {
  INSUFFICIENT_BALANCE: "Insufficient balance for this order",
  INVALID_PRICE: "Invalid price: must be greater than 0",
  INVALID_SIZE: "Invalid order size: must be greater than minimum",
  ORDER_EXPIRED: "Order has expired",
  ORDER_NOT_FOUND: "Order not found",
  UNAUTHORIZED: "Unauthorized: you don't own this order",
  FHE_ENCRYPTION_FAILED: "Failed to encrypt order parameters",
  FHE_DECRYPTION_FAILED: "Failed to decrypt order data",
  TRANSACTION_FAILED: "Transaction failed",
  NETWORK_ERROR: "Network error: please try again",
  HOOK_PAUSED: "ShadowTrade is currently paused for maintenance",
};

// Success messages
export const SUCCESS_MESSAGES = {
  ORDER_PLACED: "Order placed successfully!",
  ORDER_CANCELLED: "Order cancelled successfully!",
  ORDER_FILLED: "Your order has been filled!",
  SETTINGS_SAVED: "Settings saved successfully!",
};

// Notification settings
export const NOTIFICATION_CONFIG = {
  defaultDuration: 5000, // 5 seconds
  position: "top-right" as const,
  maxNotifications: 5,
  enablePush: false, // Enable when implementing push notifications
};

// Chart configuration
export const CHART_CONFIG = {
  defaultTimeframe: "1H" as const,
  availableTimeframes: ["1M", "5M", "15M", "1H", "4H", "1D"] as const,
  priceChartHeight: 400,
  volumeChartHeight: 100,
  candleColors: {
    up: "#10B981", // Green
    down: "#EF4444", // Red
    wick: "#6B7280", // Gray
  },
  volumeColor: "#8B5CF6", // Purple
  gridColor: "#E5E7EB", // Gray-200
};

// Local storage keys
export const STORAGE_KEYS = {
  THEME: "shadowtrade_theme",
  SETTINGS: "shadowtrade_settings",
  TRADING_PAIRS: "shadowtrade_trading_pairs",
  FHE_PERMISSIONS: "shadowtrade_fhe_permissions",
  NOTIFICATION_PREFERENCES: "shadowtrade_notifications",
  CHART_PREFERENCES: "shadowtrade_charts",
} as const;

/**
 * Get configuration for current network
 */
export const getCurrentConfig = (chainId: number): ShadowTradeConfig => {
  // Map chain IDs to network names
  const networkMap: Record<number, string> = {
    31337: "localhost", // Hardhat
    8008135: "fhenix",  // Fhenix testnet
    1: "mainnet",       // Ethereum mainnet
  };
  
  const networkName = networkMap[chainId] || "localhost";
  return SHADOWTRADE_CONFIG[networkName];
};

/**
 * Check if a network is supported
 */
export const isSupportedNetwork = (chainId: number): boolean => {
  return chainId in [31337, 8008135, 1];
};

/**
 * Format price for display
 */
export const formatPrice = (price: bigint, decimals: number = 18): string => {
  const divisor = BigInt(10 ** decimals);
  const wholePart = price / divisor;
  const fractionalPart = price % divisor;
  
  if (fractionalPart === 0n) {
    return wholePart.toString();
  }
  
  const fractionalStr = fractionalPart.toString().padStart(decimals, "0");
  const trimmed = fractionalStr.replace(/0+$/, "");
  
  if (trimmed === "") {
    return wholePart.toString();
  }
  
  return `${wholePart}.${trimmed}`;
};

/**
 * Parse price from string to bigint
 */
export const parsePrice = (priceStr: string, decimals: number = 18): bigint => {
  const [wholePart, fractionalPart = ""] = priceStr.split(".");
  const paddedFractional = fractionalPart.padEnd(decimals, "0").slice(0, decimals);
  return BigInt(wholePart + paddedFractional);
};
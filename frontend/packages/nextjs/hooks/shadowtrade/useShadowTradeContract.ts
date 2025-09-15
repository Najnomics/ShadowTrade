/**
 * useShadowTradeContract Hook
 * 
 * Central hook for interacting with the ShadowTrade limit order contract
 * Handles order placement, cancellation, and status queries
 */

import { useCallback, useState, useEffect } from "react";
import { useAccount, usePublicClient, useWalletClient } from "wagmi";
import { Address, encodeFunctionData, decodeFunctionResult, parseAbi } from "viem";
import { OrderFormData, TradingPair, OrderInfo, UsePlaceOrderReturn, UseCancelOrderReturn, OrderStatus } from "~~/types/shadowtrade";
import { useEncryptOrderParams } from "./useEncryptOrderParams";
import { getCurrentConfig, ERROR_MESSAGES, SUCCESS_MESSAGES } from "~~/utils/shadowtrade/config";
import { notification } from "~~/utils/scaffold-eth";

// ShadowTrade Contract ABI (simplified for key functions)
const SHADOWTRADE_ABI = parseAbi([
  // Order placement - using bytes arrays for FHE encrypted data
  "function placeShadowLimitOrder(bytes triggerPrice, bytes orderSize, bytes direction, bytes expirationTime, bytes minFillSize, bytes partialFillAllowed, address currency0, address currency1) external payable returns (bytes32)",
  
  // Order management
  "function cancelShadowOrder(bytes32 orderId) external",
  "function emergencyCancelOrder(bytes32 orderId) external", // Owner only
  
  // Order queries
  "function getOrder(bytes32 orderId) external view returns ((uint256,uint256,uint256,uint256,uint256,uint256,uint256), address, bytes32, address, address, uint256, uint256)",
  "function getUserOrders(address user) external view returns (bytes32[])",
  "function getActiveOrders(bytes32 poolId) external view returns (bytes32[])",
  
  // Order status
  "function isOrderActive(bytes32 orderId) external view returns (bool)",
  "function getOrderFillInfo(bytes32 orderId) external view returns (uint256, uint256, uint256, uint256)",
  
  // Configuration
  "function executionFeeBps() external view returns (uint256)",
  
  // Events
  "event ShadowOrderPlaced(bytes32 indexed orderId, address indexed user, bytes32 indexed poolId)",
  "event ShadowOrderFilled(bytes32 indexed orderId, uint256 fillAmount, uint256 executionPrice)",
  "event ShadowOrderCancelled(bytes32 indexed orderId, address indexed user)",
]);

export const useShadowTradeContract = () => {
  const { address, chainId } = useAccount();
  const publicClient = usePublicClient();
  const { data: walletClient } = useWalletClient();
  
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  
  const { encryptOrderParams } = useEncryptOrderParams();
  
  const config = getCurrentConfig(chainId || 31337);
  const hookAddress = config.hookAddress;

  const reset = useCallback(() => {
    setError(null);
    setIsLoading(false);
  }, []);

  // Place a new shadow limit order
  const usePlaceOrder = (): UsePlaceOrderReturn => {
    const placeOrder = useCallback(async (
      orderData: OrderFormData, 
      tradingPair: TradingPair
    ): Promise<string> => {
      if (!walletClient || !publicClient) {
        throw new Error("Wallet not connected");
      }

      if (!address) {
        throw new Error("No address available");
      }

      setIsLoading(true);
      setError(null);

      try {
        // Get execution fee
        const executionFee = await publicClient.readContract({
          address: hookAddress,
          abi: SHADOWTRADE_ABI,
          functionName: "executionFeeBps",
        }) as bigint;

        console.log("Execution fee:", executionFee.toString());

        // Encrypt order parameters
        const encryptedInputs = await encryptOrderParams(orderData, tradingPair);

        // Prepare transaction data
        const txData = {
          to: hookAddress,
          value: executionFee,
          data: encodeFunctionData({
            abi: SHADOWTRADE_ABI,
            functionName: "placeShadowLimitOrder",
            args: [
              `0x${Buffer.from(encryptedInputs.triggerPrice.data).toString('hex')}`,
              `0x${Buffer.from(encryptedInputs.orderSize.data).toString('hex')}`,
              `0x${Buffer.from(encryptedInputs.direction.data).toString('hex')}`,
              `0x${Buffer.from(encryptedInputs.expirationTime.data).toString('hex')}`,
              `0x${Buffer.from(encryptedInputs.minFillSize.data).toString('hex')}`,
              `0x${Buffer.from(encryptedInputs.partialFillAllowed.data).toString('hex')}`,
              tradingPair.currency0,
              tradingPair.currency1,
            ],
          }),
        };

        console.log("Sending transaction:", txData);

        // Send transaction
        const txHash = await walletClient.sendTransaction(txData);
        
        console.log("Transaction sent:", txHash);

        // Wait for confirmation
        const receipt = await publicClient.waitForTransactionReceipt({ 
          hash: txHash,
          confirmations: 1,
        });

        console.log("Transaction confirmed:", receipt);

        // Extract order ID from logs
        const placedEvent = receipt.logs.find(log => 
          log.address.toLowerCase() === hookAddress.toLowerCase() && 
          log.topics[0] === "0x..." // ShadowOrderPlaced event signature
        );

        let orderId = "unknown";
        if (placedEvent && placedEvent.topics[1]) {
          orderId = placedEvent.topics[1];
        }

        notification.success(SUCCESS_MESSAGES.ORDER_PLACED);
        return orderId;

      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : ERROR_MESSAGES.TRANSACTION_FAILED;
        setError(errorMessage);
        notification.error(errorMessage);
        throw err;
      } finally {
        setIsLoading(false);
      }
    }, [walletClient, publicClient, address, hookAddress, encryptOrderParams]);

    return { placeOrder, isLoading, error, reset };
  };

  // Cancel an existing order
  const useCancelOrder = (): UseCancelOrderReturn => {
    const cancelOrder = useCallback(async (orderId: string): Promise<void> => {
      if (!walletClient || !publicClient) {
        throw new Error("Wallet not connected");
      }

      setIsLoading(true);
      setError(null);

      try {
        // Verify order exists and is active
        const isActive = await publicClient.readContract({
          address: hookAddress,
          abi: SHADOWTRADE_ABI,
          functionName: "isOrderActive",
          args: [orderId as `0x${string}`],
        }) as boolean;

        if (!isActive) {
          throw new Error("Order is not active or does not exist");
        }

        // Send cancellation transaction
        const txHash = await walletClient.writeContract({
          address: hookAddress,
          abi: SHADOWTRADE_ABI,
          functionName: "cancelShadowOrder",
          args: [orderId as `0x${string}`],
        });

        console.log("Cancel transaction sent:", txHash);

        // Wait for confirmation
        await publicClient.waitForTransactionReceipt({ 
          hash: txHash,
          confirmations: 1,
        });

        notification.success(SUCCESS_MESSAGES.ORDER_CANCELLED);

      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : "Failed to cancel order";
        setError(errorMessage);
        notification.error(errorMessage);
        throw err;
      } finally {
        setIsLoading(false);
      }
    }, [walletClient, publicClient, hookAddress]);

    return { cancelOrder, isLoading, error };
  };

  // Get user's orders
  const getUserOrders = useCallback(async (userAddress?: Address): Promise<string[]> => {
    if (!publicClient) {
      throw new Error("Public client not available");
    }

    const queryAddress = userAddress || address;
    if (!queryAddress) {
      throw new Error("No address provided");
    }

    try {
      const orderIds = await publicClient.readContract({
        address: hookAddress,
        abi: SHADOWTRADE_ABI,
        functionName: "getUserOrders",
        args: [queryAddress],
      }) as string[];

      return orderIds;
    } catch (err) {
      console.error("Failed to get user orders:", err);
      return [];
    }
  }, [publicClient, address, hookAddress]);

  // Get order details
  const getOrderDetails = useCallback(async (orderId: string): Promise<OrderInfo | null> => {
    if (!publicClient) {
      throw new Error("Public client not available");
    }

    try {
      const [orderData, fillInfo] = await Promise.all([
        publicClient.readContract({
          address: hookAddress,
          abi: SHADOWTRADE_ABI,
          functionName: "getOrder",
          args: [orderId as `0x${string}`],
        }),
        publicClient.readContract({
          address: hookAddress,
          abi: SHADOWTRADE_ABI,
          functionName: "getOrderFillInfo",
          args: [orderId as `0x${string}`],
        }),
      ]);

      // Parse the returned data into OrderInfo structure
      // Note: This is a simplified version - actual implementation would need
      // proper type casting and error handling
      const [encryptedData, owner, poolId, currency0, currency1, createdAt, lastUpdated] = orderData as unknown as any[];
      const [totalFilled, remainingSize, averageExecutionPrice, fillCount] = fillInfo as unknown as any[];

      const orderInfo: OrderInfo = {
        orderId,
        owner: owner as Address,
        poolId,
        currency0: currency0 as Address,
        currency1: currency1 as Address,
        createdAt,
        lastUpdated,
        status: remainingSize === 0n ? OrderStatus.COMPLETED : totalFilled > 0n ? OrderStatus.PARTIALLY_FILLED : OrderStatus.ACTIVE,
        totalFilled,
        remainingSize,
        averageExecutionPrice,
        fillCount: Number(fillCount),
        encrypted: {
          encryptedTriggerPrice: encryptedData[0],
          encryptedOrderSize: encryptedData[1],
          encryptedDirection: encryptedData[2],
          encryptedExpirationTime: encryptedData[3],
          encryptedMinFillSize: encryptedData[4],
          encryptedPartialFillAllowed: encryptedData[5],
          encryptedIsActive: encryptedData[6],
        },
      };

      return orderInfo;
    } catch (err) {
      console.error("Failed to get order details:", err);
      return null;
    }
  }, [publicClient, hookAddress]);

  return {
    // Contract interaction hooks
    usePlaceOrder,
    useCancelOrder,
    
    // Query functions
    getUserOrders,
    getOrderDetails,
    
    // State
    isLoading,
    error,
    reset,
    
    // Configuration
    hookAddress,
    config,
  };
};
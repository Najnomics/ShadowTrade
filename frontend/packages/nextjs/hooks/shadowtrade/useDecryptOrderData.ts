/**
 * useDecryptOrderData Hook
 * 
 * Handles FHE decryption of order data for display to order owners
 * Only the order owner can decrypt their private order parameters
 */

import { useCallback, useState, useEffect } from "react";
import { useAccount } from "wagmi";
import { useCofhejs } from "~~/app/useCofhejs";
import { EncryptedOrder, DecryptedOrder, OrderInfo } from "~~/types/shadowtrade";
import { formatPrice, ERROR_MESSAGES } from "~~/utils/shadowtrade/config";
import { notification } from "~~/utils/scaffold-eth";

export interface UseDecryptOrderDataReturn {
  decryptOrderData: (orderInfo: OrderInfo) => Promise<DecryptedOrder | null>;
  decryptOrderField: <T extends keyof DecryptedOrder>(
    orderInfo: OrderInfo, 
    field: T
  ) => Promise<DecryptedOrder[T] | null>;
  isDecrypting: boolean;
  error: string | null;
  reset: () => void;
}

export const useDecryptOrderData = (): UseDecryptOrderDataReturn => {
  const [isDecrypting, setIsDecrypting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const { address } = useAccount();
  const { cofhe, isCofheReady } = useCofhejs();

  const decryptOrderData = useCallback(async (
    orderInfo: OrderInfo
  ): Promise<DecryptedOrder | null> => {
    if (!isCofheReady || !cofhe) {
      throw new Error("CoFHE client not ready");
    }

    if (!address) {
      throw new Error("Wallet not connected");
    }

    // Only the order owner can decrypt their order data
    if (orderInfo.owner.toLowerCase() !== address.toLowerCase()) {
      console.warn("Cannot decrypt order data: not the order owner");
      return null;
    }

    setIsDecrypting(true);
    setError(null);

    try {
      console.log("Decrypting order data for order:", orderInfo.orderId);

      const encrypted = orderInfo.encrypted;

      // Decrypt all order parameters in parallel
      const [
        triggerPrice,
        orderSize,
        direction,
        expirationTime,
        minFillSize,
        partialFillAllowed,
        isActive
      ] = await Promise.all([
        cofhe.decrypt128(encrypted.encryptedTriggerPrice),
        cofhe.decrypt128(encrypted.encryptedOrderSize),
        cofhe.decrypt8(encrypted.encryptedDirection),
        cofhe.decrypt64(encrypted.encryptedExpirationTime),
        cofhe.decrypt128(encrypted.encryptedMinFillSize),
        cofhe.decryptBool(encrypted.encryptedPartialFillAllowed),
        cofhe.decryptBool(encrypted.encryptedIsActive),
      ]);

      const decryptedOrder: DecryptedOrder = {
        triggerPrice,
        orderSize,
        direction: Number(direction), // Convert to OrderDirection enum
        expirationTime,
        minFillSize,
        partialFillAllowed,
        isActive,
      };

      console.log("Order data decrypted successfully:", {
        triggerPrice: triggerPrice.toString(),
        orderSize: orderSize.toString(),
        direction: direction.toString(),
        expirationTime: new Date(Number(expirationTime) * 1000).toISOString(),
        minFillSize: minFillSize.toString(),
        partialFillAllowed,
        isActive,
      });

      return decryptedOrder;

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : ERROR_MESSAGES.FHE_DECRYPTION_FAILED;
      setError(errorMessage);
      console.error("Failed to decrypt order data:", err);
      // Don't show notification for decryption errors as they may be expected
      return null;
    } finally {
      setIsDecrypting(false);
    }
  }, [cofhe, isCofheReady, address]);

  const decryptOrderField = useCallback(async <T extends keyof DecryptedOrder>(
    orderInfo: OrderInfo,
    field: T
  ): Promise<DecryptedOrder[T] | null> => {
    if (!isCofheReady || !cofhe) {
      throw new Error("CoFHE client not ready");
    }

    if (!address || orderInfo.owner.toLowerCase() !== address.toLowerCase()) {
      return null;
    }

    setIsDecrypting(true);
    setError(null);

    try {
      const encrypted = orderInfo.encrypted;
      let decryptedValue: any;

      switch (field) {
        case 'triggerPrice':
          decryptedValue = await cofhe.decrypt128(encrypted.encryptedTriggerPrice);
          break;
        case 'orderSize':
          decryptedValue = await cofhe.decrypt128(encrypted.encryptedOrderSize);
          break;
        case 'direction':
          decryptedValue = Number(await cofhe.decrypt8(encrypted.encryptedDirection));
          break;
        case 'expirationTime':
          decryptedValue = await cofhe.decrypt64(encrypted.encryptedExpirationTime);
          break;
        case 'minFillSize':
          decryptedValue = await cofhe.decrypt128(encrypted.encryptedMinFillSize);
          break;
        case 'partialFillAllowed':
          decryptedValue = await cofhe.decryptBool(encrypted.encryptedPartialFillAllowed);
          break;
        case 'isActive':
          decryptedValue = await cofhe.decryptBool(encrypted.encryptedIsActive);
          break;
        default:
          throw new Error(`Unknown field: ${field}`);
      }

      return decryptedValue as DecryptedOrder[T];

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : `Failed to decrypt ${field}`;
      setError(errorMessage);
      console.error(`Failed to decrypt ${field}:`, err);
      return null;
    } finally {
      setIsDecrypting(false);
    }
  }, [cofhe, isCofheReady, address]);

  const reset = useCallback(() => {
    setError(null);
    setIsDecrypting(false);
  }, []);

  // Clear error when address changes
  useEffect(() => {
    reset();
  }, [address, reset]);

  return {
    decryptOrderData,
    decryptOrderField,
    isDecrypting,
    error,
    reset,
  };
};
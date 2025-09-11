/**
 * useEncryptOrderParams Hook
 * 
 * Handles FHE encryption of order parameters before sending to blockchain
 * Uses cofhejs to encrypt sensitive order data (price, size, direction, etc.)
 */

import { useCallback, useState } from "react";
import { cofhejs } from "cofhejs/web";
import { useAccount } from "wagmi";
import { useCofhejs } from "~~/app/useCofhejs";
import { OrderFormData, EncryptedOrderInputs, TradingPair } from "~~/types/shadowtrade";
import { parsePrice, ERROR_MESSAGES } from "~~/utils/shadowtrade/config";
import { notification } from "~~/utils/scaffold-eth";

export interface UseEncryptOrderParamsReturn {
  encryptOrderParams: (orderData: OrderFormData, tradingPair: TradingPair) => Promise<EncryptedOrderInputs>;
  isEncrypting: boolean;
  error: string | null;
  reset: () => void;
}

export const useEncryptOrderParams = (): UseEncryptOrderParamsReturn => {
  const [isEncrypting, setIsEncrypting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const { address } = useAccount();
  const { cofhe, isCofheReady } = useCofhejs();

  const encryptOrderParams = useCallback(async (
    orderData: OrderFormData, 
    tradingPair: TradingPair
  ): Promise<EncryptedOrderInputs> => {
    if (!isCofheReady || !cofhe) {
      throw new Error("CoFHE client not ready");
    }

    if (!address) {
      throw new Error("Wallet not connected");
    }

    setIsEncrypting(true);
    setError(null);

    try {
      // Parse and validate order parameters
      const triggerPrice = parsePrice(orderData.triggerPrice, tradingPair.currency1Decimals);
      const orderSize = parsePrice(orderData.orderSize, tradingPair.currency0Decimals);
      const minFillSize = parsePrice(orderData.minFillSize, tradingPair.currency0Decimals);
      const expirationTime = BigInt(Math.floor(Date.now() / 1000) + (orderData.expirationHours * 3600));

      // Validate parameters
      if (triggerPrice <= 0n) {
        throw new Error(ERROR_MESSAGES.INVALID_PRICE);
      }
      
      if (orderSize <= 0n || orderSize < minFillSize) {
        throw new Error(ERROR_MESSAGES.INVALID_SIZE);
      }

      console.log("Encrypting order parameters:", {
        triggerPrice: triggerPrice.toString(),
        orderSize: orderSize.toString(),
        direction: orderData.direction,
        expirationTime: expirationTime.toString(),
        minFillSize: minFillSize.toString(),
        partialFillAllowed: orderData.partialFillAllowed,
      });

      // Encrypt each parameter using CoFHE
      const [
        encryptedTriggerPrice,
        encryptedOrderSize,
        encryptedDirection,
        encryptedExpirationTime,
        encryptedMinFillSize,
        encryptedPartialFillAllowed
      ] = await Promise.all([
        cofhe.encrypt128(triggerPrice),
        cofhe.encrypt128(orderSize),
        cofhe.encrypt8(BigInt(orderData.direction)),
        cofhe.encrypt64(expirationTime),
        cofhe.encrypt128(minFillSize),
        cofhe.encryptBool(orderData.partialFillAllowed),
      ]);

      const encryptedInputs: EncryptedOrderInputs = {
        triggerPrice: {
          data: encryptedTriggerPrice.data,
          utype: encryptedTriggerPrice.utype,
        },
        orderSize: {
          data: encryptedOrderSize.data,
          utype: encryptedOrderSize.utype,
        },
        direction: {
          data: encryptedDirection.data,
          utype: encryptedDirection.utype,
        },
        expirationTime: {
          data: encryptedExpirationTime.data,
          utype: encryptedExpirationTime.utype,
        },
        minFillSize: {
          data: encryptedMinFillSize.data,
          utype: encryptedMinFillSize.utype,
        },
        partialFillAllowed: {
          data: encryptedPartialFillAllowed.data,
          utype: encryptedPartialFillAllowed.utype,
        },
      };

      console.log("Order parameters encrypted successfully");
      return encryptedInputs;

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : ERROR_MESSAGES.FHE_ENCRYPTION_FAILED;
      setError(errorMessage);
      notification.error(errorMessage);
      throw err;
    } finally {
      setIsEncrypting(false);
    }
  }, [cofhe, isCofheReady, address]);

  const reset = useCallback(() => {
    setError(null);
    setIsEncrypting(false);
  }, []);

  return {
    encryptOrderParams,
    isEncrypting,
    error,
    reset,
  };
};
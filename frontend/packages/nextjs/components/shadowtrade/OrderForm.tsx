/**
 * OrderForm Component
 * 
 * Advanced form for creating private limit orders with FHE encryption
 * Features multi-step validation, real-time price updates, and responsive design
 */

"use client";

import { useState, useEffect, useCallback } from "react";
import { useForm, Controller } from "react-hook-form";
import { ArrowsRightLeftIcon, ClockIcon, ShieldCheckIcon, CogIcon } from "@heroicons/react/24/outline";
import { ArrowUpIcon, ArrowDownIcon } from "@heroicons/react/24/solid";
import { OrderFormData, OrderDirection, TradingPair } from "~~/types/shadowtrade";
import { useShadowTradeContract } from "~~/hooks/shadowtrade/useShadowTradeContract";
import { formatPrice, parsePrice, DEFAULT_TRADING_CONFIG } from "~~/utils/shadowtrade/config";
import { notification } from "~~/utils/scaffold-eth";

interface OrderFormProps {
  tradingPair: TradingPair;
  onOrderPlaced?: (orderId: string) => void;
  onClose?: () => void;
}

interface FormStep {
  id: number;
  title: string;
  description: string;
  isComplete: boolean;
}

export const OrderForm: React.FC<OrderFormProps> = ({ tradingPair, onOrderPlaced, onClose }) => {
  const [currentStep, setCurrentStep] = useState(1);
  const [showAdvanced, setShowAdvanced] = useState(false);
  
  const { usePlaceOrder } = useShadowTradeContract();
  const { placeOrder, isLoading, error, reset } = usePlaceOrder();
  
  const {
    control,
    handleSubmit,
    watch,
    setValue,
    formState: { errors, isValid },
    reset: resetForm,
  } = useForm<OrderFormData>({
    defaultValues: {
      triggerPrice: "",
      orderSize: "",
      direction: OrderDirection.BUY,
      expirationHours: DEFAULT_TRADING_CONFIG.defaultExpirationHours,
      minFillSize: "",
      partialFillAllowed: true,
      slippageTolerance: DEFAULT_TRADING_CONFIG.slippageTolerance,
    },
    mode: "onChange",
  });

  const watchedValues = watch();
  
  // Form validation steps
  const steps: FormStep[] = [
    {
      id: 1,
      title: "Order Parameters",
      description: "Set price, size, and direction",
      isComplete: Boolean(watchedValues.triggerPrice && watchedValues.orderSize),
    },
    {
      id: 2,
      title: "Execution Settings",
      description: "Configure expiration and fills",
      isComplete: Boolean(watchedValues.expirationHours && watchedValues.minFillSize),
    },
    {
      id: 3,
      title: "Review & Submit",
      description: "Confirm order and encrypt",
      isComplete: isValid,
    },
  ];

  // Calculate order value and fees
  const orderValue = watchedValues.triggerPrice && watchedValues.orderSize 
    ? parsePrice(watchedValues.triggerPrice, tradingPair.currency1Decimals) * 
      parsePrice(watchedValues.orderSize, tradingPair.currency0Decimals) / 
      BigInt(10 ** tradingPair.currency0Decimals)
    : 0n;

  // Auto-set minimum fill size
  useEffect(() => {
    if (watchedValues.orderSize && !watchedValues.minFillSize) {
      const orderSizeValue = parseFloat(watchedValues.orderSize);
      const suggestedMinFill = Math.max(orderSizeValue * 0.1, 0.001); // 10% of order or minimum
      setValue("minFillSize", suggestedMinFill.toString());
    }
  }, [watchedValues.orderSize, watchedValues.minFillSize, setValue]);

  const onSubmit = async (data: OrderFormData) => {
    try {
      const orderId = await placeOrder(data, tradingPair);
      notification.success(`Order placed successfully! Order ID: ${orderId.slice(0, 10)}...`);
      resetForm();
      onOrderPlaced?.(orderId);
      onClose?.();
    } catch (err) {
      console.error("Failed to place order:", err);
    }
  };

  const nextStep = () => {
    if (currentStep < 3) setCurrentStep(currentStep + 1);
  };

  const prevStep = () => {
    if (currentStep > 1) setCurrentStep(currentStep - 1);
  };

  return (
    <div className="bg-base-100 rounded-xl shadow-lg max-w-md mx-auto">
      {/* Header */}
      <div className="p-6 border-b border-base-200">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-2xl font-bold text-base-content">Private Limit Order</h2>
          <div className="flex items-center gap-2 text-primary">
            <ShieldCheckIcon className="h-5 w-5" />
            <span className="text-sm font-medium">FHE Protected</span>
          </div>
        </div>
        
        {/* Trading Pair Display */}
        <div className="flex items-center justify-center gap-3 p-3 bg-base-200 rounded-lg">
          <span className="text-lg font-semibold">{tradingPair.currency0Symbol}</span>
          <ArrowsRightLeftIcon className="h-5 w-5 text-base-content/60" />
          <span className="text-lg font-semibold">{tradingPair.currency1Symbol}</span>
        </div>
      </div>

      {/* Progress Steps */}
      <div className="px-6 py-4">
        <div className="flex justify-between items-center">
          {steps.map((step, index) => (
            <div key={step.id} className="flex flex-col items-center flex-1">
              <div className={`
                w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium
                ${step.isComplete ? 'bg-success text-success-content' : 
                  currentStep === step.id ? 'bg-primary text-primary-content' : 
                  'bg-base-300 text-base-content/60'}
              `}>
                {step.isComplete ? '✓' : step.id}
              </div>
              <div className="mt-2 text-center">
                <div className="text-xs font-medium text-base-content">{step.title}</div>
                <div className="text-xs text-base-content/60">{step.description}</div>
              </div>
              {index < steps.length - 1 && (
                <div className={`
                  absolute top-4 w-16 h-0.5 ml-8
                  ${step.isComplete ? 'bg-success' : 'bg-base-300'}
                `} />
              )}
            </div>
          ))}
        </div>
      </div>

      <form onSubmit={handleSubmit(onSubmit)}>
        {/* Step 1: Order Parameters */}
        {currentStep === 1 && (
          <div className="p-6 space-y-6">
            {/* Direction Toggle */}
            <div className="flex items-center justify-center">
              <div className="bg-base-200 rounded-lg p-1 flex">
                <Controller
                  name="direction"
                  control={control}
                  render={({ field }) => (
                    <>
                      <button
                        type="button"
                        className={`px-6 py-2 rounded-md flex items-center gap-2 transition-all ${
                          field.value === OrderDirection.BUY 
                            ? 'bg-success text-success-content shadow-md' 
                            : 'text-base-content hover:bg-base-300'
                        }`}
                        onClick={() => field.onChange(OrderDirection.BUY)}
                      >
                        <ArrowUpIcon className="h-4 w-4" />
                        Buy
                      </button>
                      <button
                        type="button"
                        className={`px-6 py-2 rounded-md flex items-center gap-2 transition-all ${
                          field.value === OrderDirection.SELL 
                            ? 'bg-error text-error-content shadow-md' 
                            : 'text-base-content hover:bg-base-300'
                        }`}
                        onClick={() => field.onChange(OrderDirection.SELL)}
                      >
                        <ArrowDownIcon className="h-4 w-4" />
                        Sell
                      </button>
                    </>
                  )}
                />
              </div>
            </div>

            {/* Trigger Price */}
            <div className="form-control">
              <label className="label">
                <span className="label-text font-medium">
                  Trigger Price ({tradingPair.currency1Symbol})
                </span>
                {tradingPair.currentPrice && (
                  <span className="label-text-alt">
                    Current: {formatPrice(tradingPair.currentPrice, tradingPair.currency1Decimals)}
                  </span>
                )}
              </label>
              <Controller
                name="triggerPrice"
                control={control}
                rules={{
                  required: "Trigger price is required",
                  pattern: {
                    value: /^\d*\.?\d+$/,
                    message: "Must be a valid number"
                  },
                  validate: (value) => {
                    const price = parseFloat(value);
                    return price > 0 || "Price must be greater than 0";
                  }
                }}
                render={({ field }) => (
                  <input
                    type="text"
                    placeholder="0.00"
                    className={`input input-bordered w-full ${errors.triggerPrice ? 'input-error' : ''}`}
                    {...field}
                  />
                )}
              />
              {errors.triggerPrice && (
                <label className="label">
                  <span className="label-text-alt text-error">{errors.triggerPrice.message}</span>
                </label>
              )}
            </div>

            {/* Order Size */}
            <div className="form-control">
              <label className="label">
                <span className="label-text font-medium">
                  Order Size ({tradingPair.currency0Symbol})
                </span>
              </label>
              <Controller
                name="orderSize"
                control={control}
                rules={{
                  required: "Order size is required",
                  pattern: {
                    value: /^\d*\.?\d+$/,
                    message: "Must be a valid number"
                  },
                  validate: (value) => {
                    const size = parseFloat(value);
                    return size > 0 || "Size must be greater than 0";
                  }
                }}
                render={({ field }) => (
                  <input
                    type="text"
                    placeholder="0.00"
                    className={`input input-bordered w-full ${errors.orderSize ? 'input-error' : ''}`}
                    {...field}
                  />
                )}
              />
              {errors.orderSize && (
                <label className="label">
                  <span className="label-text-alt text-error">{errors.orderSize.message}</span>
                </label>
              )}
            </div>

            {/* Order Value Display */}
            {orderValue > 0n && (
              <div className="bg-info/10 rounded-lg p-4">
                <div className="flex justify-between items-center">
                  <span className="text-sm text-info">Total Order Value:</span>
                  <span className="font-semibold text-info">
                    {formatPrice(orderValue, tradingPair.currency1Decimals)} {tradingPair.currency1Symbol}
                  </span>
                </div>
              </div>
            )}

            <button 
              type="button"
              onClick={nextStep}
              disabled={!steps[0].isComplete}
              className="btn btn-primary w-full"
            >
              Next: Execution Settings
            </button>
          </div>
        )}

        {/* Step 2: Execution Settings */}
        {currentStep === 2 && (
          <div className="p-6 space-y-6">
            {/* Expiration */}
            <div className="form-control">
              <label className="label">
                <span className="label-text font-medium flex items-center gap-2">
                  <ClockIcon className="h-4 w-4" />
                  Order Expiration (Hours)
                </span>
              </label>
              <Controller
                name="expirationHours"
                control={control}
                rules={{
                  required: "Expiration time is required",
                  min: { value: 0.1, message: "Must be at least 6 minutes" },
                  max: { value: 720, message: "Maximum 30 days" }
                }}
                render={({ field }) => (
                  <input
                    type="number"
                    step="0.1"
                    min="0.1"
                    max="720"
                    placeholder="24"
                    className={`input input-bordered w-full ${errors.expirationHours ? 'input-error' : ''}`}
                    {...field}
                  />
                )}
              />
              {errors.expirationHours && (
                <label className="label">
                  <span className="label-text-alt text-error">{errors.expirationHours.message}</span>
                </label>
              )}
            </div>

            {/* Minimum Fill Size */}
            <div className="form-control">
              <label className="label">
                <span className="label-text font-medium">
                  Minimum Fill Size ({tradingPair.currency0Symbol})
                </span>
                <span className="label-text-alt">Optional partial fills</span>
              </label>
              <Controller
                name="minFillSize"
                control={control}
                rules={{
                  required: "Minimum fill size is required",
                  validate: (value) => {
                    if (!watchedValues.orderSize) return true;
                    const minFill = parseFloat(value);
                    const orderSize = parseFloat(watchedValues.orderSize);
                    return minFill <= orderSize || "Cannot be larger than order size";
                  }
                }}
                render={({ field }) => (
                  <input
                    type="text"
                    placeholder="0.001"
                    className={`input input-bordered w-full ${errors.minFillSize ? 'input-error' : ''}`}
                    {...field}
                  />
                )}
              />
              {errors.minFillSize && (
                <label className="label">
                  <span className="label-text-alt text-error">{errors.minFillSize.message}</span>
                </label>
              )}
            </div>

            {/* Partial Fills Toggle */}
            <div className="form-control">
              <label className="label cursor-pointer">
                <span className="label-text font-medium">Allow Partial Fills</span>
                <Controller
                  name="partialFillAllowed"
                  control={control}
                  render={({ field }) => (
                    <input 
                      type="checkbox" 
                      className="toggle toggle-primary" 
                      checked={field.value}
                      onChange={field.onChange}
                    />
                  )}
                />
              </label>
              <div className="text-xs text-base-content/60 mt-1">
                Enable to allow order execution in multiple smaller fills
              </div>
            </div>

            {/* Advanced Settings Toggle */}
            <div className="divider">
              <button
                type="button"
                onClick={() => setShowAdvanced(!showAdvanced)}
                className="btn btn-ghost btn-sm"
              >
                <CogIcon className="h-4 w-4" />
                {showAdvanced ? 'Hide' : 'Show'} Advanced
              </button>
            </div>

            {/* Advanced Settings */}
            {showAdvanced && (
              <div className="bg-base-200 rounded-lg p-4 space-y-4">
                <div className="form-control">
                  <label className="label">
                    <span className="label-text">Slippage Tolerance (%)</span>
                  </label>
                  <Controller
                    name="slippageTolerance"
                    control={control}
                    rules={{
                      min: { value: 0.1, message: "Minimum 0.1%" },
                      max: { value: 5, message: "Maximum 5%" }
                    }}
                    render={({ field }) => (
                      <input
                        type="number"
                        step="0.1"
                        min="0.1"
                        max="5"
                        className="input input-bordered input-sm"
                        {...field}
                      />
                    )}
                  />
                </div>
              </div>
            )}

            <div className="flex gap-3">
              <button 
                type="button"
                onClick={prevStep}
                className="btn btn-outline flex-1"
              >
                Back
              </button>
              <button 
                type="button"
                onClick={nextStep}
                disabled={!steps[1].isComplete}
                className="btn btn-primary flex-1"
              >
                Review Order
              </button>
            </div>
          </div>
        )}

        {/* Step 3: Review & Submit */}
        {currentStep === 3 && (
          <div className="p-6 space-y-6">
            <div className="bg-warning/10 rounded-lg p-4 mb-6">
              <div className="flex items-center gap-2 text-warning mb-2">
                <ShieldCheckIcon className="h-5 w-5" />
                <span className="font-semibold">Privacy Notice</span>
              </div>
              <p className="text-sm text-warning/80">
                Your order parameters will be encrypted using FHE before being submitted to the blockchain. 
                Only you can decrypt and view your private order details.
              </p>
            </div>

            {/* Order Summary */}
            <div className="bg-base-200 rounded-lg p-4 space-y-3">
              <h3 className="font-semibold text-lg mb-3">Order Summary</h3>
              
              <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <div className="text-base-content/60">Direction</div>
                  <div className={`font-semibold ${
                    watchedValues.direction === OrderDirection.BUY ? 'text-success' : 'text-error'
                  }`}>
                    {watchedValues.direction === OrderDirection.BUY ? 'BUY' : 'SELL'} {tradingPair.currency0Symbol}
                  </div>
                </div>
                
                <div>
                  <div className="text-base-content/60">Trigger Price</div>
                  <div className="font-semibold">
                    {watchedValues.triggerPrice} {tradingPair.currency1Symbol}
                  </div>
                </div>
                
                <div>
                  <div className="text-base-content/60">Order Size</div>
                  <div className="font-semibold">
                    {watchedValues.orderSize} {tradingPair.currency0Symbol}
                  </div>
                </div>
                
                <div>
                  <div className="text-base-content/60">Min Fill Size</div>
                  <div className="font-semibold">
                    {watchedValues.minFillSize} {tradingPair.currency0Symbol}
                  </div>
                </div>
                
                <div>
                  <div className="text-base-content/60">Expires In</div>
                  <div className="font-semibold">
                    {watchedValues.expirationHours} hours
                  </div>
                </div>
                
                <div>
                  <div className="text-base-content/60">Partial Fills</div>
                  <div className="font-semibold">
                    {watchedValues.partialFillAllowed ? 'Allowed' : 'Disabled'}
                  </div>
                </div>
              </div>
            </div>

            {error && (
              <div className="alert alert-error">
                <span>{error}</span>
              </div>
            )}

            <div className="flex gap-3">
              <button 
                type="button"
                onClick={prevStep}
                className="btn btn-outline flex-1"
                disabled={isLoading}
              >
                Back
              </button>
              <button 
                type="submit"
                disabled={isLoading || !isValid}
                className="btn btn-primary flex-1"
              >
                {isLoading ? (
                  <>
                    <span className="loading loading-spinner loading-sm"></span>
                    Encrypting & Submitting...
                  </>
                ) : (
                  'Place Order'
                )}
              </button>
            </div>
          </div>
        )}
      </form>
    </div>
  );
};
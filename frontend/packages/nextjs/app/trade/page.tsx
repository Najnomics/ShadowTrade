/**
 * Trading Page
 * 
 * Main interface for ShadowTrade private limit orders
 * Combines order placement form with order management dashboard
 */

"use client";

import { useState, useEffect } from "react";
import { useAccount } from "wagmi";
import { PlusIcon, ChartBarIcon, Cog6ToothIcon } from "@heroicons/react/24/outline";
import { OrderForm } from "~~/components/shadowtrade/OrderForm";
import { OrdersTable } from "~~/components/shadowtrade/OrdersTable";
import { OrderInfo, TradingPair } from "~~/types/shadowtrade";
import { useShadowTradeContract } from "~~/hooks/shadowtrade/useShadowTradeContract";
import { getCurrentConfig } from "~~/utils/shadowtrade/config";

export default function TradePage() {
  const { address, chainId } = useAccount();
  const [showOrderForm, setShowOrderForm] = useState(false);
  const [selectedPair, setSelectedPair] = useState<TradingPair | null>(null);
  const [orders, setOrders] = useState<OrderInfo[]>([]);
  const [loading, setLoading] = useState(false);

  const { getUserOrders, getOrderDetails } = useShadowTradeContract();
  const config = getCurrentConfig(chainId || 31337);

  // Initialize with first trading pair
  useEffect(() => {
    if (config.supportedPairs.length > 0 && !selectedPair) {
      setSelectedPair(config.supportedPairs[0]);
    }
  }, [config.supportedPairs, selectedPair]);

  // Load user orders
  const loadOrders = async () => {
    if (!address) return;
    
    setLoading(true);
    try {
      const orderIds = await getUserOrders(address);
      const orderPromises = orderIds.map(id => getOrderDetails(id));
      const orderResults = await Promise.all(orderPromises);
      
      const validOrders = orderResults.filter((order): order is OrderInfo => order !== null);
      setOrders(validOrders);
    } catch (error) {
      console.error("Failed to load orders:", error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadOrders();
  }, [address]);

  const handleOrderPlaced = (orderId: string) => {
    setShowOrderForm(false);
    loadOrders(); // Refresh orders list
  };

  const handleOrderCancelled = (orderId: string) => {
    loadOrders(); // Refresh orders list
  };

  if (!address) {
    return (
      <div className="container mx-auto px-4 py-16">
        <div className="text-center">
          <div className="max-w-md mx-auto bg-base-100 rounded-xl shadow-lg p-8">
            <ChartBarIcon className="h-16 w-16 mx-auto text-primary mb-4" />
            <h1 className="text-2xl font-bold text-base-content mb-4">
              Connect Your Wallet
            </h1>
            <p className="text-base-content/60 mb-6">
              Connect your wallet to start trading with private limit orders powered by FHE encryption.
            </p>
            <div className="text-sm text-base-content/40">
              ShadowTrade • Private • Secure • Decentralized
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-8">
      {/* Header */}
      <div className="mb-8">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-3xl font-bold text-base-content mb-2">
              ShadowTrade
            </h1>
            <p className="text-base-content/60">
              Private limit orders with Fully Homomorphic Encryption
            </p>
          </div>
          
          <div className="flex items-center gap-4">
            {/* Trading Pair Selector */}
            <div className="form-control">
              <label className="label">
                <span className="label-text">Trading Pair</span>
              </label>
              <select 
                value={selectedPair?.name || ''} 
                onChange={(e) => {
                  const pair = config.supportedPairs.find(p => p.name === e.target.value);
                  setSelectedPair(pair || null);
                }}
                className="select select-bordered"
              >
                {config.supportedPairs.map(pair => (
                  <option key={pair.name} value={pair.name}>
                    {pair.name}
                  </option>
                ))}
              </select>
            </div>

            {/* New Order Button */}
            <button
              onClick={() => setShowOrderForm(true)}
              className="btn btn-primary"
              disabled={!selectedPair}
            >
              <PlusIcon className="h-5 w-5" />
              New Order
            </button>
          </div>
        </div>

        {/* Stats Cards */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
          <div className="bg-base-100 rounded-lg p-4 shadow-md">
            <div className="text-sm text-base-content/60">Active Orders</div>
            <div className="text-2xl font-bold text-primary">
              {orders.filter(o => o.status === 'active' || o.status === 'partially_filled').length}
            </div>
          </div>
          
          <div className="bg-base-100 rounded-lg p-4 shadow-md">
            <div className="text-sm text-base-content/60">Completed Orders</div>
            <div className="text-2xl font-bold text-success">
              {orders.filter(o => o.status === 'completed').length}
            </div>
          </div>
          
          <div className="bg-base-100 rounded-lg p-4 shadow-md">
            <div className="text-sm text-base-content/60">Total Orders</div>
            <div className="text-2xl font-bold text-info">
              {orders.length}
            </div>
          </div>
          
          <div className="bg-base-100 rounded-lg p-4 shadow-md">
            <div className="text-sm text-base-content/60">Fill Rate</div>
            <div className="text-2xl font-bold text-accent">
              {orders.length > 0 
                ? `${Math.round((orders.filter(o => o.fillCount > 0).length / orders.length) * 100)}%`
                : '0%'
              }
            </div>
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-8">
        {/* Orders Table - Takes 2/3 width on xl screens */}
        <div className="xl:col-span-2">
          <OrdersTable
            orders={orders}
            onOrderCancelled={handleOrderCancelled}
            onRefresh={loadOrders}
            loading={loading}
          />
        </div>

        {/* Side Panel - Takes 1/3 width on xl screens */}
        <div className="space-y-6">
          {/* Market Info Card */}
          {selectedPair && (
            <div className="bg-base-100 rounded-xl shadow-lg p-6">
              <h3 className="text-lg font-semibold text-base-content mb-4">
                Market Info
              </h3>
              <div className="space-y-3">
                <div className="flex justify-between">
                  <span className="text-base-content/60">Pair</span>
                  <span className="font-semibold">{selectedPair.name}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-base-content/60">Base Asset</span>
                  <span className="font-semibold">{selectedPair.currency0Symbol}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-base-content/60">Quote Asset</span>
                  <span className="font-semibold">{selectedPair.currency1Symbol}</span>
                </div>
                {selectedPair.currentPrice && (
                  <div className="flex justify-between">
                    <span className="text-base-content/60">Current Price</span>
                    <span className="font-semibold font-mono">
                      {selectedPair.currentPrice.toString()}
                    </span>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Privacy Info Card */}
          <div className="bg-primary/10 rounded-xl border border-primary/20 p-6">
            <div className="flex items-center gap-2 text-primary mb-4">
              <ChartBarIcon className="h-5 w-5" />
              <h3 className="text-lg font-semibold">Privacy Features</h3>
            </div>
            <div className="space-y-3 text-sm">
              <div className="flex items-start gap-2">
                <div className="w-2 h-2 bg-primary rounded-full mt-1.5 flex-shrink-0"></div>
                <div>
                  <div className="font-medium text-primary">Encrypted Parameters</div>
                  <div className="text-primary/80">All order details are encrypted using FHE</div>
                </div>
              </div>
              <div className="flex items-start gap-2">
                <div className="w-2 h-2 bg-primary rounded-full mt-1.5 flex-shrink-0"></div>
                <div>
                  <div className="font-medium text-primary">MEV Protection</div>
                  <div className="text-primary/80">Front-runners cannot see your orders</div>
                </div>
              </div>
              <div className="flex items-start gap-2">
                <div className="w-2 h-2 bg-primary rounded-full mt-1.5 flex-shrink-0"></div>
                <div>
                  <div className="font-medium text-primary">Private Execution</div>
                  <div className="text-primary/80">Orders execute without revealing intent</div>
                </div>
              </div>
            </div>
          </div>

          {/* Quick Actions */}
          <div className="bg-base-100 rounded-xl shadow-lg p-6">
            <h3 className="text-lg font-semibold text-base-content mb-4">
              Quick Actions
            </h3>
            <div className="space-y-3">
              <button
                onClick={() => setShowOrderForm(true)}
                disabled={!selectedPair}
                className="btn btn-primary w-full"
              >
                <PlusIcon className="h-4 w-4" />
                Create New Order
              </button>
              
              <button
                onClick={loadOrders}
                disabled={loading}
                className="btn btn-outline w-full"
              >
                {loading ? (
                  <span className="loading loading-spinner loading-sm"></span>
                ) : (
                  'Refresh Orders'
                )}
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Order Form Modal */}
      {showOrderForm && selectedPair && (
        <div className="modal modal-open">
          <div className="modal-box max-w-2xl">
            <OrderForm
              tradingPair={selectedPair}
              onOrderPlaced={handleOrderPlaced}
              onClose={() => setShowOrderForm(false)}
            />
          </div>
          <div 
            className="modal-backdrop" 
            onClick={() => setShowOrderForm(false)}
          ></div>
        </div>
      )}
    </div>
  );
}
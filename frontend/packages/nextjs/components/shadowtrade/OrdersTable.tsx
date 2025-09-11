/**
 * OrdersTable Component
 * 
 * Advanced table for displaying user's shadow limit orders
 * Features privacy controls, real-time updates, and order management
 */

"use client";

import { useState, useEffect, useCallback } from "react";
import { 
  EyeIcon, 
  EyeSlashIcon, 
  XMarkIcon, 
  ClockIcon,
  CheckCircleIcon,
  ExclamationCircleIcon,
  ArrowUpIcon,
  ArrowDownIcon,
  ShieldCheckIcon
} from "@heroicons/react/24/outline";
import { OrderInfo, OrderStatus, OrderDirection } from "~~/types/shadowtrade";
import { useDecryptOrderData } from "~~/hooks/shadowtrade/useDecryptOrderData";
import { useShadowTradeContract } from "~~/hooks/shadowtrade/useShadowTradeContract";
import { formatPrice } from "~~/utils/shadowtrade/config";
import { formatDistanceToNow, format } from "date-fns";

interface OrdersTableProps {
  orders: OrderInfo[];
  onOrderCancelled?: (orderId: string) => void;
  onRefresh?: () => void;
  loading?: boolean;
}

interface OrderRowProps {
  order: OrderInfo;
  onCancel: (orderId: string) => void;
}

const OrderRow: React.FC<OrderRowProps> = ({ order, onCancel }) => {
  const [showPrivateData, setShowPrivateData] = useState(false);
  const [decryptedOrder, setDecryptedOrder] = useState<any>(null);
  const [isDecrypting, setIsDecrypting] = useState(false);
  
  const { decryptOrderData } = useDecryptOrderData();
  const { useCancelOrder } = useShadowTradeContract();
  const { cancelOrder, isLoading: isCancelling } = useCancelOrder();

  // Handle decryption toggle
  const togglePrivateData = useCallback(async () => {
    if (showPrivateData) {
      setShowPrivateData(false);
      setDecryptedOrder(null);
      return;
    }

    if (decryptedOrder) {
      setShowPrivateData(true);
      return;
    }

    setIsDecrypting(true);
    try {
      const decrypted = await decryptOrderData(order);
      if (decrypted) {
        setDecryptedOrder(decrypted);
        setShowPrivateData(true);
      }
    } catch (err) {
      console.error("Failed to decrypt order:", err);
    } finally {
      setIsDecrypting(false);
    }
  }, [showPrivateData, decryptedOrder, decryptOrderData, order]);

  // Handle order cancellation
  const handleCancel = useCallback(async () => {
    if (!confirm("Are you sure you want to cancel this order?")) {
      return;
    }

    try {
      await cancelOrder(order.orderId);
      onCancel(order.orderId);
    } catch (err) {
      console.error("Failed to cancel order:", err);
    }
  }, [cancelOrder, order.orderId, onCancel]);

  // Status styling
  const getStatusBadge = (status: OrderStatus) => {
    switch (status) {
      case "active":
        return <span className="badge badge-success badge-sm">Active</span>;
      case "partially_filled":
        return <span className="badge badge-warning badge-sm">Partial</span>;
      case "completed":
        return <span className="badge badge-info badge-sm">Completed</span>;
      case "expired":
        return <span className="badge badge-neutral badge-sm">Expired</span>;
      case "cancelled":
        return <span className="badge badge-error badge-sm">Cancelled</span>;
      default:
        return <span className="badge badge-ghost badge-sm">{status}</span>;
    }
  };

  // Direction icon
  const getDirectionIcon = (direction?: OrderDirection) => {
    if (direction === OrderDirection.BUY) {
      return <ArrowUpIcon className="h-4 w-4 text-success" />;
    } else if (direction === OrderDirection.SELL) {
      return <ArrowDownIcon className="h-4 w-4 text-error" />;
    }
    return <ShieldCheckIcon className="h-4 w-4 text-base-content/40" />;
  };

  const isOrderActive = order.status === "active" || order.status === "partially_filled";
  
  return (
    <tr className="hover:bg-base-200/50">
      {/* Order ID */}
      <td>
        <div className="flex flex-col">
          <code className="text-xs font-mono">
            {order.orderId.slice(0, 8)}...{order.orderId.slice(-4)}
          </code>
          <div className="text-xs text-base-content/60">
            {format(new Date(Number(order.createdAt) * 1000), 'MMM dd, HH:mm')}
          </div>
        </div>
      </td>

      {/* Direction & Pair */}
      <td>
        <div className="flex items-center gap-2">
          {getDirectionIcon(decryptedOrder?.direction)}
          <div className="flex flex-col">
            <div className="font-medium text-sm">
              {showPrivateData && decryptedOrder 
                ? (decryptedOrder.direction === OrderDirection.BUY ? 'BUY' : 'SELL')
                : 'PRIVATE'
              }
            </div>
            <div className="text-xs text-base-content/60">
              Currency Pair
            </div>
          </div>
        </div>
      </td>

      {/* Trigger Price */}
      <td>
        <div className="flex flex-col">
          <div className="font-mono">
            {showPrivateData && decryptedOrder 
              ? formatPrice(decryptedOrder.triggerPrice, 6)
              : '****.**'
            }
          </div>
          <div className="text-xs text-base-content/60">
            Trigger Price
          </div>
        </div>
      </td>

      {/* Size & Filled */}
      <td>
        <div className="flex flex-col">
          <div className="font-mono">
            {showPrivateData && decryptedOrder 
              ? formatPrice(decryptedOrder.orderSize, 18)
              : '*.****'
            }
          </div>
          {order.totalFilled > 0n && (
            <div className="text-xs text-success">
              {formatPrice(order.totalFilled, 18)} filled
            </div>
          )}
          <div className="text-xs text-base-content/60">
            Order Size
          </div>
        </div>
      </td>

      {/* Status */}
      <td>
        <div className="flex flex-col items-start gap-1">
          {getStatusBadge(order.status)}
          {decryptedOrder?.expirationTime && (
            <div className="text-xs text-base-content/60 flex items-center gap-1">
              <ClockIcon className="h-3 w-3" />
              {formatDistanceToNow(new Date(Number(decryptedOrder.expirationTime) * 1000))}
            </div>
          )}
        </div>
      </td>

      {/* Fill Info */}
      <td>
        {order.fillCount > 0 ? (
          <div className="flex flex-col">
            <div className="text-sm font-medium">
              {order.fillCount} fill{order.fillCount > 1 ? 's' : ''}
            </div>
            <div className="text-xs text-base-content/60">
              Avg: {formatPrice(order.averageExecutionPrice, 6)}
            </div>
          </div>
        ) : (
          <div className="text-xs text-base-content/40">
            No fills yet
          </div>
        )}
      </td>

      {/* Actions */}
      <td>
        <div className="flex items-center gap-2">
          {/* Privacy Toggle */}
          <button
            onClick={togglePrivateData}
            disabled={isDecrypting}
            className="btn btn-ghost btn-xs"
            title={showPrivateData ? "Hide private data" : "Show private data"}
          >
            {isDecrypting ? (
              <span className="loading loading-spinner loading-xs"></span>
            ) : showPrivateData ? (
              <EyeSlashIcon className="h-4 w-4" />
            ) : (
              <EyeIcon className="h-4 w-4" />
            )}
          </button>

          {/* Cancel Button */}
          {isOrderActive && (
            <button
              onClick={handleCancel}
              disabled={isCancelling}
              className="btn btn-ghost btn-xs text-error hover:bg-error/10"
              title="Cancel order"
            >
              {isCancelling ? (
                <span className="loading loading-spinner loading-xs"></span>
              ) : (
                <XMarkIcon className="h-4 w-4" />
              )}
            </button>
          )}
        </div>
      </td>
    </tr>
  );
};

export const OrdersTable: React.FC<OrdersTableProps> = ({ 
  orders, 
  onOrderCancelled, 
  onRefresh,
  loading = false 
}) => {
  const [filter, setFilter] = useState<'all' | 'active' | 'completed'>('all');
  const [sortBy, setSortBy] = useState<'newest' | 'oldest'>('newest');

  // Filter and sort orders
  const filteredOrders = orders
    .filter(order => {
      switch (filter) {
        case 'active':
          return order.status === 'active' || order.status === 'partially_filled';
        case 'completed':
          return order.status === 'completed' || order.status === 'cancelled' || order.status === 'expired';
        default:
          return true;
      }
    })
    .sort((a, b) => {
      const aTime = Number(a.createdAt);
      const bTime = Number(b.createdAt);
      return sortBy === 'newest' ? bTime - aTime : aTime - bTime;
    });

  const handleOrderCancel = useCallback((orderId: string) => {
    onOrderCancelled?.(orderId);
    onRefresh?.();
  }, [onOrderCancelled, onRefresh]);

  return (
    <div className="bg-base-100 rounded-xl shadow-lg">
      {/* Header */}
      <div className="p-6 border-b border-base-200">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-2xl font-bold text-base-content">Your Orders</h2>
          <div className="flex items-center gap-2 text-primary">
            <ShieldCheckIcon className="h-5 w-5" />
            <span className="text-sm font-medium">Private Orders</span>
          </div>
        </div>
        
        {/* Filters */}
        <div className="flex flex-wrap items-center gap-4">
          <div className="flex items-center gap-2">
            <span className="text-sm font-medium">Filter:</span>
            <div className="join">
              {(['all', 'active', 'completed'] as const).map((f) => (
                <button
                  key={f}
                  onClick={() => setFilter(f)}
                  className={`join-item btn btn-sm ${
                    filter === f ? 'btn-primary' : 'btn-outline'
                  }`}
                >
                  {f.charAt(0).toUpperCase() + f.slice(1)}
                </button>
              ))}
            </div>
          </div>
          
          <div className="flex items-center gap-2">
            <span className="text-sm font-medium">Sort:</span>
            <select 
              value={sortBy} 
              onChange={(e) => setSortBy(e.target.value as any)}
              className="select select-bordered select-sm"
            >
              <option value="newest">Newest First</option>
              <option value="oldest">Oldest First</option>
            </select>
          </div>

          {onRefresh && (
            <button 
              onClick={onRefresh}
              disabled={loading}
              className="btn btn-ghost btn-sm ml-auto"
            >
              {loading ? (
                <span className="loading loading-spinner loading-sm"></span>
              ) : (
                'Refresh'
              )}
            </button>
          )}
        </div>
      </div>

      {/* Table */}
      <div className="overflow-x-auto">
        {filteredOrders.length === 0 ? (
          <div className="p-12 text-center">
            <div className="text-base-content/40 mb-4">
              {filter === 'all' ? (
                <CheckCircleIcon className="h-16 w-16 mx-auto mb-4" />
              ) : (
                <ExclamationCircleIcon className="h-16 w-16 mx-auto mb-4" />
              )}
            </div>
            <h3 className="text-lg font-semibold text-base-content/60 mb-2">
              {filter === 'all' ? 'No orders yet' : `No ${filter} orders`}
            </h3>
            <p className="text-base-content/40">
              {filter === 'all' 
                ? 'Create your first private limit order to get started'
                : `You don't have any ${filter} orders at the moment`
              }
            </p>
          </div>
        ) : (
          <table className="table w-full">
            <thead>
              <tr>
                <th>Order ID</th>
                <th>Direction</th>
                <th>Trigger Price</th>
                <th>Size</th>
                <th>Status</th>
                <th>Fills</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredOrders.map((order) => (
                <OrderRow
                  key={order.orderId}
                  order={order}
                  onCancel={handleOrderCancel}
                />
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* Footer */}
      {filteredOrders.length > 0 && (
        <div className="p-4 border-t border-base-200 text-center">
          <div className="text-sm text-base-content/60">
            Showing {filteredOrders.length} of {orders.length} orders
          </div>
          <div className="text-xs text-base-content/40 mt-1">
            <ShieldCheckIcon className="h-3 w-3 inline mr-1" />
            All order data is encrypted and only visible to you
          </div>
        </div>
      )}
    </div>
  );
};
/**
 * Homepage
 * 
 * Landing page for ShadowTrade showcasing features and directing users to trading interface
 */

"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useAccount } from "wagmi";
import { 
  ShieldCheckIcon, 
  EyeSlashIcon, 
  BoltIcon, 
  ChartBarIcon,
  ArrowRightIcon,
  SparklesIcon,
  LockClosedIcon
} from "@heroicons/react/24/outline";

export default function HomePage() {
  const { address } = useAccount();
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted) return null;

  return (
    <div className="min-h-screen bg-gradient-to-br from-primary/5 via-base-100 to-secondary/5">
      {/* Hero Section */}
      <div className="container mx-auto px-4 pt-20 pb-16">
        <div className="text-center max-w-4xl mx-auto">
          {/* Hero Badge */}
          <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-primary/10 text-primary border border-primary/20 mb-6">
            <SparklesIcon className="h-4 w-4" />
            <span className="text-sm font-medium">Powered by Fully Homomorphic Encryption</span>
          </div>

          {/* Hero Title */}
          <h1 className="text-5xl lg:text-6xl font-bold text-base-content mb-6 leading-tight">
            Trade with
            <span className="text-primary"> Complete Privacy</span>
          </h1>

          {/* Hero Subtitle */}
          <p className="text-xl text-base-content/70 mb-8 max-w-2xl mx-auto">
            Place limit orders that remain completely private until execution. 
            No front-running, no MEV, just pure decentralized trading.
          </p>

          {/* Hero Actions */}
          <div className="flex flex-col sm:flex-row gap-4 justify-center items-center">
            <Link 
              href="/trade" 
              className="btn btn-primary btn-lg px-8"
            >
              {address ? 'Start Trading' : 'Connect & Trade'}
              <ArrowRightIcon className="h-5 w-5" />
            </Link>
            
            <button className="btn btn-ghost btn-lg">
              Learn More
            </button>
          </div>

          {/* Hero Stats */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-8 mt-16 max-w-2xl mx-auto">
            <div className="text-center">
              <div className="text-3xl font-bold text-primary mb-2">100%</div>
              <div className="text-sm text-base-content/60">Private Orders</div>
            </div>
            <div className="text-center">
              <div className="text-3xl font-bold text-primary mb-2">0</div>
              <div className="text-sm text-base-content/60">MEV Attacks</div>
            </div>
            <div className="text-center">
              <div className="text-3xl font-bold text-primary mb-2">∞</div>
              <div className="text-sm text-base-content/60">Privacy Level</div>
            </div>
          </div>
        </div>
      </div>

      {/* Features Section */}
      <div className="bg-base-100 py-20">
        <div className="container mx-auto px-4">
          <div className="text-center mb-16">
            <h2 className="text-3xl lg:text-4xl font-bold text-base-content mb-4">
              Revolutionary Trading Features
            </h2>
            <p className="text-lg text-base-content/60 max-w-2xl mx-auto">
              Experience the future of decentralized trading with our cutting-edge FHE technology
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
            {/* Feature 1: Complete Privacy */}
            <div className="bg-base-100 rounded-2xl p-8 shadow-lg border border-base-200 hover:shadow-xl transition-all duration-300">
              <div className="w-12 h-12 bg-primary/10 rounded-lg flex items-center justify-center mb-6">
                <EyeSlashIcon className="h-6 w-6 text-primary" />
              </div>
              <h3 className="text-xl font-semibold text-base-content mb-4">
                Complete Privacy
              </h3>
              <p className="text-base-content/60 mb-6">
                Your order parameters (price, size, direction) remain encrypted on-chain. 
                Only you can decrypt and view your private trading data.
              </p>
              <div className="text-primary text-sm font-medium">
                ✓ Encrypted trigger prices<br/>
                ✓ Hidden order sizes<br/>
                ✓ Private trade directions
              </div>
            </div>

            {/* Feature 2: MEV Protection */}
            <div className="bg-base-100 rounded-2xl p-8 shadow-lg border border-base-200 hover:shadow-xl transition-all duration-300">
              <div className="w-12 h-12 bg-success/10 rounded-lg flex items-center justify-center mb-6">
                <ShieldCheckIcon className="h-6 w-6 text-success" />
              </div>
              <h3 className="text-xl font-semibold text-base-content mb-4">
                MEV Protection
              </h3>
              <p className="text-base-content/60 mb-6">
                Eliminate front-running and sandwich attacks. Your trading intent 
                remains hidden until the moment of execution.
              </p>
              <div className="text-success text-sm font-medium">
                ✓ No front-running<br/>
                ✓ No sandwich attacks<br/>
                ✓ Protected from MEV bots
              </div>
            </div>

            {/* Feature 3: Smart Execution */}
            <div className="bg-base-100 rounded-2xl p-8 shadow-lg border border-base-200 hover:shadow-xl transition-all duration-300">
              <div className="w-12 h-12 bg-warning/10 rounded-lg flex items-center justify-center mb-6">
                <BoltIcon className="h-6 w-6 text-warning" />
              </div>
              <h3 className="text-xl font-semibold text-base-content mb-4">
                Smart Execution
              </h3>
              <p className="text-base-content/60 mb-6">
                Advanced execution engine with partial fills, VWAP tracking, 
                and optimal liquidity matching for the best possible fills.
              </p>
              <div className="text-warning text-sm font-medium">
                ✓ Partial fill support<br/>
                ✓ VWAP calculation<br/>
                ✓ Liquidity optimization
              </div>
            </div>

            {/* Feature 4: Uniswap v4 Integration */}
            <div className="bg-base-100 rounded-2xl p-8 shadow-lg border border-base-200 hover:shadow-xl transition-all duration-300">
              <div className="w-12 h-12 bg-info/10 rounded-lg flex items-center justify-center mb-6">
                <ChartBarIcon className="h-6 w-6 text-info" />
              </div>
              <h3 className="text-xl font-semibold text-base-content mb-4">
                Uniswap v4 Native
              </h3>
              <p className="text-base-content/60 mb-6">
                Built as a native Uniswap v4 hook for seamless integration 
                with the most advanced DEX infrastructure.
              </p>
              <div className="text-info text-sm font-medium">
                ✓ Native v4 integration<br/>
                ✓ Gas efficient execution<br/>
                ✓ Professional-grade reliability
              </div>
            </div>

            {/* Feature 5: Advanced Order Types */}
            <div className="bg-base-100 rounded-2xl p-8 shadow-lg border border-base-200 hover:shadow-xl transition-all duration-300">
              <div className="w-12 h-12 bg-secondary/10 rounded-lg flex items-center justify-center mb-6">
                <LockClosedIcon className="h-6 w-6 text-secondary" />
              </div>
              <h3 className="text-xl font-semibold text-base-content mb-4">
                Advanced Orders
              </h3>
              <p className="text-base-content/60 mb-6">
                Comprehensive order management with expiration times, 
                minimum fill sizes, and flexible execution parameters.
              </p>
              <div className="text-secondary text-sm font-medium">
                ✓ Flexible expiration<br/>
                ✓ Minimum fill controls<br/>
                ✓ Advanced order logic
              </div>
            </div>

            {/* Feature 6: Real-time Monitoring */}
            <div className="bg-base-100 rounded-2xl p-8 shadow-lg border border-base-200 hover:shadow-xl transition-all duration-300">
              <div className="w-12 h-12 bg-accent/10 rounded-lg flex items-center justify-center mb-6">
                <SparklesIcon className="h-6 w-6 text-accent" />
              </div>
              <h3 className="text-xl font-semibold text-base-content mb-4">
                Real-time Updates
              </h3>
              <p className="text-base-content/60 mb-6">
                Monitor your orders with real-time updates, execution notifications, 
                and comprehensive fill history tracking.
              </p>
              <div className="text-accent text-sm font-medium">
                ✓ Live order status<br/>
                ✓ Execution alerts<br/>
                ✓ Complete fill history
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* How It Works Section */}
      <div className="py-20 bg-gradient-to-r from-primary/5 to-secondary/5">
        <div className="container mx-auto px-4">
          <div className="text-center mb-16">
            <h2 className="text-3xl lg:text-4xl font-bold text-base-content mb-4">
              How ShadowTrade Works
            </h2>
            <p className="text-lg text-base-content/60 max-w-2xl mx-auto">
              Three simple steps to private, MEV-protected trading
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8 max-w-6xl mx-auto">
            {/* Step 1 */}
            <div className="text-center">
              <div className="w-16 h-16 bg-primary rounded-full flex items-center justify-center mx-auto mb-6">
                <span className="text-2xl font-bold text-primary-content">1</span>
              </div>
              <h3 className="text-xl font-semibold text-base-content mb-4">
                Create Order
              </h3>
              <p className="text-base-content/60">
                Set your desired price, order size, and execution parameters. 
                All data is encrypted locally before submission.
              </p>
            </div>

            {/* Step 2 */}
            <div className="text-center">
              <div className="w-16 h-16 bg-secondary rounded-full flex items-center justify-center mx-auto mb-6">
                <span className="text-2xl font-bold text-secondary-content">2</span>
              </div>
              <h3 className="text-xl font-semibold text-base-content mb-4">
                Private Monitoring
              </h3>
              <p className="text-base-content/60">
                Your encrypted order waits on-chain, invisible to MEV bots 
                and front-runners, until market conditions are met.
              </p>
            </div>

            {/* Step 3 */}
            <div className="text-center">
              <div className="w-16 h-16 bg-success rounded-full flex items-center justify-center mx-auto mb-6">
                <span className="text-2xl font-bold text-success-content">3</span>
              </div>
              <h3 className="text-xl font-semibold text-base-content mb-4">
                Automatic Execution
              </h3>
              <p className="text-base-content/60">
                When your trigger price is reached, the order executes automatically 
                with optimal fill and transparent settlement.
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* CTA Section */}
      <div className="bg-gradient-to-r from-primary to-secondary py-20">
        <div className="container mx-auto px-4 text-center">
          <h2 className="text-3xl lg:text-4xl font-bold text-primary-content mb-6">
            Ready to Trade Privately?
          </h2>
          <p className="text-xl text-primary-content/80 mb-8 max-w-2xl mx-auto">
            Join the future of decentralized trading with complete privacy and MEV protection.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Link 
              href="/trade"
              className="btn btn-neutral btn-lg px-8"
            >
              Start Trading Now
              <ArrowRightIcon className="h-5 w-5" />
            </Link>
          </div>
        </div>
      </div>

      {/* Footer */}
      <div className="bg-base-200 py-12">
        <div className="container mx-auto px-4 text-center">
          <div className="flex items-center justify-center gap-2 mb-4">
            <ShieldCheckIcon className="h-6 w-6 text-primary" />
            <span className="text-xl font-bold text-base-content">ShadowTrade</span>
          </div>
          <p className="text-base-content/60 mb-4">
            Private limit orders powered by Fully Homomorphic Encryption
          </p>
          <div className="text-sm text-base-content/40">
            Built on Uniswap v4 • Secured by Fhenix CoFHE • Open Source
          </div>
        </div>
      </div>
    </div>
  );
}

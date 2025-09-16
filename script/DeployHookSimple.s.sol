// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {ShadowTradeLimitHook} from "../src/ShadowTradeLimitHook.sol";

/// @title Deploy ShadowTrade Hook for Anvil (Simple)
/// @notice Deploys the ShadowTrade Limit Hook without address validation for testing
contract DeployHookSimple is Script {
    
    IPoolManager public poolManager;
    ShadowTradeLimitHook public hook;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("=== ShadowTrade Hook Simple Deployment for Anvil ===");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Deploy PoolManager for Anvil
        console2.log("Deploying PoolManager for Anvil...");
        poolManager = new PoolManager(deployer);
        console2.log("PoolManager deployed at:", address(poolManager));
        
        // Step 2: Deploy hook directly (without address validation for testing)
        console2.log("Deploying ShadowTrade Hook...");
        hook = new ShadowTradeLimitHook(poolManager);
        console2.log("ShadowTrade Hook deployed at:", address(hook));
        
        // Step 3: Verify deployment
        console2.log("Verifying deployment...");
        require(hook.owner() == deployer, "Hook owner not set correctly");
        require(hook.executionFeeBps() == 5, "Default execution fee not set");
        console2.log("Deployment verification passed");
        
        // Step 4: Initialize hook
        console2.log("Initializing hook...");
        hook.setExecutionFee(5);
        console2.log("Hook initialized with 5 basis points execution fee");
        
        vm.stopBroadcast();
        
        // Step 5: Output summary
        outputDeploymentSummary(deployer);
    }
    
    function outputDeploymentSummary(address deployer) internal view {
        console2.log("\n=== DEPLOYMENT SUMMARY ===");
        console2.log("Network: Anvil Local (Chain ID: 31337)");
        console2.log("Deployer:", deployer);
        console2.log("Deployment Block:", block.number);
        
        console2.log("\n--- Contract Addresses ---");
        console2.log("PoolManager:", address(poolManager));
        console2.log("ShadowTrade Hook:", address(hook));
        
        console2.log("\n--- Hook Configuration ---");
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        console2.log("beforeSwap:", permissions.beforeSwap);
        console2.log("afterSwap:", permissions.afterSwap);
        console2.log("Execution Fee:", hook.executionFeeBps(), "bps");
        
        console2.log("\n--- Important Notes ---");
        console2.log("WARNING: This deployment bypasses hook address validation");
        console2.log("WARNING: For production, use proper address mining");
        console2.log("WARNING: This is suitable for testing only");
        
        console2.log("\n--- Next Steps ---");
        console2.log("1. Test the hook with limit orders");
        console2.log("2. Integrate with frontend");
        console2.log("3. Monitor hook events");
        
        console2.log("\nShadowTrade Hook deployment completed successfully!");
    }
}

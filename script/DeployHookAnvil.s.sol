// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {ShadowTradeLimitHook} from "../src/ShadowTradeLimitHook.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";

/// @title Deploy ShadowTrade Hook for Anvil
/// @notice Deploys the ShadowTrade Limit Hook using proper address mining for Anvil
contract DeployHookAnvil is Script {
    using HookMiner for address;
    
    IPoolManager public poolManager;
    ShadowTradeLimitHook public hook;
    
    // CREATE2 deployer address
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("=== ShadowTrade Hook Deployment for Anvil ===");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Deploy PoolManager for Anvil
        console2.log("Deploying PoolManager for Anvil...");
        poolManager = new PoolManager(deployer);
        console2.log("PoolManager deployed at:", address(poolManager));
        
        // Step 2: Mine hook address with proper flags
        console2.log("Mining hook address with proper flags...");
        
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | 
            Hooks.AFTER_SWAP_FLAG
        );
        
        console2.log("Required hook flags:", flags);
        
        // Prepare constructor arguments
        bytes memory constructorArgs = abi.encode(poolManager);
        
        // Mine the salt for a valid hook address
        bytes32 salt = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            type(ShadowTradeLimitHook).creationCode,
            constructorArgs
        );
        
        // Compute the expected hook address
        address hookAddress = HookMiner.computeCreate2Address(
            CREATE2_DEPLOYER,
            salt,
            abi.encodePacked(type(ShadowTradeLimitHook).creationCode, constructorArgs)
        );
        
        console2.log("Mined hook address:", hookAddress);
        console2.log("Mined salt:", vm.toString(salt));
        
        // Step 3: Deploy hook using CREATE2
        console2.log("Deploying ShadowTrade Hook with CREATE2...");
        hook = new ShadowTradeLimitHook{salt: salt}(poolManager);
        
        require(address(hook) == hookAddress, "Hook address mismatch");
        console2.log("ShadowTrade Hook deployed at:", address(hook));
        
        // Step 4: Verify deployment
        console2.log("Verifying deployment...");
        require(hook.owner() == deployer, "Hook owner not set correctly");
        require(hook.executionFeeBps() == 5, "Default execution fee not set");
        console2.log("Deployment verification passed");
        
        // Step 5: Initialize hook
        console2.log("Initializing hook...");
        hook.setExecutionFee(5);
        console2.log("Hook initialized with 5 basis points execution fee");
        
        vm.stopBroadcast();
        
        // Step 6: Output summary
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
        
        console2.log("\n--- Next Steps ---");
        console2.log("1. Test the hook with limit orders");
        console2.log("2. Integrate with frontend");
        console2.log("3. Monitor hook events");
        
        console2.log("\nShadowTrade Hook deployment completed successfully!");
    }
}

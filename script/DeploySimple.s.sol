// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {ShadowTradeLimitHook} from "../src/ShadowTradeLimitHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";

contract DeploySimpleScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("=== Simple ShadowTrade Deployment ===");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy PoolManager first
        console2.log("Deploying PoolManager...");
        PoolManager poolManager = new PoolManager(deployer);
        console2.log("PoolManager deployed at:", address(poolManager));
        
        // Calculate required hook flags
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | 
            Hooks.AFTER_SWAP_FLAG
        );
        
        console2.log("Required hook flags:", flags);
        
        // Use HookMiner to find valid salt for hook address
        console2.log("Mining hook address...");
        
        // Create the hook creation code
        bytes memory hookBytecode = abi.encodePacked(
            type(ShadowTradeLimitHook).creationCode,
            abi.encode(address(poolManager))
        );
        
        // Mine for a valid salt
        bytes32 salt = HookMiner.find(
            deployer,
            flags,
            type(ShadowTradeLimitHook).creationCode,
            abi.encode(address(poolManager))
        );
        
        console2.log("Found valid salt:", vm.toString(salt));
        
        // Deploy hook with mined salt
        ShadowTradeLimitHook hook = new ShadowTradeLimitHook{salt: salt}(IPoolManager(address(poolManager)));
        
        console2.log("Hook deployed at:", address(hook));
        console2.log("Hook address validation passed!");
        
        // Verify hook permissions
        console2.log("Verifying hook permissions...");
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        console2.log("beforeSwap:", permissions.beforeSwap);
        console2.log("afterSwap:", permissions.afterSwap);
        
        vm.stopBroadcast();
        
        console2.log("\n=== Deployment Complete ===");
        console2.log("PoolManager:", address(poolManager));
        console2.log("ShadowTrade Hook:", address(hook));
        console2.log("Hook Owner:", hook.owner());
        console2.log("Execution Fee:", hook.executionFeeBps(), "bps");
    }
}
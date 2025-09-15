// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {ShadowTradeLimitHook} from "../src/ShadowTradeLimitHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";

contract DeploySimpleScript is Script {
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("=== Simple ShadowTrade Deployment ===");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy PoolManager first
        console2.log("Deploying PoolManager...");
        PoolManager poolManager = new PoolManager(address(0));
        console2.log("PoolManager deployed at:", address(poolManager));
        
        // Calculate required hook flags
        uint160 permissions = uint160(
            Hooks.BEFORE_SWAP_FLAG | 
            Hooks.AFTER_SWAP_FLAG
        );
        
        console2.log("Required hook permissions:", permissions);
        
        // Mine a salt that will produce a hook address with the correct permissions
        console2.log("Mining hook address...");
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            permissions,
            type(ShadowTradeLimitHook).creationCode,
            abi.encode(address(poolManager))
        );
        
        console2.log("Found valid salt:", vm.toString(salt));
        console2.log("Target hook address:", hookAddress);
        
        // Deploy hook with mined salt using CREATE2
        ShadowTradeLimitHook hook = new ShadowTradeLimitHook{salt: salt}(IPoolManager(address(poolManager)));
        require(address(hook) == hookAddress, "DeployScript: hook address mismatch");
        
        console2.log("Hook deployed at:", address(hook));
        console2.log("Hook address validation passed!");
        
        // Verify hook permissions
        console2.log("Verifying hook permissions...");
        Hooks.Permissions memory permissions_check = hook.getHookPermissions();
        console2.log("beforeSwap:", permissions_check.beforeSwap);
        console2.log("afterSwap:", permissions_check.afterSwap);
        
        vm.stopBroadcast();
        
        console2.log("\n=== Deployment Complete ===");
        console2.log("PoolManager:", address(poolManager));
        console2.log("ShadowTrade Hook:", address(hook));
        console2.log("Hook Owner:", hook.owner());
        console2.log("Execution Fee:", hook.executionFeeBps(), "bps");
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {ShadowTradeLimitHook} from "../src/ShadowTradeLimitHook.sol";
import {HybridFHERC20} from "../src/HybridFHERC20.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";

/// @title Deploy ShadowTrade to Ethereum Mainnet
/// @notice Production deployment script for mainnet
contract DeployToMainnet is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("=== ShadowTrade Mainnet Deployment ===");
        console2.log("Deployer:", deployer);
        console2.log("Deployer balance:", deployer.balance);
        console2.log("Chain ID:", block.chainid);

        // Verify we're on mainnet
        require(block.chainid == 1, "DeployToMainnet: Not on mainnet");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy PoolManager
        IPoolManager poolManager = IPoolManager(address(new PoolManager(deployer)));
        console2.log("PoolManager deployed at:", address(poolManager));

        // Deploy ShadowTradeLimitHook
        ShadowTradeLimitHook hook = new ShadowTradeLimitHook(poolManager);
        console2.log("ShadowTradeLimitHook deployed at:", address(hook));

        // Deploy HybridFHERC20 token
        HybridFHERC20 token = new HybridFHERC20("ShadowTrade Token", "SHT");
        console2.log("HybridFHERC20 deployed at:", address(token));

        // Mint initial tokens to deployer
        token.mint(deployer, 1000000 * 10**18);
        console2.log("Minted 1M tokens to deployer");

        vm.stopBroadcast();

        console2.log("=== Mainnet Deployment Complete ===");
        console2.log("PoolManager:", address(poolManager));
        console2.log("ShadowTradeLimitHook:", address(hook));
        console2.log("HybridFHERC20:", address(token));
        
        console2.log("=== Next Steps ===");
        console2.log("1. Verify contracts on Etherscan");
        console2.log("2. Set up monitoring");
        console2.log("3. Configure access controls");
        console2.log("4. Announce deployment to community");
    }
}

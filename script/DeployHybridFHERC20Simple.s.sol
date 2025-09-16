// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console2} from "forge-std/Script.sol";
import {HybridFHERC20} from "../src/HybridFHERC20.sol";

contract DeployHybridFHERC20Simple is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("Deploying HybridFHERC20 with deployer:", deployer);
        console2.log("Deployer balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the HybridFHERC20 token
        HybridFHERC20 token = new HybridFHERC20("ShadowTrade Token", "SHT");
        
        console2.log("HybridFHERC20 deployed at:", address(token));
        
        // Mint some initial tokens to the deployer
        token.mint(deployer, 1000000 * 10**18);
        console2.log("Minted 1M tokens to deployer");
        
        // Test basic functionality
        console2.log("Token name:", token.name());
        console2.log("Token symbol:", token.symbol());
        console2.log("Deployer balance:", token.balanceOf(deployer));
        console2.log("Total supply:", token.totalSupply());
        
        vm.stopBroadcast();
    }
}

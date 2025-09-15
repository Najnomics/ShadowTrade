// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

contract DeployMockTokensScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("=== Mock Tokens Deployment ===");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy mock tokens
        console2.log("Deploying mock tokens...");
        
        MockERC20 weth = new MockERC20("Wrapped Ether", "WETH", 18);
        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);
        MockERC20 wbtc = new MockERC20("Wrapped Bitcoin", "WBTC", 8);
        MockERC20 dai = new MockERC20("Dai Stablecoin", "DAI", 18);
        
        console2.log("WETH deployed at:", address(weth));
        console2.log("USDC deployed at:", address(usdc));
        console2.log("WBTC deployed at:", address(wbtc));
        console2.log("DAI deployed at:", address(dai));
        
        // Mint initial supply to deployer for testing
        uint256 initialMintAmount = 1_000_000; // 1M tokens
        
        weth.mint(deployer, initialMintAmount * 10**18); // 1M WETH
        usdc.mint(deployer, initialMintAmount * 10**6);  // 1M USDC
        wbtc.mint(deployer, initialMintAmount * 10**8);  // 1M WBTC
        dai.mint(deployer, initialMintAmount * 10**18);  // 1M DAI
        
        console2.log("\nInitial supply minted to deployer:");
        console2.log("- WETH:", initialMintAmount, "tokens");
        console2.log("- USDC:", initialMintAmount, "tokens");
        console2.log("- WBTC:", initialMintAmount, "tokens");
        console2.log("- DAI:", initialMintAmount, "tokens");
        
        // Also mint to common test accounts for easy testing
        address[] memory testAccounts = new address[](3);
        testAccounts[0] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Account 1
        testAccounts[1] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // Account 2
        testAccounts[2] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906; // Account 3
        
        uint256 testMintAmount = 10_000; // 10K tokens for testing
        
        for (uint i = 0; i < testAccounts.length; i++) {
            weth.mint(testAccounts[i], testMintAmount * 10**18);
            usdc.mint(testAccounts[i], testMintAmount * 10**6);
            wbtc.mint(testAccounts[i], testMintAmount * 10**8);
            dai.mint(testAccounts[i], testMintAmount * 10**18);
            console2.log("Minted", testMintAmount, "tokens to:", testAccounts[i]);
        }
        
        vm.stopBroadcast();
        
        console2.log("\n=== Token Deployment Complete ===");
        console2.log("All tokens deployed and initial supply distributed");
        console2.log("Ready for frontend integration!");
        
        console2.log("\n=== Update Frontend Config ===");
        console2.log("Update TOKEN_ADDRESSES.localhost in config.ts:");
        console2.log("WETH:", address(weth));
        console2.log("USDC:", address(usdc));
        console2.log("WBTC:", address(wbtc));
        console2.log("DAI:", address(dai));
    }
}
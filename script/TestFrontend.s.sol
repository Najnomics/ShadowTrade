// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {ShadowTradeLimitHook} from "../src/ShadowTradeLimitHook.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {PoolModifyLiquidityTest} from "v4-core/src/test/PoolModifyLiquidityTest.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {Constants} from "v4-core/src/../test/utils/Constants.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/src/types/PoolOperation.sol";

contract TestFrontendScript is Script {
    // Deployed contract addresses
    IPoolManager poolManager = IPoolManager(0x5FbDB2315678afecb367f032d93F642f64180aa3);
    ShadowTradeLimitHook hook = ShadowTradeLimitHook(0x1cC3CBE6469dDc151864B4aFcC7e60d13BB540C0);
    
    // Token addresses
    MockERC20 weth = MockERC20(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0);
    MockERC20 usdc = MockERC20(0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9);
    
    PoolModifyLiquidityTest lpRouter;
    PoolSwapTest swapRouter;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("=== Testing Frontend with Real Transactions ===");
        console2.log("Deployer:", deployer);
        console2.log("Hook:", address(hook));
        console2.log("PoolManager:", address(poolManager));
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy routers for pool interaction
        lpRouter = new PoolModifyLiquidityTest(poolManager);
        swapRouter = new PoolSwapTest(poolManager);
        console2.log("LP Router deployed:", address(lpRouter));
        console2.log("Swap Router deployed:", address(swapRouter));
        
        // Create a pool key
        PoolKey memory poolKey = PoolKey(
            Currency.wrap(address(weth)),
            Currency.wrap(address(usdc)),
            3000, // 0.3% fee
            60,   // tick spacing
            IHooks(address(hook))
        );
        
        // Initialize the pool
        console2.log("Initializing pool...");
        poolManager.initialize(poolKey, Constants.SQRT_PRICE_1_1);
        console2.log("Pool initialized at price 1:1");
        
        // Approve tokens
        weth.approve(address(lpRouter), type(uint256).max);
        usdc.approve(address(lpRouter), type(uint256).max);
        weth.approve(address(swapRouter), type(uint256).max);
        usdc.approve(address(swapRouter), type(uint256).max);
        weth.approve(address(hook), type(uint256).max);
        usdc.approve(address(hook), type(uint256).max);
        
        // Add liquidity
        console2.log("Adding liquidity...");
        int24 tickLower = TickMath.minUsableTick(60);
        int24 tickUpper = TickMath.maxUsableTick(60);
        
        ModifyLiquidityParams memory liqParams = ModifyLiquidityParams(
            tickLower,
            tickUpper,
            1 ether, // 1 unit of liquidity to avoid decimal issues
            0
        );
        
        lpRouter.modifyLiquidity(poolKey, liqParams, "");
        console2.log("Liquidity added successfully");
        
        // Test hook functionality - place a shadow order
        console2.log("\n=== Testing Shadow Order Placement ===");
        
        // This would normally be encrypted, but for testing we'll use mock values
        // In the real frontend, these would be FHE encrypted
        uint256 orderSize = 1 ether; // 1 WETH
        uint256 targetPrice = 2000 * 1e6; // 2000 USDC per WETH
        uint256 expiration = block.timestamp + 1 hours;
        
        console2.log("Placing shadow order:");
        console2.log("- Size:", orderSize);
        console2.log("- Target Price:", targetPrice);
        console2.log("- Expiration:", expiration);
        
        // This is a simplified version - the real frontend would encrypt these values
        // Note: This is just testing the basic setup
        // The actual order placement would require FHE encryption in the frontend
        console2.log("Shadow order placement would happen here with encrypted parameters");
        console2.log("Hook is ready to receive encrypted orders from frontend");
        
        // Test a regular swap to show the hook is working
        console2.log("\n=== Testing Regular Swap (to trigger hook) ===");
        
        SwapParams memory swapParams = SwapParams({
            zeroForOne: true,
            amountSpecified: 0.1 ether,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        
        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        });
        
        swapRouter.swap(poolKey, swapParams, testSettings, "");
        console2.log("Swap executed - hook callbacks triggered");
        
        vm.stopBroadcast();
        
        console2.log("\n=== Frontend Testing Setup Complete ===");
        console2.log("Pool created and initialized");
        console2.log("Liquidity added");
        console2.log("Hook is active and responding");
        console2.log("Routers deployed for pool interactions");
        console2.log("\nFrontend at http://localhost:3001 is ready for testing!");
        console2.log("Connect wallet to Anvil (localhost:8545)");
        console2.log("Use test account:", deployer);
        console2.log("Go to /trade page to place shadow orders");
        
        // Output addresses for frontend reference
        console2.log("\n=== Contract Addresses for Frontend ===");
        console2.log("Hook:", address(hook));
        console2.log("PoolManager:", address(poolManager));
        console2.log("WETH:", address(weth));
        console2.log("USDC:", address(usdc));
        console2.log("LP Router:", address(lpRouter));
        console2.log("Swap Router:", address(swapRouter));
    }
}
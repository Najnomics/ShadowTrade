// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {HybridFHERC20} from "../src/HybridFHERC20.sol";
import {CoFheTest} from "@fhenixprotocol/cofhe-mock-contracts/CoFheTest.sol";
import {FHE, euint128, InEuint128} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

contract HybridFHERC20IntegrationTest is Test, CoFheTest {
    HybridFHERC20 private token;
    
    address private user1 = makeAddr("user1");
    address private user2 = makeAddr("user2");
    address private hook = makeAddr("hook");
    
    uint128 private initialSupply = 1000000 * 10**18;
    
    function setUp() public {
        token = new HybridFHERC20("ShadowTrade Token", "SHT");
        
        // Mint initial supply to user1
        token.mint(user1, initialSupply);
        
        // Create encrypted balance for user1 using the same pattern as working tests
        vm.startPrank(user1);
        InEuint128 memory encryptedAmount = createInEuint128(initialSupply, user1);
        token.mintEncrypted(user1, encryptedAmount);
        vm.stopPrank();
        
        // Initialize user2 with zero encrypted balance
        token.mintEncrypted(user2, FHE.asEuint128(0));
    }
    
    function testBasicFunctionality() public {
        // Test public balance
        assertEq(token.balanceOf(user1), initialSupply);
        assertEq(token.totalSupply(), initialSupply);
        
        // Test encrypted balance exists by checking the hash value
        assertHashValue(token.encBalances(user1), initialSupply);
    }
    
    function testEncryptedTransfer() public {
        uint128 transferAmount = 1000 * 10**18;
        
        // Create encrypted transfer amount
        InEuint128 memory encryptedTransfer = createInEuint128(transferAmount, user1);
        
        // Perform encrypted transfer
        vm.prank(user1);
        token.transferEncrypted(user2, encryptedTransfer);
        
        // Verify balances using hash assertions
        assertHashValue(token.encBalances(user1), initialSupply - transferAmount);
        assertHashValue(token.encBalances(user2), transferAmount);
    }
    
    function testWrapUnwrap() public {
        uint128 wrapAmount = 5000 * 10**18;
        
        // Test wrapping
        token.wrap(user1, wrapAmount);
        
        // Check that public balance decreased
        assertEq(token.balanceOf(user1), initialSupply - wrapAmount);
        
        // Test unwrapping
        InEuint128 memory unwrapAmount = createInEuint128(wrapAmount, user1);
        vm.prank(user1);
        euint128 handle = token.requestUnwrap(user1, unwrapAmount);
        
        // Simulate time passing for decryption
        vm.warp(block.timestamp + 11);
        
        // Get unwrap result
        uint128 unwrappedAmount = token.getUnwrapResult(user1, handle);
        assertEq(unwrappedAmount, wrapAmount);
        
        // Check that public balance increased back
        assertEq(token.balanceOf(user1), initialSupply);
    }
    
    function testHookIntegration() public {
        // Simulate hook operations
        uint128 hookAmount = 10000 * 10**18;
        
        // Hook mints encrypted tokens using user1 as the signer
        vm.startPrank(user1);
        InEuint128 memory encryptedAmount = createInEuint128(hookAmount, user1);
        token.mintEncrypted(hook, encryptedAmount);
        vm.stopPrank();
        
        // Hook transfers to user using user1 as the signer
        vm.startPrank(user1);
        InEuint128 memory transferAmount = createInEuint128(hookAmount, user1);
        token.transferFromEncrypted(hook, user2, transferAmount);
        vm.stopPrank();
        
        // Verify operations completed using hash assertions
        assertHashValue(token.encBalances(hook), 0);
        assertHashValue(token.encBalances(user2), hookAmount);
    }
}

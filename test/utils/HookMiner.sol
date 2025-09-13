// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Vm} from "forge-std/Vm.sol";

library HookMiner {
    // Address of the CREATE2 deployer for deterministic addresses
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    
    /// @notice Mine a salt for a hook address with specific flags
    /// @param deployer The deployer address
    /// @param flags Required hook flags
    /// @param creationCode The contract creation code
    /// @param constructorArgs ABI-encoded constructor arguments
    /// @return salt The mined salt that produces a valid hook address
    function find(
        address deployer,
        uint160 flags,
        bytes memory creationCode,
        bytes memory constructorArgs
    ) internal pure returns (bytes32 salt) {
        bytes memory bytecode = abi.encodePacked(creationCode, constructorArgs);
        
        for (uint256 i = 0; i < 100000; i++) {
            salt = bytes32(i);
            
            address hookAddress = computeCreate2Address(deployer, salt, bytecode);
            
            if (uint160(hookAddress) & flags == flags) {
                return salt;
            }
        }
        
        revert("HookMiner: could not find valid salt");
    }
    
    /// @notice Compute CREATE2 address
    function computeCreate2Address(
        address deployer,
        bytes32 salt,
        bytes memory bytecode
    ) internal pure returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                deployer,
                salt,
                keccak256(bytecode)
            )
        );
        
        return address(uint160(uint256(hash)));
    }
}
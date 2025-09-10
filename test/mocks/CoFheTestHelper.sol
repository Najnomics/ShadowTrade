// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {TaskManager} from "./MockTaskManager.sol";
import {MockCoFHE} from "./MockCoFHE.sol";
import {ACL} from "./ACL.sol";
import {MockZkVerifier} from "./MockZkVerifier.sol";
import {MockZkVerifierSigner} from "./MockZkVerifierSigner.sol";
import {TASK_MANAGER_ADDRESS} from "@fhenixprotocol/cofhe-contracts/FHE.sol";
import {Utils, EncryptedInput, InEuint128, InEuint64, InEuint8, InEbool} from "@fhenixprotocol/cofhe-contracts/ICofhe.sol";

/// @title CoFheTestHelper
/// @notice Simplified helper for FHE testing based on official cofhe-mock-contracts
/// @dev Provides functions to create encrypted inputs for testing
contract CoFheTestHelper is Test {
    TaskManager public taskManager;
    MockCoFHE public mockCoFHE;
    ACL public acl;
    MockZkVerifier public zkVerifier;
    MockZkVerifierSigner public zkVerifierSigner;
    
    address constant TM_ADMIN = address(128);
    address constant ACL_ADDRESS = 0xa6Ea4b5291d044D93b73b3CFf3109A1128663E8B;
    address constant ZK_VERIFIER_ADDRESS = address(256);
    address constant ZK_VERIFIER_SIGNER_ADDRESS = address(257);
    address constant SIGNER_ADDRESS = 0x6E12D8C87503D4287c294f2Fdef96ACd9DFf6bd2;
    
    constructor() {
        setupFhenixMocks();
    }
    
    function setupFhenixMocks() internal {
        // Override chain id to match official CoFheTest
        vm.chainId(420105); // Localfhenix host 1
        
        // Deploy TaskManager
        deployCodeTo("MockTaskManager.sol:TaskManager", TASK_MANAGER_ADDRESS);
        taskManager = TaskManager(TASK_MANAGER_ADDRESS);
        taskManager.initialize(TM_ADMIN);
        
        // Set up TaskManager
        vm.startPrank(TM_ADMIN);
        taskManager.setSecurityZoneMin(0);
        taskManager.setSecurityZoneMax(1);
        taskManager.setVerifierSigner(address(0)); // Disable signature validation for testing
        vm.stopPrank();
        
        // Deploy ACL
        deployCodeTo("ACL.sol:ACL", abi.encode(TM_ADMIN), ACL_ADDRESS);
        acl = ACL(ACL_ADDRESS);
        
        vm.prank(TM_ADMIN);
        taskManager.setACLContract(address(acl));
        
        // Deploy ZK Verifier
        deployCodeTo("MockZkVerifier.sol:MockZkVerifier", ZK_VERIFIER_ADDRESS);
        zkVerifier = MockZkVerifier(ZK_VERIFIER_ADDRESS);
        
        // Deploy ZK Verifier Signer
        deployCodeTo("MockZkVerifierSigner.sol:MockZkVerifierSigner", ZK_VERIFIER_SIGNER_ADDRESS);
        zkVerifierSigner = MockZkVerifierSigner(ZK_VERIFIER_SIGNER_ADDRESS);
        
        // Set up mock CoFHE
        mockCoFHE = MockCoFHE(TASK_MANAGER_ADDRESS);
    }
    
    /// @notice Create an InEuint128 for testing
    function createInEuint128(uint128 value, address sender) public returns (InEuint128 memory) {
        return createInEuint128(value, 0, sender);
    }
    
    /// @notice Create an InEuint128 for testing with security zone
    function createInEuint128(uint128 value, uint8 securityZone, address sender) public returns (InEuint128 memory) {
        EncryptedInput memory input = createEncryptedInput(Utils.EUINT128_TFHE, value, securityZone, sender);
        return abi.decode(abi.encode(input), (InEuint128));
    }
    
    /// @notice Create an InEuint64 for testing
    function createInEuint64(uint64 value, address sender) public returns (InEuint64 memory) {
        return createInEuint64(value, 0, sender);
    }
    
    /// @notice Create an InEuint64 for testing with security zone
    function createInEuint64(uint64 value, uint8 securityZone, address sender) public returns (InEuint64 memory) {
        EncryptedInput memory input = createEncryptedInput(Utils.EUINT64_TFHE, value, securityZone, sender);
        return abi.decode(abi.encode(input), (InEuint64));
    }
    
    /// @notice Create an InEuint8 for testing
    function createInEuint8(uint8 value, address sender) public returns (InEuint8 memory) {
        return createInEuint8(value, 0, sender);
    }
    
    /// @notice Create an InEuint8 for testing with security zone
    function createInEuint8(uint8 value, uint8 securityZone, address sender) public returns (InEuint8 memory) {
        EncryptedInput memory input = createEncryptedInput(Utils.EUINT8_TFHE, value, securityZone, sender);
        return abi.decode(abi.encode(input), (InEuint8));
    }
    
    /// @notice Create an InEbool for testing
    function createInEbool(bool value, address sender) public returns (InEbool memory) {
        return createInEbool(value, 0, sender);
    }
    
    /// @notice Create an InEbool for testing with security zone
    function createInEbool(bool value, uint8 securityZone, address sender) public returns (InEbool memory) {
        EncryptedInput memory input = createEncryptedInput(Utils.EBOOL_TFHE, value ? 1 : 0, securityZone, sender);
        return abi.decode(abi.encode(input), (InEbool));
    }
    
    /// @notice Create encrypted input using official ZK verification and signing
    function createEncryptedInput(
        uint8 utype,
        uint256 value,
        uint8 securityZone,
        address sender
    ) internal returns (EncryptedInput memory input) {
        // Create input using ZK verifier
        input = zkVerifier.zkVerify(
            value,
            utype,
            sender,
            securityZone,
            block.chainid
        );

        // Sign the input
        input = zkVerifierSigner.zkVerifySign(input, sender);
    }
    
    /// @notice Get value from mock storage
    function getValue(uint256 ctHash) public view returns (uint256) {
        return taskManager.mockStorage(ctHash);
    }
    
    /// @notice Check if value exists in mock storage
    function exists(uint256 ctHash) public view returns (bool) {
        return taskManager.inMockStorage(ctHash);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {FHE, euint128, euint64, euint8, euint32, ebool, InEuint128, InEuint64, InEuint8, InEuint32, InEbool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";
import {Utils} from "@fhenixprotocol/cofhe-contracts/ICofhe.sol";

/// @title MockFHE
/// @notice Mock implementation of FHE operations for testing
/// @dev Based on cofhe-mock-contracts patterns, provides deterministic FHE operations for tests
contract MockFHE {
    
    // Storage for encrypted values (ctHash => plaintext value)
    mapping(uint256 => uint256) public mockStorage;
    mapping(uint256 => bool) public inMockStorage;
    
    // Track permissions
    mapping(uint256 => mapping(address => bool)) private _permissions;
    mapping(address => mapping(uint256 => bool)) private _selfPermissions;
    
    // Events for debugging
    event ValueStored(uint256 indexed ctHash, uint256 value, string valueType);
    event PermissionGranted(uint256 indexed ctHash, address indexed account);
    
    // Constants for type encoding (from Utils)
    uint256 constant uintTypeMask = (type(uint8).max >> 1); // 0x7f
    uint256 constant triviallyEncryptedMask = type(uint8).max - uintTypeMask; // 0x80
    uint256 constant shiftedTypeMask = uintTypeMask << 8; // 0x7f00
    
    /// @notice Create ctHash with proper type encoding
    function _createCtHash(uint8 utype, uint256 value) internal pure returns (uint256) {
        // Create a deterministic ctHash based on value and type
        uint256 hash = uint256(keccak256(abi.encode(value, utype, "mock")));
        // Encode the type in the hash
        return (hash & ~shiftedTypeMask) | (uint256(utype) << 8);
    }
    
    /// @notice Get type from ctHash
    function _getUintTypeFromHash(uint256 hash) internal pure returns (uint8) {
        return uint8((hash & shiftedTypeMask) >> 8);
    }
    
    /// @notice Get type mask for value truncation
    function _getUtypeMask(uint256 hash) internal pure returns (uint256) {
        uint8 inputType = _getUintTypeFromHash(hash);
        if (inputType == Utils.EBOOL_TFHE) return (1 << 8) - 1;
        if (inputType == Utils.EUINT8_TFHE) return (1 << 8) - 1;
        if (inputType == Utils.EUINT16_TFHE) return (1 << 16) - 1;
        if (inputType == Utils.EUINT32_TFHE) return (1 << 32) - 1;
        if (inputType == Utils.EUINT64_TFHE) return (1 << 64) - 1;
        if (inputType == Utils.EUINT128_TFHE) return (1 << 128) - 1;
        if (inputType == Utils.EUINT256_TFHE) return type(uint256).max;
        if (inputType == Utils.EADDRESS_TFHE) return (1 << 160) - 1;
        return type(uint256).max;
    }
    
    /// @notice Store value in mock storage
    function _set(uint256 ctHash, uint256 value) internal {
        uint256 mask = _getUtypeMask(ctHash);
        mockStorage[ctHash] = value & mask;
        inMockStorage[ctHash] = true;
    }
    
    /// @notice Get value from mock storage
    function _get(uint256 ctHash) internal view returns (uint256) {
        require(inMockStorage[ctHash], "MockFHE: Value not in storage");
        uint256 mask = _getUtypeMask(ctHash);
        return mockStorage[ctHash] & mask;
    }
    
    /// @notice Mock FHE.allow functionality
    function grantPermission(uint256 ctHash, address account) external {
        _permissions[ctHash][account] = true;
        emit PermissionGranted(ctHash, account);
    }
    
    /// @notice Mock FHE.allowThis functionality
    function grantSelfPermission(address contractAddr, uint256 ctHash) external {
        _selfPermissions[contractAddr][ctHash] = true;
    }
    
    /// @notice Check permission
    function hasPermission(uint256 ctHash, address account) external view returns (bool) {
        return _permissions[ctHash][account];
    }
    
    /// @notice Check self permission
    function hasSelfPermission(address contractAddr, uint256 ctHash) external view returns (bool) {
        return _selfPermissions[contractAddr][ctHash];
    }
    
    /// @notice Create mock euint128 with specific value
    function mockEuint128(uint128 value) external returns (euint128) {
        uint256 ctHash = _createCtHash(Utils.EUINT128_TFHE, value);
        _set(ctHash, value);
        emit ValueStored(ctHash, value, "euint128");
        return euint128.wrap(ctHash);
    }
    
    /// @notice Create mock euint64 with specific value
    function mockEuint64(uint64 value) external returns (euint64) {
        uint256 ctHash = _createCtHash(Utils.EUINT64_TFHE, value);
        _set(ctHash, value);
        emit ValueStored(ctHash, value, "euint64");
        return euint64.wrap(ctHash);
    }
    
    /// @notice Create mock euint8 with specific value
    function mockEuint8(uint8 value) external returns (euint8) {
        uint256 ctHash = _createCtHash(Utils.EUINT8_TFHE, value);
        _set(ctHash, value);
        emit ValueStored(ctHash, value, "euint8");
        return euint8.wrap(ctHash);
    }
    
    /// @notice Create mock euint32 with specific value
    function mockEuint32(uint32 value) external returns (euint32) {
        uint256 ctHash = _createCtHash(Utils.EUINT32_TFHE, value);
        _set(ctHash, value);
        emit ValueStored(ctHash, value, "euint32");
        return euint32.wrap(ctHash);
    }
    
    /// @notice Create mock ebool with specific value
    function mockEbool(bool value) external returns (ebool) {
        uint256 ctHash = _createCtHash(Utils.EBOOL_TFHE, value ? 1 : 0);
        _set(ctHash, value ? 1 : 0);
        emit ValueStored(ctHash, value ? 1 : 0, "ebool");
        return ebool.wrap(ctHash);
    }
    
    /// @notice Create InEuint128 struct for testing
    function mockInEuint128(uint128 value) external returns (InEuint128 memory) {
        uint256 ctHash = _createCtHash(Utils.EUINT128_TFHE, value);
        _set(ctHash, value);
        return InEuint128({
            ctHash: ctHash,
            securityZone: 0,
            utype: Utils.EUINT128_TFHE,
            signature: ""
        });
    }
    
    /// @notice Create InEuint64 struct for testing
    function mockInEuint64(uint64 value) external returns (InEuint64 memory) {
        uint256 ctHash = _createCtHash(Utils.EUINT64_TFHE, value);
        _set(ctHash, value);
        return InEuint64({
            ctHash: ctHash,
            securityZone: 0,
            utype: Utils.EUINT64_TFHE,
            signature: ""
        });
    }
    
    /// @notice Create InEuint8 struct for testing
    function mockInEuint8(uint8 value) external returns (InEuint8 memory) {
        uint256 ctHash = _createCtHash(Utils.EUINT8_TFHE, value);
        _set(ctHash, value);
        return InEuint8({
            ctHash: ctHash,
            securityZone: 0,
            utype: Utils.EUINT8_TFHE,
            signature: ""
        });
    }
    
    /// @notice Create InEuint32 struct for testing
    function mockInEuint32(uint32 value) external returns (InEuint32 memory) {
        uint256 ctHash = _createCtHash(Utils.EUINT32_TFHE, value);
        _set(ctHash, value);
        return InEuint32({
            ctHash: ctHash,
            securityZone: 0,
            utype: Utils.EUINT32_TFHE,
            signature: ""
        });
    }
    
    /// @notice Create InEbool struct for testing
    function mockInEbool(bool value) external returns (InEbool memory) {
        uint256 ctHash = _createCtHash(Utils.EBOOL_TFHE, value ? 1 : 0);
        _set(ctHash, value ? 1 : 0);
        return InEbool({
            ctHash: ctHash,
            securityZone: 0,
            utype: Utils.EBOOL_TFHE,
            signature: ""
        });
    }
    
    /// @notice Get stored value by ctHash
    function getValue(uint256 ctHash) external view returns (uint256) {
        return _get(ctHash);
    }
    
    /// @notice Check if value exists
    function exists(uint256 ctHash) external view returns (bool) {
        return inMockStorage[ctHash];
    }
    
    /// @notice Get all stored values for debugging
    function getAllStoredValues() external view returns (uint256[] memory handles, uint256[] memory values) {
        // This is a simplified version - in practice you'd need to track all stored keys
        handles = new uint256[](0);
        values = new uint256[](0);
    }
    
    /// @notice Mock arithmetic operations using new storage system
    function mockAdd(uint256 lhs, uint256 rhs) external returns (uint256) {
        uint256 result = _get(lhs) + _get(rhs);
        uint256 ctHash = _createCtHash(Utils.EUINT128_TFHE, result);
        _set(ctHash, result);
        return ctHash;
    }
    
    function mockSub(uint256 lhs, uint256 rhs) external returns (uint256) {
        uint256 result = _get(lhs) - _get(rhs);
        uint256 ctHash = _createCtHash(Utils.EUINT128_TFHE, result);
        _set(ctHash, result);
        return ctHash;
    }
    
    function mockMul(uint256 lhs, uint256 rhs) external returns (uint256) {
        uint256 result = _get(lhs) * _get(rhs);
        uint256 ctHash = _createCtHash(Utils.EUINT128_TFHE, result);
        _set(ctHash, result);
        return ctHash;
    }
    
    function mockDiv(uint256 lhs, uint256 rhs) external returns (uint256) {
        uint256 rhsVal = _get(rhs);
        uint256 result = rhsVal == 0 ? type(uint256).max : _get(lhs) / rhsVal;
        uint256 ctHash = _createCtHash(Utils.EUINT128_TFHE, result);
        _set(ctHash, result);
        return ctHash;
    }
    
    /// @notice Mock comparison operations
    function mockLt(uint256 lhs, uint256 rhs) external returns (uint256) {
        bool result = _get(lhs) < _get(rhs);
        uint256 ctHash = _createCtHash(Utils.EBOOL_TFHE, result ? 1 : 0);
        _set(ctHash, result ? 1 : 0);
        return ctHash;
    }
    
    function mockLte(uint256 lhs, uint256 rhs) external returns (uint256) {
        bool result = _get(lhs) <= _get(rhs);
        uint256 ctHash = _createCtHash(Utils.EBOOL_TFHE, result ? 1 : 0);
        _set(ctHash, result ? 1 : 0);
        return ctHash;
    }
    
    function mockGt(uint256 lhs, uint256 rhs) external returns (uint256) {
        bool result = _get(lhs) > _get(rhs);
        uint256 ctHash = _createCtHash(Utils.EBOOL_TFHE, result ? 1 : 0);
        _set(ctHash, result ? 1 : 0);
        return ctHash;
    }
    
    function mockGte(uint256 lhs, uint256 rhs) external returns (uint256) {
        bool result = _get(lhs) >= _get(rhs);
        uint256 ctHash = _createCtHash(Utils.EBOOL_TFHE, result ? 1 : 0);
        _set(ctHash, result ? 1 : 0);
        return ctHash;
    }
    
    function mockEq(uint256 lhs, uint256 rhs) external returns (uint256) {
        bool result = _get(lhs) == _get(rhs);
        uint256 ctHash = _createCtHash(Utils.EBOOL_TFHE, result ? 1 : 0);
        _set(ctHash, result ? 1 : 0);
        return ctHash;
    }
    
    /// @notice Mock logical operations
    function mockAnd(uint256 lhs, uint256 rhs) external returns (uint256) {
        bool result = (_get(lhs) > 0) && (_get(rhs) > 0);
        uint256 ctHash = _createCtHash(Utils.EBOOL_TFHE, result ? 1 : 0);
        _set(ctHash, result ? 1 : 0);
        return ctHash;
    }
    
    function mockOr(uint256 lhs, uint256 rhs) external returns (uint256) {
        bool result = (_get(lhs) > 0) || (_get(rhs) > 0);
        uint256 ctHash = _createCtHash(Utils.EBOOL_TFHE, result ? 1 : 0);
        _set(ctHash, result ? 1 : 0);
        return ctHash;
    }
    
    /// @notice Mock conditional operations
    function mockSelect(uint256 condition, uint256 ifTrue, uint256 ifFalse) external returns (uint256) {
        uint256 result = _get(condition) > 0 ? _get(ifTrue) : _get(ifFalse);
        uint256 ctHash = _createCtHash(Utils.EUINT128_TFHE, result);
        _set(ctHash, result);
        return ctHash;
    }
    
    function mockMin(uint256 lhs, uint256 rhs) external returns (uint256) {
        uint256 lhsVal = _get(lhs);
        uint256 rhsVal = _get(rhs);
        uint256 result = lhsVal < rhsVal ? lhsVal : rhsVal;
        uint256 ctHash = _createCtHash(Utils.EUINT128_TFHE, result);
        _set(ctHash, result);
        return ctHash;
    }
    
    function mockMax(uint256 lhs, uint256 rhs) external returns (uint256) {
        uint256 lhsVal = _get(lhs);
        uint256 rhsVal = _get(rhs);
        uint256 result = lhsVal > rhsVal ? lhsVal : rhsVal;
        uint256 ctHash = _createCtHash(Utils.EUINT128_TFHE, result);
        _set(ctHash, result);
        return ctHash;
    }
}
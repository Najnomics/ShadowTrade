// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {FHE, euint128, euint64, euint8, euint32, ebool, InEuint128, InEuint64, InEuint8, InEuint32, InEbool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

/// @title SimpleFHEMock
/// @notice Simple mock for FHE operations that bypasses the CoFHE coprocessor
/// @dev This is a workaround for testing without a full CoFHE setup
contract SimpleFHEMock {
    
    // Storage for mock values
    mapping(uint256 => uint256) private _values;
    mapping(uint256 => bool) private _exists;
    
    // Events for debugging
    event MockOperation(string operation, uint256 input, uint256 result);
    
    /// @notice Mock FHE.add operation
    function mockAdd(uint256 a, uint256 b) external returns (uint256) {
        uint256 result = _getValue(a) + _getValue(b);
        uint256 handle = _storeValue(result);
        emit MockOperation("add", a, result);
        return handle;
    }
    
    /// @notice Mock FHE.sub operation
    function mockSub(uint256 a, uint256 b) external returns (uint256) {
        uint256 result = _getValue(a) - _getValue(b);
        uint256 handle = _storeValue(result);
        emit MockOperation("sub", a, result);
        return handle;
    }
    
    /// @notice Mock FHE.mul operation
    function mockMul(uint256 a, uint256 b) external returns (uint256) {
        uint256 result = _getValue(a) * _getValue(b);
        uint256 handle = _storeValue(result);
        emit MockOperation("mul", a, result);
        return handle;
    }
    
    /// @notice Mock FHE.div operation
    function mockDiv(uint256 a, uint256 b) external returns (uint256) {
        uint256 bVal = _getValue(b);
        uint256 result = bVal == 0 ? type(uint256).max : _getValue(a) / bVal;
        uint256 handle = _storeValue(result);
        emit MockOperation("div", a, result);
        return handle;
    }
    
    /// @notice Mock FHE.gt operation
    function mockGt(uint256 a, uint256 b) external returns (uint256) {
        bool result = _getValue(a) > _getValue(b);
        uint256 handle = _storeValue(result ? 1 : 0);
        emit MockOperation("gt", a, result ? 1 : 0);
        return handle;
    }
    
    /// @notice Mock FHE.gte operation
    function mockGte(uint256 a, uint256 b) external returns (uint256) {
        bool result = _getValue(a) >= _getValue(b);
        uint256 handle = _storeValue(result ? 1 : 0);
        emit MockOperation("gte", a, result ? 1 : 0);
        return handle;
    }
    
    /// @notice Mock FHE.lt operation
    function mockLt(uint256 a, uint256 b) external returns (uint256) {
        bool result = _getValue(a) < _getValue(b);
        uint256 handle = _storeValue(result ? 1 : 0);
        emit MockOperation("lt", a, result ? 1 : 0);
        return handle;
    }
    
    /// @notice Mock FHE.lte operation
    function mockLte(uint256 a, uint256 b) external returns (uint256) {
        bool result = _getValue(a) <= _getValue(b);
        uint256 handle = _storeValue(result ? 1 : 0);
        emit MockOperation("lte", a, result ? 1 : 0);
        return handle;
    }
    
    /// @notice Mock FHE.eq operation
    function mockEq(uint256 a, uint256 b) external returns (uint256) {
        bool result = _getValue(a) == _getValue(b);
        uint256 handle = _storeValue(result ? 1 : 0);
        emit MockOperation("eq", a, result ? 1 : 0);
        return handle;
    }
    
    /// @notice Mock FHE.and operation
    function mockAnd(uint256 a, uint256 b) external returns (uint256) {
        bool result = (_getValue(a) > 0) && (_getValue(b) > 0);
        uint256 handle = _storeValue(result ? 1 : 0);
        emit MockOperation("and", a, result ? 1 : 0);
        return handle;
    }
    
    /// @notice Mock FHE.or operation
    function mockOr(uint256 a, uint256 b) external returns (uint256) {
        bool result = (_getValue(a) > 0) || (_getValue(b) > 0);
        uint256 handle = _storeValue(result ? 1 : 0);
        emit MockOperation("or", a, result ? 1 : 0);
        return handle;
    }
    
    /// @notice Mock FHE.select operation
    function mockSelect(uint256 condition, uint256 ifTrue, uint256 ifFalse) external returns (uint256) {
        uint256 result = _getValue(condition) > 0 ? _getValue(ifTrue) : _getValue(ifFalse);
        uint256 handle = _storeValue(result);
        emit MockOperation("select", condition, result);
        return handle;
    }
    
    /// @notice Mock FHE.min operation
    function mockMin(uint256 a, uint256 b) external returns (uint256) {
        uint256 aVal = _getValue(a);
        uint256 bVal = _getValue(b);
        uint256 result = aVal < bVal ? aVal : bVal;
        uint256 handle = _storeValue(result);
        emit MockOperation("min", a, result);
        return handle;
    }
    
    /// @notice Mock FHE.max operation
    function mockMax(uint256 a, uint256 b) external returns (uint256) {
        uint256 aVal = _getValue(a);
        uint256 bVal = _getValue(b);
        uint256 result = aVal > bVal ? aVal : bVal;
        uint256 handle = _storeValue(result);
        emit MockOperation("max", a, result);
        return handle;
    }
    
    /// @notice Mock FHE.cast operation
    function mockCast(uint256 input, uint8 toType) external returns (uint256) {
        uint256 result = _getValue(input);
        uint256 handle = _storeValue(result);
        emit MockOperation("cast", input, result);
        return handle;
    }
    
    /// @notice Mock FHE.trivialEncrypt operation
    function mockTrivialEncrypt(uint256 value, uint8 toType) external returns (uint256) {
        uint256 handle = _storeValue(value);
        emit MockOperation("trivialEncrypt", value, value);
        return handle;
    }
    
    /// @notice Mock FHE.decrypt operation
    function mockDecrypt(uint256 input) external returns (uint256) {
        uint256 result = _getValue(input);
        emit MockOperation("decrypt", input, result);
        return result;
    }
    
    /// @notice Mock FHE.getDecryptResult operation
    function mockGetDecryptResult(uint256 input) external view returns (uint256) {
        return _getValue(input);
    }
    
    /// @notice Mock FHE.getDecryptResultSafe operation
    function mockGetDecryptResultSafe(uint256 input) external view returns (uint256, bool) {
        if (_exists[input]) {
            return (_getValue(input), true);
        }
        return (0, false);
    }
    
    /// @notice Mock FHE.allow operation
    function mockAllow(uint256 ctHash, address account) external {
        // For testing, we'll just emit an event
        emit MockOperation("allow", ctHash, uint256(uint160(account)));
    }
    
    /// @notice Mock FHE.allowThis operation
    function mockAllowThis(uint256 ctHash) external {
        // For testing, we'll just emit an event
        emit MockOperation("allowThis", ctHash, 0);
    }
    
    /// @notice Store a value and return a handle
    function _storeValue(uint256 value) internal returns (uint256) {
        uint256 handle = uint256(keccak256(abi.encode(value, block.timestamp, msg.sender)));
        _values[handle] = value;
        _exists[handle] = true;
        return handle;
    }
    
    /// @notice Get a value by handle
    function _getValue(uint256 handle) internal view returns (uint256) {
        if (_exists[handle]) {
            return _values[handle];
        }
        // If not found, return the handle itself (for testing)
        return handle;
    }
    
    /// @notice Get all stored values for debugging
    function getAllValues() external view returns (uint256[] memory handles, uint256[] memory values) {
        // This is a simplified version - in practice you'd need to track all stored keys
        handles = new uint256[](0);
        values = new uint256[](0);
    }
}

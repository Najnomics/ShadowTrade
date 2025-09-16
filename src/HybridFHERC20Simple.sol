// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IFHERC20} from "./interface/IFHERC20.sol";
import {InEuint128, euint128} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

/**
 * @dev Simple version of HybridFHERC20 that can be deployed without FHE infrastructure
 * This version only implements the public ERC20 functionality
 * FHE functionality can be added later when the FHE infrastructure is available
 */
contract HybridFHERC20Simple is ERC20, IFHERC20 {

    //errors
    error HybridFHERC20__InvalidSender();
    error HybridFHERC20__InvalidReceiver();

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        // No FHE initialization in constructor
    }

    // ----------- Public Mint Functions --------------------
    function mint(address user, uint256 amount) public {
        _mint(user, amount);
    }

    // ----------- Public Burn Functions --------------------
    function burn(address user, uint256 amount) public {
        _burn(user, amount);
    }

    // ----------- Encrypted Mint Functions -----------------
    // These functions will revert until FHE infrastructure is deployed
    function mintEncrypted(address user, InEuint128 memory amount) public pure {
        revert("FHE infrastructure not available");
    }

    function mintEncrypted(address user, euint128 amount) public pure {
        revert("FHE infrastructure not available");
    }

    // ----------- Encrypted Burn Functions -----------------
    function burnEncrypted(address user, InEuint128 memory amount) public pure {
        revert("FHE infrastructure not available");
    }

    function burnEncrypted(address user, euint128 amount) public pure {
        revert("FHE infrastructure not available");
    }

    // ----------- Encrypted Transfer Functions ---------------
    function transferEncrypted(address to, InEuint128 memory amount) external pure returns(euint128) {
        revert("FHE infrastructure not available");
    }

    function transferEncrypted(address to, euint128 amount) external pure returns(euint128) {
        revert("FHE infrastructure not available");
    }

    function transferFromEncrypted(address from, address to, InEuint128 memory amount) external pure returns(euint128) {
        revert("FHE infrastructure not available");
    }

    function transferFromEncrypted(address from, address to, euint128 amount) external pure returns(euint128) {
        revert("FHE infrastructure not available");
    }

    // --------- Decrypt Balance Functions ------------------
    function decryptBalance(address user) public pure {
        revert("FHE infrastructure not available");
    }

    function getDecryptBalanceResult(address user) public pure returns(uint128) {
        revert("FHE infrastructure not available");
    }

    function getDecryptBalanceResultSafe(address user) public pure returns(uint128, bool) {
        revert("FHE infrastructure not available");
    }

    // --------- Encrypted Wrapping Functions ---------------
    function wrap(address user, uint128 amount) external pure {
        revert("FHE infrastructure not available");
    }

    // --------- Encrypted Unwrapping Functions ---------------
    function requestUnwrap(address user, InEuint128 memory amount) external pure returns(euint128) {
        revert("FHE infrastructure not available");
    }

    function requestUnwrap(address user, euint128 amount) external pure returns(euint128) {
        revert("FHE infrastructure not available");
    }

    function getUnwrapResult(address user, euint128 burnAmount) external pure returns(uint128 amount) {
        revert("FHE infrastructure not available");
    }

    function getUnwrapResultSafe(address user, euint128 burnAmount) external pure returns(uint128 amount, bool decrypted) {
        revert("FHE infrastructure not available");
    }

    // --------- View for encrypted balances --------
    function encBalances(address user) external pure returns (euint128) {
        revert("FHE infrastructure not available");
    }
}

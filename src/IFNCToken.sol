// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IFNCToken
 * @notice Interface for FNCToken contract with role-based access control, minting limits, and a fixed maximum supply.
 */
interface IFNCToken {

    function mint(address to, uint256 amount) external;
    function grantMinterRoleWithLimit(address account, uint256 limit) external;
    function updateMintLimit(address account, uint256 newLimit) external;
    function revokeMinterRole(address account) external;
    function burn(uint256 amount) external;
    function transferAdminRole(address newAdmin) external;

    // Event declarations
    event MinterRoleGranted(address indexed account, uint256 limit);
    event MinterRoleRevoked(address indexed account);
    event MintLimitUpdated(address indexed account, uint256 newLimit);
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(uint256 amount);
    event AdminRoleTransferred(address indexed previousAdmin, address indexed newAdmin);
}

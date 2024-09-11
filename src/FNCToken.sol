// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title FNCToken
 * @author UrukHan
 * @notice This contract implements an ERC20 token with role-based access control for minting, minting limits per minter, and a fixed maximum supply.
 * The contract uses the Gnosis Safe multisig for admin control and role management, ensuring secure and decentralized control over minting operations.
 * Admins have the ability to grant and revoke minter roles, update minting limits, and transfer the admin role to other addresses.
 */

/**
 * Library Imports
 */
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// Custom Errors for gas optimization
error OnlyAdmin();
error OnlyMinter();
error MintLimitExceeded(uint256 limit, uint256 requested);
error InsufficientBalance();
error MaxSupplyExceeded();

/**
 * @title FNCToken
 * @dev This contract extends the ERC20 token standard with additional role-based functionality. The minting of tokens is restricted to accounts
 * with the MINTER_ROLE, and each minter has an associated minting limit to prevent over-minting. The total supply is capped by a predefined max supply.
 * The admin role can be transferred to another address (e.g., a Gnosis Safe multisig) to decentralize control over the token.
 */
contract FNCToken is ERC20, AccessControl {

    // Role Definitions
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Minting Limits and Max Supply
    uint256 public immutable s_maxSupply;
    mapping(address => uint256) public s_mintLimits;
    mapping(address => uint256) public s_mintedAmounts;
    address public s_admin;

    /**
     * @dev Deploys the contract with a max supply and sets up initial roles for the deployer.
     * Admins can later transfer their role to Gnosis Safe or any other contract.
     * @param name Token name (e.g., "FNCToken").
     * @param symbol Token symbol (e.g., "FNC").
     * @param maxSupply The maximum supply of tokens that can ever be minted.
     */
    constructor(string memory name, string memory symbol, uint256 maxSupply) ERC20(name, symbol) {
        require(maxSupply > 0, "Max supply must be greater than 0");
        s_maxSupply = maxSupply;
        s_admin = msg.sender;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

    }

    /////////////////////
    // Functions
    /////////////////////

    /**
     * @dev Mints new tokens to the specified address, with a check on the max supply.
     * Can only be called by accounts with the MINTER_ROLE and within their minting limit.
     * @param to The address receiving the newly minted tokens.
     * @param amount The number of tokens to mint.
     */
    function mint(address to, uint256 amount) public {
        if (!hasRole(MINTER_ROLE, msg.sender)) {
            revert OnlyMinter();
        }

        uint256 _availableLimit = s_mintLimits[msg.sender] - s_mintedAmounts[msg.sender];
        if (amount > _availableLimit) {
            revert MintLimitExceeded(_availableLimit, amount);
        }

        // Ensure the new minting doesn't exceed the max supply
        if (totalSupply() + amount > s_maxSupply) {
            revert MaxSupplyExceeded();
        }

        s_mintedAmounts[msg.sender] += amount;
        _mint(to, amount);
    }

    /**
     * @dev Grants the MINTER_ROLE to a specified account with a minting limit.
     * Can only be called by the Gnosis Safe admin contract.
     * @param account The address to grant the MINTER_ROLE.
     * @param limit The maximum number of tokens this minter is allowed to mint.
     */
    function grantMinterRoleWithLimit(address account, uint256 limit) public {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert OnlyAdmin();
        }
        grantRole(MINTER_ROLE, account);
        s_mintLimits[account] = limit;
    }

    /**
     * @dev Updates the minting limit for an existing minter.
     * Can only be called by the Gnosis Safe admin contract.
     * @param account The minter's address.
     * @param newLimit The new minting limit for this minter.
     */
    function updateMintLimit(address account, uint256 newLimit) public {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert OnlyAdmin();
        }
        require(hasRole(MINTER_ROLE, account), "Account is not a minter");
        s_mintLimits[account] = newLimit;
    }

    /**
     * @dev Revokes the MINTER_ROLE and resets the minting limit for a specific account.
     * Can only be called by the Gnosis Safe admin contract.
     * @param account The address whose MINTER_ROLE will be revoked.
     */
    function revokeMinterRole(address account) public {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert OnlyAdmin();
        }
        revokeRole(MINTER_ROLE, account);
        s_mintLimits[account] = 0;
        s_mintedAmounts[account] = 0;
    }

    /**
     * @dev Burns tokens.
     * Can only be called by the Gnosis Safe admin contract.
     * @param amount The number of tokens to burn.
     */
    function burn(uint256 amount) public {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert OnlyAdmin();
        }
        if (balanceOf(address(this)) < amount) {
            revert InsufficientBalance();
        }
        _burn(address(this), amount);
    }

    /**
     * @dev Transfers admin role to a new address, such as a Gnosis Safe.
     * Can only be called by the current admin.
     * @param newAdmin The address of the new admin (e.g., Gnosis Safe).
     */
    function transferAdminRole(address newAdmin) public {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert OnlyAdmin();
        }
        _grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
        _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
}

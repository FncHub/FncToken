// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title FNCToken
 * @author UrukHan
 * @notice This contract extends the ERC20 token standard with:
 * - A fixed maximum supply (s_maxSupply)
 * - Role-based access control (MINTER_ROLE, BURNER_ROLE, and DEFAULT_ADMIN_ROLE)
 * - Each minter has a one-time limit. Once assigned, the tokens are "reserved".
 * - Minter limits + totalAssigned cannot exceed maxSupply.
 * - No revocation or update of minter limits is allowed (for fairness).
 */

/**
 * Library Imports
 */
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IFNCToken.sol";

// Custom Errors for gas optimization
error OnlyAdmin();
error OnlyBurner();
error OnlyMinter();
error MintLimitExceeded(uint256 limit, uint256 requested);
error InsufficientBalance();
error MaxSupplyExceeded();
error NotEnoughUnreservedSupply(uint256 requested, uint256 available);


/**
 * @title FNCToken
 * @dev This contract extends the ERC20 token standard with additional role-based functionality. The minting of tokens is restricted to accounts
 * with the MINTER_ROLE, and each minter has an associated minting limit to prevent over-minting. The total supply is capped by a predefined max supply.
 * The admin role can be transferred to another address (e.g., a Gnosis Safe multisig) to decentralize control over the token.
 */
contract FNCToken is ERC20, AccessControl, IFNCToken {

    // Role Definitions
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // Minting Limits and Max Supply
    uint256 public immutable s_maxSupply;
    mapping(address => uint256) public s_mintLimits;
    mapping(address => uint256) public s_mintedAmounts;
    uint256 public s_totalAssigned;
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
     * @dev Mints new tokens to the specified address, respecting both
     * the minter's personal limit and the global max supply.
     * @param to The address receiving newly minted tokens.
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

        emit TokensMinted(to, amount);
    }

    /**
     * @dev Grants the MINTER_ROLE to a specified account and "reserves" tokens for it.
     *      Once assigned, the limit cannot be revoked or updated.
     * @param account The minter address.
     * @param limit The maximum tokens this minter may mint.
     */
    function grantMinterRoleWithLimit(address account, uint256 limit) public {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert OnlyAdmin();
        }

        uint256 previousLimit = s_mintLimits[account];
        uint256 newLimit = previousLimit + limit;

        if (s_totalAssigned + limit > s_maxSupply) {
            revert NotEnoughUnreservedSupply(limit, s_maxSupply - s_totalAssigned);
        }

        _grantRole(MINTER_ROLE, account);
        s_mintLimits[account] = newLimit;
        s_totalAssigned += limit;

        emit MinterRoleGranted(account, newLimit);
    }

    /**
     * @dev Grants the BURNER_ROLE to a specified account, enabling burn().
     * @param account The address to become burner.
     */
    function grantBurnerRole(address account) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert OnlyAdmin();
        }
        _grantRole(BURNER_ROLE, account);
        emit BurnerRoleGranted(account);
    }

    /**
     * @dev Revokes the BURNER_ROLE from an account.
     * @param account The address losing burner status.
     */
    function revokeBurnerRole(address account) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert OnlyAdmin();
        }
        _revokeRole(BURNER_ROLE, account);
        emit BurnerRoleRevoked(account);
    }


    /**
     * @dev Burns tokens from the caller. Caller must have BURNER_ROLE.
     * @param amount The number of tokens to burn.
     */
    function burn(uint256 amount) external {
        if (!hasRole(BURNER_ROLE, msg.sender)) {
            revert OnlyBurner();
        }
        if (balanceOf(msg.sender) < amount) {
            revert InsufficientBalance();
        }
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount);
    }

    /**
     * @dev Transfers the admin role (DEFAULT_ADMIN_ROLE) to a new address (e.g. Gnosis Safe).
     * @param newAdmin The address of the new admin.
     */
    function transferAdminRole(address newAdmin) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert OnlyAdmin();
        }
        _grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
        _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);

        emit AdminRoleTransferred(msg.sender, newAdmin);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * Library Imports
 */
import {Test, console} from "forge-std/Test.sol";
import {FNCToken} from "../../src/FNCToken.sol";
import {DeployFNCToken} from "../../script/deployments/DeployFNCToken.s.sol";
import {DeploySafeFactory} from "../../script/deployments/DeploySafeFactory.s.sol";
import {DeploySafe} from "../../script/deployments/DeploySafe.s.sol";
import {DeploySafeProxy} from "../../script/deployments/DeploySafeProxy.s.sol";
import {Safe} from "@gnosis.pm/safe-contracts/contracts/Safe.sol";
import {Enum} from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import {SafeProxy} from "@gnosis.pm/safe-contracts/contracts/proxies/SafeProxy.sol";
import {SafeProxyFactory} from "@gnosis.pm/safe-contracts/contracts/proxies/SafeProxyFactory.sol";
// Utility for encoding/decoding JSON addresses
import "../../script/utils/EncodeDecode.s.sol";
import "../../script/utils/Format.s.sol";


/**
 * @title FNCTokenTest
 * @dev This test contract is designed to test the core functionality of the FNCToken contract, including
 *      minting, burning, role management, and Gnosis Safe multisig interactions. The contract follows a structured
 *      approach for deploying and testing with Safe and token interactions.
 */
contract FNCTokenTest is Test {
    // Storage variables
    FNCToken s_token;
    Safe s_safeSingleton;
    SafeProxyFactory s_safeFactory;
    address s_safe;

    uint256 s_maxSupply = 1000000000 * 10**18;
    uint256 s_requiredConfirmations = 2;

    address s_deployer = vm.addr(1);
    address s_minter = vm.addr(2);
    address s_user = vm.addr(3);
    address s_burner = vm.addr(4);

    address s_adminFirst;
    address s_adminSecond;
    address s_adminThird;
    uint256 s_adminFirstPrivateKey;
    uint256 s_adminSecondPrivateKey;
    uint256 s_adminThirdPrivateKey;

    /////////////////////
    // Initialization
    /////////////////////

    /**
     * @dev Sets up the initial environment, including deploying Gnosis Safe, Proxy, and FNCToken contracts.
     *      Admin addresses are generated, and admin roles are transferred to the Safe.
     */
    function setUp() external {
        // Generate admin addresses and private keys
        (s_adminFirst, s_adminFirstPrivateKey) = makeAddrAndKey("adminFirst");
        (s_adminSecond, s_adminSecondPrivateKey) = makeAddrAndKey("adminSecond");
        (s_adminThird, s_adminThirdPrivateKey) = makeAddrAndKey("adminThird");

        string memory owners = EncodeDecode.encodeAddressArray(s_adminFirst, s_adminSecond, s_adminThird);

        // Step 1: Deploy Gnosis Safe singleton
        DeploySafe _safeDeployment = new DeploySafe();
        s_safeSingleton = _safeDeployment.run();

        // Step 2: Deploy Gnosis Safe Proxy Factory
        DeploySafeFactory _safeFactoryDeployment = new DeploySafeFactory();
        s_safeFactory = _safeFactoryDeployment.run();

        // Step 3: Deploy SafeProxy using the Safe singleton and owners, along with FallbackHandler
        DeploySafeProxy _safeProxyDeployment = new DeploySafeProxy();
        s_safe = address(_safeProxyDeployment.run(
            address(s_safeFactory),
            address(s_safeSingleton),
            owners,
            s_requiredConfirmations
        ));

        // Step 4: Deploy FNCToken
        DeployFNCToken _fncTokenDeployment = new DeployFNCToken();
        s_token = _fncTokenDeployment.run("FNCToken", "FNC", s_maxSupply);

        // Step 5: Transfer admin role to the Gnosis Safe
        s_token.transferAdminRole(s_safe);
    }

    /////////////////////
    // Tests
    /////////////////////

    /**
     * @dev Tests the process of granting the minter role to an address with a specific minting limit.
     *      It ensures that the transaction requires multiple signatures for execution and checks both success and failure scenarios.
     */
    function testGrantMinterRoleTokens() public {
        bytes memory _data = abi.encodeWithSelector(
            s_token.grantMinterRoleWithLimit.selector,
            s_minter,
            500 * 10**18
        );

        // Check with one signature (should revert)
        address[] memory _singleAdmin = new address[](1);
        _singleAdmin[0] = s_adminFirst;
        uint256[] memory _singleKey = new uint256[](1);
        _singleKey[0] = s_adminFirstPrivateKey;
        string memory revertWith = "GS020";
        executeTransactionRevertWith(_data, _singleAdmin, _singleKey, revertWith);

        // Check with two signatures (should succeed)
        address[] memory _twoAdmins = new address[](2);
        _twoAdmins[0] = s_adminFirst;
        _twoAdmins[1] = s_adminSecond;
        uint256[] memory _twoKeys = new uint256[](2);
        _twoKeys[0] = s_adminFirstPrivateKey;
        _twoKeys[1] = s_adminSecondPrivateKey;
        executeTransaction(_data, _twoAdmins, _twoKeys);

        assertEq(s_token.hasRole(s_token.MINTER_ROLE(), s_minter), true);
        assertEq(s_token.s_mintLimits(s_minter), 500 * 10**18);
    }

    /**
     * @dev Tests the minting process for the minter and ensures that the minting limit is respected.
     *      It also checks the revert case when minting exceeds the limit.
     */
    function testMintTokens() external {
        testGrantMinterRoleTokens();

        // Minter starts minting tokens
        vm.startPrank(s_minter);
        s_token.mint(s_user, 200 * 10**18);
        vm.stopPrank();

        // Check user balance
        assertEq(s_token.balanceOf(s_user), 200 * 10**18);

        // Check minting limit enforcement
        vm.startPrank(s_minter);
        vm.expectRevert(
            abi.encodeWithSignature(
                "MintLimitExceeded(uint256,uint256)",
                300 * 10**18,
                400 * 10**18
            )
        );
        s_token.mint(s_user, 400 * 10**18);
        vm.stopPrank();
    }

    /**
     * @dev Tests the process of assigning the burner role to an address.
     *      Ensures that multiple signatures are required to complete a transaction, and tests both success and failure scenarios.
     */
    function testGrantBurnerRole() public {
        bytes memory _data = abi.encodeWithSelector(
            s_token.grantBurnerRole.selector,
            s_burner
        );

        // Check with one signature (should revert)
        address[] memory _singleAdmin = new address[](1);
        _singleAdmin[0] = s_adminFirst;
        uint256[] memory _singleKey = new uint256[](1);
        _singleKey[0] = s_adminFirstPrivateKey;
        string memory revertWith = "GS020";
        executeTransactionRevertWith(_data, _singleAdmin, _singleKey, revertWith);

        // Check with two signatures (should succeed)
        address[] memory _twoAdmins = new address[](2);
        _twoAdmins[0] = s_adminFirst;
        _twoAdmins[1] = s_adminSecond;
        uint256[] memory _twoKeys = new uint256[](2);
        _twoKeys[0] = s_adminFirstPrivateKey;
        _twoKeys[1] = s_adminSecondPrivateKey;
        executeTransaction(_data, _twoAdmins, _twoKeys);

        assertTrue(s_token.hasRole(s_token.BURNER_ROLE(), s_burner));
    }

    /**
     * @dev Tests the process of burning tokens from the burner balance.
     *      Makes sure that the burning works correctly and checks the limits.
     */
    function testBurnTokensFromBurner() external {
        // Step 1: Assign the burner role
        testGrantBurnerRole();

        // Step 2: Grant minter role to mint tokens to burner
        testGrantMinterRoleTokens();

        // Step 3: Transfer tokens to the burner address
        vm.startPrank(s_minter);
        s_token.mint(s_burner, 500 * 10**18);
        vm.stopPrank();

        // Checking the balance of the burner
        assertEq(s_token.balanceOf(s_burner), 500 * 10**18);

        // Step 4: The burner burns tokens from its balance
        vm.startPrank(s_burner);
        s_token.burn(300 * 10**18);
        vm.stopPrank();

        // Step 5: Check that the tokens have been burned
        assertEq(s_token.balanceOf(s_burner), 200 * 10**18);

        // Step 6: Check the balance limit
        vm.startPrank(s_burner);
        vm.expectRevert(abi.encodeWithSignature("InsufficientBalance()"));
        s_token.burn(500 * 10**18);
        vm.stopPrank();
    }


    /**
     * @dev Tests revocation of the burner role from an address. After revocation of the role, burning should be rejected.
     */
    function testRevokeBurnerRole() external {
        // Step 1: Assign the burner role
        testGrantBurnerRole();

        // Step 2: Prepare data for the revokeBurnerRole function
        bytes memory _data = abi.encodeWithSelector(
            s_token.revokeBurnerRole.selector,
            s_burner
        );

        // Execute transaction with two signatures to revoke the burner role
        address[] memory _twoAdmins = new address[](2);
        _twoAdmins[0] = s_adminFirst;
        _twoAdmins[1] = s_adminSecond;
        uint256[] memory _twoKeys = new uint256[](2);
        _twoKeys[0] = s_adminFirstPrivateKey;
        _twoKeys[1] = s_adminSecondPrivateKey;
        executeTransaction(_data, _twoAdmins, _twoKeys);

        // Step 3: Make sure the burner role is revoked
        assertFalse(s_token.hasRole(s_token.BURNER_ROLE(), s_burner));

        // Step 4: Check that burning now reverts
        vm.startPrank(s_burner);
        vm.expectRevert(abi.encodeWithSignature("OnlyBurner()"));
        s_token.burn(100 * 10**18);
        vm.stopPrank();
    }


    /**
     * @dev Tests transferring the admin role to a new address.
     *      This ensures the admin rights are fully transferred and the current admins lose their privileges.
     */
    function testTransferAdminRole() external {
        // Step 1: Prepare data for transferAdminRole function
        bytes memory _data = abi.encodeWithSelector(
            s_token.transferAdminRole.selector,
            s_deployer // Transfer role to deployer
        );

        // Execute transaction with two signatures to transfer admin role
        address[] memory _twoAdmins = new address[](2);
        _twoAdmins[0] = s_adminFirst;
        _twoAdmins[1] = s_adminSecond;
        uint256[] memory _twoKeys = new uint256[](2);
        _twoKeys[0] = s_adminFirstPrivateKey;
        _twoKeys[1] = s_adminSecondPrivateKey;
        executeTransaction(_data, _twoAdmins, _twoKeys);

        // Step 2: Verify that admin role is transferred to deployer
        assertEq(s_token.hasRole(s_token.DEFAULT_ADMIN_ROLE(), s_deployer), true);

        // Verify that current admins lost their rights
        assertEq(s_token.hasRole(s_token.DEFAULT_ADMIN_ROLE(), s_adminFirst), false);
        assertEq(s_token.hasRole(s_token.DEFAULT_ADMIN_ROLE(), s_adminSecond), false);
    }

    /////////////////////
    // Utility Functions
    /////////////////////

    /**
     * @dev Executes a Gnosis Safe transaction using valid admin signatures.
     * @param data The encoded function call data.
     * @param admins The list of admin addresses for signing the transaction.
     * @param privateKeys The list of private keys corresponding to the admin addresses.
     */
    function executeTransaction(bytes memory data, address[] memory admins, uint256[] memory privateKeys) internal {
        Safe _safeContract = Safe(payable(s_safe));

        // Get transaction hash
        bytes32 txHash = _safeContract.getTransactionHash(
            address(s_token),
            0, // value
            data,
            Enum.Operation.Call,
            0, // safeTxGas
            0, // baseGas
            0, // gasPrice
            address(0), // gasToken
            payable(address(0)), // refundReceiver
            _safeContract.nonce()
        );
        console.log("Data: ", Format.bytes32ToHexString(txHash));
        // Get valid signatures
        bytes memory _signatures = getSignatures(txHash, admins, privateKeys);

        // Execute transaction through Safe
        _safeContract.execTransaction(
            address(s_token),
            0, // value
            data,
            Enum.Operation.Call,
            0, // safeTxGas
            0, // baseGas
            0, // gasPrice,
            address(0), // gasToken,
            payable(address(0)),  // refundReceiver,
            _signatures
        );
    }

    /**
     * @dev Executes a Gnosis Safe transaction expecting it to revert with a specific reason.
     * @param data The encoded function call data.
     * @param admins The list of admin addresses for signing the transaction.
     * @param privateKeys The list of private keys corresponding to the admin addresses.
     * @param revertWith The expected revert reason string.
     */
    function executeTransactionRevertWith(bytes memory data, address[] memory admins, uint256[] memory privateKeys, string memory revertWith) internal {
        Safe _safeContract = Safe(payable(s_safe));

        // Get transaction hash
        bytes32 txHash = _safeContract.getTransactionHash(
            address(s_token),
            0, // value
            data,
            Enum.Operation.Call,
            0, // safeTxGas
            0, // baseGas
            0, // gasPrice
            address(0), // gasToken
            payable(address(0)), // refundReceiver
            _safeContract.nonce()
        );

        // Get valid signatures
        bytes memory _signatures = getSignatures(txHash, admins, privateKeys);

        // Execute transaction through Safe
        vm.expectRevert(bytes(revertWith));
        _safeContract.execTransaction(
            address(s_token),
            0, // value
            data,
            Enum.Operation.Call,
            0, // safeTxGas
            0, // baseGas
            0, // gasPrice,
            address(0), // gasToken,
            payable(address(0)),  // refundReceiver,
            _signatures
        );
    }

    /**
     * @dev Generates the signatures for the Gnosis Safe transaction based on the admin addresses and their private keys.
     * @param txHash The transaction hash generated by the Safe contract.
     * @param admins The list of admin addresses.
     * @param privateKeys The list of private keys corresponding to the admin addresses.
     * @return The packed signature bytes to be passed into the transaction execution.
     */
    function getSignatures(bytes32 txHash, address[] memory admins, uint256[] memory privateKeys) internal pure returns (bytes memory) {
        require(admins.length == privateKeys.length, "Mismatched admins and keys");

        // Array to store signatures (r, s, v for each admin)
        bytes memory _signatures;

        // Generate signatures for each admin
        for (uint256 i = 0; i < admins.length; i++) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeys[i], txHash);

            // Add signature to signatures array
            _signatures = abi.encodePacked(_signatures, r, s, v);
        }

        // Sort signatures by admin addresses if more than one signature
        if (admins.length > 1) {
            _signatures = sortSignatures(_signatures, admins);
        }

        return _signatures;
    }

    /**
     * @dev Sorts the signatures based on the admin addresses.
     * @param signatures The packed signature bytes.
     * @param admins The list of admin addresses.
     * @return The sorted signature bytes.
     */
    function sortSignatures(bytes memory signatures, address[] memory admins) internal pure returns (bytes memory) {
        // Sort the addresses and corresponding signatures based on their numerical value
        for (uint256 i = 0; i < admins.length - 1; i++) {
            for (uint256 j = 0; j < admins.length - i - 1; j++) {
                if (uint160(admins[j]) > uint160(admins[j + 1])) {
                    // Swap admin addresses
                    (admins[j], admins[j + 1]) = (admins[j + 1], admins[j]);

                    // Swap signatures (r, s, v values)
                    for (uint256 k = 0; k < 65; k++) {
                        (signatures[j * 65 + k], signatures[(j + 1) * 65 + k]) = (signatures[(j + 1) * 65 + k], signatures[j * 65 + k]);
                    }
                }
            }
        }

        return signatures;
    }

}
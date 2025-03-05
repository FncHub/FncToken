// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * Library Imports
 */
import {Test} from "forge-std/Test.sol";
import {Vesting} from "../../src/Vesting.sol";
import {FNCToken} from "../../src/FNCToken.sol";

/**
 * @title VestingTest
 * @dev This test contract is designed to test the core functionality of the Vesting contract,
 *      including the vesting schedule, token release, and interactions with the FNCToken contract.
 */
contract VestingTest is Test {
    // Storage variables
    FNCToken s_token;
    Vesting s_vesting;

    uint256 s_maxSupply = 1_000_000_000 * 10**18; // 1,000,000,000 tokens with 18 decimals

    // Vesting parameters
    address s_beneficiary;
    uint256 s_totalVestingAmount = 40_000_000 * 10**18; // 40,000,000 tokens
    uint64 s_startTimestamp;
    uint64 s_cliffDuration = 18 * 30 days; // 18 months
    uint64 s_vestingDuration = 24 * 30 days; // 24 months

    // Test accounts
    address s_admin;
    address s_otherAccount;

    /////////////////////
    // Initialization
    /////////////////////

    /**
     * @dev Sets up the initial environment, including deploying FNCToken and Vesting contracts.
     *      Admin account is assigned, and the Vesting contract is granted the MINTER_ROLE.
     */
    function setUp() external {
        // Assign test accounts
        s_admin = address(this); // The test contract itself acts as the admin
        s_otherAccount = vm.addr(1);
        s_beneficiary = vm.addr(2);

        // Step 1: Deploy FNCToken from admin account
        s_token = new FNCToken("FNCToken", "FNC", s_maxSupply);

        // Step 2: Deploy Vesting contract
        s_startTimestamp = uint64(block.timestamp);
        s_vesting = new Vesting(
            address(s_token),
            s_beneficiary,
            s_startTimestamp,
            s_cliffDuration,
            s_vestingDuration,
            s_totalVestingAmount
        );

        // Step 3: Grant MINTER_ROLE to Vesting contract
        s_token.grantMinterRoleWithLimit(address(s_vesting), s_totalVestingAmount);

        // Verify that Vesting contract has MINTER_ROLE
        assertTrue(s_token.hasRole(s_token.MINTER_ROLE(), address(s_vesting)));
    }

    /////////////////////
    // Tests
    /////////////////////

    /**
     * @dev Tests that no tokens can be released before the cliff period ends.
     */
    function testCannotReleaseTokensBeforeCliff() external {
        // Try to release tokens before cliff
        vm.expectRevert(abi.encodeWithSignature("NoTokensDue()"));
        s_vesting.release();
    }

    /**
     * @dev Tests that tokens can be released correctly after the cliff period ends.
     */
    function testReleaseTokensAfterCliff() external {
        // Move forward in time to just after the cliff
        vm.warp(s_startTimestamp + s_cliffDuration + 1);

        // Calculate expected vested amount
        uint256 expectedVestedAmount = s_vesting.vestedAmount();
        assertTrue(expectedVestedAmount > 0);

        // Release tokens
        s_vesting.release();

        // Check beneficiary balance
        uint256 beneficiaryBalance = s_token.balanceOf(s_beneficiary);
        assertEq(beneficiaryBalance, expectedVestedAmount);

        // Check that no tokens are releasable immediately after release
        uint256 releasable = s_vesting.releasableAmount();
        assertEq(releasable, 0);
    }

    /**
     * @dev Tests that tokens are vested linearly over the vesting period.
     */
    function testReleaseTokensMidVesting() external {
        // Move forward in time to the middle of the vesting period
        uint64 timePassed = s_cliffDuration + (s_vestingDuration / 2);
        vm.warp(s_startTimestamp + timePassed);

        // Calculate expected vested amount
        uint256 expectedVestedAmount = s_vesting.vestedAmount();

        // Release tokens
        s_vesting.release();

        // Check beneficiary balance
        uint256 beneficiaryBalance = s_token.balanceOf(s_beneficiary);
        assertEq(beneficiaryBalance, expectedVestedAmount);

        // Check that no tokens are releasable immediately after release
        uint256 releasable = s_vesting.releasableAmount();
        assertEq(releasable, 0);
    }

    /**
     * @dev Tests that all tokens can be released after the vesting period ends.
     */
    function testReleaseTokensAfterVestingEnds() external {
        // Move forward in time to after the vesting period
        vm.warp(s_startTimestamp + s_cliffDuration + s_vestingDuration + 1);

        // Release tokens
        s_vesting.release();

        // Check beneficiary balance
        uint256 beneficiaryBalance = s_token.balanceOf(s_beneficiary);
        assertEq(beneficiaryBalance, s_totalVestingAmount);

        // Check that no tokens are releasable
        uint256 releasable = s_vesting.releasableAmount();
        assertEq(releasable, 0);
    }

    /**
     * @dev Tests that only the beneficiary address receives tokens, even if someone else calls release().
     */
    function testReleaseTokensByOtherAccount() external {
        // Move forward in time to after the cliff
        vm.warp(s_startTimestamp + s_cliffDuration + 1);

        // Other account calls release()
        vm.prank(s_otherAccount);
        s_vesting.release();

        // Check beneficiary balance
        uint256 beneficiaryBalance = s_token.balanceOf(s_beneficiary);
        assertTrue(beneficiaryBalance > 0);

        // Ensure that other account did not receive tokens
        uint256 otherBalance = s_token.balanceOf(s_otherAccount);
        assertEq(otherBalance, 0);
    }
}

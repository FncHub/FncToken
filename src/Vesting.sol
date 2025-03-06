// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Vesting
 * @author ...
 * @notice This contract implements a token vesting mechanism with a cliff period and linear vesting schedule.
 * It allows a beneficiary to release vested tokens over time according to the specified schedule.
 * The contract interacts with the FNCToken contract to mint tokens when they become vested.
 */

/**
 * Library Imports
 */
import "./FNCToken.sol";

// Custom Errors for gas optimization
error NoTokensDue();
error TokenAddressCannotBeZero();
error BeneficiaryCannotBeZeroAddress();

/**
 * @title Vesting
 * @dev This contract handles the vesting of FNCToken tokens for a beneficiary, releasing them over time
 * according to a linear vesting schedule with an optional cliff period.
 * The contract must have the MINTER_ROLE in the FNCToken contract with an appropriate minting limit.
 */
contract Vesting {

    // Token Interface
    FNCToken private immutable s_token;

    // Vesting Parameters
    address private immutable s_beneficiary;
    uint256 private immutable s_totalAmount;
    uint256 private s_releasedAmount;
    uint64 private immutable s_start;
    uint64 private immutable s_cliff;
    uint64 private immutable s_duration;
    uint64 private immutable s_end;

    // Events
    event TokensReleased(uint256 amount);

    /**
     * @dev Sets up the vesting contract with the specified parameters.
     * @param tokenAddress The address of the FNCToken contract.
     * @param beneficiary The address of the beneficiary to whom vested tokens are released.
     * @param startTimestamp The starting timestamp for the vesting schedule.
     * @param cliffDurationSeconds The duration of the cliff period in seconds.
     * @param vestingDurationSeconds The total duration of the vesting schedule in seconds.
     * @param totalAmount The total amount of tokens to be vested.
     */
    constructor(
        address tokenAddress,
        address beneficiary,
        uint64 startTimestamp,
        uint64 cliffDurationSeconds,
        uint64 vestingDurationSeconds,
        uint256 totalAmount
    ) {
        if (tokenAddress == address(0)) {
            revert TokenAddressCannotBeZero();
        }
        if (beneficiary == address(0)) {
            revert BeneficiaryCannotBeZeroAddress();
        }

        s_token = FNCToken(tokenAddress);
        s_beneficiary = beneficiary;
        s_start = startTimestamp;
        s_cliff = startTimestamp + cliffDurationSeconds;
        s_duration = vestingDurationSeconds;
        s_end = startTimestamp + vestingDurationSeconds;
        s_totalAmount = totalAmount;
    }

    /**
     * @dev Releases the vested tokens to the beneficiary.
     * Can be called by anyone, but tokens are always transferred to the beneficiary.
     */
    function release() public {
        uint256 unreleased = releasableAmount();
        if (unreleased == 0) {
            revert NoTokensDue();
        }

        s_releasedAmount += unreleased;

        // Mint tokens to the beneficiary
        s_token.mint(s_beneficiary, unreleased);

        emit TokensReleased(unreleased);
    }

    /**
     * @dev Calculates the amount of tokens that can be released at the current time.
     * @return The amount of tokens that can be released.
     */
    function releasableAmount() public view returns (uint256) {
        return vestedAmount() - s_releasedAmount;
    }

    /**
     * @dev Calculates the total amount of vested tokens at the current time.
     * @return The amount of tokens that have vested.
     */
    function vestedAmount() public view returns (uint256) {
        uint256 currentTime = block.timestamp;

        if (currentTime < s_cliff) {
            return 0;
        } else if (currentTime >= s_end) {
            return s_totalAmount;
        } else {
            uint256 timeFromCliff = currentTime - s_cliff;
            uint256 vestingDurationAfterCliff = s_end - s_cliff;
            return (s_totalAmount * timeFromCliff) / vestingDurationAfterCliff;
        }
    }
}

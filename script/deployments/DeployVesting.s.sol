// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DeployVesting
 * @notice This script is used for deploying the Vesting contract in both testing (with forked networks) and real blockchain environments (testnets or mainnets).
 */

/**
 * Library Imports
 */
import {Script} from "forge-std/Script.sol";
import {Vesting} from "../../src/Vesting.sol";
import {FNCToken} from "../../src/FNCToken.sol";
import "../utils/Format.s.sol";

contract DeployVesting is Script {
    // Indicates if the deployment is being done in a forked environment (useful for testing)
    string public s_fork = vm.envOr("FORK", string("false"));

    /**
     * @dev Deploys the Vesting contract to the appropriate blockchain environment.
     * Depending on the environment (testnet or real network), the deployment process differs.
     * In the test environment, it simulates the deployment with `startPrank`, while on real networks, it uses `startBroadcast`.
     *
     * @param tokenAddress The address of the deployed FNCToken contract.
     * @param beneficiary The address of the beneficiary.
     * @param startTimestamp The start time of the vesting period.
     * @param cliffDurationSeconds The duration of the cliff in seconds.
     * @param vestingDurationSeconds The total duration of the vesting in seconds.
     * @param totalAmount The total amount of tokens to be vested.
     *
     * @return Returns the deployed Vesting contract instance.
     */
    function run(
        address tokenAddress,
        address beneficiary,
        uint64 startTimestamp,
        uint64 cliffDurationSeconds,
        uint64 vestingDurationSeconds,
        uint256 totalAmount
    ) external returns (Vesting) {
        // Fetch the chain ID for the test environment
        uint256 _testChainId = Format.parseEnvStringToUint("TEST_CHAIN_ID", vm);

        // Instantiate the token contract
        FNCToken token = FNCToken(tokenAddress);

        // If the environment is a testnet or forked testnet, simulate the deployment
        if (block.chainid == _testChainId || keccak256(abi.encodePacked(s_fork)) != keccak256(abi.encodePacked("false"))) {
            // Test environment deployment (using prank)
            vm.startPrank(msg.sender);
            Vesting vestingContract = new Vesting(
                tokenAddress,
                beneficiary,
                startTimestamp,
                cliffDurationSeconds,
                vestingDurationSeconds,
                totalAmount
            );

            // Grant minter role with limit to the vesting contract
            token.grantMinterRoleWithLimit(address(vestingContract), totalAmount);

            vm.stopPrank();
            return vestingContract;
        } else {
            // Real network deployment (broadcast transaction)
            vm.startBroadcast();
            Vesting vestingContract = new Vesting(
                tokenAddress,
                beneficiary,
                startTimestamp,
                cliffDurationSeconds,
                vestingDurationSeconds,
                totalAmount
            );
            vm.stopBroadcast();

            // In the real network, you need to grant minter role via Gnosis Safe or the admin account
            // This may require manual intervention if the deployer doesn't have admin rights

            return vestingContract;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Gnosis Safe Deployment Script
 * @author UrukHan
 * @notice This contract script is used to deploy a Gnosis Safe singleton contract, either in a testing environment or a real blockchain environment.
 * It supports automatic detection of the environment and adjusts the deployment process accordingly (testnet vs. mainnet).
 */

/**
 * Library Imports
 */
import {Script} from "forge-std/Script.sol";
import {Safe} from "@gnosis.pm/safe-contracts/contracts/Safe.sol";
import "../utils/Format.s.sol";

/**
 * @title DeploySafe
 * @dev This script is designed to deploy the Gnosis Safe singleton contract. It checks whether the environment is a testnet (or forked testnet) or a real network.
 * In a test environment, it performs the deployment without broadcasting the transaction, while in a mainnet or testnet environment, it broadcasts the deployment.
 */
contract DeploySafe is Script {

    // Indicates whether a forked environment is being used for testing
    string public s_fork = vm.envOr("FORK", string("false"));

    /**
     * @dev Deploys the Gnosis Safe singleton contract. Depending on the environment, it either simulates the deployment in a test environment
     * or broadcasts the transaction on a real blockchain network.
     *
     * @return Returns the deployed Gnosis Safe contract instance.
     */
    function run() external returns (Safe) {
        // Retrieve the environment chain ID for testing
        uint256 testChainId = Format.parseEnvStringToUint("TEST_CHAIN_ID", vm);

        // Deploy the contract based on the environment (test or real)
        if (block.chainid == testChainId || keccak256(abi.encodePacked(s_fork)) != keccak256(abi.encodePacked("false"))) {
            // Test environment deployment (without broadcasting)
            Safe _safe = new Safe();
            return _safe;
        } else {
            // Mainnet/testnet deployment (broadcasting the transaction)
            vm.startBroadcast();
            Safe _safe = new Safe();
            vm.stopBroadcast();
            return _safe;
        }
    }
}

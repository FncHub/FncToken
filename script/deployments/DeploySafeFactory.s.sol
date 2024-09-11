// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {SafeProxyFactory} from "@gnosis.pm/safe-contracts/contracts/proxies/SafeProxyFactory.sol";
import "../utils/Format.s.sol";  // Utility for parsing environment variables

/**
 * @title DeploySafeFactory
 * @author UrukHan
 * @notice This script deploys the Gnosis Safe Proxy Factory, either in a test environment or a real environment (testnet or mainnet).
 * It detects the chain ID and determines whether to broadcast the deployment on-chain or simulate it for testing.
 */
contract DeploySafeFactory is Script {

    // Flag to determine if we are using a forked environment for testing
    string public s_fork = vm.envOr("FORK", string("false"));

    /**
     * @dev Deploys the Gnosis Safe Proxy Factory.
     * If the script is run in a test environment (based on chain ID or forked network), it simulates the deployment without broadcasting it.
     * In a real environment (testnet or mainnet), the deployment is broadcasted on-chain.
     * @return The deployed SafeProxyFactory contract instance.
     */
    function run() external returns (SafeProxyFactory) {
        // Fetch the chain ID for the test environment
        uint256 testChainId = Format.parseEnvStringToUint("TEST_CHAIN_ID", vm);

        // Check if the current environment is a test chain or a forked environment
        if (block.chainid == testChainId || keccak256(abi.encodePacked(s_fork)) != keccak256(abi.encodePacked("false"))) {
            // Test environment: simulate the deployment without broadcasting
            SafeProxyFactory _safeFactory = new SafeProxyFactory();
            return _safeFactory;
        } else {
            // Real environment: broadcast the deployment on-chain
            vm.startBroadcast();
            SafeProxyFactory _safeFactory = new SafeProxyFactory();
            vm.stopBroadcast();
            return _safeFactory;
        }
    }
}

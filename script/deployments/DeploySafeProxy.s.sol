// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DeploySafeProxy Script
 * @author UrukHan
 * @notice This contract is designed to deploy a Gnosis Safe proxy using the SafeProxyFactory, allowing dynamic owner configuration and required confirmations.
 * It supports deployment in both forked testing environments and live networks.
 */

/**
 * Library Imports
 */
import {Script} from "forge-std/Script.sol";
import {SafeProxyFactory} from "@gnosis.pm/safe-contracts/contracts/proxies/SafeProxyFactory.sol";
import {SafeProxy} from "@gnosis.pm/safe-contracts/contracts/proxies/SafeProxy.sol";
import "../utils/EncodeDecode.s.sol";  // Utility for decoding JSON addresses
import "../utils/Format.s.sol";  // Utility for parsing environment variables

/**
 * @title DeploySafeProxy
 * @dev This script deploys a Gnosis Safe proxy using the SafeProxyFactory. It dynamically configures owners and required confirmations
 *      based on the input provided. The script detects the environment (testnet or mainnet) and manages the deployment accordingly.
 *
 * @notice The contract allows deploying Gnosis Safe proxies for both testing (on forked networks) and live environments, ensuring seamless multi-signature wallet setup.
 */
contract DeploySafeProxy is Script {

    // Indicates whether we are using a forked environment for testing
    string public s_fork = vm.envOr("FORK", string("false"));

    /**
     * @dev Deploys a Gnosis Safe proxy contract with dynamically defined owners and required confirmations.
     *      In a test environment, the proxy is deployed without broadcasting the transaction, while in live environments, it is broadcasted.
     *
     * @param factoryAddress The address of the deployed Gnosis Safe Proxy Factory.
     * @param singletonAddress The address of the Gnosis Safe singleton (template contract).
     * @param jsonAddresses A JSON string containing the owner addresses for the Gnosis Safe proxy.
     * @param requiredConfirmations The number of confirmations required to execute transactions within the Safe.
     *
     * @return proxy The deployed Gnosis Safe proxy.
     */
    function run(address factoryAddress, address singletonAddress, string calldata jsonAddresses, uint256 requiredConfirmations) external returns (SafeProxy) {
        // Decode the JSON string to an array of owner addresses
        address[] memory _owners = EncodeDecode.decodeAddresses(jsonAddresses);

        // Fetch the test environment chain ID
        uint256 _testChainId = Format.parseEnvStringToUint("TEST_CHAIN_ID", vm);

        // Define the initializer (setup data for the Safe)
        bytes memory initializer = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            _owners,                         // List of owner addresses
            requiredConfirmations,          // Required confirmations for transactions
            address(0),                     // to (Delegate call address)
            bytes(""),                      // Optional setup data
            address(0),                     // Optional fallback handler
            address(0),                     // Optional payment token
            0,                              // Optional payment amount
            address(0)                      // Optional payment receiver
        );

        SafeProxyFactory _safeFactory = SafeProxyFactory(factoryAddress);
        SafeProxy _proxy;

        // Check the environment and deploy accordingly
        if (block.chainid == _testChainId || keccak256(abi.encodePacked(s_fork)) != keccak256(abi.encodePacked("false"))) {
            // Deploy in a test environment (forked)
            _proxy = _safeFactory.createProxyWithNonce(address(singletonAddress), initializer, block.timestamp);
        } else {
            // Broadcast deployment to the blockchain (mainnet or testnet)
            vm.startBroadcast();
            _proxy = _safeFactory.createProxyWithNonce(address(singletonAddress), initializer, block.timestamp);
            vm.stopBroadcast();
        }

        // Return the deployed proxy
        return _proxy;
    }
}

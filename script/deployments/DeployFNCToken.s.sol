// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title FNCToken Deployment Script
 * @author UrukHan
 * @notice This contract is used for deploying the FNCToken smart contract in both testing (with forked networks) and real blockchain environments (testnets or mainnets).
 * It supports seamless deployment via Gnosis Safe, ensuring proper deployment based on the environment.
 */

/**
 * Library Imports
 */
import {Script} from "forge-std/Script.sol";
import {FNCToken} from "../../src/FNCToken.sol";
import "../utils/Format.s.sol";
import {console} from "forge-std/Test.sol";

/**
 * @title DeployFNCToken
 * @dev This script facilitates the deployment of the FNCToken contract. Depending on the environment, it will either simulate a local deployment for testing
 * (such as using a Gnosis Safe for governance) or execute a real transaction on the blockchain, broadcasting the deployment of the contract.
 *
 * @notice The script automatically checks the environment (whether it's a forked testnet, testnet, or mainnet) and adjusts the deployment process accordingly.
 * If running on a testnet, the contract deployment can be simulated with `startPrank`, but in real environments, the deployment is broadcasted on-chain.
 */
contract DeployFNCToken is Script {

    // Indicates if the deployment is being done in a forked environment (useful for testing)
    string public s_fork = vm.envOr("FORK", string("false"));

    /**
     * @dev Deploys the FNCToken contract to the appropriate blockchain environment.
     * Depending on the environment (testnet or real network), the deployment process differs.
     * In the test environment, it simulates the deployment with `startPrank`, while on real networks, it uses `startBroadcast`.
     *
     * @param name The name of the FNCToken (e.g., "FNCToken").
     * @param symbol The symbol of the FNCToken (e.g., "FNC").
     * @param maxSupply The maximum supply of tokens that can ever be minted.
     *
     * @return Returns the deployed FNCToken contract instance.
     */
    function run(string memory name, string memory symbol, uint256 maxSupply) external returns (FNCToken) {
        // Fetch the chain ID for the test environment
        uint256 _testChainId = Format.parseEnvStringToUint("TEST_CHAIN_ID", vm);

        // If the environment is a testnet or forked testnet, simulate the deployment
        if (block.chainid == _testChainId || keccak256(abi.encodePacked(s_fork)) != keccak256(abi.encodePacked("false"))) {
            // Test environment deployment (using prank)
            vm.startPrank(msg.sender);
            FNCToken _token = new FNCToken(name, symbol, maxSupply);
            vm.stopPrank();
            return _token;
        } else {
            // Real network deployment (broadcast transaction)
            vm.startBroadcast();
            FNCToken _token = new FNCToken(name, symbol, maxSupply);
            vm.stopBroadcast();
            return _token;
        }
    }
}

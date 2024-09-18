// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * Library Imports
 */
import {Script, console} from "forge-std/Script.sol";
import {FNCToken} from "../../src/FNCToken.sol";
import "foundry-devops/src/DevOpsTools.sol";
import "../utils/Format.s.sol";

/**
 * @title MintToken
 * @notice Contract to handle the token minting operations
 * @dev Uses the Script contract to perform minting based on chain ID
 */
contract TransferAdminRole is Script {

    // Indicates if the deployment is being done in a forked environment (useful for testing)
    string public s_fork = vm.envOr("FORK", string("false"));

    /**
    */
    function run(address token, address admin) external {
        // Fetch the chain ID for the test environment
        uint256 _testChainId = Format.parseEnvStringToUint("TEST_CHAIN_ID", vm);

        // If the environment is a testnet or forked testnet, simulate the deployment
        if (block.chainid == _testChainId || keccak256(abi.encodePacked(s_fork)) != keccak256(abi.encodePacked("false"))) {
            // Test environment deployment (using prank)
            vm.startPrank(msg.sender);
            FNCToken(token).transferAdminRole(admin);
            vm.stopPrank();
        } else {
            // Broadcast
            vm.startBroadcast();
            FNCToken(token).transferAdminRole(admin);
            vm.stopBroadcast();
        }
        console.log("Admin role to %s", admin);
    }
}

/**
 */
contract TransferAdminRoleLast is Script {

    // Indicates if the deployment is being done in a forked environment (useful for testing)
    string public s_fork = vm.envOr("FORK", string("false"));

    /**
    */
    function run(address token, uint256 admin) external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("FNCToken", block.chainid);
        // Fetch the chain ID for the test environment
        uint256 _testChainId = Format.parseEnvStringToUint("TEST_CHAIN_ID", vm);

        // If the environment is a testnet or forked testnet, simulate the deployment
        if (block.chainid == _testChainId || keccak256(abi.encodePacked(s_fork)) != keccak256(abi.encodePacked("false"))) {
            // Test environment deployment (using prank)
            vm.startPrank(msg.sender);
            FNCToken(token).transferAdminRole(admin);
            vm.stopPrank();
        } else {
            // Broadcast
            vm.startBroadcast();
            FNCToken(mostRecentlyDeployed).transferAdminRole(admin);
            vm.stopBroadcast();
        }
    }
}




// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * Library Imports
 */
import {Script} from "forge-std/Script.sol";
import {Safe} from "@gnosis.pm/safe-contracts/contracts/Safe.sol";
import {Enum} from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import "../utils/Format.s.sol";

/**
 * @title MintToken
 * @notice Contract to handle the token minting operations
 * @dev Uses the Script contract to perform minting based on chain ID
 */
contract GetOwners is Script {

    // Indicates if the deployment is being done in a forked environment (useful for testing)
    string public s_fork = vm.envOr("FORK", string("false"));

    /**
    */
    function run(address safe) external returns (address[] memory){
        // Fetch the chain ID for the test environment
        uint256 _testChainId = Format.parseEnvStringToUint("TEST_CHAIN_ID", vm);
        address[] memory owners;
        // If the environment is a testnet or forked testnet, simulate the deployment
        if (block.chainid == _testChainId || keccak256(abi.encodePacked(s_fork)) != keccak256(abi.encodePacked("false"))) {
            // Test environment deployment (using prank)
            vm.startPrank(msg.sender);
            owners = Safe(payable(safe)).getOwners();
            vm.stopPrank();
        } else {
            // Broadcast
            vm.startBroadcast();
            owners = Safe(payable(safe)).getOwners();
            vm.stopBroadcast();
        }
        return owners;
    }
}



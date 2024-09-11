// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Vm} from "forge-std/Vm.sol";

/**
 * @title Format Library
 * @notice This library provides utility functions for parsing environment variables and data conversions.
 * It includes functions to convert string values from environment variables into `uint256` and `address` types, as well as functions for working with `bytes32` data.
 * The library is primarily used in testing and deployment scripts.
 */
library Format {

    /**
     * @notice Parses an environment variable string into a `uint256` value.
     * @dev This function reads a string environment variable and converts it to a `uint256`.
     * @param key The name of the environment variable to be parsed.
     * @param vm The instance of the `Vm` to access environment variables.
     * @return The parsed `uint256` value from the environment variable.
     */
    function parseEnvStringToUint(string memory key, Vm vm) internal view returns (uint256) {
        return _parseStringToUint(vm.envString(key));
    }

    /**
     * @notice Parses an environment variable string into an `address` value.
     * @dev This function reads a string environment variable and converts it to an `address`.
     * @param key The name of the environment variable to be parsed.
     * @param vm The instance of the `Vm` to access environment variables.
     * @return The parsed `address` value from the environment variable.
     */
    function parseEnvStringToAddress(string memory key, Vm vm) internal view returns (address) {
        return _parseStringToAddress(vm.envString(key));
    }

    /////////////////////
    // Private Helpers
    /////////////////////

    /**
     * @dev Converts a string representation of a number into a `uint256`.
     * This is a private helper function used to process strings from environment variables.
     * @param s The string to be parsed into a `uint256`.
     * @return The parsed `uint256` value.
     */
    function _parseStringToUint(string memory s) private pure returns (uint256) {
        bytes memory _b = bytes(s);
        uint256 _i;
        uint256 _result = 0;
        for (_i = 0; _i < _b.length; _i++) {
            uint256 _c = uint256(uint8(_b[_i]));
            if (_c >= 48 && _c <= 57) {
                _result = _result * 10 + (_c - 48);
            }
        }
        return _result;
    }

    /**
     * @dev Converts a string representation of a hexadecimal address into an `address`.
     * This is a private helper function used to process strings from environment variables.
     * @param a The string to be parsed into an `address`.
     * @return The parsed `address`.
     */
    function _parseStringToAddress(string memory a) internal pure returns (address) {
        bytes memory _tmp = bytes(a);
        uint160 _iaddr = 0;
        uint160 _b1;
        uint160 _b2;
        for (uint i = 2; i < 2 + 2 * 20; i += 2) {
            _iaddr *= 256;
            _b1 = uint160(uint8(_tmp[i]));
            _b2 = uint160(uint8(_tmp[i + 1]));
            if ((_b1 >= 97) && (_b1 <= 102)) _b1 -= 87;
            else if ((_b1 >= 65) && (_b1 <= 70)) _b1 -= 55;
            else if ((_b1 >= 48) && (_b1 <= 57)) _b1 -= 48;
            if ((_b2 >= 97) && (_b2 <= 102)) _b2 -= 87;
            else if ((_b2 >= 65) && (_b2 <= 70)) _b2 -= 55;
            else if ((_b2 >= 48) && (_b2 <= 57)) _b2 -= 48;
            _iaddr += (_b1 * 16 + _b2);
        }
        return address(_iaddr);
    }

    /////////////////////
    // Bytes32 Utilities
    /////////////////////

    /**
     * @notice Converts a `bytes32` value into a string.
     * @param b32 The `bytes32` value to be converted.
     * @return The converted string value.
     */
    function bytes32ToString(bytes32 b32) internal pure returns (string memory) {
        uint8 _i = 0;
        while (_i < 32 && b32[_i] != 0) {
            _i++;
        }
        bytes memory _bytesArray = new bytes(_i);
        for (_i = 0; _i < 32 && b32[_i] != 0; _i++) {
            _bytesArray[_i] = b32[_i];
        }
        return string(_bytesArray);
    }

    /**
     * @notice Converts a `bytes32` value into its hexadecimal string representation.
     * @param data The `bytes32` value to be converted.
     * @return The hexadecimal string representation of the `bytes32` value.
     */
    function bytes32ToHexString(bytes32 data) internal pure returns (string memory) {
        bytes memory _alphabet = "0123456789abcdef";
        bytes memory _str = new bytes(64);
        for (uint256 i = 0; i < 32; i++) {
            _str[i * 2] = _alphabet[uint8(data[i] >> 4)];
            _str[1 + i * 2] = _alphabet[uint8(data[i] & 0x0f)];
        }
        return string(_str);
    }
}

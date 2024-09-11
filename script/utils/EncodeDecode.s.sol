// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console} from "forge-std/Script.sol";

/**
 * @title EncodeDecode Library
 * @notice This library provides a set of utilities to encode and decode various types of data, particularly focused on parsing JSON-like structures.
 * It includes functions for decoding fields, parsing addresses, integers, booleans, and converting addresses to strings.
 * The library is useful for handling complex data structures in Ethereum smart contracts.
 */
library EncodeDecode {

    /**
     * @dev Structure to define fields with their names and types, used for parsing JSON-like data structures.
     */
    struct Field {
        string name;
        string typeSignature;
    }


    /////////////////////
    // Decoding Functions
    /////////////////////

    /**
     * @notice Decodes a specific field from the given data bytes, starting at a specified position.
     * @param dataBytes The raw byte data containing the encoded fields.
     * @param start The position to start decoding from in the byte array.
     * @param fieldName The name of the field to decode.
     * @param fieldType The type of the field to decode (e.g., "address", "uint", "bool").
     * @return The decoded value as a byte array and the updated position in the byte array.
     */
    function decodeField(bytes memory dataBytes, uint start, string memory fieldName, string memory fieldType) internal pure returns (bytes memory, uint) {

        uint _j = start + find(dataBytes, start, string(abi.encodePacked('\"', fieldName, '\":'))) + bytes(fieldName).length + 3;

        if (keccak256(bytes(fieldType)) == keccak256("address")) {
            bytes memory _addressBytes = new bytes(42);
            for (uint k = 0; k < 42; k++) {
                _addressBytes[k] = dataBytes[_j + 1 + k];
            }
            _j += 43;
            return (_addressBytes, _j);
        }

        if (keccak256(bytes(fieldType)) == keccak256("uint")) {
            bytes memory _numBytes = new bytes(0);
            while (dataBytes[_j] != ',' && dataBytes[_j] != '}') {
                bytes memory _tempBytes = new bytes(_numBytes.length + 1);
                for (uint i = 0; i < _numBytes.length; i++) {
                    _tempBytes[i] = _numBytes[i];
                }
                _tempBytes[_numBytes.length] = dataBytes[_j];
                _numBytes = _tempBytes;
                _j++;
            }
            return (_numBytes, _j);
        }

        if (keccak256(bytes(fieldType)) == keccak256("bool")) {
            bytes memory _boolBytes = new bytes(5);
            uint _k = 0;
            while (dataBytes[_j] != ',' && dataBytes[_j] != '}') {
                _boolBytes[_k] = dataBytes[_j];
                _k++;
                _j++;
            }
            return (_boolBytes, _j);
        }

        return (new bytes(0), _j);
    }

    /**
     * @notice Decodes a structured object from the given data bytes, starting at a specified position.
     * @param dataBytes The raw byte data containing the encoded fields.
     * @param start The position to start decoding from.
     * @param fields The array of field definitions to decode from the data.
     * @return The array of decoded values and the updated position in the byte array.
     */
    function decodeStruct(bytes memory dataBytes, uint start, Field[] memory fields) internal pure returns (bytes[] memory, uint) {
        bytes[] memory _parsedFields = new bytes[](fields.length);
        uint _j = start;

        for (uint i = 0; i < fields.length; i++) {
            (bytes memory value, uint newJ) = decodeField(dataBytes, _j, fields[i].name, fields[i].typeSignature);
            _parsedFields[i] = value;
            _j = newJ;
        }

        return (_parsedFields, _j);
    }

    /**
     * @notice Decodes multiple instances of structured objects from a string, based on the given fields.
     * @param data The raw data string containing multiple objects.
     * @param fields The array of field definitions for each object.
     * @return The array of arrays containing decoded values for each object.
     */
    function decode(string memory data, Field[] memory fields) internal pure returns (bytes[][] memory) {
        bytes memory _dataBytes = bytes(data);
        bytes[][] memory _parsedData = new bytes[][](countInstances(_dataBytes, "{"));
        uint _j = 0;
        for (uint i = 0; i < _parsedData.length; i++) {
            _j += find(_dataBytes, _j, "{") + 1;
            (bytes[] memory parsedFields, uint newJ) = decodeStruct(_dataBytes, _j, fields);
            _parsedData[i] = parsedFields;
            _j = newJ;
        }
        return _parsedData;
    }

    /////////////////////
    // Utility Functions
    /////////////////////

    /**
     * @notice Counts the number of occurrences of a specific marker (e.g., `{`) in the given data.
     * @param data The raw byte data to search within.
     * @param marker The marker to count instances of.
     * @return The number of occurrences of the marker in the data.
     */
    function countInstances(bytes memory data, string memory marker) internal pure returns (uint) {
        uint _count = 0;
        uint _j = 0;

        while (_j < data.length) {
            _j += find(data, _j, marker) + bytes(marker).length;
            if (_j < data.length) _count++;
        }
        return _count;
    }

    /**
     * @notice Finds the position of a specific marker (substring) in the given data, starting from a specified position.
     * @param data The raw byte data to search within.
     * @param start The starting position in the data to search from.
     * @param marker The marker to search for.
     * @return The position of the marker relative to the start position, or the data length if not found.
     */
    function find(bytes memory data, uint start, string memory marker) internal pure returns (uint) {
        bytes memory _markerBytes = bytes(marker);
        for (uint i = start; i <= data.length - _markerBytes.length; i++) {
            bool found = true;
            for (uint j = 0; j < _markerBytes.length; j++) {
                if (data[i + j] != _markerBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return i - start;
        }
        return data.length;
    }

    /////////////////////
    // Parsing Functions
    /////////////////////

    /**
     * @notice Parses a byte array representing an address.
     * @param a The byte array containing the address.
     * @return The parsed Ethereum address.
     */
    function parseAddress(bytes memory a) internal pure returns (address) {
        require(a.length == 42, "Address should have 42 bytes");
        uint160 _iaddr = 0;
        uint160 _b1;
        uint160 _b2;
        for (uint i = 2; i < 2 + 2 * 20; i += 2) {
            _iaddr *= 256;
            _b1 = uint160(uint8(a[i]));
            _b2 = uint160(uint8(a[i + 1]));
            if ((_b1 >= 97) && (_b1 <= 102)) {
                _b1 -= 87;
            } else if ((_b1 >= 65) && (_b1 <= 70)) {
                _b1 -= 55;
            } else if ((_b1 >= 48) && (_b1 <= 57)) {
                _b1 -= 48;
            }
            if ((_b2 >= 97) && (_b2 <= 102)) {
                _b2 -= 87;
            } else if ((_b2 >= 65) && (_b2 <= 70)) {
                _b2 -= 55;
            } else if ((_b2 >= 48) && (_b2 <= 57)) {
                _b2 -= 48;
            }
            _iaddr += (_b1 * 16 + _b2);
        }
        return address(_iaddr);
    }

    /**
     * @notice Converts a string representing an integer into a `uint`.
     * @param a The string to be parsed into an integer.
     * @return The parsed `uint` value.
     */
    function parseInt(string memory a) internal pure returns (uint) {
        bytes memory _bresult = bytes(a);
        uint _mint = 0;
        for (uint i = 0; i < _bresult.length; i++) {
            if ((uint8(_bresult[i]) >= 48) && (uint8(_bresult[i]) <= 57)) {
                _mint *= 10;
                _mint += uint(uint8(_bresult[i])) - 48;
            }
        }
        return _mint;
    }

    /**
     * @notice Converts a byte array representing a boolean into a boolean value.
     * @param a The byte array containing the boolean.
     * @return The parsed boolean value.
     */
    function parseBool(bytes memory a) internal pure returns (bool) {
        return a[0] == 't' ? true : false;
    }

    /**
     * @notice Splits a byte array into an array of strings, using a specified separator.
     * @param data The byte array to be split.
     * @param separator The byte character used as a separator for splitting.
     * @return An array of strings, split by the separator.
     */
    function split(bytes memory data, bytes1 separator) internal pure returns (string[] memory) {
        uint _count = 1;
        for (uint i = 0; i < data.length; i++) {
            if (data[i] == separator) {
                _count++;
            }
        }

        string[] memory parts = new string[](_count);
        uint _start = 0;
        uint _partIndex = 0;

        for (uint i = 0; i <= data.length; i++) {
            if (i == data.length || data[i] == separator) {
                bytes memory part = new bytes(i - _start);
                for (uint j = _start; j < i; j++) {
                    part[j - _start] = data[j];
                }
                parts[_partIndex] = string(part);
                _partIndex++;
                _start = i + 1;
            }
        }

        return parts;
    }


    /**
     * @notice Removes leading and trailing quotes, spaces, and tabs from a string.
     * @param input The string from which to remove quotes, spaces, and tabs.
     * @return A string with the quotes, spaces, and tabs removed.
     */
    function removeQuotesAndSpaces(string memory input) internal pure returns (string memory) {
        bytes memory _inputBytes = bytes(input);
        uint _len = _inputBytes.length;

        uint _start = 0;
        uint _end = _len - 1;

        while (_start < _len && (_inputBytes[_start] == ' ' || _inputBytes[_start] == '"' || _inputBytes[_start] == '\t')) {
            _start++;
        }

        while (_end > _start && (_inputBytes[_end] == ' ' || _inputBytes[_end] == '"' || _inputBytes[_end] == '\t')) {
            _end--;
        }

        bytes memory _trimmed = new bytes(_end - _start + 1);
        for (uint i = _start; i <= _end; i++) {
            _trimmed[i - _start] = _inputBytes[i];
        }

        return string(_trimmed);
    }

    /**
     * @notice Decodes a JSON-like string containing an array of addresses into an array of Ethereum addresses.
     * The input must be a string in JSON format (e.g., `["0xAddress1", "0xAddress2", "0xAddress3"]`).
     * @param data The string containing the JSON array of addresses.
     * @return An array of Ethereum addresses parsed from the input string.
     */
    function decodeAddresses(string memory data) internal pure returns (address[] memory) {
        bytes memory _dataBytes = bytes(data);
        require(_dataBytes.length >= 2 && _dataBytes[0] == '[' && _dataBytes[_dataBytes.length - 1] == ']', "Invalid JSON format");

        bytes memory _trimmedData = new bytes(_dataBytes.length - 2);
        for (uint i = 1; i < _dataBytes.length - 1; i++) {
            _trimmedData[i - 1] = _dataBytes[i];
        }

        string[] memory _parts = split(_trimmedData, ',');

        for (uint i = 0; i < _parts.length; i++) {
            _parts[i] = removeQuotesAndSpaces(_parts[i]);
        }

        address[] memory _addresses = new address[](_parts.length);
        for (uint i = 0; i < _parts.length; i++) {
            _addresses[i] = parseAddress(bytes(_parts[i]));
        }

        return _addresses;
    }

    /**
     * @notice Encodes an array of three Ethereum addresses into a JSON-like string format.
     * The output is formatted as a JSON array (e.g., `["0xAddress1", "0xAddress2", "0xAddress3"]`).
     * @param a The first Ethereum address.
     * @param b The second Ethereum address.
     * @param c The third Ethereum address.
     * @return A string containing the encoded addresses in JSON-like format.
     */
    function encodeAddressArray(address a, address b, address c) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                "[\"",
                toAsciiString(a),
                "\", \"",
                toAsciiString(b),
                "\", \"",
                toAsciiString(c),
                "\"]"
            )
        );
    }


    /////////////////////
    // String and Address Manipulation
    /////////////////////

    /**
     * @notice Converts an address to its ASCII string representation.
     * @param x The address to be converted.
     * @return The ASCII string representation of the address.
     */
    function toAsciiString(address x) internal pure returns (string memory) {
        bytes memory _s = new bytes(42);
        _s[0] = '0';
        _s[1] = 'x';
        for (uint i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint(uint160(x)) / (2**(8*(19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            _s[2+i*2] = char(hi);
            _s[3+i*2] = char(lo);
        }
        return string(_s);
    }

    /**
     * @notice Returns the character representation of a byte value.
     * @param b The byte to be converted to a character.
     * @return The ASCII character.
     */
    function char(bytes1 b) internal pure returns (bytes1) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }
}

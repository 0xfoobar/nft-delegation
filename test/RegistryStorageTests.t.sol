// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IDelegateRegistry as IRegistry} from "src/IDelegateRegistry.sol";
import {RegistryStorage as Storage} from "src/libraries/RegistryStorage.sol";
import {RegistryHarness as Harness} from "src/tools/RegistryHarness.sol";

contract RegistryStorageTests is Test {
    Harness harness;

    function setUp() public {
        harness = new Harness();
    }

    /// @dev Check that storage positions match up with the expect form of the delegations array
    function testStoragePositionsEnum() public {
        assertEq(uint256(type(Storage.Positions).min), 0);
        assertEq(uint256(type(Storage.Positions).max), harness.exposedDelegations(0).length - 1);
    }

    /// @dev Check that storage library constants are as intended
    function testStorageConstants() public {
        assertEq(Storage.cleanAddress, bytes32(uint256(type(uint160).max)));
        assertEq(Storage.cleanFirst8BytesAddress, bytes32(uint256(type(uint64).max) << 96));
        assertEq(Storage.cleanLast12BytesAddress, bytes32(uint256(type(uint96).max)));
        assertEq(Storage.cleanPacked8BytesAddress, bytes32(uint256(type(uint64).max) << 160));
    }

    /// @dev Check that pack addresses works as intended
    function testPackAddresses(address from, address to, address contract_) public {
        (bytes32 firstPacked, bytes32 secondPacked) = Storage.packAddresses(from, to, contract_);
        assertEq(from, address(uint160(uint256(firstPacked))));
        assertEq(to, address(uint160(uint256(secondPacked))));
        // Check that there is 4 bytes of zeros at the start of first packed
        assertEq(0, uint256(firstPacked) >> 224);
        // Check contract is stored correctly
        assertEq(uint256(uint160(contract_)) >> 96, uint256(firstPacked) >> 160);
        assertEq((uint256(uint160(contract_)) << 160) >> 160, uint256(secondPacked) >> 160);
        // Check that unPackAddresses inverts correctly
        (address checkFrom, address checkTo, address checkContract_) = Storage.unPackAddresses(firstPacked, secondPacked);
        assertEq(from, checkFrom);
        assertEq(to, checkTo);
        assertEq(contract_, checkContract_);
        // Check that unpackAddress inverts correctly
        (checkFrom) = Storage.unpackAddress(firstPacked);
        (checkTo) = Storage.unpackAddress(secondPacked);
        assertEq(checkFrom, from);
        assertEq(checkTo, to);
    }

    function testPackAddressesLargeInputs(uint256 from, uint256 to, uint256 contract_) public {
        uint256 minSize = type(uint160).max;
        vm.assume(from > minSize && to > minSize && contract_ > minSize);
        address largeFrom;
        address largeTo;
        address largeContract_;
        assembly {
            largeFrom := from
            largeTo := to
            largeContract_ := contract_
        }
        uint256 testLargeFrom;
        uint256 testLargeTo;
        uint256 testLargeContract_;
        assembly {
            testLargeFrom := largeFrom
            testLargeTo := largeTo
            testLargeContract_ := largeContract_
        }
        assertEq(testLargeFrom, from);
        assertEq(testLargeTo, to);
        assertEq(testLargeContract_, contract_);
        bytes32 firstPacked;
        bytes32 secondPacked;
        (firstPacked, secondPacked) = Storage.packAddresses(largeFrom, largeTo, largeContract_);
        // Check that there is 4 bytes of zeros at the start of first packed
        assertEq(0, uint256(firstPacked) >> 224);
        // Check that large numbers do not match
        assertFalse(uint160(uint256(firstPacked)) == from);
        assertFalse(uint160(uint256(secondPacked)) == to);
        // Check that large numbers were correctly cleaned
        assertEq(uint160(uint256(firstPacked)), uint160(from));
        assertEq(uint160(uint256(secondPacked)), uint160(to));
        // unPackAddress and check they do not equal inputs
        (largeFrom, largeTo, largeContract_) = Storage.unPackAddresses(firstPacked, secondPacked);

        assembly {
            testLargeFrom := largeFrom
            testLargeTo := largeTo
            testLargeContract_ := largeContract_
        }
        // Assert that clean unpacked does not equal large inputs
        assertFalse(from == testLargeFrom);
        assertFalse(to == testLargeTo);
        assertFalse(contract_ == testLargeContract_);
        // Assert that clean unpacked matches cleaned inputs
        assertEq(address(uint160(from)), largeFrom);
        assertEq(address(uint160(to)), largeTo);
        assertEq(address(uint160(contract_)), largeContract_);
        // unpackAddress and check they do not equal inputs
        (largeFrom) = Storage.unpackAddress(firstPacked);
        (largeTo) = Storage.unpackAddress(secondPacked);
        assembly {
            testLargeFrom := largeFrom
            testLargeTo := largeTo
        }
        // Assert that clean unpacked does not equal large inputs
        assertFalse(from == testLargeFrom);
        assertFalse(to == testLargeTo);
        // Assert that clean unpacked matches cleaned inputs
        assertEq(address(uint160(from)), largeFrom);
        assertEq(address(uint160(to)), largeTo);
    }
}

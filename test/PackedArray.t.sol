// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/PackedArray.sol";

contract PackedAddressArrayTest is Test {
    using PackedAddressArray for PackedAddressArray.Array;

    PackedAddressArray.Array internal arr;

    uint160[] internal arr2;
    address[] internal addrArr;

    function test_compare_gas() public {
        uint256 gasBefore = gasleft();
        addrArr.push(address(0x01));
        addrArr.push(address(0x02));
        addrArr.push(address(0x03));
        address a = addrArr[0];
        address b = addrArr[1];
        address c = addrArr[2];
        console.log("gas used - 20 bytes", gasBefore - gasleft());
        gasBefore = gasleft();
        arr.push(address(0x01));
        arr.push(address(0x02));
        arr.push(address(0x03));
        address aa = arr.get(0);
        address bb = arr.get(1);
        address cc = arr.get(2);
        console.log("gas used - 20 bytes", gasBefore - gasleft());
    }

    function test_packs_addresses_correctly() public {
        arr.push(address(type(uint160).max));
        arr.push(address(type(uint160).max - 1));
        arr.push(address(type(uint160).max - 2));
        assertEq(arr.slots.length, 3); // 2 slots + 1 for the count
        assertEq(arr.get(0), address(type(uint160).max));
        assertEq(arr.get(1), address(type(uint160).max - 1));
        assertEq(arr.get(2), address(type(uint160).max - 2));
    }
}

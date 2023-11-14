// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/PackedArrayYul.sol";

contract PackedAddressArrayTest is Test {
    using PackedAddressArray for PackedAddressArray.Array;

    PackedAddressArray.Array internal arr;

    address[] internal addrArr;

    function test_compare_gas() public {
        uint256 gasBefore = gasleft();
        addrArr.push(address(0x01));
        addrArr.push(address(0x02));
        addrArr.push(address(0x03));
        address a = addrArr[0];
        address b = addrArr[1];
        address c = addrArr[2];
        console.log("gas used not packed - 20 bytes", gasBefore - gasleft());
        gasBefore = gasleft();
        arr.push(address(0x01));
        arr.push(address(0x02));
        arr.push(address(0x03));
        address aa = arr.get(0);
        address bb = arr.get(1);
        address cc = arr.get(2);
        console.log("gas used packed array - 20 bytes", gasBefore - gasleft());
    }

    function test_fuzz_push_get(address a, address b, address c) public {
        arr.push(a);
        arr.push(b);
        arr.push(c);
        assertEq(arr.get(0), a);
        assertEq(arr.get(1), b);
        assertEq(arr.get(2), c);
    }

    function test_gas_details() public {
        uint256 gasBefore = gasleft();
        // do the above but in a loop
        uint256 iterations = 11;
        // TODO: this breaks after 8
        for (uint256 i = 0; i < iterations; i++) {
            gasBefore = gasleft();
            arr.push(address(0x0000111122223333444455556666777788889999));
            console.log("push address number ", i, gasBefore - gasleft());
        }

        for (uint256 i = 0; i < iterations; i++) {
            gasBefore = gasleft();
            arr.get(i);
            console.log("get address number ", i, gasBefore - gasleft());
        }
        console.log("get 1 address", gasBefore - gasleft());
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

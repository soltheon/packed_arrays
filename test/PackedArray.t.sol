// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/PackedArrayYul.sol";

contract PackedAddressArrayTest is Test {
    using PackedAddressArray for PackedAddressArray.Array;

    PackedAddressArray.Array internal arr;

    address[] internal addrArr;

    function test_pop_empty() public {
        vm.expectRevert("Array is empty");
        arr.pop();
    }

    function test_pop_works() public {

        arr.push(address(0xCAFE));
        arr.push(address(0xBEEF));
        arr.pop();
        assertEq(arr.slots.length, 1);

        vm.expectRevert("Index out of bounds");
        arr.get(1);
    }

    function test_pop_sequence() public {
        arr.push(address(0xCAFE));
        arr.push(address(0xDECAF));
        console.log("address[1]", arr.get(1));
        assertEq(arr.get(1), address(0xDECAF));
        arr.pop();
        arr.pop();
        arr.push(address(0xBEEF));
        assertEq(arr.get(0), address(0xBEEF));
    }

    function test_push_pop(address[69] calldata addrs) public {
        for (uint256 i = 0; i < addrs.length; i++) {
            arr.push(addrs[i]);
        }
        assertEq(arr.slots.length, addrs.length);

        // pop all
        for (uint256 i = 0; i < addrs.length; i++) {
            arr.pop();
        }
        assertEq(arr.slots.length, 0);
    }

    function test_fuzz_push_get_single(address a, address b, address c) public {
        arr.push(a);
        arr.push(b);
        arr.push(c);
        assertEq(arr.get(0), a);
        assertEq(arr.get(1), b);
        assertEq(arr.get(2), c);
    }

    function test_fuzz_push_get_loop(address[200] calldata addrs) public {
        for (uint256 i = 0; i < addrs.length; i++) {
            arr.push(addrs[i]);
        }
        for (uint256 i = 0; i < addrs.length; i++) {
            assertEq(arr.get(i), addrs[i]);
        }
    }

    function test_compare_gas() public {
        uint256 gasBefore = gasleft();
        addrArr.push(address(0xCAFE));
        addrArr.push(address(0xBEEF));
        addrArr.push(address(0xDECAF));
        address aa = addrArr[0];
        address bb = addrArr[1];
        address cc = addrArr[2];
        addrArr.pop();
        addrArr.pop();
        addrArr.pop();
        console.log("gas used 3 addresses not packed - 20 bytes", gasBefore - gasleft());
        assertEq(aa, address(0xCAFE));
        assertEq(bb, address(0xBEEF));
        assertEq(cc, address(0xDECAF));

        gasBefore = gasleft();
        arr.push(address(0x0000111122223333444455556666777788889999));
        arr.push(address(0x9999888877776666555544443333222211110000));
        arr.push(address(0x0000111122223333444455556666777788889999));
        address a = arr.get(0);
        address b = arr.get(1);
        address c = arr.get(2);
        arr.pop();
        arr.pop();
        arr.pop();
        console.log("gas used 3 addresses packed array - 20 bytes", gasBefore - gasleft());
        assertEq(a, address(0x0000111122223333444455556666777788889999));
        assertEq(b, address(0x9999888877776666555544443333222211110000));
        assertEq(c, address(0x0000111122223333444455556666777788889999));
    }


    function test_gas_push_get() public {
        uint256 gasBefore = gasleft();
        // do the above but in a loop
        uint256 iterations = 50;

        gasBefore = gasleft();
        for (uint256 i = 0; i < iterations;) {
            arr.push(address(0x0000111122223333444455556666777788889999));
            unchecked {
                i++;
            }
        }
        console.log("push ", iterations, " addresses gas: ", gasBefore - gasleft());

        gasBefore = gasleft();
        for (uint256 i = 0; i < iterations;) {
            arr.get(i);
            unchecked {
                i++;
            }
        }
        console.log("get ", iterations, "addresses gas: ", gasBefore - gasleft());

        gasBefore = gasleft();
        arr.push(address(0xCAFE));
        console.log("push 1 address gas: ", gasBefore - gasleft());
        gasBefore = gasleft();
        arr.get(0);
        console.log("get 1 address gas: ", gasBefore - gasleft());
    }
}

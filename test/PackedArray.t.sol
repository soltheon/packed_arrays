// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/PackedArray.sol";

contract PackedAddressArrayTest is Test {
    using PackedAddressArray for PackedAddressArray.Array;

    PackedAddressArray.Array internal arr;

    function test_set_debug() public {
        address a = address(type(uint160).max);
        address b = address(0xFF << 80);
        for (uint256 i = 0; i < 10; i++) {
            arr.push(a);
        }
        for (uint256 i = 0; i < 10; i++) {
            console.logBytes32(bytes32(arr.slots[i]));
        }
        for (uint256 i = 0; i < 10; i++) {
            arr.set(i, address(b));
            assertEq(arr.get(i), address(b));
        }
        for (uint256 i = 0; i < 10; i++) {
            console.logBytes32(bytes32(arr.slots[i]));
        }
    }

    function test_fuzz_set(address[20] calldata addrsA, address[20] calldata addrsB) public {
        for (uint256 i = 0; i < addrsA.length; i++) {
            arr.push(addrsA[i]);
        }

        for (uint256 i = 0; i < addrsB.length; i++) {
            // console.log("set", i, addrsA[i], addrsB[i]);
            arr.set(i, addrsB[i]);
            // console.log("get", i, arr.get(i));
            assertEq(arr.get(i), addrsB[i]);
        }

        for (uint256 i = 0; i < addrsA.length; i++) {
            arr.set(i, addrsA[i]);
            assertEq(arr.get(i), addrsA[i]);
        }
    }

    function test_fuzz_get_many(address[50] calldata array, uint256 from, uint256 to) public {
        for (uint256 i = 0; i < array.length; i++) {
            arr.push(array[i]);
        }

        if (to > array.length) {
            vm.expectRevert(PackedAddressArray.IndexOutOfBounds.selector);
        } else if (from >= to) {
            vm.expectRevert(PackedAddressArray.InvalidIndexRange.selector);
        }

        address[] memory addrs = arr.getMany(from, to);
        console.log("addrs length", addrs.length);

        for (uint256 i = 0; i < addrs.length; i++) {
            assertEq(addrs[i], array[from + i]);
        }
    }

    function test_pop_empty() public {
        vm.expectRevert(PackedAddressArray.PopEmptyArray.selector);
        arr.pop();
    }

    function test_pop_functionality() public {
        arr.push(address(0xCAFE));
        arr.push(address(0xBEEF));
        arr.pop();
        assertEq(arr.slots.length, 1);

        vm.expectRevert(PackedAddressArray.IndexOutOfBounds.selector);
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
            assertEq(addrs[i], arr.get(i));
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
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/PackedArray.sol";

contract PackedAddressTest is Test {
    using PackedArray for PackedArray.Addresses;

    PackedArray.Addresses internal arr;

    function test_append_push_equivolance(address a) public {
        arr.push(a);
        address[] memory addrs = arr.slice(0, 1);
        arr.append(addrs);
        assertEq(arr.slots.length, 2);
        assertEq(arr.get(0), a);
        assertEq(arr.get(1), a);
    }

    function test_large_array() public {
        uint256 arraySize = 1000;
        address[] memory addrs = new address[](arraySize);
        for (uint160 i = 0; i < arraySize; i++) {
            addrs[i] = address(type(uint160).max - i);
        }

        for (uint256 i = 0; i < 10; i++) {
            arr.append(addrs);
        }
        assertEq(arr.slots.length, arraySize * 10);
    }

    function test_append_empty() public {
        address[] memory addrs = new address[](0);
        arr.append(addrs);
        assertEq(arr.slots.length, 0);
    }

    function test_append_not_empty() public {
        arr.push(address(0xCAFE));
        arr.push(address(0xCAFE));
        arr.push(address(0xCAFE));
        uint256 lengthBefore = arr.slots.length;
        address[] memory addrs = new address[](8);

        for (uint160 i = 0; i < 8; i++) {
            addrs[i] = address(type(uint160).max - i);
        }

        arr.append(addrs);
        assertEq(arr.slots.length, 8 + lengthBefore);

        for (uint256 i = lengthBefore; i < 8 + lengthBefore; i++) {
            assertEq(arr.get(i), addrs[i - lengthBefore]);
        }
    }

    function test_append_fuzz(address[20] calldata addrsA, address[20] memory addrsB) public {
        address[] memory a = new address[](20);
        address[] memory b = new address[](20);
        for (uint256 i = 0; i < addrsA.length; i++) {
            a[i] = addrsA[i];
            b[i] = addrsB[i];
        }
        arr.append(a);
        assertEq(arr.slots.length, addrsA.length);
        for (uint256 i = 0; i < addrsA.length; i++) {
            assertEq(arr.get(i), addrsA[i]);
        }

        arr.append(b);
        assertEq(arr.slots.length, (addrsA.length + addrsB.length));

        for (uint256 i = 0; i < addrsA.length; i++) {
            assertEq(arr.get(i), addrsA[i]);
        }

        for (uint256 i = addrsA.length; i < addrsA.length + addrsB.length; i++) {
            assertEq(arr.get(i), addrsB[i - addrsA.length]);
        }
    }

    function test_fuzz_set(address[3] calldata addrsA, address[3] calldata addrsB) public {
        uint256 arrayLen = addrsA.length;
        assertEq(addrsA.length, addrsB.length);

        for (uint256 i = 0; i < arrayLen; i++) {
            arr.push(addrsA[i]);
        }

        for (uint256 i = 0; i < arrayLen; i++) {
            assertEq(arr.get(i), addrsA[i]);
            arr.set(i, addrsB[i]);
            assertEq(arr.get(i), addrsB[i]);
        }

        for (uint256 i = 0; i < arrayLen; i++) {
            assertEq(arr.get(i), addrsB[i]);
            arr.set(i, addrsA[i]);
            assertEq(arr.get(i), addrsA[i]);
        }
    }

    function test_slice_free_memory() public {
        uint256 freeMem;
        assembly {
            freeMem := mload(0x40)
        }

        while (arr.slots.length < 50) {
            arr.push(address(0xBEEF));
        }

        address[] memory addrs = arr.slice(20, 50);

        uint256 freeMemAfter;
        assembly {
            freeMemAfter := mload(0x40)
        }
        assertEq(freeMem + (32 * addrs.length), freeMemAfter);
    }

    function test_slice_append() public {
        uint256 length = 10;
        while (arr.slots.length < length) {
            arr.push(address(type(uint160).max));
        }

        address[] memory addrs = arr.slice(0, length);
        address[] memory addrs2 = arr.slice(0, length);
        address[] memory addrs3 = arr.slice(0, length);
        assertEq(addrs.length, addrs2.length);
        assertEq(addrs2.length, addrs3.length);
        for (uint256 i = 0; i < length; i++) {
            assertEq(addrs[i], addrs2[i]);
            assertEq(addrs2[i], addrs3[i]);
        }

        arr.append(addrs);
        addrs = arr.slice(0, length * 2);
        addrs2 = arr.slice(0, length * 2);
        assertEq(addrs.length, addrs2.length);

        for (uint256 i = 0; i < length * 2; i++) {
            assertEq(addrs[i], addrs2[i]);
        }
    }

    function test_fuzz_slice(address[50] calldata array, uint256 from, uint256 to) public {
        for (uint256 i = 0; i < array.length; i++) {
            arr.push(array[i]);
        }

        if (to > array.length) {
            vm.expectRevert(PackedArray.IndexOutOfBounds.selector);
        } else if (from >= to) {
            vm.expectRevert(PackedArray.InvalidIndexRange.selector);
        }

        address[] memory addrs = arr.slice(from, to);
        assertEq(addrs.length, to - from);

        for (uint256 i = 0; i < addrs.length; i++) {
            assertEq(addrs[i], array[from + i]);
        }
    }

    function test_slice_correct_amount() public {
        arr.push(address(0xCAFE));
        address[] memory addrs = arr.slice(0, 1);
        assertEq(addrs.length, 1);
        arr.push(address(0));
        addrs = arr.slice(0, 2);
        assertEq(addrs.length, 2);
        addrs = arr.slice(0, 1);
        assertEq(addrs.length, 1);
    }

    function test_pop_empty() public {
        vm.expectRevert(PackedArray.PopEmptyArray.selector);
        arr.pop();
    }

    function test_pop_functionality() public {
        arr.push(address(0xCAFE));
        arr.push(address(0xBEEF));
        arr.pop();
        assertEq(arr.slots.length, 1);

        vm.expectRevert(PackedArray.IndexOutOfBounds.selector);
        arr.get(1);
    }

    function test_pop_sequence() public {
        arr.push(address(0xCAFE));
        arr.push(address(0xDECAF));
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

    function test_fuzz_complex_functionality(address[30] calldata addrs, address a, address b) public {
        address[] memory _addrs = new address[](addrs.length);
        for (uint256 i = 0; i < addrs.length; i++) {
            _addrs[i] = addrs[i];
        }

        // push and append
        arr.push(a);
        assertEq(arr.slots.length, 1);
        assertEq(arr.get(0), a);

        arr.append(_addrs);
        assertEq(arr.slots.length, _addrs.length + 1);
        for (uint256 i = 0; i < _addrs.length; i++) {
            assertEq(arr.get(i + 1), _addrs[i]);
        }

        // remove last 1, and set all to address(0)
        arr.pop();
        assertEq(arr.slots.length, addrs.length);

        for (uint256 i = 0; i < addrs.length; i++) {
            arr.set(i, address(0));
            assertEq(arr.get(i), address(0));
        }
        assertEq(arr.slots.length, addrs.length);
        assertEq(_addrs.length, addrs.length);

        // Get all zero addresses
        address[] memory zeroAddrs = arr.slice(0, addrs.length);
        assertEq(zeroAddrs.length, addrs.length);
        assertEq(arr.slots.length, addrs.length);

        assertEq(_addrs.length, addrs.length);

        // Remove all addresses
        for (uint256 i = 0; i < addrs.length; i++) {
            arr.pop();
        }

        vm.expectRevert(PackedArray.PopEmptyArray.selector);
        arr.pop();
        assertEq(arr.slots.length, 0);

        arr.push(b);
        assertEq(arr.get(0), b);
        assertEq(arr.slots.length, 1);
        arr.set(0, a);
        assertEq(arr.get(0), a);
    }
}

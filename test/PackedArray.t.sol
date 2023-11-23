// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/PackedArray.sol";

contract PackedAddressTest is Test {
    using PackedArray for PackedArray.Addresses;

    PackedArray.Addresses internal arr;

    function test_append_empty() public {
        address[] memory addrs = new address[](8);

        for (uint160 i = 0; i < 8; i++) {
            addrs[i] = address(type(uint160).max - i);
        }

        arr.append(addrs);
        assertEq(arr.slots.length, 8);

        for (uint256 i = 0; i < 8; i++) {
            assertEq(arr.get(i), addrs[i]);
        }
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

    function test_fuzz_all_functionality(address[30] calldata addrs, address a, address b) public {
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

        // TODO: why is this array being reset
        // assertEq(_addrs.length, addrs.length);

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

    function test_set_debug() public {
        address a = address(type(uint160).max);
        address b = address(0xFF << 80);
        for (uint256 i = 0; i < 10; i++) {
            arr.push(a);
        }
        for (uint256 i = 0; i < 10; i++) {
            arr.set(i, address(b));
            assertEq(arr.get(i), address(b));
        }
    }

    function test_fuzz_set(address[20] calldata addrsA, address[20] calldata addrsB) public {
        for (uint256 i = 0; i < addrsA.length; i++) {
            arr.push(addrsA[i]);
        }

        for (uint256 i = 0; i < addrsB.length; i++) {
            arr.set(i, addrsB[i]);
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

    function test_get_many_correct_amount() public {
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
}

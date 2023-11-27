// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/PackedArray.sol";

contract MockPackedArray is StdCheats, StdUtils {
    using PackedArray for PackedArray.Addresses;

    PackedArray.Addresses private arr;
    address[] private arr2;

    function set0(address addr, uint index) public {
        push0(addr);
        index = bound(index, 0, arr2.length - 1);
        arr.set(index, addr);
        arr2[index] = addr;
    }

    function push0(address addr) public {
        arr.push(addr);
        arr2.push(addr);
    }

    function append0(address[] memory addrs) public {
        arr.append(addrs);
        for (uint256 i = 0; i < addrs.length; i++) {
            arr2.push(addrs[i]);
        }
    }

    function pop() public {
        if (arr.slots.length > 0) {
            arr.pop();
            arr2.pop();
        }
    }

    function getter() public view returns (PackedArray.Addresses memory) {
        return arr;
    }

    function getter2() public view returns (address[] memory) {
        return arr2;
    }

}

contract PackedArrayInvariantTest is Test {
    using PackedArray for PackedArray.Addresses;

    MockPackedArray internal mock;
    PackedArray.Addresses internal arr;
    
    function setUp() public {
        mock = new MockPackedArray();
    }

    function invariant_equals() public {
        arr = mock.getter();
        address[] memory arr2 = mock.getter2();

        if (arr.slots.length == 0) {
            assertEq(arr2.length, 0);
            return;
        }

        address[] memory arr3 = arr.slice(0, arr.slots.length);

        assertEq(arr.slots.length, arr2.length);
        assertEq(arr3.length, arr2.length);
        for (uint256 i = 0; i < arr3.length; i++) {
            assertEq(arr.get(i), arr2[i]);
            assertEq(arr3[i], arr2[i]);
        }
    }

 
}

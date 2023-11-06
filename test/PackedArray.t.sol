// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/PackedArray.sol";

contract PackedArrayTest is Test {
    using PackedArray for PackedArray.Array;

    PackedArray.Array internal arr;

    function testFuzz_init(uint8 val) public {
        if (val < 8) {
            vm.expectRevert(PackedArray.InvalidBitSize.selector);
            arr.init(val);
        } else if (val > 128) {
            vm.expectRevert(PackedArray.InvalidBitSize.selector);
            arr.init(val);
        } else if (256 % val != 0) {
            vm.expectRevert(PackedArray.MustBeMultipleOf256.selector);
            arr.init(val);
        } else {
            arr.init(val);
            assertEq(arr.bits(), val, "Bit size not set");
            assertEq(arr.numItems(), 0, "Array should be empty");
        }
    }

    function test_init_not_multiple_of_256_bits() public {
        vm.expectRevert(PackedArray.MustBeMultipleOf256.selector);
        arr.init(116);
    }

    function test_fail_get_beyond_index() public {
        arr.init(8);
        arr.push(15);

        vm.expectRevert(PackedArray.IndexOutOfBounds.selector);
        arr.get(1);
    }

    function test_fail_init_twice() public {
        arr.init(8);

        vm.expectRevert(PackedArray.AlreadyInitialized.selector);
        arr.init(32);
    }

    function test_correct_packing() public {
        arr.init(8);
        uint gasBefore = gasleft();
        for (uint256 i = 0; i < 32; i++) {
            arr.push(10);
        }
        console.log("gas used - 32 bytes", gasBefore - gasleft());
        assertEq(arr.length(), 1);
        assertEq(arr.numItems(), 32);
    }

    function testFuzz_uint8_single(uint8 val) public {
        bytes memory data = abi.encodePacked(val);
        arr.init(uint8(data.length) * 8);

        arr.push(val);
        assertEq(arr.get(0), val, "Value0 not set");

        arr.push(val);
        assertEq(arr.get(1), val, "Value1 not set");

        assertEq(arr.pop(), val, "Pop not returning value");
        assertEq(arr.get(0), val, "Value not set");
    }

    function testFuzz_uint8_multiple(uint8 val1, uint8 val2, uint8 val3) public {
        bytes memory data = abi.encodePacked(val1);
        arr.init(uint8(data.length) * 8);
        arr.push(val1);
        arr.push(val2);
        assertEq(arr.get(1), val2);
        // overwrite second index
        arr.set(1, val3);
        assertEq(arr.get(1), val3);
        assertEq(arr.numItems(), 2);
        arr.pop();
        arr.pop();
        assertEq(arr.numItems(), 0);
        assertEq(arr.length(), 0);
    }

    function testFuzz_large_array(uint128 val1, uint128 val2) public {
        arr.init(128);
        for (uint256 i = 1; i < 100; i++) {
            arr.push(val1);
            arr.push(val2);
            assertEq(arr.length(), i);
            assertEq(arr.numItems(), i * 2);
        }
        // remove all elemetns
        for (uint256 i = arr.length(); i > 0; i--) {
            arr.pop();
            arr.pop();
        }
        assertEq(arr.length(), 0);
        assertEq(arr.numItems(), 0);
        assertEq(arr.inner.length, 1);
    }

    function test_value_lower_than_bitsize() public {
        arr.init(128);
        arr.push(uint64(69));
        arr.push(uint64(69));
        arr.push(uint64(69));
        // should take up 1.5 slots
        assertEq(arr.length(), 2);
        assertEq(arr.numItems(), 3);
        arr.push(uint64(69));
        assertEq(arr.length(), 2);
        assertEq(arr.numItems(), 4);
        arr.push(uint64(69));
        assertEq(arr.length(), 3);
        assertEq(arr.numItems(), 5);
    }

    function test_fails_over_128() public {
        vm.expectRevert(PackedArray.InvalidBitSize.selector);
        arr.init(129);
    }

    function test_pop_empty_array() public {
        arr.init(8);
        vm.expectRevert();
        arr.pop();
    }

    function test_fail_to_use_before_init() public {
        vm.expectRevert();
        arr.pop();

        vm.expectRevert();
        arr.push(10);

        vm.expectRevert();
        arr.get(0);

        vm.expectRevert();
        arr.set(0, 1);
    }

    function test_oversized_value32() public {
        arr.init(32);
        vm.expectRevert();
        arr.push(type(uint32).max + 1);

        vm.expectRevert();
        arr.set(0, type(uint32).max + 1);
    }

    function test_oversized_value64() public {
        arr.init(64);

        vm.expectRevert();
        arr.push(type(uint64).max + 1);

        vm.expectRevert();
        arr.set(0, type(uint64).max + 1);
    }

    function test_oversized_value128() public {
        arr.init(128);

        vm.expectRevert();
        arr.push(type(uint128).max + 1);
    }

    function test_max_value() public {
        arr.init(64);

        arr.push(type(uint64).max);
        arr.set(0, type(uint64).max);
    }

    function test_checkGas() public {
        uint256 gasBefore = gasleft();
        arr.init(64);
        console.log("init gas", gasBefore - gasleft());
        gasBefore = gasleft();
        arr.push(10);
        console.log("push first value gas", gasBefore - gasleft());
        gasBefore = gasleft();
        arr.push(10);
        console.log("push second value gas", gasBefore - gasleft());
        gasBefore = gasleft();
        arr.push(10);
        arr.push(10);
        console.log("push third and 4th value gas", gasBefore - gasleft());
        arr.push(10);
        console.log("push 5th value gas", gasBefore - gasleft());
        gasBefore = gasleft();
        arr.push(10);
        arr.push(10);
        arr.push(10);
        console.log("push 6th, 7th and 8th value gas", gasBefore - gasleft());
    }
}

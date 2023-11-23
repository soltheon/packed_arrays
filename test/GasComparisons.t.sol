// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/PackedArray.sol";

contract PackedAddressGasTest is Test {
    using PackedArray for PackedArray.Addresses;

    PackedArray.Addresses internal arr;

    address[] internal addrArr;

    function test_gas_all_operations_1_addr() public {
        address a = address(0xCAFE);
        address b = address(0xBEEF);
        uint256 gas0 = gasleft();
        addrArr.push(a);
        a = addrArr[0];
        addrArr[0] = b;
        addrArr.pop();
        console.log("gas regular array push/set/get/pop: ", gas0 - gasleft());

        uint256 gas1 = gasleft();
        arr.push(a);
        a = arr.get(0);
        arr.set(0, b);
        arr.pop();
        console.log("gas packed array push/set/get/pop: ", gas1 - gasleft());
    }

    function test_gas_all_operations_5_addr() public {
        unchecked {
            address a = address(0xCAFE);
            address b = address(0xBEEF);
            uint256 gas0 = gasleft();
            for (uint256 i = 0; i < 5; i++) {
                addrArr.push(a);
                a = addrArr[i];
                addrArr[i] = b;
            }
            addrArr.pop();
            console.log("gas regular array: push/set/get/pop", gas0 - gasleft());

            uint256 gas1 = gasleft();
            for (uint256 i = 0; i < 5; i++) {
                arr.push(a);
                a = arr.get(i);
                arr.set(i, b);
            }
            arr.pop();
            console.log("gas packed array: push/set/get/pop", gas1 - gasleft());
        }
    }

    function test_gas_all_operations_50_addr() public {
        unchecked {
            address a = address(0xCAFE);
            address b = address(0xBEEF);
            uint256 gas0 = gasleft();
            for (uint256 i = 0; i < 50; i++) {
                addrArr.push(a);
                a = addrArr[0];
                addrArr[i] = b;
            }
            addrArr.pop();
            console.log("gas regular array push/set/get/pop: ", gas0 - gasleft());

            uint256 gas1 = gasleft();
            for (uint256 i = 0; i < 50; i++) {
                arr.push(a);
                a = arr.get(i);
                arr.set(i, b);
            }
            arr.pop();
            console.log("gas packed array: push/set/get/pop ", gas1 - gasleft());
        }
    }

    function test_gas_all_operations_100_addr() public {
        unchecked {
            address a = address(0xCAFE);
            address b = address(0xBEEF);
            uint256 gas0 = gasleft();
            for (uint256 i = 0; i < 100; i++) {
                addrArr.push(a);
                a = addrArr[0];
                addrArr[i] = b;
            }
            addrArr.pop();
            console.log("gas regular array push/set/get/pop: ", gas0 - gasleft());

            uint256 gas1 = gasleft();
            for (uint256 i = 0; i < 100; i++) {
                arr.push(a);
                a = arr.get(i);
                arr.set(i, b);
            }
            arr.pop();
            console.log("gas packed array: push/set/get/pop ", gas1 - gasleft());
        }
    }

    function test_gas_set_50() public {
        // set up array
        uint256 numberOfAddrs = 50;
        address[] memory normalArray = new address[](numberOfAddrs);
        for (uint256 i = 0; i < normalArray.length; i++) {
            address addr = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
            normalArray[i] = addr;
        }

        uint256 gasBefore = gasleft();
        for (uint256 i = 0; i < normalArray.length; i++) {
            addrArr.push(normalArray[i]);
        }
        console.log("gas used normal address array: ", gasBefore - gasleft());

        uint256 gasBefore2 = gasleft();
        arr.append(normalArray);
        console.log("gas used packed address array: ", gasBefore2 - gasleft());
    }


    function test_gas_set_100() public {
        // set up array
        uint256 numberOfAddrs = 100;
        address[] memory normalArray = new address[](numberOfAddrs);
        for (uint256 i = 0; i < normalArray.length; i++) {
            address addr = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
            normalArray[i] = addr;
        }

        uint256 gasBefore = gasleft();
        for (uint256 i = 0; i < normalArray.length; i++) {
            addrArr.push(normalArray[i]);
        }
        console.log("gas used normal address array: ", gasBefore - gasleft());

        uint256 gasBefore2 = gasleft();
        arr.append(normalArray);
        console.log("gas used packed address array: ", gasBefore2 - gasleft());
    }




    function test_gas_get_100_packed() public {
        uint256 numberOfAddrs = 100;

        for (uint256 i = 0; i < numberOfAddrs; i++) {
            address addr = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
            arr.push(addr);
            addrArr.push(addr);
        }

        address[] memory normalArray = new address[](numberOfAddrs);
        uint256 gas0 = gasleft();
        for (uint256 i = 0; i < normalArray.length; i++) {
            normalArray[i] = addrArr[i];
        }
        console.log("gas used normal address array: ", gas0 - gasleft());

        address[] memory array = new address[](numberOfAddrs);
        uint256 gas1 = gasleft();
        for (uint256 i = 0; i < array.length; i++) {
            array[i] = arr.get(i);
        }
        console.log("gas used get", gas1 - gasleft());

        uint256 gas2 = gasleft();
        address[] memory addrs = arr.get(0, array.length - 1);
        console.log("gas used getMany", gas2 - gasleft());

        for (uint256 i = 0; i < addrs.length; i++) {
            assertEq(addrs[i], array[i]);
        }
    }

    function test_gas_get_50_packed() public {
        uint256 numberOfAddrs = 50;

        for (uint256 i = 0; i < numberOfAddrs; i++) {
            address addr = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
            arr.push(addr);
            addrArr.push(addr);
        }

        address[] memory normalArray = new address[](numberOfAddrs);
        uint256 gas0 = gasleft();
        for (uint256 i = 0; i < normalArray.length; i++) {
            normalArray[i] = addrArr[i];
        }
        console.log("gas used normal address array: ", gas0 - gasleft());

        address[] memory array = new address[](numberOfAddrs);
        uint256 gas1 = gasleft();
        for (uint256 i = 0; i < array.length; i++) {
            array[i] = arr.get(i);
        }
        console.log("gas used get", gas1 - gasleft());

        uint256 gas2 = gasleft();
        address[] memory addrs = arr.get(0, array.length - 1);
        console.log("gas used getMany", gas2 - gasleft());

        for (uint256 i = 0; i < addrs.length; i++) {
            assertEq(addrs[i], array[i]);
        }
    }

    function test_compare_gas_2_items() public {
        // regular array
        uint256 gasBefore = gasleft();
        addrArr.push(address(0xCAFE));
        addrArr.push(address(0xBEEF));
        address aa = addrArr[0];
        address bb = addrArr[1];
        addrArr.pop();
        addrArr.pop();
        console.log("gas used 2 addresses not packed - 20 bytes", gasBefore - gasleft());
        assertEq(aa, address(0xCAFE));
        assertEq(bb, address(0xBEEF));

        // packed array
        gasBefore = gasleft();
        arr.push(address(0x0000111122223333444455556666777788889999));
        arr.push(address(0x9999888877776666555544443333222211110000));
        address a = arr.get(0);
        address b = arr.get(1);
        arr.pop();
        arr.pop();
        console.log("gas used 2 addresses packed array - 20 bytes", gasBefore - gasleft());
        assertEq(a, address(0x0000111122223333444455556666777788889999));
        assertEq(b, address(0x9999888877776666555544443333222211110000));
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

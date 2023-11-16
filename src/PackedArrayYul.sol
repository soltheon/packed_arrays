// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.21;

import "forge-std/Test.sol";

library PackedAddressArray {
    struct Array {
        uint256[] slots;
    }

    function push(Array storage arr, address value) internal {
        assembly {
            let numItems := sload(arr.slot)
            let totalBitsUsed := mul(numItems, 160)
            let slotIndex := div(totalBitsUsed, 256)
            let offset := mod(totalBitsUsed, 256)

            // Calculate storage spot for array
            let freeMemPtr := mload(0x40)
            mstore(freeMemPtr, arr.slot)
            let storageSlot := keccak256(freeMemPtr, 0x20)
            let arraySlot := add(storageSlot, slotIndex)

            switch gt(offset, 96)
            case 1 {
                // If the offset is greater than 96, we need to split the address across two slots
                let sliceLength := sub(160, sub(256, offset))
                sstore(arraySlot, or(sload(arraySlot), shr(sliceLength, value)))
                sstore(add(arraySlot, 1), shl(sub(256, sliceLength), value))
            }
            default {
                // If the offset is less than 96, we can fit the whole address in the slot
                sstore(arraySlot, or(sload(arraySlot), shl(sub(96, offset), value)))
            }
            // Increment array
            sstore(arr.slot, add(sload(arr.slot), 1)) // increment array length
        }
    }

    function pop(Array storage arr) internal {
        uint numItems = arr.slots.length;
        require(numItems > 0, "Array is empty");

        assembly {

            let totalBitsUsed := mul(numItems, 160)
            let slotIndex := div(totalBitsUsed, 256)
            let offset := mod(totalBitsUsed, 256)
            
            // Calculate storage spot for array
            let freeMemPtr := mload(0x40)
            mstore(freeMemPtr, arr.slot)
            let storageSlot := keccak256(freeMemPtr, 0x20)
            let arraySlot := add(storageSlot, slotIndex)

            switch gt(offset, 159)
            case 1 {
                // If offset is greater than 160, a whole address should exist here
                let rawSlotValue := sload(arraySlot)

                // trim the last address + padding
                let sliceLength := add(160, sub(256, offset))
                let newValue := shl(sliceLength, shr(sliceLength, rawSlotValue))
                sstore(arraySlot, newValue)
            }
            default {
                // The address to pop exists across two slots
                
                // The second slot can be zeroed out since nothing else should be there
                sstore(arraySlot, 0)

                let decrementedArraySlot := sub(arraySlot, 1)
                let RawSlotValue := sload(decrementedArraySlot)

                // Number of bits to trim off end of this slot
                let sliceLength := sub(160, offset)
                let newValue := shl(sliceLength, shr(sliceLength, RawSlotValue))
                sstore(decrementedArraySlot, newValue)

            }
            // Decrement array length
            sstore(arr.slot, sub(numItems, 1))
        }
   }

    function get(Array storage arr, uint256 index) internal view returns (address addr) {
        require(index < arr.slots.length, "Index out of bounds");

        assembly {
            let bitStart := mul(index, 160)
            let startSlot := div(bitStart, 256)
            let offset := mod(bitStart, 256)

            // Calculate storage spot for array
            let freeMemPtr := mload(0x40)
            mstore(freeMemPtr, arr.slot)
            let storageSlot := keccak256(freeMemPtr, 0x20)
            let storageSlotIndex := add(storageSlot, startSlot)

            switch gt(offset, 96)
            case 1 {
                // If the offset is greater than 96, we need to get the address across two slots
                let sliceLength := sub(160, sub(256, offset))
                // Trim off 'offset' number of bits and 
                let highBits := shr(sub(offset, sliceLength), shl(offset, sload(storageSlotIndex)))
                let lowBits := shr(sub(256, sliceLength), sload(add(storageSlotIndex, 1)))
                addr := or(highBits, lowBits)
            }
            default {
                // If the offset is less than 96 the address is in this slot alone
                addr := shr(sub(96, offset), sload(storageSlotIndex))
            }
        }
    }
}

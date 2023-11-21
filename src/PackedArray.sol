// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.21;

import "forge-std/Test.sol";

library PackedAddressArray {
    error IndexOutOfBounds();
    error InvalidIndexRange();
    error PopEmptyArray();

    struct Array {
        uint256[] slots;
    }

    function getMany(Array storage arr, uint256 fromIndex, uint256 toIndex)
        internal
        view
        returns (address[] memory addrs)
    {
        uint256 arrayLength = arr.slots.length;
        if (toIndex > arrayLength) {
            revert IndexOutOfBounds();
        }
        if (fromIndex >= toIndex) {
            revert InvalidIndexRange();
        }

        assembly {
            // for loop
            let i := fromIndex
            let numItems := sub(toIndex, fromIndex)
            let bitsAtStart := mul(i, 160)
            let startSlot := div(bitsAtStart, 256)
            let offset := mod(bitsAtStart, 256)

            // Allocate memory for the arrayLength
            mstore(addrs, numItems)
            let freeMemPtr := mload(0x40)
            let arrayEnd := add(addrs, mul(numItems, 32))
            // set free memory to end of array
            mstore(0x40, add(arrayEnd, 32))

            // Calculate storage spot for arrayLength
            mstore(0x00, arr.slot)
            let storageSlot := keccak256(0x00, 0x20)
            let storageSlotIndex := add(storageSlot, startSlot)

            // Cache beginning of array
            let arrayPtr := addrs
            // Cache raw slot value to avoid multiple sloads
            let cachedStorageValue := sload(storageSlotIndex)

            for {} lt(i, toIndex) { i := add(i, 1) } {
                arrayPtr := add(arrayPtr, 32)
                switch gt(offset, 96)
                // If the offset is greater than 96, we need to get the address across two slots
                case 1 {
                    let sliceLength := sub(160, sub(256, offset))
                    // Slice end of address from previous slot
                    let highBits := shr(sub(offset, sliceLength), shl(offset, cachedStorageValue))
                    // Move to next slot and grab the rest of the address
                    storageSlotIndex := add(storageSlotIndex, 1)
                    cachedStorageValue := sload(storageSlotIndex)
                    let lowBits := shr(sub(256, sliceLength), cachedStorageValue)
                    mstore(arrayPtr, or(highBits, lowBits))
                }
                // If the offset is less than 96 the address is fully in this slot
                default { mstore(arrayPtr, shr(sub(96, offset), cachedStorageValue)) }

                offset := mod(add(offset, 160), 256)

                if iszero(offset) {
                    storageSlotIndex := add(storageSlotIndex, 1)
                    cachedStorageValue := sload(storageSlotIndex)
                }
            }
        }
    }

    function push(Array storage arr, address value) internal {
        assembly {
            let numItems := sload(arr.slot)
            let totalBitsUsed := mul(numItems, 160)
            let slotIndex := div(totalBitsUsed, 256)
            let offset := mod(totalBitsUsed, 256)

            // Calculate storage spot for array
            mstore(0x0, arr.slot)
            let storageSlot := keccak256(0x0, 0x20)
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
        uint256 numItems = arr.slots.length;

        if (numItems == 0) {
            revert PopEmptyArray();
        }

        assembly {
            let totalBitsUsed := mul(numItems, 160)
            let slotIndex := div(totalBitsUsed, 256)
            let offset := mod(totalBitsUsed, 256)

            // Calculate storage spot for array
            mstore(0x0, arr.slot)
            let storageSlot := keccak256(0x0, 0x20)
            let arraySlot := add(storageSlot, slotIndex)

            switch gt(offset, 159)
            case 1 {
                // If offset is greater than 159, the whole address should exist here
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

    function set(Array storage arr, uint256 index, address value) internal {
        if (index >= arr.slots.length) {
            revert IndexOutOfBounds();
        }

        assembly {
            let bitStart := mul(index, 160)
            let startSlot := div(bitStart, 256)
            let offset := mod(bitStart, 256)

            // Calculate storage spot for array
            mstore(0x0, arr.slot)
            let storageSlot := keccak256(0x0, 0x20)
            let storageSlotIndex := add(storageSlot, startSlot)

            switch gt(offset, 96)
            case 1 {
                // If the offset is greater than 96, we need to split the address across two slots
                /*
                let sliceLength := sub(160, sub(256, offset))
                sstore(storageSlotIndex, or(and(sload(storageSlotIndex), shl(sub(256, sliceLength), value)), shr(sliceLength, value)))
                sstore(add(storageSlotIndex, 1), shl(sub(256, sliceLength), value))
                */

                // TODO: how could this possibly be clearing the old bits?
                let sliceLength := sub(160, sub(256, offset))
                sstore(storageSlotIndex, or(sload(storageSlotIndex), shr(sliceLength, value)))
                sstore(add(storageSlotIndex, 1), shl(sub(256, sliceLength), value))
            }
            default {
                // If the offset is less than 96, we can fit the whole address in the slot
                // Preserve offset
                let sliceLength := sub(256, offset)
                let cleanedSlot := shl(sliceLength, shr(sliceLength, sload(storageSlotIndex)))
                let newValue := shl(sub(96, offset), value)
                sstore(storageSlotIndex, or(cleanedSlot, newValue))
            }
        }
    }

    function get(Array storage arr, uint256 index) internal view returns (address addr) {
        if (index >= arr.slots.length) {
            revert IndexOutOfBounds();
        }

        assembly {
            let bitStart := mul(index, 160)
            let startSlot := div(bitStart, 256)
            let offset := mod(bitStart, 256)

            // Calculate storage spot for array
            mstore(0x0, arr.slot)
            let storageSlot := keccak256(0x0, 0x20)
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

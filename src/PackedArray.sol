// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.21;

import "forge-std/Test.sol";

library PackedArray {
    error IndexOutOfBounds();
    error InvalidIndexRange();
    error PopEmptyArray();

    struct Addresses {
        uint256[] slots;
    }

    function append(Addresses storage arr, address[] memory addrs) internal {
        assembly {
            let arrayLen := sload(arr.slot)

            let bitsAtStart := mul(arrayLen, 160)
            let startSlot := div(bitsAtStart, 256)
            let offset := mod(bitsAtStart, 256)

            // calculate storage slot
            mstore(0x00, arr.slot)
            let storageSlot := keccak256(0x00, 0x20)
            let storageSlotIndex := add(storageSlot, startSlot)
            let cachedStorageValue := sload(storageSlotIndex)

            let newAddrsLen := mload(addrs)
            let i := 0

            for {} lt(i, newAddrsLen) { i := add(i, 1) } {
                let value := mload(add(add(addrs, 32), mul(i, 32)))

                switch gt(offset, 96)
                case 1 {
                    // If the offset is greater than 96, we need to split the address across two slots
                    let sliceLength := sub(160, sub(256, offset))
                    sstore(storageSlotIndex, or(cachedStorageValue, shr(sliceLength, value)))
                    storageSlotIndex := add(storageSlotIndex, 1)
                    cachedStorageValue := shl(sub(256, sliceLength), value)
                }
                default {
                    // If the offset is less than 96, we can fit the whole address in the slot
                    cachedStorageValue := or(cachedStorageValue, shl(sub(96, offset), value))
                }

                offset := mod(add(offset, 160), 256)

                // If next offset is 0, update storage slot beforehand
                if iszero(offset) {
                    sstore(storageSlotIndex, cachedStorageValue)
                    storageSlotIndex := add(storageSlotIndex, 1)
                    cachedStorageValue := sload(storageSlotIndex)
                }
            }

            if gt(cachedStorageValue, 0) { sstore(storageSlotIndex, cachedStorageValue) }

            // Increment array
            sstore(arr.slot, add(newAddrsLen, arrayLen)) // increment array length
        }
    }

    // Gets addresses starting at fromIndex..toIndex (does not include toIndex)
    function slice(Addresses storage arr, uint256 fromIndex, uint256 toIndex)
        internal
        view
        returns (address[] memory addrs)
    {
        assembly {
            let length := sload(arr.slot)

            if gt(toIndex, length) {
                mstore(0x00, 0x4e23d035) // IndexOutOfBounds()
                revert(0x1c, 0x04)
            }

            if iszero(gt(toIndex, fromIndex)) {
                mstore(0x00, 0x92f1b435) // InvalidIndexRange()
                revert(0x1c, 0x04)
            }

            // for loop
            let i := fromIndex
            let numItems := sub(toIndex, fromIndex)
            let bitsAtStart := mul(i, 160)
            let startSlot := div(bitsAtStart, 256)
            let offset := mod(bitsAtStart, 256)

            // Allocate memory for the returned arrayLength
            mstore(addrs, numItems)
            let freeMemPtr := mload(0x40)
            let arrayEnd := add(addrs, mul(numItems, 32))
            // update free memory to end of array
            mstore(0x40, add(arrayEnd, 32))

            // Calculate storage spot for returned arrayLength
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

                // If next offset is 0, update storage slot beforehand
                if iszero(offset) {
                    storageSlotIndex := add(storageSlotIndex, 1)
                    cachedStorageValue := sload(storageSlotIndex)
                }
            }
        }
    }

    // Push an address into the array
    function push(Addresses storage arr, address value) internal {
        assembly {
            let numItems := sload(arr.slot)
            let totalBitsUsed := mul(numItems, 160)
            let slotIndex := div(totalBitsUsed, 256)
            let offset := mod(totalBitsUsed, 256)

            // Calculate storage spot for array
            mstore(0x0, arr.slot)
            let storageSlot := keccak256(0x0, 0x20)
            let storageSlotIndex := add(storageSlot, slotIndex)

            switch gt(offset, 96)
            case 1 {
                // If the offset is greater than 96, we need to split the address across two slots
                let sliceLength := sub(160, sub(256, offset))
                sstore(storageSlotIndex, or(sload(storageSlotIndex), shr(sliceLength, value)))
                sstore(add(storageSlotIndex, 1), shl(sub(256, sliceLength), value))
            }
            default {
                // If the offset is less than 96, we can fit the whole address in the slot
                sstore(storageSlotIndex, or(sload(storageSlotIndex), shl(sub(96, offset), value)))
            }
            // Increment array
            sstore(arr.slot, add(sload(arr.slot), 1)) // increment array length
        }
    }

    // Remove last address from array and decrement length
    function pop(Addresses storage arr) internal {
        assembly {
            // Calculate storage spot for array
            mstore(0x0, arr.slot)
            let storageSlot := keccak256(0x0, 0x20)
            let numItems := sload(arr.slot)

            if iszero(numItems) {
                mstore(0x00, 0xcef37a85) // PopEmptyArray()
                revert(0x1c, 0x04)
            }

            // calculate offset
            let totalBitsUsed := mul(numItems, 160)
            let slotIndex := div(totalBitsUsed, 256)
            let offset := mod(totalBitsUsed, 256)

            let indexToPop := add(storageSlot, slotIndex)

            switch gt(offset, 159)
            // If offset is greater than 159, the whole address should exist here
            case 1 {
                let rawSlotValue := sload(indexToPop)

                // trim the last address + padding
                let sliceLength := add(160, sub(256, offset))
                let newValue := shl(sliceLength, shr(sliceLength, rawSlotValue))
                sstore(indexToPop, newValue)
            }
            // The address to pop exists across two slots
            default {
                // The second slot can be zeroed out since nothing else should be there
                sstore(indexToPop, 0)

                let decrementedArraySlot := sub(indexToPop, 1)
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

    // Replace an addres in the array with new address value
    function set(Addresses storage arr, uint256 index, address value) internal {
        assembly {
            let length := sload(arr.slot)

            if iszero(gt(length, index)) {
                mstore(0x00, 0x4e23d035) // IndexOutOfBounds()
                revert(0x1c, 0x04)
            }

            let bitStart := mul(index, 160)
            let startSlot := div(bitStart, 256)
            let offset := mod(bitStart, 256)

            // Calculate storage spot for array
            mstore(0x0, arr.slot)
            let storageSlot := keccak256(0x0, 0x20)
            let storageSlotIndex := add(storageSlot, startSlot)

            switch gt(offset, 96)
            // Need to replace address across two slots
            case 1 {
                // Remove lower bits from storage and store upper bits of new value
                let sliceLength := sub(256, offset)
                let cleanedSlot := shl(sliceLength, shr(sliceLength, sload(storageSlotIndex)))
                let sliceRemainder := sub(160, sliceLength)
                sstore(storageSlotIndex, or(cleanedSlot, shr(sliceRemainder, value)))
                // Remove upper bits and store lower bits of new value
                let nextStorageSlot := add(storageSlotIndex, 1)
                cleanedSlot := shr(sliceRemainder, shl(sliceRemainder, sload(nextStorageSlot)))
                sstore(nextStorageSlot, or(cleanedSlot, shl(sub(256, sliceRemainder), value)))
            }
            // If the offset is less than 96, we can fit the whole address in the slot
            default {
                let sliceLength := sub(96, offset)
                let addressMask := shl(sliceLength, 0xffffffffffffffffffffffffffffffffffffffff)
                let cleanedSlot := and(sload(storageSlotIndex), not(addressMask))
                sstore(storageSlotIndex, or(cleanedSlot, shl(sliceLength, value)))
            }
        }
    }

    // Get an address from the array
    function get(Addresses storage arr, uint256 index) internal view returns (address addr) {
        assembly {
            let length := sload(arr.slot)

            if iszero(gt(length, index)) {
                mstore(0x00, 0x4e23d035) // IndexOutOfBounds()
                revert(0x1c, 0x04)
            }

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

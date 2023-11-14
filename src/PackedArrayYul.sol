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

                mstore(0x00, arr.slot)
                let storageSlot := keccak256(0x00, 0x20)
                let arraySlot := add(storageSlot, slotIndex)

                switch gt(offset, 96)
                case 1 {
                    // If the offset is greater than 96, we need to split the address across two slots
                    let sliceLength := sub(160, sub(256, offset))
                    sstore(arraySlot, or(sload(arraySlot), shr(sliceLength, value)))
                    sstore(add(arraySlot, 1), shl(sub(256, sliceLength), value))
                }
                default {
                    // If the offset is less than 96, we can fit the whole address in the slots
                    sstore(arraySlot, or(sload(arraySlot), shl(sub(96, offset), value)))
                }

                sstore(arr.slot, add(sload(arr.slot), 1)) // increment array length
            }
    }

    function pop(Array storage arr) internal returns (address addr) {
        require(arr.slots.length > 1, "Array is empty");
        // get total number of items
        uint256 numItems = arr.slots[0];

        // Each address takes up 160 bits. We can fit 1 whole address in each slot,
        // and a part of the next address if there's space.
        uint256 totalBitsUsed = numItems * 160;
        uint256 slotIndex = totalBitsUsed / 256 + 1;
        uint256 offset = totalBitsUsed % 256; // The start position of the next address to be stored

        if (offset <= 96) {
            // If the offset is less than 96, we can delete the whole slot
            addr = address(uint160(arr.slots[slotIndex] << (96 - offset)));
            delete arr.slots[slotIndex];
            arr.slots[0]--;
        } else {
            // If the offset is greater than 96, we need to delete the address accross multiple slots
            /*
                uint256 sliceLength = 160 - (256 - offset);
                arr.slots[slotIndex] |= val >> sliceLength;
                arr.slots.push(val << (256 - sliceLength));
                arr.slots[0]++;
                */
        }
    }

    function get(Array storage arr, uint256 index) internal view returns (address) {
        require(index < arr.slots.length, "Index out of bounds");

        unchecked {
            // Calculate the starting bit of the address indexed
            uint256 bitStart = index * 160;
            // Determine the slot containing the start of the address
            uint256 startSlot = bitStart / 256; // Adjusting for the first slot being the count
            // Calculate the offset in bits within the starting slot
            uint256 offset = bitStart % 256;

            // If the address is fully contained within a single slot, extract and return it
            if (offset <= 96) {
                return address(uint160(arr.slots[startSlot] >> (96 - offset)));
            } else {
                // Address spans two slots, need to extract high and low bits from the slots
                uint256 bitsInSecondSlot = (160 - (256 - offset));
                uint256 highBits = ((arr.slots[startSlot] << offset) >> (offset - (bitsInSecondSlot)));
                uint256 lowBits;

                if (startSlot + 1 < arr.slots.length) {
                    // Ensure we do not read beyond the array's bounds if we're at the last address
                    lowBits = arr.slots[startSlot + 1] >> (256 - (bitsInSecondSlot));
                }

                // Combine the two parts to form the full address and return
                return address(uint160((highBits | lowBits)));
            }
        }
    }
}

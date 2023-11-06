// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.21;

import "forge-std/Test.sol";

library PackedAddressArray {
    struct Array {
        uint256[] slots;
    }

    function push(Array storage arr, address value) internal {
        unchecked {
            if (arr.slots.length == 0) {
                arr.slots.push(1);
                arr.slots.push(uint256(uint160(value)) << 96);
                return;
            }

            // get total number of items
            uint256 numItems = arr.slots[0];

            // Each address takes up 160 bits. We can fit 1 whole address in each slot,
            // and a part of the next address if there's space.
            uint256 val = uint256(uint160(value));
            uint256 totalBitsUsed = numItems * 160;
            uint256 slotIndex = totalBitsUsed / 256 + 1;
            uint256 offset = totalBitsUsed % 256; // The start position of the next address to be stored

            if (offset <= 96) {
                // If the offset is less than 96, we can fit the whole address in the slot
                arr.slots[slotIndex] |= uint256(val) << (96 - offset);
                arr.slots[0]++;
            } else {
                // If the offset is greater than 96, we need to split the address across two slots
                uint256 sliceLength = 160 - (256 - offset);
                arr.slots[slotIndex] |= uint256(val) >> sliceLength;
                arr.slots.push(val << (256 - sliceLength));
                arr.slots[0]++;
            }
        }
    }

    function pop(Array storage arr) internal returns (address addr) {
        require(arr.slots.length > 1, "Array is empty");

        uint256 numItems = arr.slots[0];
        require(numItems > 0, "No items to pop");

        // Decrement the count of items
        arr.slots[0]--;

        // Each address takes up 160 bits. Calculate the slot index and the offset within the slot.
        uint256 totalBitsUsed = (numItems - 1) * 160;
        uint256 slotIndex = totalBitsUsed / 256 + 1; // Corrected to '+ 1' to account for the first slot holding the count
        uint256 offset = totalBitsUsed % 256; // Offset for the last item

        if (offset == 0) {
            // If offset is 0, the last address is fully contained in the last slot
            addr = address(uint160(arr.slots[slotIndex]));
            arr.slots.pop(); // Remove the now-unused slot
        } else {
            // If the offset is not 0, the last address is split across the last two slots
            uint256 lastSlotValue = arr.slots[slotIndex] >> offset;
            uint256 secondLastSlotValue = arr.slots[slotIndex - 1];

            // Combine the parts of the address
            addr = address(uint160((secondLastSlotValue << (160 - offset)) | lastSlotValue));

            // If the last address was partially in the last slot, we clean it up
            arr.slots[slotIndex] = secondLastSlotValue & ~((1 << (160 - offset)) - 1);

            // If after this operation the last slot has no useful data (everything was in the second last slot), we remove it
            if (offset <= 96) {
                arr.slots.pop();
            }
        }
    }

    function get(Array storage arr, uint256 index) internal view returns (address) {
        require(index < arr.slots[0], "Index out of bounds");

        unchecked {
            // Calculate the starting bit of the address indexed
            uint256 bitStart = index * 160;
            // Determine the slot containing the start of the address
            uint256 startSlot = bitStart / 256 + 1; // Adjusting for the first slot being the count

            // Calculate the offset in bits within the starting slot
            uint256 offset = bitStart % 256;

            // If the address is fully contained within a single slot, extract and return it
            if (offset <= 96) {
                // If the whole address fits in the current slot without overflowing to the next
                return address(uint160((arr.slots[startSlot] >> (96 - offset)) & ((1 << 160) - 1)));
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

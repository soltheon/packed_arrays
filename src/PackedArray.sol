// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.21;

library PackedArray {
    error AlreadyInitialized();
    error InvalidBitSize();
    error MustBeMultipleOf256();
    error IndexOutOfBounds();

    /*

    The first slot of the array is used to store metadata about the array.
    | 31 bytes | 1 byte  |
    | numItems | numBits |

    Warning: 
        -Use the length() getter to get the true length of the array since the first slot is used for metadata
        -Use numItems() to get the total number of packed items
    */
    struct Array {
        uint256[] inner;
    }

    function init(Array storage data, uint8 numBits) internal {
        if (data.inner.length > 0) {
            revert AlreadyInitialized();
        }
        if (numBits < 8 || numBits > 128) {
            revert InvalidBitSize();
        }
        if (256 % numBits != 0) {
            revert MustBeMultipleOf256();
        }
        data.inner.push(numBits);
    }

    function push(Array storage data, uint256 value) internal {
        uint256 metadata = data.inner[0];
        uint8 numBits = uint8(metadata);
        uint256 _numItems = metadata >> 8;
        (uint256 arrayIndex, uint256 offset) = getIndexAndOffset(
            numBits,
            _numItems
        );

        // Update the length
        unchecked {
            _numItems++;
            updateNumItems(data, _numItems, numBits);
        }

        // Expand the array if necessary
        if (arrayIndex >= data.inner.length) {
            data.inner.push(0);
        }

        uint256 mask = getMask(numBits, offset);
        data.inner[arrayIndex] =
            (data.inner[arrayIndex] & ~mask) |
            (value << offset);
    }

    function pop(Array storage data) internal returns (uint256) {
        uint256 metadata = data.inner[0];
        uint8 numBits = uint8(metadata);
        uint256 _numItems = metadata >> 8;
        unchecked {
            _numItems--;
        }
        uint256 lastElement = get(data, _numItems);

        // Update the number of items
        updateNumItems(data, _numItems, numBits);

        if (canStorageBeFreed(data.inner.length, _numItems, numBits)) {
            data.inner.pop();
        }

        return lastElement;
    }

    function set(Array storage data, uint256 index, uint256 value) internal {
        uint256 metadata = data.inner[0];
        uint8 numBits = uint8(metadata);
        uint256 _numItems = metadata >> 8;

        if (index >= _numItems) {
            revert IndexOutOfBounds();
        }

        (uint256 arrayIndex, uint256 offset) = getIndexAndOffset(
            numBits,
            index
        );

        uint256 mask = getMask(numBits, offset);
        data.inner[arrayIndex] =
            (data.inner[arrayIndex] & ~mask) |
            (value << offset);
    }

    function get(
        Array storage data,
        uint256 index
    ) internal view returns (uint256) {
        uint256 metadata = data.inner[0];
        uint8 numBits = uint8(metadata);
        uint256 _numItems = metadata >> 8;

        if (index >= _numItems) {
            revert IndexOutOfBounds();
        }

        (uint256 arrayIndex, uint256 offset) = getIndexAndOffset(
            numBits,
            index
        );

        uint256 mask = getMask(numBits, offset);
        return (data.inner[arrayIndex] & mask) >> offset;
    }

    function canStorageBeFreed(
        uint256 arrayLength,
        uint256 _numItems,
        uint256 bitSize
    ) internal pure returns (bool available) {
        assembly {
            let activeSlots := div(add(mul(_numItems, bitSize), 255), 256)
            available := lt(activeSlots, sub(arrayLength, 1))
        }
    }

    function getIndexAndOffset(
        uint256 numBits,
        uint256 index
    ) internal pure returns (uint256 arrayIndex, uint256 offset) {
        assembly {
            let perSlot := div(256, numBits)
            arrayIndex := add(div(index, perSlot), 1) // +1 to skip metadata slot
            offset := mul(mod(index, perSlot), numBits)
        }
    }

    function getMask(
        uint256 numBits,
        uint256 offset
    ) internal pure returns (uint256 mask) {
        assembly {
            mask := sub(shl(numBits, 1), 1)
            mask := shl(offset, mask)
        }
    }

    function length(Array storage data) internal view returns (uint256) {
        return data.inner.length - 1; // first item is metadata
    }

    function numItems(Array storage data) internal view returns (uint256) {
        return data.inner[0] >> 8;
    }

    function updateNumItems(
        Array storage data,
        uint256 _numItems,
        uint8 numBits
    ) internal {
        data.inner[0] = (_numItems << 8) | numBits;
    }

    function bits(Array storage data) internal view returns (uint8) {
        return uint8(data.inner[0]);
    }
}

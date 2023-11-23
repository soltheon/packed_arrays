## Solidity Packed Arrays

## Overview
Solidity Packed Arrays is a library designed to optimize storage and gas efficiency in Solidity by bit-packing address values in an array. Traditional storage of addresses in Ethereum wastes 37% of storage space, leading to unnecessary costs. This library aims to utilize 100% of the storage space by splitting addresses across storage slots.

## Features

- **Gas Cost Reduction**: Reduces gas costs significantly, especially beneficial for operations involving multiple addresses.
- **Efficient Storage**: Maximizes storage efficiency by fitting addresses snugly within 32-byte storage slots.
- **Caching Mechanism**: Minimizes SLOAD/SSTORE operations when fetching multiple addresses

## Usage

Import the library

```solidity
    using PackedArray for PackedArray.Addresses;
```

Declare the type in storage

```solidity
    PackedArray.Addresses public array;
````
**Push**: Push an address to the array
```solidity 
    array.push(address(0xCAFE));
```

**Set**: Change the address at a particular index
```solidity
    array.set(0, address(0xBEEF));
```

**Get**: Fetch an address in the array
```solidity
    address beef = array.get(0);
```
**Pop**: Remove an item
```solidity
    array.pop();
```

**Append**: Store multiple addresses efficiently
```solidity
    address[] memory addresses;

    array.append(addresses);
```
**Get Many**: Fetch multiple addresses efficiently
```solidity
    address[] memory addrs = array.get(0, addresses.length);
```

## Gas Comparison

The following operations are tested against using a regular address array in solidity:

| Operation          | Normal Array | Packed Array | Percentage |
|--------------------|--------------|--------------|------------|
| Batch store 50     | 1,151,753    | 739,635      | -35.78%    |
| Batch retrieve 50  | 25,853       | 13,312       | -48.51%    |
| Set, Get, Edit 50  | 1,179,545    | 823,333      | -30.19%    |
| Set, Get, Edit 5   | 138,275      | 120,563      | -12.81%    |
| Set, Get, Edit 1   | 45,626       | 46,232       | +1.33%     |


## Test

```shell
$ forge test
```

## Security

The code is tested but not audited. Use it at your own risk.

## Contributing

Contributions to the library are welcome. Please submit pull requests for any enhancements.

## Planned Future Features

- **Support for Variable Data Sizes**: Future updates will include the ability to handle data sizes that do not fit snugly into 32 bytes.

## License

This project is licensed under the GNU General Public License v3.0 or later (GPL-3.0-or-later).

For more details visit [GNU General Public License v3.0 or later](https://www.gnu.org/licenses/gpl-3.0.en.html).


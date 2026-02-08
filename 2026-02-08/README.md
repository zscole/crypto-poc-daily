# EIP-8024: Deep Stack Manipulation Opcodes

**Date:** 2026-02-08  
**EIP:** [EIP-8024](https://eips.ethereum.org/EIPS/eip-8024)  
**Status:** Review  
**Authors:** Francisco Giordano, Charles Cooper, Alex Beregszaszi

## Overview

EIP-8024 introduces three new EVM opcodes that break the 16-depth stack access limitation:

- `DUPN` (0xe6) - Duplicate the Nth stack item to the top
- `SWAPN` (0xe7) - Swap the top with the N+1th stack item  
- `EXCHANGE` (0xe8) - Swap two arbitrary stack positions

Currently, `DUP1-DUP16` and `SWAP1-SWAP16` can only access the top 16 stack elements. This severely limits compiler optimizations and forces complex memory workarounds for functions with many local variables.

## Why It Matters

1. **Compiler Efficiency** - Solidity/Vyper can generate simpler code without "stack too deep" errors
2. **Function Calls** - Functions with >16 parameters no longer need memory elevation
3. **Stack Scheduling** - Enables better register allocation algorithms for stack machines

## Key Innovation: Backward-Compatible Encoding

The clever part is the immediate byte encoding that maintains backward compatibility with `JUMPDEST` analysis. Values 91-127 are reserved (91 = 0x5b = JUMPDEST), so the encoding skips this range.

### Single Operand Encoding (DUPN, SWAPN)

```
n in [17, 107]  -> immediate = n - 17        (0x00-0x5a)
n in [108, 235] -> immediate = n + 20        (0x80-0xff)
```

### Pair Encoding (EXCHANGE)

Uses a triangular mapping to encode two stack positions (n, m) where n < m into a single byte.

## Files

- `DeepStack.sol` - Solidity library with encode/decode functions
- `deep_stack.ts` - TypeScript implementation with EVM simulation
- `DeepStack.t.sol` - Foundry tests validating the encoding

## Build & Test

```bash
# Install dependencies
forge install

# Run tests
forge test -vvv

# Run TypeScript simulation
npx ts-node deep_stack.ts
```

## Example Usage

```solidity
// Encode DUPN for stack depth 50
uint8 immediate = DeepStackEncoder.encodeSingle(50);
// Result: 0x21 (33 in decimal, since 50-17=33)

// Encode EXCHANGE for positions (3, 25)
uint8 immediate = DeepStackEncoder.encodePair(3, 25);
// Uses triangular encoding
```

## References

- [EIP-8024 Full Specification](https://eips.ethereum.org/EIPS/eip-8024)
- [Ethereum Magicians Discussion](https://ethereum-magicians.org/t/eip-8024-backward-compatible-swapn-dupn-exchange/25486)
- [EOF/EIP-663](https://eips.ethereum.org/EIPS/eip-663) - Related EOF stack instructions

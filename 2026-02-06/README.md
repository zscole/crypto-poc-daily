# Argo: Arithmetic vs Binary Circuits for EC Operations

**Date:** 2026-02-06  
**Source:** Bitcoin Optech #390, [Argo Paper](https://eprint.iacr.org/2026/049.pdf) by Liam Eagen & Ying Tong Lai  
**Topic:** Garbled Circuits Efficiency for BitVM-like Constructs

## Overview

Argo introduces a garbled-circuits scheme that achieves ~1000x more efficient off-chain computation compared to traditional binary circuit approaches. The key insight: **use arithmetic circuits over elliptic curve points instead of binary circuits**.

### Why This Matters

Traditional garbled circuits (used in BitVM) represent computations as binary circuits:
- EC point multiplication requires **millions of binary gates**
- Each gate needs encryption/decryption overhead
- Verification is computationally expensive

Argo's arithmetic circuit approach:
- EC point multiplication needs only **a single arithmetic gate**
- Uses homomorphic MACs (Message Authentication Codes) over EC points
- Dramatically reduces circuit complexity

## The Math

### Binary Circuit Approach
For a 256-bit scalar multiplication `k * G`:
- Need to represent k as 256 bits
- Each bit requires point doubling (multiple gates)
- Conditional point addition per bit
- Total: ~O(256 * gates_per_double_and_add) = millions of gates

### Arithmetic Circuit Approach  
Same operation `k * G`:
- Single arithmetic gate: `MUL(k, G)`
- MAC verifies correctness: `MAC(k * G) = k * MAC(G)`
- Homomorphic property enables direct verification
- Total: 1 gate

## This POC

Demonstrates the conceptual difference between:
1. **Binary circuit simulation** - Breaking down EC operations into bit-level operations
2. **Arithmetic circuit simulation** - Direct field operations with homomorphic verification

```bash
pip install -r requirements.txt
python argo_circuit_demo.py
```

## Key Concepts Implemented

1. **GarbledWire** - Represents encrypted wire values in the circuit
2. **BinaryCircuit** - Simulates traditional bit-by-bit EC multiplication
3. **ArithmeticCircuit** - Simulates Argo's single-gate approach
4. **HomomorphicMAC** - Simplified MAC that preserves algebraic structure

## References

- [Argo Paper](https://eprint.iacr.org/2026/049.pdf)
- [Bitcoin Optech #390](https://bitcoinops.org/en/newsletters/2026/01/30/)
- [BitVM Overview](https://bitvm.org/bitvm.pdf)
- [Delving Bitcoin Discussion](https://delvingbitcoin.org/t/argo-a-garbled-circuits-scheme-for-1000x-more-efficient-off-chain-computation/2210)

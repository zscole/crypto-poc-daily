# Argo-Style Arithmetic Garbled Circuits POC

**Date**: 2026-02-02  
**Source**: [Bitcoin Optech Newsletter #390](https://bitcoinops.org/en/newsletters/2026/01/30/)  
**Paper**: [Argo: A Garbled Circuits Scheme for 1000x More Efficient Off-Chain Computation](https://eprint.iacr.org/2026/049.pdf)

## Overview

This POC demonstrates the core concepts behind **Argo**, a new garbled circuits scheme by Liam Eagen and Ying Tong Lai that enables 1000x more efficient off-chain computation for BitVM-style contracts.

### Key Innovation

Traditional garbled circuits work over **binary circuits** where each operation (AND, XOR, etc.) operates on individual bits. For cryptographic operations like elliptic curve point multiplication, this requires *millions* of binary gates.

Argo introduces **arithmetic circuits** using a homomorphic MAC that encodes circuit wires as EC points. A single arithmetic gate can represent what previously required millions of binary gates.

## What This POC Demonstrates

1. **Binary vs Arithmetic Circuits**: Side-by-side comparison showing gate count difference
2. **Homomorphic EC-MAC**: Implementation of a MAC scheme where operations on MACs correspond to operations on the underlying values
3. **Simple Garbled Gate**: Demonstration of garbling and evaluating gates using both approaches

## Files

- `garbled_circuit.py` - Core garbled circuit implementation
- `ec_mac.py` - Elliptic curve-based homomorphic MAC
- `demo.py` - Interactive demonstration comparing approaches
- `benchmark.py` - Performance comparison

## Run

```bash
# Install dependencies
pip install -r requirements.txt

# Run demo
python demo.py

# Run benchmarks
python benchmark.py
```

## Technical Background

### Garbled Circuits (Yao's Protocol)

Garbled circuits allow two parties to compute a function on their private inputs without revealing those inputs. One party "garbles" (encrypts) a circuit, the other "evaluates" it.

### Why Arithmetic Circuits Matter for Bitcoin

BitVM uses garbled circuits for off-chain computation with on-chain dispute resolution. The efficiency of the garbled circuit directly impacts:
- Challenge/response size in disputes
- Number of on-chain transactions needed
- Overall practicality of BitVM contracts

Argo's 1000x improvement makes previously impractical BitVM applications feasible.

## References

- [Argo Paper (ePrint 2026/049)](https://eprint.iacr.org/2026/049.pdf)
- [BitVM Whitepaper](https://bitvm.org/bitvm.pdf)
- [Garbled Locks - Newsletter #369](https://bitcoinops.org/en/newsletters/2025/06/20/#improvements-to-bitvm-style-contracts)

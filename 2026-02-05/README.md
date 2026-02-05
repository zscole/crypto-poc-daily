# Argo: Arithmetic vs Binary Circuits for Garbled Computation

**Date:** 2026-02-05  
**Source:** [Bitcoin Optech Newsletter #390](https://bitcoinops.org/en/newsletters/2026/01/30/) / [Argo Paper](https://eprint.iacr.org/2026/049.pdf)

## Background

BitVM enables arbitrary computation verification on Bitcoin through garbled circuits. The key limitation has been efficiency: representing elliptic curve operations in binary circuits requires millions of gates.

The Argo paper by Liam Eagen and Ying Tong Lai introduces a MAC (message authentication code) that encodes garbled circuit wires as EC points, enabling arithmetic circuits instead of binary circuits.

## The Core Insight

| Operation | Binary Circuit | Arithmetic Circuit |
|-----------|---------------|-------------------|
| EC Point Multiplication | ~1M+ binary gates | 1 arithmetic gate |
| Field Multiplication | ~10K binary gates | 1 arithmetic gate |

This enables 1000x improvement in off-chain computation efficiency for BitVM-style contracts.

## This POC

Demonstrates the gate count difference between binary and arithmetic representations for:

1. Field element multiplication in a finite field
2. Simple elliptic curve point operations

This is educational - showing WHY arithmetic circuits matter, not implementing full garbled circuits.

## Files

- `binary_circuit.py` - Simulates binary circuit gate counting for field operations
- `arithmetic_circuit.py` - Arithmetic circuit equivalent showing efficiency gains
- `comparison.py` - Side-by-side comparison with metrics

## Run

```bash
python3 comparison.py
```

## References

- [Argo Paper](https://eprint.iacr.org/2026/049.pdf)
- [BitVM Overview](https://bitvm.org/)
- [Garbled Circuits Primer](https://www.mpc.wiki/protocols/garbled-circuits)

# Multi KZG Point Evaluation POC

Implementation inspired by EIP-8141 "Multi KZG Point Evaluation Precompile"

## Context

KZG polynomial commitments are fundamental to Ethereum's data availability solution (EIP-4844) and future Danksharding. The recent EIP-8141 proposes a precompile for efficient multi-point evaluation, which would reduce gas costs for verifying multiple polynomial evaluations.

## What This Implements

- Basic KZG polynomial commitment scheme
- Multi-point polynomial evaluation
- Verification of commitments at multiple points
- Gas estimation comparison vs single-point evaluations

## Files

- `kzg-basic.js` - Core KZG implementation
- `multi-eval.js` - Multi-point evaluation optimization
- `gas-analysis.js` - Gas cost comparison
- `test.js` - Basic tests

## Key Insight

Multi-point evaluation can reduce verification overhead from O(n) to O(log n + m) where n is polynomial degree and m is number of evaluation points.
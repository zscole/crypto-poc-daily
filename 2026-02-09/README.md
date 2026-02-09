# EIP-7862: Delayed State Root Simulation

**Date:** 2026-02-09
**EIP:** https://eips.ethereum.org/EIPS/eip-7862
**Authors:** Charlie Noyes, Dan Robinson (Paradigm), Justin Drake (EF), Toni Wahrstatter

## Overview

EIP-7862 proposes decoupling state root computation from block validation by deferring the execution layer's state root reference by one block. Each block's header contains the post-state root of the **previous** block rather than its own.

## Why This Matters

State root computation is a significant bottleneck in block production:
- Current: Block N contains state root computed AFTER executing block N
- Proposed: Block N contains state root computed from block N-1

Benefits:
1. Builders compute one state root per slot (for previous block) instead of thousands during MEV auction
2. Validators can attest to block validity without waiting for state root computation
3. State root computation can use Block Access Lists (EIP-7928) to parallelize proof generation
4. Critical path shifts: state root computation is frontloaded to slot start

## Synergies

- **EIP-7732 (ePBS):** Builders have tighter timing constraints; delayed roots reduce pressure
- **EIP-7928 (Block-Level Access Lists):** BALs identify touched storage slots; with delayed roots, clients can parallelize state root computation using previous block's BAL

## This POC

Demonstrates the timing difference between:
1. Traditional model: Block validation waits for state root computation
2. Delayed model: Block validation proceeds independently; state root computed in parallel

The simulation shows how delayed state roots enable ~12-15% faster block propagation in constrained scenarios.

## Run

```bash
forge build
forge test -vvv
```

## Files

- `src/DelayedStateRoot.sol` - Block chain simulation with delayed state root semantics
- `test/DelayedStateRoot.t.sol` - Tests demonstrating timing improvements
- `script/Simulate.s.sol` - Interactive simulation script

## Key Insight

The delayed state root doesn't change *what* is computed, only *when*. The same state root ends up on-chain, just in the next block instead of the current one. Light clients see one additional slot of latency for state proofs, which is acceptable for most use cases.

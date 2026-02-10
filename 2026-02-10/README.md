# EIP-7862: Delayed State Root Simulator

A proof-of-concept demonstrating how delayed state roots decouple state root computation from block validation.

## Concept

EIP-7862 proposes that each block's header contains the **post-state root of the previous block** rather than its own. This enables:

- Validators can attest to block validity without waiting for state root computation
- State root computation can use Block Access Lists (EIP-7928) for parallelization
- Critical path shifts: state root is frontloaded to slot start instead of blocking attestations

## How It Works

```
Block N-1                    Block N                     Block N+1
+-----------+               +-----------+               +-----------+
| state_root| <-- contains  | state_root| <-- contains  | state_root|
| (of N-2)  |    post-state | (of N-1)  |    post-state | (of N)    |
+-----------+    of N-2     +-----------+    of N-1     +-----------+
     |                           |                           |
     v                           v                           v
  Execute                     Execute                     Execute
     |                           |                           |
     v                           v                           v
  Compute state root         Compute state root         Compute state root
  (included in N)            (included in N+1)          (included in N+2)
```

## Timing Improvement

**Without EIP-7862:**
```
[Receive Block] -> [Execute Txs] -> [Compute State Root] -> [Attest]
                   |<------------- BLOCKING -------------->|
```

**With EIP-7862:**
```
[Receive Block] -> [Execute Txs] -> [Attest]
                         |
                   [Compute State Root (for next block, non-blocking)]
```

## Files

- `DelayedStateRoot.sol` - Solidity simulation of the mechanism
- `simulator.ts` - TypeScript demonstration of timing benefits
- `test/` - Foundry tests

## Usage

```bash
# Install dependencies
forge install

# Run tests
forge test -vvv

# Run TypeScript simulator
npx ts-node simulator.ts
```

## References

- [EIP-7862](https://eips.ethereum.org/EIPS/eip-7862) - Delayed State Root
- [EIP-7928](https://eips.ethereum.org/EIPS/eip-7928) - Block-Level Access Lists
- [EIP-7732](https://eips.ethereum.org/EIPS/eip-7732) - Enshrined Proposer-Builder Separation

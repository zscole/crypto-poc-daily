# EIP-8037 State Gas Reservoir Simulator

**Date:** 2026-02-11  
**Topic:** Multidimensional Gas Metering for State Creation  
**Reference:** [EIP-8037](https://eips.ethereum.org/EIPS/eip-8037)

## Overview

EIP-8037 introduces a fundamental change to Ethereum's gas model: separate metering for state creation costs. This POC simulates the reservoir model for transaction-level gas accounting.

## Key Concepts

### Problem Being Solved
- State growth bottlenecks scaling under increased block gas limits
- Current state: ~340 GiB, growing ~73 GiB/year at 36M gas limit
- At 100M gas limit: ~197 GiB/year growth, hitting 650 GiB threshold in <2.5 years

### Multidimensional Metering
Instead of a single gas dimension, EIP-8037 introduces:
- `regular_gas` - computation, calldata, access lists
- `state_gas` - state creation (storage slots, accounts, contract code)

### Reservoir Model
```
execution_gas = tx.gas - intrinsic_gas
regular_gas_budget = TX_MAX_GAS_LIMIT - intrinsic_regular_gas
gas_left = min(regular_gas_budget, execution_gas)
state_gas_reservoir = execution_gas - gas_left
```

State gas charges deduct from reservoir first, then from gas_left when exhausted.

### Dynamic Cost Per State Byte
```
raw = ceil((gas_limit * 2_628_000) / (2 * TARGET_STATE_GROWTH_PER_YEAR))
shifted = raw + CPSB_OFFSET
shift = max(bit_length(shifted) - CPSB_SIGNIFICANT_BITS, 0)
cost_per_state_byte = max(((shifted >> shift) << shift) - CPSB_OFFSET, 1)
```

## Files

- `StateGasSimulator.sol` - Solidity library simulating reservoir model
- `GasCostCalculator.sol` - Cost per state byte calculations
- `test/StateGas.t.sol` - Foundry tests demonstrating gas scenarios
- `analysis.md` - Impact analysis at various block gas limits

## Run Tests

```bash
forge test -vvv
```

## Key Findings

At 60M gas limit:
- cost_per_state_byte = ~1,176 gas
- SSTORE (new slot): 37,632 state gas + 2,900 regular gas
- Contract creation: 131,712 state gas + 9,000 regular gas

The reservoir model allows large contract deployments without hitting TX_MAX_GAS_LIMIT for regular gas.

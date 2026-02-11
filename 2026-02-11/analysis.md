# EIP-8037 Impact Analysis

## State Growth Projections

| Gas Limit | Daily Growth | Annual Growth | Years to 650 GiB |
|-----------|--------------|---------------|------------------|
| 30M       | ~102 MiB     | ~36 GiB       | >8 years         |
| 36M       | ~205 MiB     | ~73 GiB       | ~4.2 years       |
| 60M       | ~349 MiB     | ~124 GiB      | ~2.5 years       |
| 100M      | ~553 MiB     | ~197 GiB      | ~1.6 years       |

EIP-8037 targets 100 GiB/year growth regardless of gas limit by dynamically pricing state creation.

## Cost Per State Byte (CPSB)

Formula:
```
raw = ceil((gas_limit * 2,628,000) / (2 * 100 GiB))
quantized = keep top 5 significant bits after offset
cpsb = quantized - 9578
```

| Gas Limit | CPSB (approx) |
|-----------|---------------|
| 30M       | ~368 gas/byte |
| 36M       | ~440 gas/byte |
| 60M       | ~736 gas/byte |
| 100M      | ~1,224 gas/byte |

## Operation Costs at 60M Gas Limit

### Storage (SSTORE new slot)
- Old: 20,000 gas (flat)
- New: 2,900 regular + 23,552 state gas
- Total: ~26,452 gas equivalent

### Account Creation (CREATE)
- Old: 32,000 gas (flat)
- New: 9,000 regular + 82,432 state gas
- Total: ~91,432 gas equivalent

### Code Deployment (per byte)
- Old: 200 gas/byte
- New: ~6 regular + 736 state gas/byte
- Total: ~742 gas/byte equivalent

## Key Benefits of Reservoir Model

### 1. Large Contract Deployments
Without reservoir:
- 24KB contract at 60M would need ~17.7M state gas
- Would consume most of TX_MAX_GAS_LIMIT (30M)

With reservoir:
- State gas comes from reservoir (excess over TX_MAX_GAS_LIMIT)
- Regular gas only needs ~9,000 + hash costs
- Enables larger contracts without hitting tx limits

### 2. Natural Rate Limiting
Block fullness = max(regular_gas, state_gas)
- Compute-heavy blocks fill regular gas first
- State-heavy blocks fill state gas first
- Either dimension hitting limit stops the block

### 3. Backwards Compatibility
- GAS opcode still returns regular gas only
- Existing gas estimation works for compute
- State-heavy ops need updated estimation

## Migration Considerations

### Affected Patterns
1. Factory contracts deploying many children
2. Batch minting (many new storage slots)
3. Airdrop contracts (new accounts)
4. State-heavy DeFi protocols

### Mitigation Strategies
1. Use proxies (deploy once, clone addresses)
2. Batch state operations across transactions
3. Use CREATE2 for deterministic addresses
4. Consider L2s for state-heavy applications

## Quantization Rationale

The formula quantizes CPSB to avoid:
- Frequent small price changes as gas limit fluctuates
- Complex calculations for users/wallets
- MEV opportunities from price prediction

Only top 5 significant bits are kept, creating predictable price tiers.

## References

- [EIP-8037 Full Specification](https://eips.ethereum.org/EIPS/eip-8037)
- [EIP-7825 TX_MAX_GAS_LIMIT](https://eips.ethereum.org/EIPS/eip-7825)
- [EIP-8011 Multidimensional Metering](https://eips.ethereum.org/EIPS/eip-8011)
- [Ethereum Magicians Discussion](https://ethereum-magicians.org/t/eip-8037-state-creation-gas-cost-increase/25694)

# Dust Disposal Tool - POC

**Date:** 2026-02-07  
**Source:** Bitcoin Optech Newsletter #391  
**Topic:** Dust Attack Mitigation via Provably Unspendable Outputs

## Background

Dust attacks occur when adversaries send tiny UTXOs to wallet addresses, hoping users will accidentally consolidate them with legitimate UTXOs, linking addresses together and compromising privacy.

Traditional mitigation: Mark dust UTXOs as "frozen" in wallet software. Problem: On wallet restore from seed, the new client doesn't know which UTXOs were dust - the attack vectors reopen.

## The Solution

Create a transaction that:
1. Spends the dust UTXO entirely (no change)
2. Outputs to OP_RETURN (provably unspendable)
3. Uses SIGHASH_ANYONECANPAY|ALL for fee efficiency
4. Results in an on-chain record that the UTXO is permanently burned

This permanently neutralizes the dust without risk of future accidental spending.

## Implementation

This POC demonstrates:
1. Dust detection in a UTXO set
2. Construction of dust disposal transactions
3. OP_RETURN output creation with minimal overhead (3-byte payload)
4. Fee calculation at minimum relay rate (0.1 sat/vbyte per Bitcoin Core v30+)

## Usage

```bash
# Install dependencies
npm install

# Run simulation
npm start

# Run with custom dust threshold (satoshis)
DUST_THRESHOLD=1000 npm start
```

## Technical Notes

- Minimum relay transaction size: 65 bytes (non-witness)
- OP_RETURN output: `OP_RETURN <3-byte-marker>`
- Using ANYONECANPAY allows fee bumping by third parties
- At 0.1 sat/vbyte, a 110-vbyte disposal tx costs ~11 sats

## Files

- `dust-disposal.ts` - Core disposal transaction builder
- `utxo-analyzer.ts` - Dust detection and analysis
- `index.ts` - CLI demonstration
- `types.ts` - TypeScript interfaces

## References

- [Delving Bitcoin Discussion](https://delvingbitcoin.org/t/disposing-of-dust-attack-utxos/2215)
- [ddust experimental tool](https://github.com/bubb1es71/ddust)
- Bitcoin Core v30 minimum relay fee changes

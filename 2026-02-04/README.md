# IBC Message Authentication POC

**Date:** 2026-02-04  
**Topic:** Cross-chain message validation vulnerabilities  
**Reference:** Saga IBC Bridge Exploit ($7M loss, Jan 21 2026)

## Background

On January 21, 2026, the Saga blockchain was exploited for $7 million through forged IBC (Inter-Blockchain Communication) messages. The attacker deployed a helper contract that sent custom IBC payloads to Saga's precompile, which minted Saga Dollar (D token) without verifying that the messages corresponded to actual deposits on the source chain.

The vulnerability was traced to the original Ethermint codebase, affecting multiple Cosmos EVM chains.

## The Vulnerability

The vulnerable pattern:
1. Bridge receives IBC message claiming "User X deposited Y tokens on Chain A"
2. Bridge trusts the message content without cryptographic verification
3. Bridge mints equivalent tokens on Chain B

The attacker simply crafted messages claiming deposits that never happened.

## This POC

This POC demonstrates:
1. **VulnerableBridge.sol** - The insecure pattern: accepts any message claiming to be from IBC
2. **SecureBridge.sol** - Proper validation using:
   - Relayer signature verification (trusted relayer set)
   - Merkle proof verification (proving inclusion in source chain state)
   - Nonce tracking (replay protection)
   - Source chain validation

## Key Lessons

1. **Never trust message content alone** - Always verify the source cryptographically
2. **Validate against source chain state** - Use light client proofs or trusted relayer signatures
3. **Implement replay protection** - Track nonces/packet sequences
4. **Whitelist valid sources** - Only accept messages from known chain IDs

## Files

- `VulnerableBridge.sol` - The insecure pattern (DO NOT USE)
- `SecureBridge.sol` - Secure implementation with proper validation
- `IBCMessageLib.sol` - Message structures and utilities
- `test_scenario.js` - Demonstration of the attack and defense

## Running

```bash
# Install dependencies
npm install

# Run tests
npx hardhat test

# Or run the scenario script
node test_scenario.js
```

## References

- [Rekt News - Saga Rekt](https://rekt.news/saga-rekt)
- [Cosmos Labs Statement](https://x.com/cosmoslabs_io/status/2014428829423706156)
- [Saga Investigation Update](https://medium.com/sagaxyz/sagaevm-security-incident-investigation-update-29a1d2a6b0cd)
- [IBC Protocol Spec](https://github.com/cosmos/ibc)

# EIP-8141 Frame Transaction POC

**Date:** 2026-02-12  
**EIP:** [EIP-8141](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-8141.md)  
**Authors:** Vitalik Buterin, lightclient, Felix Lange, Yoav Weiss, Alex Forshtat, Dror Tirosh, Shahaf Nacson

## Overview

EIP-8141 introduces Frame Transactions - a new transaction type (`0x06`) that enables native account abstraction at the protocol level. This is Ethereum's path to post-quantum security and true account abstraction without relying solely on ECDSA.

### Key Concepts

**Frames**: A Frame Transaction contains multiple "frames" - sub-operations that execute sequentially:
- `DEFAULT` (mode 0): Execute as ENTRY_POINT
- `VERIFY` (mode 1): Validation frame, must call APPROVE
- `SENDER` (mode 2): Execute as the sender account

**New Opcodes:**
- `APPROVE` (0xaa): Exit context and update approval state (execution, payment, or both)
- `TXPARAMLOAD/SIZE/COPY` (0xb0-0xb2): Introspect transaction parameters

**Approval Scopes:**
- `0x0`: Approve execution (sender authorizes future SENDER mode frames)
- `0x1`: Approve payment (payer pays gas, increments nonce)
- `0x2`: Approve both (combined)

### Why This Matters

1. **Post-Quantum Ready**: Accounts can use any signature scheme, not just ECDSA
2. **Native AA**: No more ERC-4337 bundlers for basic account abstraction
3. **Flexible Gas Payment**: Separates who executes from who pays
4. **Multi-frame Transactions**: Complex operations in a single atomic transaction

## This POC

This implementation demonstrates:
1. Frame transaction structure and encoding
2. Account contracts implementing VERIFY mode validation
3. Signature abstraction (supports ECDSA, Schnorr, BLS patterns)
4. The APPROVE opcode pattern for execution/payment authorization

## Files

- `src/FrameAccount.sol` - Smart account implementing EIP-8141 validation
- `src/FrameTypes.sol` - Frame transaction type definitions
- `src/MockApprove.sol` - APPROVE opcode simulation (until native support)
- `test/FrameTransaction.t.sol` - Integration tests

## Build & Test

```bash
forge build
forge test -vv
```

## References

- [EIP-8141 Draft](https://eips.ethereum.org/EIPS/eip-8141)
- [Ethereum Magicians Discussion](https://ethereum-magicians.org/t/frame-transaction/27617)
- [EIP-2718 Typed Transactions](https://eips.ethereum.org/EIPS/eip-2718)

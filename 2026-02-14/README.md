# EIP-7708: ETH Transfer Logs POC

**Date**: February 14, 2026  
**EIP**: [7708 - ETH transfers and burns emit a log](https://eips.ethereum.org/EIPS/eip-7708)  
**Status**: Draft (Updated Feb 13, 2026 - ETH burn logs added)  

## Overview

EIP-7708 proposes that all ETH transfers and burns automatically emit logs, making ETH tracking consistent with ERC-20 tokens. Currently, ETH movements are invisible to event-based indexers unless manually logged.

## The Problem

**Current State**: ETH tracking requires multiple data sources
- EOA transfers: Parse transaction receipts
- Contract transfers: Trace CALL opcodes  
- Burns: Monitor SELFDESTRUCT + state diffs
- Smart wallet deposits often missed by exchanges

**Result**: Complex, error-prone infrastructure with poor smart wallet support

## EIP-7708 Solution

**Automatic Logging**: Protocol generates events for all ETH movements
```solidity
// For transfers (LOG3)
event Transfer(address indexed from, address indexed to, uint256 value);

// For burns (LOG2) - added in recent update
event Burn(address indexed from, uint256 value);
```

## POC Contents

### 1. `EIP7708_ETH_Transfer_Logs.sol`
- Demonstrates automatic logging for various transfer types
- Shows unified tracking interface
- Includes batch operations and burn scenarios

### 2. `test_eip7708.js` 
- Compares current vs EIP-7708 behavior
- Shows infrastructure simplification
- Calculates gas overhead estimates

### 3. Key Benefits Demonstrated

#### Unified Interface
```javascript
// Same query for ETH and ERC-20
const transfers = await contract.queryFilter(
    contract.filters.Transfer(userAddress, null)
);
```

#### Infrastructure Simplification
- **Before**: Multi-step ETH tracking pipeline
- **After**: Single event stream like ERC-20

#### Gas Overhead
- Transfer log: ~630 gas (LOG3)
- Burn log: ~630 gas (LOG2)
- Impact: <2% for typical transactions

## Recent Updates

**Feb 13, 2026**: EIP-7708 updated to include ETH burn logs
- Added Burn event specification
- Improved spec consistency
- Addresses SELFDESTRUCT and explicit burns

## Technical Details

### Automatic Log Generation
The protocol would emit logs for:
- Nonzero-value transactions to different accounts
- Nonzero-value CALLs to different accounts  
- SELFDESTRUCT operations (burn logs)
- Transaction-level transfers

### Log Format
```
Transfer: LOG3(Transfer(address,address,uint256), from, to, value)
Burn: LOG2(Burn(address,uint256), from, value)
```

## Impact Assessment

### Infrastructure Benefits
- Exchanges: Better smart wallet deposit detection
- Indexers: Unified ETH/token tracking pipeline
- dApps: Consistent balance monitoring interface
- Analytics: Complete ETH movement visibility

### Ecosystem Adoption
- Minimal breaking changes
- Optional indexer upgrades
- Backward compatible queries

## Running the POC

```bash
# View the demonstration
node test_eip7708.js

# Deploy contract (requires Foundry/Hardhat)
# solc EIP7708_ETH_Transfer_Logs.sol
```

## Status & Timeline

- **Current**: Draft specification
- **Recent**: Burn logs specification added
- **Next**: Core dev review and testnet implementation

This POC demonstrates why EIP-7708 would significantly simplify Ethereum infrastructure by making ETH behave like any other token from an indexing perspective.
# Integer Overflow Exploit - TrueBit Pattern

POC demonstrating the integer overflow vulnerability pattern used in the TrueBit exploit (January 8, 2026, $26.2M loss).

## Background

TrueBit was deployed in 2021 using Solidity 0.5.3, which lacks automatic overflow checks. While most arithmetic used SafeMath, one critical addition in `getPurchasePrice()` was unprotected. Passing astronomically large values caused the result to wrap around to near-zero, allowing the attacker to mint billions of tokens for essentially nothing.

## The Vulnerability Pattern

Pre-Solidity 0.8.0, integer arithmetic silently wraps on overflow:
- `uint256.max + 1 = 0`
- Large intermediate calculations can produce unexpected small results

## Files

- `VulnerableBondingCurve.sol` - Vulnerable contract (Solidity 0.5.x style)
- `SafeBondingCurve.sol` - Fixed version demonstrating mitigations
- `AttackSimulation.sol` - Exploit demonstration
- `test/` - Foundry tests proving the vulnerability

## Running the POC

```bash
# Install Foundry if needed
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install dependencies
forge install

# Run tests
forge test -vvv

# See gas comparison
forge test --gas-report
```

## Key Lessons

1. **Solidity < 0.8.0 requires SafeMath everywhere** - one missed operation = exploit
2. **Unverified bytecode is a red flag** - can't audit what you can't read
3. **Old contracts are hunting grounds** - attackers target abandoned code
4. **Bonding curve edge cases matter** - test with extreme inputs

## References

- [Rekt News Coverage](https://rekt.news/truebit-rekt)
- [Original 2021 Warning by Banteg](https://x.com/banteg/status/1389032239162347521)
- [Attack Transaction](https://etherscan.io/tx/0xcd4755645595094a8ab984d0db7e3b4aabde72a5c87c4f176a030629c47fb014)

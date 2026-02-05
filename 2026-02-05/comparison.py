#!/usr/bin/env python3
"""
Binary vs Arithmetic Circuit Comparison

Demonstrates the 1000x+ efficiency improvement from using arithmetic
circuits as described in the Argo paper for BitVM-style contracts.

This is the core insight that makes advanced smart contracts feasible
on Bitcoin through off-chain computation with on-chain verification.
"""

from binary_circuit import BinaryFieldCircuit, GateCount
from arithmetic_circuit import ArithmeticFieldCircuit, ArithmeticGateCount


def format_number(n: int) -> str:
    """Format large numbers with K/M suffixes."""
    if n >= 1_000_000:
        return f"{n/1_000_000:.1f}M"
    elif n >= 1_000:
        return f"{n/1_000:.1f}K"
    return str(n)


def compare_operations():
    """Compare gate counts between binary and arithmetic circuits."""
    
    print("=" * 75)
    print("  ARGO: BINARY vs ARITHMETIC CIRCUIT EFFICIENCY COMPARISON")
    print("=" * 75)
    print()
    print("  Context: BitVM enables smart contracts on Bitcoin via garbled circuits.")
    print("  Problem: Binary circuits require millions of gates for crypto operations.")
    print("  Solution: Argo uses arithmetic circuits with homomorphic MAC on EC points.")
    print()
    print("=" * 75)
    
    # Operations to compare
    operations = [
        ("Field Addition", "field_addition", "binary_addition"),
        ("Field Multiplication", "field_multiplication", "field_multiplication"),
        ("Field Inversion", "field_inversion", "field_inversion"),
        ("EC Point Addition", "ec_point_addition", "ec_point_addition"),
        ("EC Scalar Multiply", "ec_scalar_multiplication", "ec_scalar_multiplication"),
    ]
    
    print()
    print(f"{'Operation':<25} {'Binary Gates':>15} {'Arithmetic Gates':>18} {'Improvement':>15}")
    print("-" * 75)
    
    total_binary = 0
    total_arith = 0
    
    for name, arith_method, binary_method in operations:
        # Binary circuit
        binary = BinaryFieldCircuit(256)
        binary_gates = getattr(binary, binary_method)()
        binary_total = binary_gates.total
        
        # Arithmetic circuit
        arith = ArithmeticFieldCircuit(256)
        arith_gates = getattr(arith, arith_method)()
        arith_total = arith_gates.total
        
        # Calculate improvement
        improvement = binary_total / arith_total if arith_total > 0 else float('inf')
        
        total_binary += binary_total
        total_arith += arith_total
        
        print(f"{name:<25} {format_number(binary_total):>15} {arith_total:>18} {improvement:>14.0f}x")
    
    print("-" * 75)
    overall = total_binary / total_arith if total_arith > 0 else float('inf')
    print(f"{'TOTAL':<25} {format_number(total_binary):>15} {total_arith:>18} {overall:>14.0f}x")
    print()
    
    # Detailed breakdown
    print("=" * 75)
    print("  DETAILED ANALYSIS: EC SCALAR MULTIPLICATION")
    print("=" * 75)
    print()
    print("  This operation is critical for signature verification, key derivation,")
    print("  and most cryptographic protocols. It's the bottleneck for BitVM.")
    print()
    
    binary = BinaryFieldCircuit(256)
    binary_ec = binary.ec_scalar_multiplication()
    
    arith = ArithmeticFieldCircuit(256)
    arith_ec = arith.ec_scalar_multiplication()
    
    print("  Binary Circuit Breakdown:")
    print(f"    AND gates:    {binary_ec.and_gates:>15,}")
    print(f"    XOR gates:    {binary_ec.xor_gates:>15,}")
    print(f"    NOT gates:    {binary_ec.not_gates:>15,}")
    print(f"    TOTAL:        {binary_ec.total:>15,}")
    print()
    print("  Arithmetic Circuit Breakdown:")
    print(f"    ADD gates:    {arith_ec.add_gates:>15,}")
    print(f"    MULT gates:   {arith_ec.mult_gates:>15,}")
    print(f"    INV gates:    {arith_ec.inv_gates:>15,}")
    print(f"    CONST gates:  {arith_ec.const_gates:>15,}")
    print(f"    TOTAL:        {arith_ec.total:>15,}")
    print()
    
    improvement = binary_ec.total / arith_ec.total
    print(f"  Improvement Factor: {improvement:,.0f}x")
    print()
    
    # Practical implications
    print("=" * 75)
    print("  PRACTICAL IMPLICATIONS FOR BITVM")
    print("=" * 75)
    print()
    print("  Before Argo:")
    print("    - Verifying a single ECDSA signature: ~billions of binary gates")
    print("    - Complex smart contracts: impractical on-chain verification")
    print("    - Use case: Limited to simple hash-based challenges")
    print()
    print("  After Argo:")
    print("    - Same signature verification: ~thousands of arithmetic gates")
    print("    - Enables practical ZK proofs, complex predicates")
    print("    - Opens door for bridges, rollups, advanced contracts on Bitcoin")
    print()
    print("  The ~1000x improvement makes previously impractical computations")
    print("  feasible for Bitcoin's limited Script environment.")
    print()
    print("=" * 75)
    print("  KEY INSIGHT: Argo's homomorphic MAC encodes wires as EC points,")
    print("  allowing arithmetic operations (which are native to EC math) to")
    print("  be represented directly, avoiding binary decomposition overhead.")
    print("=" * 75)


def main():
    compare_operations()


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Benchmark: Binary vs Arithmetic Circuit Simulation

Compares actual computation time for circuits of varying complexity.
"""

import time
import secrets
from dataclasses import dataclass
from typing import List

from ec_mac import N, generate_h_point, ArgoWire, ECMac
from garbled_circuit import BinaryWire, BinaryGarbledGate, GateType


@dataclass
class BenchmarkResult:
    name: str
    operations: int
    total_time_ms: float
    per_op_ms: float
    
    def __repr__(self):
        return f"{self.name}: {self.per_op_ms:.4f} ms/op ({self.operations} ops, {self.total_time_ms:.2f} ms total)"


def benchmark_binary_circuit(n_gates: int = 100) -> BenchmarkResult:
    """Benchmark binary garbled circuit operations"""
    
    # Create gates
    gates = []
    wires = [BinaryWire.create() for _ in range(n_gates + 2)]
    
    start = time.perf_counter()
    
    for i in range(n_gates):
        gate = BinaryGarbledGate(
            GateType.AND,
            wires[i],
            wires[i + 1],
            wires[i + 2] if i + 2 < len(wires) else BinaryWire.create()
        )
        gates.append(gate)
    
    garble_time = time.perf_counter() - start
    
    # Evaluate
    start = time.perf_counter()
    
    current_label = wires[0].get_label(1)
    for i, gate in enumerate(gates):
        next_label = wires[i + 1].get_label(1)
        current_label = gate.evaluate(current_label, next_label)
    
    eval_time = time.perf_counter() - start
    total_time = (garble_time + eval_time) * 1000
    
    return BenchmarkResult(
        name="Binary Garbled Gates",
        operations=n_gates,
        total_time_ms=total_time,
        per_op_ms=total_time / n_gates
    )


def benchmark_arithmetic_circuit(n_ops: int = 100) -> BenchmarkResult:
    """Benchmark Argo-style arithmetic operations"""
    
    H = generate_h_point()
    
    # Create wires with random values and keys
    values = [secrets.randbelow(1000) for _ in range(n_ops)]
    keys = [secrets.randbelow(N) for _ in range(n_ops)]
    
    start = time.perf_counter()
    
    # Create wires (garbling)
    wires = [ArgoWire.create(v, k, H) for v, k in zip(values, keys)]
    
    garble_time = time.perf_counter() - start
    
    # Evaluate - chain of additions
    start = time.perf_counter()
    
    result = wires[0]
    for wire in wires[1:]:
        result = result.add(wire)
    
    eval_time = time.perf_counter() - start
    total_time = (garble_time + eval_time) * 1000
    
    return BenchmarkResult(
        name="Arithmetic (Argo) Ops",
        operations=n_ops,
        total_time_ms=total_time,
        per_op_ms=total_time / n_ops
    )


def benchmark_ec_mac_operations(n_ops: int = 100) -> List[BenchmarkResult]:
    """Detailed EC-MAC operation benchmarks"""
    results = []
    H = generate_h_point()
    
    # MAC Creation
    keys = [secrets.randbelow(N) for _ in range(n_ops)]
    values = [secrets.randbelow(N) for _ in range(n_ops)]
    
    start = time.perf_counter()
    macs = [ECMac.create(k, v, H) for k, v in zip(keys, values)]
    t = (time.perf_counter() - start) * 1000
    results.append(BenchmarkResult("MAC Creation", n_ops, t, t/n_ops))
    
    # MAC Addition
    start = time.perf_counter()
    result = macs[0]
    for mac in macs[1:]:
        result = result.add(mac)
    t = (time.perf_counter() - start) * 1000
    results.append(BenchmarkResult("MAC Addition", n_ops-1, t, t/(n_ops-1)))
    
    # Scalar Multiplication
    scalars = [secrets.randbelow(1000) for _ in range(n_ops)]
    start = time.perf_counter()
    scaled = [mac.scalar_mul(s) for mac, s in zip(macs, scalars)]
    t = (time.perf_counter() - start) * 1000
    results.append(BenchmarkResult("Scalar Multiply", n_ops, t, t/n_ops))
    
    return results


def estimate_bitvm_improvement():
    """
    Estimate the real-world improvement for BitVM operations.
    
    Consider a simple BitVM challenge: verify a Schnorr signature.
    - Requires 1 EC scalar multiplication + 1 EC point addition + hash
    """
    print("\n" + "=" * 70)
    print("BitVM Use Case: Schnorr Signature Verification")
    print("=" * 70)
    
    # Binary circuit estimate
    # Scalar mul: ~75M gates (from our calculation)
    # Point add: ~200K gates
    # SHA256: ~30K gates
    binary_gates = 75_000_000 + 200_000 + 30_000
    
    # Arithmetic circuit estimate
    # Scalar mul: ~3840 gates
    # Point add: ~10 gates
    # SHA256: Still binary, ~30K gates (but can be optimized)
    arith_gates = 3_840 + 10 + 30_000  # Hash still dominates!
    
    # With optimized hash (algebraic hash function)
    arith_gates_optimized = 3_840 + 10 + 100  # Poseidon-style hash
    
    print(f"\nBinary circuit gates:           {binary_gates:>15,}")
    print(f"Arithmetic circuit gates:       {arith_gates:>15,}")
    print(f"Arithmetic + algebraic hash:    {arith_gates_optimized:>15,}")
    
    print(f"\nImprovement (vs binary):")
    print(f"  Standard arithmetic: {binary_gates/arith_gates:>10,.0f}x")
    print(f"  With algebraic hash: {binary_gates/arith_gates_optimized:>10,.0f}x")
    
    # Estimate on-chain cost
    # Assume each gate requires ~32 bytes in worst-case dispute
    binary_dispute_size = binary_gates * 32 / 1_000_000  # MB
    arith_dispute_size = arith_gates_optimized * 32 / 1_000_000  # MB
    
    print(f"\nWorst-case dispute proof size:")
    print(f"  Binary:     {binary_dispute_size:>10,.1f} MB")
    print(f"  Arithmetic: {arith_dispute_size:>10,.4f} MB")


def main():
    print("""
╔══════════════════════════════════════════════════════════════════════╗
║              Garbled Circuits Performance Benchmark                   ║
╚══════════════════════════════════════════════════════════════════════╝
""")
    
    # Run benchmarks
    print("Running benchmarks (this may take a moment)...\n")
    
    n_ops = 100
    
    print("=" * 70)
    print("Operation Benchmarks")
    print("=" * 70)
    
    binary_result = benchmark_binary_circuit(n_ops)
    print(f"\n{binary_result}")
    
    arith_result = benchmark_arithmetic_circuit(n_ops)
    print(f"{arith_result}")
    
    print(f"\nArithmetic is {binary_result.per_op_ms / arith_result.per_op_ms:.1f}x faster per operation")
    print("(Note: This is just operation overhead; the real win is gate count reduction)")
    
    print("\n" + "=" * 70)
    print("Detailed EC-MAC Benchmarks")
    print("=" * 70)
    
    mac_results = benchmark_ec_mac_operations(n_ops)
    for r in mac_results:
        print(f"\n{r}")
    
    # BitVM use case
    estimate_bitvm_improvement()
    
    print("\n" + "=" * 70)
    print("Conclusion")
    print("=" * 70)
    print("""
Argo's arithmetic circuit approach provides:

1. ~1000x reduction in gate count for EC operations
2. ~19,000x reduction when using algebraic hash functions
3. Drastically smaller on-chain dispute proofs for BitVM
4. Makes previously impractical BitVM contracts feasible

This enables:
- On-chain verification of ZK proofs
- Complex smart contract logic via optimistic execution
- Trustless bridges with practical security assumptions
""")


if __name__ == "__main__":
    main()

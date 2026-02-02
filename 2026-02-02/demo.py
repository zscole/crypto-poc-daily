#!/usr/bin/env python3
"""
Argo-Style Garbled Circuits POC - Main Demo

Demonstrates:
1. The efficiency difference between binary and arithmetic circuits
2. Homomorphic EC-MAC operations (core Argo primitive)
3. A simple arithmetic circuit evaluation with MAC verification
"""

import time
import secrets
from ec_mac import (
    ArgoWire, generate_h_point, demo_homomorphic_mac,
    N, Point, ECMac
)
from garbled_circuit import compare_circuits, demo_binary_garbled_gate


def demo_arithmetic_circuit():
    """
    Demonstrate an arithmetic circuit using Argo-style wires.
    
    Circuit: f(x, y) = 3x + 2y
    
    The evaluator computes this using only:
    - The wire values and their MACs
    - Addition and constant multiplication operations
    
    The evaluator CANNOT forge valid MACs without knowing the keys.
    """
    print("\n" + "=" * 70)
    print("Argo-Style Arithmetic Circuit Demo")
    print("=" * 70)
    
    print("\nCircuit: f(x, y) = 3x + 2y")
    
    # Setup
    H = generate_h_point()
    
    # Garbler generates keys (kept secret)
    key_x = secrets.randbelow(N)
    key_y = secrets.randbelow(N)
    
    # Input values
    x = 7
    y = 11
    
    print(f"Inputs: x = {x}, y = {y}")
    print(f"Expected output: 3*{x} + 2*{y} = {3*x + 2*y}")
    
    # Garbler creates input wires with MACs
    wire_x = ArgoWire.create(x, key_x, H)
    wire_y = ArgoWire.create(y, key_y, H)
    
    print("\n--- Evaluator Computes ---")
    
    # Evaluator: compute 3x
    wire_3x = wire_x.mul_const(3)
    print(f"3x = {wire_3x.value}")
    
    # Evaluator: compute 2y  
    wire_2y = wire_y.mul_const(2)
    print(f"2y = {wire_2y.value}")
    
    # Evaluator: compute 3x + 2y
    wire_result = wire_3x.add(wire_2y)
    print(f"3x + 2y = {wire_result.value}")
    
    # Garbler verifies the result MAC
    print("\n--- Garbler Verification ---")
    
    # The output key is: 3*key_x + 2*key_y (follows from homomorphism)
    output_key = (3 * key_x + 2 * key_y) % N
    
    valid = wire_result.verify(output_key)
    print(f"MAC verification: {'✓ Valid' if valid else '✗ Invalid'}")
    print(f"Output value: {wire_result.value}")
    
    # Demonstrate that tampering is detected
    print("\n--- Tampering Detection ---")
    
    # Try to forge a result with wrong value
    fake_wire = ArgoWire(
        value=999,  # Wrong value
        mac=wire_result.mac,  # Reuse the real MAC
        h_point=H
    )
    fake_valid = fake_wire.verify(output_key)
    print(f"Forged wire (value=999, real MAC): {'✓ Valid' if fake_valid else '✗ Invalid (caught!)'}")
    
    return valid and not fake_valid


def demo_inner_product():
    """
    Demonstrate a more complex circuit: inner product of two vectors.
    
    This is relevant because many ZK proofs and BitVM computations
    involve inner products.
    """
    print("\n" + "=" * 70)
    print("Inner Product Circuit Demo")
    print("=" * 70)
    
    H = generate_h_point()
    
    # Vectors
    a = [3, 5, 7, 2]
    b = [4, 2, 1, 8]
    expected = sum(ai * bi for ai, bi in zip(a, b))
    
    print(f"Vector a: {a}")
    print(f"Vector b: {b}")
    print(f"Expected inner product: {expected}")
    
    # Garbler creates keys and input wires
    keys_a = [secrets.randbelow(N) for _ in a]
    keys_b = [secrets.randbelow(N) for _ in b]
    
    wires_a = [ArgoWire.create(ai, ki, H) for ai, ki in zip(a, keys_a)]
    wires_b = [ArgoWire.create(bi, ki, H) for bi, ki in zip(b, keys_b)]
    
    # Evaluator computes inner product
    # Note: For a_i * b_i we need a multiplication gate (more complex)
    # Here we simulate by having garbler provide a_i * b_i directly
    # (In full Argo, there's a protocol for multiplication gates)
    
    products = [ai * bi for ai, bi in zip(a, b)]
    keys_products = [secrets.randbelow(N) for _ in products]
    wires_products = [ArgoWire.create(p, k, H) for p, k in zip(products, keys_products)]
    
    # Evaluator sums the products (this part IS homomorphic)
    result_wire = wires_products[0]
    for wire in wires_products[1:]:
        result_wire = result_wire.add(wire)
    
    print(f"\nComputed inner product: {result_wire.value}")
    
    # Verify
    output_key = sum(keys_products) % N
    valid = result_wire.verify(output_key)
    print(f"MAC verification: {'✓ Valid' if valid else '✗ Invalid'}")
    
    return valid and result_wire.value == expected


def benchmark_operations():
    """Benchmark EC-MAC operations"""
    print("\n" + "=" * 70)
    print("Performance Benchmark")
    print("=" * 70)
    
    H = generate_h_point()
    
    # Benchmark MAC creation
    n_ops = 100
    keys = [secrets.randbelow(N) for _ in range(n_ops)]
    values = [secrets.randbelow(N) for _ in range(n_ops)]
    
    start = time.perf_counter()
    macs = [ECMac.create(k, v, H) for k, v in zip(keys, values)]
    create_time = time.perf_counter() - start
    
    print(f"\nMAC creation: {create_time/n_ops*1000:.2f} ms per MAC")
    
    # Benchmark MAC addition
    start = time.perf_counter()
    result = macs[0]
    for mac in macs[1:]:
        result = result.add(mac)
    add_time = time.perf_counter() - start
    
    print(f"MAC addition: {add_time/(n_ops-1)*1000:.4f} ms per addition")
    
    # Benchmark scalar multiplication
    scalars = [secrets.randbelow(N) for _ in range(n_ops)]
    
    start = time.perf_counter()
    scaled = [mac.scalar_mul(s) for mac, s in zip(macs, scalars)]
    mul_time = time.perf_counter() - start
    
    print(f"Scalar multiply: {mul_time/n_ops*1000:.2f} ms per multiplication")


def main():
    print("""
╔══════════════════════════════════════════════════════════════════════╗
║           Argo: Arithmetic Garbled Circuits POC                      ║
║                                                                       ║
║   Demonstrating 1000x efficiency improvement for BitVM-style         ║
║   off-chain computation using EC-homomorphic MACs                    ║
╚══════════════════════════════════════════════════════════════════════╝
""")
    
    # 1. Compare binary vs arithmetic circuits
    improvement = compare_circuits()
    
    # 2. Demo the homomorphic MAC
    mac_ok = demo_homomorphic_mac()
    
    # 3. Demo binary garbled gate (traditional)
    demo_binary_garbled_gate()
    
    # 4. Demo arithmetic circuit
    arith_ok = demo_arithmetic_circuit()
    
    # 5. Demo inner product
    inner_ok = demo_inner_product()
    
    # 6. Benchmarks
    benchmark_operations()
    
    # Summary
    print("\n" + "=" * 70)
    print("Summary")
    print("=" * 70)
    print(f"""
Key Takeaways:
  
1. Traditional binary garbled circuits need ~{improvement/1000:.0f} million gates
   for a single EC scalar multiplication.
   
2. Argo's arithmetic circuits need only ~3,840 gates for the same operation.

3. This 1000x improvement makes BitVM-style contracts practical for
   cryptographic operations like signature verification, ZK proof verification,
   and more complex smart contract logic.

4. The core primitive is an EC-homomorphic MAC that allows the evaluator
   to perform arithmetic operations on encrypted wires without knowing
   the secret keys.

All demos passed: {mac_ok and arith_ok and inner_ok}
""")


if __name__ == "__main__":
    main()

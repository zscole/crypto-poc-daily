"""
Garbled Circuits: Binary vs Arithmetic

Demonstrates the fundamental difference between traditional binary garbled
circuits and Argo's arithmetic approach.
"""

import hashlib
import secrets
from dataclasses import dataclass
from typing import Dict, List, Tuple
from enum import Enum


class GateType(Enum):
    AND = "AND"
    XOR = "XOR"
    OR = "OR"
    ADD = "ADD"  # Arithmetic
    MUL = "MUL"  # Arithmetic


@dataclass
class BinaryLabel:
    """Wire label for binary garbled circuits (traditional Yao)"""
    label: bytes  # 128-bit random label
    
    @classmethod
    def random(cls) -> 'BinaryLabel':
        return cls(secrets.token_bytes(16))
    
    def __xor__(self, other: 'BinaryLabel') -> 'BinaryLabel':
        return BinaryLabel(bytes(a ^ b for a, b in zip(self.label, other.label)))
    
    def hash_with(self, *others: 'BinaryLabel') -> bytes:
        """Hash labels together for garbled table encryption"""
        h = hashlib.sha256()
        h.update(self.label)
        for other in others:
            h.update(other.label)
        return h.digest()[:16]


@dataclass  
class BinaryWire:
    """A wire in a binary circuit with labels for 0 and 1"""
    label_0: BinaryLabel
    label_1: BinaryLabel
    
    @classmethod
    def create(cls) -> 'BinaryWire':
        return cls(BinaryLabel.random(), BinaryLabel.random())
    
    def get_label(self, value: int) -> BinaryLabel:
        return self.label_1 if value else self.label_0


class BinaryGarbledGate:
    """
    Traditional binary garbled gate using point-and-permute + row reduction.
    
    For an AND gate with inputs A, B and output C:
    - Garbler creates encrypted table mapping (label_A, label_B) -> label_C
    - Evaluator can only decrypt the one row corresponding to their labels
    """
    
    def __init__(self, gate_type: GateType, in_wire_a: BinaryWire, 
                 in_wire_b: BinaryWire, out_wire: BinaryWire):
        self.gate_type = gate_type
        self.in_a = in_wire_a
        self.in_b = in_wire_b
        self.out = out_wire
        self.garbled_table = self._garble()
    
    def _gate_func(self, a: int, b: int) -> int:
        """Evaluate the gate function"""
        if self.gate_type == GateType.AND:
            return a & b
        elif self.gate_type == GateType.XOR:
            return a ^ b
        elif self.gate_type == GateType.OR:
            return a | b
        raise ValueError(f"Unsupported gate type: {self.gate_type}")
    
    def _garble(self) -> List[bytes]:
        """Create the garbled table"""
        table = []
        
        # For each possible input combination
        for a in [0, 1]:
            for b in [0, 1]:
                # Get input labels
                label_a = self.in_a.get_label(a)
                label_b = self.in_b.get_label(b)
                
                # Compute output value and get output label
                out_val = self._gate_func(a, b)
                label_out = self.out.get_label(out_val)
                
                # Encrypt output label with input labels
                key = label_a.hash_with(label_b)
                encrypted = bytes(k ^ o for k, o in zip(key, label_out.label))
                
                table.append(encrypted)
        
        # Shuffle table (in practice, use point-and-permute)
        secrets.SystemRandom().shuffle(table)
        return table
    
    def evaluate(self, label_a: BinaryLabel, label_b: BinaryLabel) -> BinaryLabel:
        """Evaluator decrypts the garbled table"""
        key = label_a.hash_with(label_b)
        
        # Try to decrypt each row (in practice, point-and-permute tells us which)
        for encrypted in self.garbled_table:
            decrypted = bytes(k ^ e for k, e in zip(key, encrypted))
            # In real implementation, would verify decryption succeeded
            # Here we just return first decryption (simplified)
            return BinaryLabel(decrypted)
        
        raise ValueError("Decryption failed")


def count_binary_gates_for_multiplication(bits: int = 256) -> Dict[str, int]:
    """
    Estimate gate count for a single EC point multiplication in binary circuits.
    
    A 256-bit modular multiplication requires:
    - ~256² AND gates for schoolbook multiplication
    - Plus XOR gates for addition/reduction
    - EC point multiplication needs ~256 of these plus point additions
    """
    
    # Schoolbook multiplication: n² AND gates, ~2n² XOR gates
    mul_and = bits * bits  # 65,536 AND gates per multiplication
    mul_xor = 2 * bits * bits  # 131,072 XOR gates
    
    # Modular reduction (simplified): ~2n² additional gates
    mod_gates = 2 * bits * bits
    
    # Single field multiplication
    field_mul_total = mul_and + mul_xor + mod_gates
    
    # EC point addition needs ~10 field multiplications + other ops
    ec_add_muls = 10
    ec_add_total = ec_add_muls * field_mul_total
    
    # Scalar multiplication (256-bit) needs ~384 point additions (on average)
    # Using double-and-add with ~50% bit density
    scalar_mul_point_ops = 384
    
    total_gates = scalar_mul_point_ops * ec_add_total
    
    return {
        "bits": bits,
        "single_field_mul_and": mul_and,
        "single_field_mul_xor": mul_xor,
        "single_field_mul_total": field_mul_total,
        "single_ec_add": ec_add_total,
        "total_scalar_mul_gates": total_gates,
        "total_millions": total_gates / 1_000_000
    }


def count_arithmetic_gates_for_multiplication() -> Dict[str, int]:
    """
    Gate count for EC point multiplication in Argo's arithmetic circuits.
    
    With arithmetic circuits over a prime field:
    - Field multiplication is a SINGLE arithmetic gate
    - EC point addition needs ~10 arithmetic gates
    - Scalar multiplication needs ~384 point operations
    """
    
    field_mul = 1  # Single gate!
    
    # EC point addition: ~10 field operations
    ec_add = 10
    
    # Scalar multiplication
    scalar_mul_point_ops = 384
    total = scalar_mul_point_ops * ec_add
    
    return {
        "single_field_mul": field_mul,
        "single_ec_add": ec_add,
        "total_scalar_mul_gates": total
    }


def compare_circuits():
    """Compare binary vs arithmetic circuit complexity"""
    print("=" * 70)
    print("Binary vs Arithmetic Garbled Circuits")
    print("=" * 70)
    
    print("\n--- Binary Circuit (Traditional Yao) ---")
    binary = count_binary_gates_for_multiplication()
    print(f"For a single 256-bit EC scalar multiplication:")
    print(f"  Single field multiplication: {binary['single_field_mul_total']:,} gates")
    print(f"    - AND gates: {binary['single_field_mul_and']:,}")
    print(f"    - XOR gates: {binary['single_field_mul_xor']:,}")
    print(f"  Single EC point addition: {binary['single_ec_add']:,} gates")
    print(f"  Full scalar multiplication: {binary['total_scalar_mul_gates']:,} gates")
    print(f"                            = {binary['total_millions']:.1f} million gates")
    
    print("\n--- Arithmetic Circuit (Argo) ---")
    arith = count_arithmetic_gates_for_multiplication()
    print(f"For a single 256-bit EC scalar multiplication:")
    print(f"  Single field multiplication: {arith['single_field_mul']} gate")
    print(f"  Single EC point addition: {arith['single_ec_add']} gates")
    print(f"  Full scalar multiplication: {arith['total_scalar_mul_gates']:,} gates")
    
    improvement = binary['total_scalar_mul_gates'] / arith['total_scalar_mul_gates']
    print(f"\n--- Improvement ---")
    print(f"Argo is {improvement:,.0f}x more efficient for EC operations!")
    print(f"This is the '1000x improvement' mentioned in the paper.")
    
    return improvement


def demo_binary_garbled_gate():
    """Demonstrate a simple binary garbled AND gate"""
    print("\n" + "=" * 70)
    print("Binary Garbled AND Gate Demo")
    print("=" * 70)
    
    # Create wires
    wire_a = BinaryWire.create()
    wire_b = BinaryWire.create()
    wire_out = BinaryWire.create()
    
    # Garble the gate
    gate = BinaryGarbledGate(GateType.AND, wire_a, wire_b, wire_out)
    
    print(f"\nGarbled table has {len(gate.garbled_table)} encrypted entries")
    print("Each entry is 16 bytes (128 bits)")
    
    # Evaluate with inputs (1, 1) -> should give 1
    a_val, b_val = 1, 1
    label_a = wire_a.get_label(a_val)
    label_b = wire_b.get_label(b_val)
    
    result_label = gate.evaluate(label_a, label_b)
    
    # Check which output value we got
    is_one = result_label.label == wire_out.label_1.label
    is_zero = result_label.label == wire_out.label_0.label
    
    print(f"\nInput: a={a_val}, b={b_val}")
    print(f"Expected AND result: {a_val & b_val}")
    print(f"Evaluator got label for: {'1' if is_one else '0' if is_zero else 'unknown'}")


if __name__ == "__main__":
    compare_circuits()
    demo_binary_garbled_gate()

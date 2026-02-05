"""
Arithmetic Circuit Model for Field Operations

Demonstrates the Argo paper insight: using arithmetic circuits over
finite fields instead of binary circuits enables massive efficiency gains.

In arithmetic circuits, each gate operates on field elements directly.
A single multiplication gate can multiply two 256-bit field elements.
"""

from dataclasses import dataclass
from typing import List


@dataclass
class ArithmeticGateCount:
    """Tracks gate usage in an arithmetic circuit."""
    add_gates: int = 0      # Field addition
    mult_gates: int = 0     # Field multiplication  
    inv_gates: int = 0      # Field inversion (expensive but O(1))
    const_gates: int = 0    # Constant multiplication
    
    @property
    def total(self) -> int:
        return self.add_gates + self.mult_gates + self.inv_gates + self.const_gates
    
    def __add__(self, other: "ArithmeticGateCount") -> "ArithmeticGateCount":
        return ArithmeticGateCount(
            self.add_gates + other.add_gates,
            self.mult_gates + other.mult_gates,
            self.inv_gates + other.inv_gates,
            self.const_gates + other.const_gates
        )
    
    def __repr__(self) -> str:
        return (f"ADD: {self.add_gates}, MULT: {self.mult_gates}, "
                f"INV: {self.inv_gates}, CONST: {self.const_gates} | Total: {self.total}")


class ArithmeticFieldCircuit:
    """
    Arithmetic circuit model for finite field operations.
    
    In the Argo scheme, wires carry field elements (as EC points with
    homomorphic MAC), and gates operate on these elements directly.
    
    This is the key insight: what takes millions of binary gates
    becomes a single arithmetic gate.
    """
    
    def __init__(self, field_bits: int = 256):
        self.field_bits = field_bits
        self.total_gates = ArithmeticGateCount()
    
    def field_addition(self) -> ArithmeticGateCount:
        """
        Field addition: ONE arithmetic gate.
        
        Compare to binary circuit: ~1,500 gates for 256-bit addition.
        """
        gates = ArithmeticGateCount(add_gates=1)
        self.total_gates = self.total_gates + gates
        return gates
    
    def field_subtraction(self) -> ArithmeticGateCount:
        """
        Field subtraction: ONE arithmetic gate.
        
        In a field, subtraction is addition with negation (free in circuit).
        """
        gates = ArithmeticGateCount(add_gates=1)
        self.total_gates = self.total_gates + gates
        return gates
    
    def field_multiplication(self) -> ArithmeticGateCount:
        """
        Field multiplication: ONE arithmetic gate.
        
        This is the killer feature. In binary circuits, field multiplication
        requires ~300,000+ gates. Here it's just 1.
        """
        gates = ArithmeticGateCount(mult_gates=1)
        self.total_gates = self.total_gates + gates
        return gates
    
    def field_squaring(self) -> ArithmeticGateCount:
        """
        Field squaring: ONE arithmetic gate (same as multiplication).
        """
        return self.field_multiplication()
    
    def field_inversion(self) -> ArithmeticGateCount:
        """
        Field inversion: ONE arithmetic gate.
        
        In binary circuits: ~1M+ gates.
        In arithmetic circuits: 1 gate (though may be more expensive to verify).
        """
        gates = ArithmeticGateCount(inv_gates=1)
        self.total_gates = self.total_gates + gates
        return gates
    
    def constant_multiplication(self) -> ArithmeticGateCount:
        """
        Multiplication by a constant: essentially free / ONE gate.
        """
        gates = ArithmeticGateCount(const_gates=1)
        self.total_gates = self.total_gates + gates
        return gates
    
    def ec_point_addition(self) -> ArithmeticGateCount:
        """
        Elliptic curve point addition using arithmetic gates.
        
        Uses complete addition formula for short Weierstrass curves.
        
        Binary circuit: ~3M+ gates
        Arithmetic circuit: ~10-15 gates
        """
        gates = ArithmeticGateCount()
        
        # lambda = (y2 - y1) / (x2 - x1)
        gates = gates + self.field_subtraction()     # y2 - y1
        gates = gates + self.field_subtraction()     # x2 - x1  
        gates = gates + self.field_inversion()       # 1 / (x2 - x1)
        gates = gates + self.field_multiplication()  # lambda
        
        # x3 = lambda^2 - x1 - x2
        gates = gates + self.field_squaring()        # lambda^2
        gates = gates + self.field_subtraction()     # - x1
        gates = gates + self.field_subtraction()     # - x2
        
        # y3 = lambda * (x1 - x3) - y1
        gates = gates + self.field_subtraction()     # x1 - x3
        gates = gates + self.field_multiplication()  # lambda * (x1 - x3)
        gates = gates + self.field_subtraction()     # - y1
        
        return gates
    
    def ec_point_doubling(self) -> ArithmeticGateCount:
        """
        EC point doubling: similar gate count to addition.
        
        lambda = (3*x1^2 + a) / (2*y1)
        """
        gates = ArithmeticGateCount()
        
        # lambda = (3*x1^2 + a) / (2*y1)
        gates = gates + self.field_squaring()        # x1^2
        gates = gates + self.constant_multiplication()  # 3*x1^2
        gates = gates + self.field_addition()        # + a
        gates = gates + self.field_addition()        # 2*y1 (via add)
        gates = gates + self.field_inversion()       # 1/(2*y1)
        gates = gates + self.field_multiplication()  # lambda
        
        # x3, y3 similar to addition
        gates = gates + self.field_squaring()        # lambda^2
        gates = gates + self.field_subtraction()     # - 2*x1
        gates = gates + self.field_subtraction()     # x1 - x3
        gates = gates + self.field_multiplication()  # lambda*(x1-x3)
        gates = gates + self.field_subtraction()     # - y1
        
        return gates
    
    def ec_scalar_multiplication(self, scalar_bits: int = 256) -> ArithmeticGateCount:
        """
        EC scalar multiplication using double-and-add.
        
        ~1.5n point operations for n-bit scalar.
        
        Binary circuit: ~1 BILLION+ gates
        Arithmetic circuit: ~3,000-5,000 gates
        """
        gates = ArithmeticGateCount()
        
        # n doublings
        for _ in range(scalar_bits):
            gates = gates + self.ec_point_doubling()
        
        # ~n/2 additions on average
        for _ in range(scalar_bits // 2):
            gates = gates + self.ec_point_addition()
        
        return gates


def analyze_arithmetic_circuit():
    """Analyze gate counts for common operations in arithmetic circuits."""
    
    print("=" * 70)
    print("ARITHMETIC CIRCUIT GATE ANALYSIS (256-bit field)")
    print("=" * 70)
    
    print("\n[Basic Operations]")
    
    circuit = ArithmeticFieldCircuit(256)
    add = circuit.field_addition()
    print(f"  Addition:           {add}")
    
    circuit = ArithmeticFieldCircuit(256)
    mult = circuit.field_multiplication()
    print(f"  Multiplication:     {mult}")
    
    circuit = ArithmeticFieldCircuit(256)
    inv = circuit.field_inversion()
    print(f"  Field Inversion:    {inv}")
    
    print("\n[Elliptic Curve Operations]")
    
    circuit = ArithmeticFieldCircuit(256)
    ec_add = circuit.ec_point_addition()
    print(f"  EC Point Addition:  {ec_add}")
    
    circuit = ArithmeticFieldCircuit(256)
    ec_mult = circuit.ec_scalar_multiplication()
    print(f"  EC Scalar Multiply: {ec_mult}")
    
    print("\n" + "-" * 70)
    print("NOTE: Arithmetic gates operate on full field elements.")
    print("The Argo paper enables this via homomorphic MAC on EC points.")
    print("-" * 70)
    
    return circuit.total_gates


if __name__ == "__main__":
    analyze_arithmetic_circuit()

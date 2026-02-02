"""
Elliptic Curve Homomorphic MAC - Argo Style

Demonstrates the core cryptographic primitive behind Argo:
A MAC scheme where the tag is an EC point, and operations on tags
correspond to arithmetic operations on the underlying values.

This enables arithmetic circuits over EC points rather than binary circuits.
"""

import hashlib
import secrets
from dataclasses import dataclass
from typing import Tuple, Optional


# Using secp256k1 parameters (Bitcoin's curve)
# For simplicity, we work in a scalar field and simulate EC operations

P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
G_X = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798
G_Y = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8


@dataclass
class Point:
    """Simple EC point representation"""
    x: int
    y: int
    is_infinity: bool = False
    
    @classmethod
    def infinity(cls) -> 'Point':
        return cls(0, 0, is_infinity=True)
    
    @classmethod
    def generator(cls) -> 'Point':
        return cls(G_X, G_Y)
    
    def __eq__(self, other: 'Point') -> bool:
        if self.is_infinity and other.is_infinity:
            return True
        return self.x == other.x and self.y == other.y
    
    def __repr__(self) -> str:
        if self.is_infinity:
            return "Point(∞)"
        return f"Point({hex(self.x)[:10]}..., {hex(self.y)[:10]}...)"


def mod_inverse(a: int, m: int) -> int:
    """Extended Euclidean algorithm for modular inverse"""
    if a < 0:
        a = a % m
    g, x, _ = extended_gcd(a, m)
    if g != 1:
        raise ValueError("Modular inverse does not exist")
    return x % m


def extended_gcd(a: int, b: int) -> Tuple[int, int, int]:
    if a == 0:
        return b, 0, 1
    gcd, x1, y1 = extended_gcd(b % a, a)
    x = y1 - (b // a) * x1
    y = x1
    return gcd, x, y


def point_add(p1: Point, p2: Point) -> Point:
    """Add two EC points"""
    if p1.is_infinity:
        return p2
    if p2.is_infinity:
        return p1
    
    if p1.x == p2.x and p1.y != p2.y:
        return Point.infinity()
    
    if p1.x == p2.x:
        # Point doubling
        lam = (3 * p1.x * p1.x * mod_inverse(2 * p1.y, P)) % P
    else:
        # Point addition
        lam = ((p2.y - p1.y) * mod_inverse(p2.x - p1.x, P)) % P
    
    x3 = (lam * lam - p1.x - p2.x) % P
    y3 = (lam * (p1.x - x3) - p1.y) % P
    
    return Point(x3, y3)


def point_mul(k: int, p: Point) -> Point:
    """Scalar multiplication using double-and-add"""
    if k == 0:
        return Point.infinity()
    
    k = k % N
    result = Point.infinity()
    addend = p
    
    while k:
        if k & 1:
            result = point_add(result, addend)
        addend = point_add(addend, addend)
        k >>= 1
    
    return result


@dataclass
class ECMac:
    """
    Elliptic Curve Homomorphic MAC
    
    The MAC of a value v with key k is: MAC(k, v) = k * G + v * H
    where G is the generator and H is a secondary generator.
    
    This MAC is additively homomorphic:
    MAC(k1, v1) + MAC(k2, v2) = MAC(k1+k2, v1+v2)
    
    And supports scalar multiplication:
    c * MAC(k, v) = MAC(c*k, c*v)
    """
    tag: Point
    
    @classmethod
    def create(cls, key: int, value: int, h_point: Point) -> 'ECMac':
        """Create a MAC for a value"""
        g_term = point_mul(key, Point.generator())
        h_term = point_mul(value, h_point)
        tag = point_add(g_term, h_term)
        return cls(tag=tag)
    
    def add(self, other: 'ECMac') -> 'ECMac':
        """Homomorphic addition"""
        new_tag = point_add(self.tag, other.tag)
        return ECMac(tag=new_tag)
    
    def scalar_mul(self, scalar: int) -> 'ECMac':
        """Homomorphic scalar multiplication"""
        new_tag = point_mul(scalar, self.tag)
        return ECMac(tag=new_tag)


class ArgoWire:
    """
    Represents a wire in an Argo-style arithmetic circuit.
    
    Each wire carries a value v and its MAC: (v, MAC(k, v))
    The key k is known only to the garbler.
    """
    
    def __init__(self, value: int, mac: ECMac, h_point: Point):
        self.value = value % N
        self.mac = mac
        self.h_point = h_point
    
    @classmethod
    def create(cls, value: int, key: int, h_point: Point) -> 'ArgoWire':
        """Create a new wire with a value and fresh MAC"""
        mac = ECMac.create(key, value, h_point)
        return cls(value, mac, h_point)
    
    def add(self, other: 'ArgoWire') -> 'ArgoWire':
        """
        Addition gate: output = input1 + input2
        
        The evaluator can compute this without knowing the key!
        (v1, MAC(k1, v1)) + (v2, MAC(k2, v2)) = (v1+v2, MAC(k1+k2, v1+v2))
        """
        new_value = (self.value + other.value) % N
        new_mac = self.mac.add(other.mac)
        return ArgoWire(new_value, new_mac, self.h_point)
    
    def mul_const(self, c: int) -> 'ArgoWire':
        """
        Multiplication by constant: output = c * input
        
        The evaluator can compute: c * (v, MAC(k, v)) = (c*v, MAC(c*k, c*v))
        """
        c = c % N
        new_value = (c * self.value) % N
        new_mac = self.mac.scalar_mul(c)
        return ArgoWire(new_value, new_mac, self.h_point)
    
    def verify(self, key: int) -> bool:
        """Verify the MAC (garbler only)"""
        expected = ECMac.create(key, self.value, self.h_point)
        return self.mac.tag == expected.tag


def generate_h_point() -> Point:
    """
    Generate a secondary generator H such that no one knows log_G(H).
    In practice, this is done via hash-to-curve.
    Here we use a simplified version.
    """
    # Hash a known string to get a deterministic "nothing up my sleeve" point
    h = hashlib.sha256(b"argo-h-generator").digest()
    x = int.from_bytes(h, 'big') % P
    
    # Find a valid y for this x (simplified - in practice use proper hash-to-curve)
    # y^2 = x^3 + 7 (mod p)
    y_squared = (pow(x, 3, P) + 7) % P
    y = pow(y_squared, (P + 1) // 4, P)  # Tonelli-Shanks for p ≡ 3 (mod 4)
    
    if pow(y, 2, P) != y_squared:
        # Try x+1 if first attempt fails
        x = (x + 1) % P
        y_squared = (pow(x, 3, P) + 7) % P
        y = pow(y_squared, (P + 1) // 4, P)
    
    return Point(x, y)


def demo_homomorphic_mac():
    """Demonstrate the homomorphic properties of the EC-MAC"""
    print("=" * 60)
    print("EC Homomorphic MAC Demonstration")
    print("=" * 60)
    
    H = generate_h_point()
    
    # Generate random keys
    k1 = secrets.randbelow(N)
    k2 = secrets.randbelow(N)
    
    # Values to compute on
    v1 = 42
    v2 = 100
    
    print(f"\nValues: v1 = {v1}, v2 = {v2}")
    
    # Create MACs
    mac1 = ECMac.create(k1, v1, H)
    mac2 = ECMac.create(k2, v2, H)
    
    print(f"\nMAC(k1, v1) = {mac1.tag}")
    print(f"MAC(k2, v2) = {mac2.tag}")
    
    # Homomorphic addition
    mac_sum = mac1.add(mac2)
    expected_sum = ECMac.create((k1 + k2) % N, (v1 + v2) % N, H)
    
    print(f"\n--- Homomorphic Addition ---")
    print(f"MAC(k1, v1) + MAC(k2, v2) = {mac_sum.tag}")
    print(f"MAC(k1+k2, v1+v2)         = {expected_sum.tag}")
    print(f"Match: {mac_sum.tag == expected_sum.tag}")
    
    # Homomorphic scalar multiplication
    c = 5
    mac_scaled = mac1.scalar_mul(c)
    expected_scaled = ECMac.create((c * k1) % N, (c * v1) % N, H)
    
    print(f"\n--- Homomorphic Scalar Multiplication ---")
    print(f"{c} * MAC(k1, v1)    = {mac_scaled.tag}")
    print(f"MAC({c}*k1, {c}*v1) = {expected_scaled.tag}")
    print(f"Match: {mac_scaled.tag == expected_scaled.tag}")
    
    return mac_sum.tag == expected_sum.tag and mac_scaled.tag == expected_scaled.tag


if __name__ == "__main__":
    success = demo_homomorphic_mac()
    print(f"\n{'✓ All checks passed!' if success else '✗ Some checks failed'}")

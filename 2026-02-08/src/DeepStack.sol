// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title DeepStackEncoder
/// @notice Implements EIP-8024 encoding/decoding for DUPN, SWAPN, and EXCHANGE opcodes
/// @dev These opcodes allow stack access beyond depth 16, breaking the DUP16/SWAP16 limitation
library DeepStackEncoder {
    // Opcodes
    uint8 constant DUPN = 0xe6;
    uint8 constant SWAPN = 0xe7;
    uint8 constant EXCHANGE = 0xe8;

    // Reserved range (JUMPDEST compatibility): 91-127 (0x5b-0x7f)
    uint8 constant RESERVED_START = 91;
    uint8 constant RESERVED_END = 127;

    error InvalidStackDepth(uint256 n);
    error InvalidImmediate(uint8 x);
    error InvalidPairDepth(uint256 n, uint256 m);

    /// @notice Encode a single stack depth for DUPN or SWAPN
    /// @param n Stack depth (17-235 for DUPN, which accesses stack[n])
    /// @return immediate The encoded immediate byte
    function encodeSingle(uint256 n) internal pure returns (uint8 immediate) {
        if (n < 17 || n > 235) {
            revert InvalidStackDepth(n);
        }

        if (n <= 107) {
            // n in [17, 107] -> immediate in [0, 90]
            immediate = uint8(n - 17);
        } else {
            // n in [108, 235] -> immediate in [128, 255]
            immediate = uint8(n + 20);
        }
    }

    /// @notice Decode a single operand immediate
    /// @param x The immediate byte from bytecode
    /// @return n The decoded stack depth
    function decodeSingle(uint8 x) internal pure returns (uint256 n) {
        if (x > 90 && x < 128) {
            revert InvalidImmediate(x);
        }

        if (x <= 90) {
            n = uint256(x) + 17;
        } else {
            n = uint256(x) - 20;
        }
    }

    /// @notice Encode a pair of stack positions for EXCHANGE
    /// @param n First stack position (1-based, n < m)
    /// @param m Second stack position (1-based)
    /// @return immediate The encoded immediate byte
    function encodePair(uint256 n, uint256 m) internal pure returns (uint8 immediate) {
        // Ensure n < m (canonical ordering)
        if (n >= m) {
            (n, m) = (m, n);
        }

        // Calculate k using inverse triangular mapping
        uint256 k;
        if (n + m <= 29) {
            // Lower triangle: q < r case in decode
            // k = q * 16 + r where q = n-1, r = m-1
            k = (n - 1) * 16 + (m - 1);
        } else {
            // Upper triangle: q >= r case in decode
            // k = (29 - n - 1) * 16 + (m - 1) + 48
            // Simplified: We need k such that decode gives back (n, m)
            // From decode: r = k % 16, q = k / 16
            // If q >= r: n = r + 1, m = 29 - q
            // So: r = n - 1, q = 29 - m
            // k = q * 16 + r = (29 - m) * 16 + (n - 1)
            k = (29 - m) * 16 + (n - 1);
        }

        // Map k to immediate, skipping reserved range
        if (k <= 79) {
            immediate = uint8(k);
        } else {
            immediate = uint8(k + 48);
        }
    }

    /// @notice Decode a pair of stack positions from EXCHANGE immediate
    /// @param x The immediate byte
    /// @return n First stack position
    /// @return m Second stack position
    function decodePair(uint8 x) internal pure returns (uint256 n, uint256 m) {
        if (x > 79 && x < 128) {
            revert InvalidImmediate(x);
        }

        uint256 k = x <= 79 ? uint256(x) : uint256(x) - 48;
        uint256 q = k / 16;
        uint256 r = k % 16;

        if (q < r) {
            n = q + 1;
            m = r + 1;
        } else {
            n = r + 1;
            m = 29 - q;
        }
    }

    /// @notice Check if an immediate value is in the reserved JUMPDEST range
    /// @param x The immediate byte
    /// @return True if reserved (invalid for these opcodes)
    function isReserved(uint8 x) internal pure returns (bool) {
        return x > 90 && x < 128;
    }

    /// @notice Generate bytecode for DUPN instruction
    /// @param n Stack depth to duplicate
    /// @return bytecode The 2-byte instruction
    function byteDUPN(uint256 n) internal pure returns (bytes memory bytecode) {
        uint8 imm = encodeSingle(n);
        bytecode = new bytes(2);
        bytecode[0] = bytes1(DUPN);
        bytecode[1] = bytes1(imm);
    }

    /// @notice Generate bytecode for SWAPN instruction
    /// @param n Stack position to swap with top (swaps top with stack[n+1])
    /// @return bytecode The 2-byte instruction
    function byteSWAPN(uint256 n) internal pure returns (bytes memory bytecode) {
        uint8 imm = encodeSingle(n);
        bytecode = new bytes(2);
        bytecode[0] = bytes1(SWAPN);
        bytecode[1] = bytes1(imm);
    }

    /// @notice Generate bytecode for EXCHANGE instruction
    /// @param n First stack position
    /// @param m Second stack position
    /// @return bytecode The 2-byte instruction
    function byteEXCHANGE(uint256 n, uint256 m) internal pure returns (bytes memory bytecode) {
        uint8 imm = encodePair(n, m);
        bytecode = new bytes(2);
        bytecode[0] = bytes1(EXCHANGE);
        bytecode[1] = bytes1(imm);
    }
}

/// @title DeepStackDemo
/// @notice Demonstrates EIP-8024 encoding and provides test helpers
contract DeepStackDemo {
    using DeepStackEncoder for uint256;

    event EncodedSingle(uint256 indexed n, uint8 immediate);
    event EncodedPair(uint256 indexed n, uint256 indexed m, uint8 immediate);
    event DecodedSingle(uint8 indexed immediate, uint256 n);
    event DecodedPair(uint8 indexed immediate, uint256 n, uint256 m);

    /// @notice Demonstrate single encoding roundtrip
    function demonstrateSingleEncoding(uint256 n) external returns (uint8 immediate, uint256 decoded) {
        immediate = DeepStackEncoder.encodeSingle(n);
        decoded = DeepStackEncoder.decodeSingle(immediate);
        
        emit EncodedSingle(n, immediate);
        emit DecodedSingle(immediate, decoded);
        
        require(decoded == n, "Roundtrip failed");
    }

    /// @notice Demonstrate pair encoding roundtrip
    function demonstratePairEncoding(uint256 n, uint256 m) external returns (uint8 immediate, uint256 dn, uint256 dm) {
        immediate = DeepStackEncoder.encodePair(n, m);
        (dn, dm) = DeepStackEncoder.decodePair(immediate);
        
        emit EncodedPair(n, m, immediate);
        emit DecodedPair(immediate, dn, dm);
        
        // Pairs are normalized to (smaller, larger)
        (uint256 minN, uint256 maxN) = n < m ? (n, m) : (m, n);
        require(dn == minN && dm == maxN, "Roundtrip failed");
    }

    /// @notice Get all valid single encoding values
    function getValidSingleRange() external pure returns (uint256 min, uint256 max) {
        return (17, 235);
    }

    /// @notice Generate sample bytecode demonstrating deep stack access
    function generateSampleBytecode() external pure returns (bytes memory) {
        // Example: DUP the 50th stack item, SWAP with 100th, EXCHANGE positions 5 and 20
        bytes memory dup50 = DeepStackEncoder.byteDUPN(50);
        bytes memory swap100 = DeepStackEncoder.byteSWAPN(100);
        bytes memory exchange5_20 = DeepStackEncoder.byteEXCHANGE(5, 20);
        
        // Concatenate
        bytes memory result = new bytes(6);
        result[0] = dup50[0];
        result[1] = dup50[1];
        result[2] = swap100[0];
        result[3] = swap100[1];
        result[4] = exchange5_20[0];
        result[5] = exchange5_20[1];
        
        return result;
    }
}

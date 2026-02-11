// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title EIP-8037 Gas Cost Calculator
/// @notice Calculates dynamic cost_per_state_byte based on block gas limit
/// @dev Implements the quantization formula from EIP-8037
library GasCostCalculator {
    /// @notice Target state growth: 100 GiB per year
    uint256 constant TARGET_STATE_GROWTH_PER_YEAR = 100 * 1024 * 1024 * 1024;
    
    /// @notice Significant bits for quantization
    uint256 constant CPSB_SIGNIFICANT_BITS = 5;
    
    /// @notice Offset for quantization stability
    uint256 constant CPSB_OFFSET = 9578;
    
    /// @notice Seconds per year (365.25 days / 12 months * 12 = ~2,628,000 blocks/year at 12s)
    uint256 constant BLOCKS_PER_YEAR = 2_628_000;

    /// @notice Calculate cost per state byte for a given gas limit
    /// @param gasLimit The block gas limit
    /// @return cpsb The cost per state byte in gas
    function costPerStateByte(uint256 gasLimit) internal pure returns (uint256 cpsb) {
        // raw = ceil((gas_limit * 2_628_000) / (2 * TARGET_STATE_GROWTH_PER_YEAR))
        uint256 numerator = gasLimit * BLOCKS_PER_YEAR;
        uint256 denominator = 2 * TARGET_STATE_GROWTH_PER_YEAR;
        uint256 raw = (numerator + denominator - 1) / denominator; // ceiling division
        
        // Apply offset for quantization
        uint256 shifted = raw + CPSB_OFFSET;
        
        // Calculate shift amount based on bit length
        uint256 bitLen = _bitLength(shifted);
        uint256 shift = bitLen > CPSB_SIGNIFICANT_BITS ? bitLen - CPSB_SIGNIFICANT_BITS : 0;
        
        // Quantize by keeping only significant bits
        uint256 quantized = (shifted >> shift) << shift;
        
        // Remove offset, ensure minimum of 1
        cpsb = quantized > CPSB_OFFSET ? quantized - CPSB_OFFSET : 1;
    }

    /// @notice Calculate gas costs for various state operations
    /// @param gasLimit The block gas limit
    /// @return createGas Gas for CREATE/CREATE2 (account creation portion)
    /// @return sstoreGas Gas for SSTORE (new slot)
    /// @return newAccountGas Gas for creating new account via CALL
    function stateOperationCosts(uint256 gasLimit) 
        internal 
        pure 
        returns (
            uint256 createGas,
            uint256 sstoreGas,
            uint256 newAccountGas
        ) 
    {
        uint256 cpsb = costPerStateByte(gasLimit);
        
        // Account = 112 bytes (address + nonce + balance + codehash + storageRoot)
        createGas = 112 * cpsb;
        
        // Storage slot = 32 bytes
        sstoreGas = 32 * cpsb;
        
        // New account via CALL = same as CREATE
        newAccountGas = 112 * cpsb;
    }

    /// @notice Calculate code deployment cost
    /// @param gasLimit The block gas limit
    /// @param codeLength Length of bytecode in bytes
    /// @return stateGas State gas for code storage
    /// @return regularGas Regular gas for hashing
    function codeDeploymentCost(uint256 gasLimit, uint256 codeLength)
        internal
        pure
        returns (uint256 stateGas, uint256 regularGas)
    {
        uint256 cpsb = costPerStateByte(gasLimit);
        
        // State gas: cpsb per byte of code
        stateGas = cpsb * codeLength;
        
        // Regular gas: 6 gas per 32-byte word for hashing
        uint256 words = (codeLength + 31) / 32;
        regularGas = 6 * words;
    }

    /// @notice Calculate bit length of a number
    function _bitLength(uint256 x) private pure returns (uint256 len) {
        while (x > 0) {
            len++;
            x >>= 1;
        }
    }
}

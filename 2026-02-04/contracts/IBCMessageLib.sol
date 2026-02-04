// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IBCMessageLib
 * @notice Message structures and utilities for IBC cross-chain communication
 * @dev Simplified version for POC demonstration
 */
library IBCMessageLib {
    struct IBCPacket {
        uint64 sequence;           // Unique packet sequence number
        string sourcePort;         // Source port identifier
        string sourceChannel;      // Source channel identifier  
        string destPort;           // Destination port identifier
        string destChannel;        // Destination channel identifier
        bytes data;                // Application-specific data
        uint64 timeoutHeight;      // Block height timeout
        uint64 timeoutTimestamp;   // Unix timestamp timeout
    }

    struct DepositMessage {
        address depositor;         // Address that made the deposit
        address token;             // Token address on source chain
        uint256 amount;            // Amount deposited
        address recipient;         // Recipient on destination chain
        bytes32 depositHash;       // Hash of the deposit tx on source chain
    }

    struct MerkleProof {
        bytes32[] proof;           // Merkle proof nodes
        uint256 index;             // Leaf index
        bytes32 root;              // Expected Merkle root
    }

    /**
     * @notice Encode a deposit message for IBC transmission
     */
    function encodeDepositMessage(DepositMessage memory msg_) 
        internal 
        pure 
        returns (bytes memory) 
    {
        return abi.encode(
            msg_.depositor,
            msg_.token,
            msg_.amount,
            msg_.recipient,
            msg_.depositHash
        );
    }

    /**
     * @notice Decode a deposit message from IBC packet data
     */
    function decodeDepositMessage(bytes memory data) 
        internal 
        pure 
        returns (DepositMessage memory) 
    {
        (
            address depositor,
            address token,
            uint256 amount,
            address recipient,
            bytes32 depositHash
        ) = abi.decode(data, (address, address, uint256, address, bytes32));

        return DepositMessage({
            depositor: depositor,
            token: token,
            amount: amount,
            recipient: recipient,
            depositHash: depositHash
        });
    }

    /**
     * @notice Compute the commitment hash for a packet
     * @dev Used for signature verification
     */
    function computePacketCommitment(IBCPacket memory packet) 
        internal 
        pure 
        returns (bytes32) 
    {
        return keccak256(abi.encode(
            packet.sequence,
            packet.sourcePort,
            packet.sourceChannel,
            packet.destPort,
            packet.destChannel,
            keccak256(packet.data),
            packet.timeoutHeight,
            packet.timeoutTimestamp
        ));
    }

    /**
     * @notice Verify a Merkle proof
     * @dev Simple implementation for POC
     */
    function verifyMerkleProof(
        MerkleProof memory proof,
        bytes32 leaf
    ) internal pure returns (bool) {
        bytes32 computedHash = leaf;
        
        for (uint256 i = 0; i < proof.proof.length; i++) {
            bytes32 proofElement = proof.proof[i];
            
            if (proof.index % 2 == 0) {
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
            
            proof.index = proof.index / 2;
        }
        
        return computedHash == proof.root;
    }
}

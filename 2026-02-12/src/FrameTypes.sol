// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title FrameTypes - EIP-8141 Frame Transaction Type Definitions
/// @notice Type definitions for Frame Transactions as specified in EIP-8141
/// @dev These types mirror the RLP structure defined in the EIP

/// @notice Frame execution modes
/// @dev Mode determines how the frame executes and who the caller appears as
enum FrameMode {
    DEFAULT, // Execute as ENTRY_POINT (0xaa)
    VERIFY,  // Validation frame - must call APPROVE, static execution
    SENDER   // Execute as transaction sender
}

/// @notice Approval scopes for the APPROVE opcode
/// @dev Determines what the APPROVE call authorizes
enum ApprovalScope {
    EXECUTION,         // 0x0: Approve future SENDER mode frames
    PAYMENT,           // 0x1: Approve gas payment (increments nonce, collects fees)
    EXECUTION_PAYMENT  // 0x2: Approve both execution and payment
}

/// @notice A single frame within a Frame Transaction
/// @param mode The execution mode (DEFAULT, VERIFY, or SENDER)
/// @param target The contract to call (or address(0) for contract creation)
/// @param gasLimit Gas allocated to this frame
/// @param data Calldata for the frame
struct Frame {
    FrameMode mode;
    address target;
    uint256 gasLimit;
    bytes data;
}

/// @notice Complete Frame Transaction structure
/// @dev Corresponds to EIP-2718 type 0x06
/// @param chainId Chain identifier
/// @param nonce Account nonce (managed by APPROVE)
/// @param sender The logical sender of the transaction
/// @param frames Array of frames to execute
/// @param maxPriorityFeePerGas EIP-1559 priority fee
/// @param maxFeePerGas EIP-1559 max fee
/// @param maxFeePerBlobGas EIP-4844 blob fee (0 if no blobs)
/// @param blobVersionedHashes EIP-4844 blob hashes (empty if no blobs)
struct FrameTransaction {
    uint256 chainId;
    uint64 nonce;
    address sender;
    Frame[] frames;
    uint256 maxPriorityFeePerGas;
    uint256 maxFeePerGas;
    uint256 maxFeePerBlobGas;
    bytes32[] blobVersionedHashes;
}

/// @notice Frame execution result
/// @param status True if frame succeeded
/// @param gasUsed Gas consumed by the frame
/// @param logs Encoded logs (simplified for POC)
struct FrameReceipt {
    bool status;
    uint256 gasUsed;
    bytes logs;
}

/// @notice Full transaction receipt
/// @param cumulativeGasUsed Total gas used
/// @param payer Address that paid for gas
/// @param frameReceipts Results for each frame
struct TransactionReceipt {
    uint256 cumulativeGasUsed;
    address payer;
    FrameReceipt[] frameReceipts;
}

/// @notice Constants from EIP-8141
library FrameConstants {
    uint8 constant FRAME_TX_TYPE = 0x06;
    uint256 constant FRAME_TX_INTRINSIC_COST = 15000;
    address constant ENTRY_POINT = address(0xaa);
    uint256 constant MAX_FRAMES = 1000;
    
    // Opcode values (for reference)
    uint8 constant OP_APPROVE = 0xaa;
    uint8 constant OP_TXPARAMLOAD = 0xb0;
    uint8 constant OP_TXPARAMSIZE = 0xb1;
    uint8 constant OP_TXPARAMCOPY = 0xb2;
}

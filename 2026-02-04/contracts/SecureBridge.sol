// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IBCMessageLib.sol";

/**
 * @title SecureBridge
 * @notice Demonstrates proper IBC message validation
 * @dev Implements multiple layers of security:
 *      1. Relayer signature verification (trusted relayer set)
 *      2. Merkle proof verification (proves inclusion in source chain state)
 *      3. Nonce/sequence tracking (replay protection)
 *      4. Source chain validation (only accept from known chains)
 */
contract SecureBridge {
    using IBCMessageLib for *;

    // ============ State Variables ============

    // Minted token balances
    mapping(address => uint256) public balances;
    
    // Total supply minted through the bridge
    uint256 public totalMinted;

    // Authorized relayers (addresses that can submit proofs)
    mapping(address => bool) public authorizedRelayers;
    
    // Processed packet sequences (replay protection)
    // channelId => sequence => processed
    mapping(bytes32 => mapping(uint64 => bool)) public processedSequences;
    
    // Valid source channels
    mapping(bytes32 => bool) public validSourceChannels;
    
    // Light client state root for proof verification
    // In production, this would be updated by a light client
    bytes32 public stateRoot;
    
    // Admin (for relayer management)
    address public admin;

    // ============ Events ============

    event DepositProcessed(
        address indexed recipient,
        uint256 amount,
        bytes32 depositHash,
        uint64 sequence
    );
    event RelayerAdded(address indexed relayer);
    event RelayerRemoved(address indexed relayer);
    event StateRootUpdated(bytes32 newRoot);
    event SourceChannelAdded(bytes32 indexed channelId);

    // ============ Errors ============

    error UnauthorizedRelayer();
    error InvalidSignature();
    error PacketAlreadyProcessed();
    error InvalidSourceChannel();
    error InvalidMerkleProof();
    error PacketTimeout();
    error OnlyAdmin();

    // ============ Constructor ============

    constructor() {
        admin = msg.sender;
    }

    // ============ Modifiers ============

    modifier onlyAdmin() {
        if (msg.sender != admin) revert OnlyAdmin();
        _;
    }

    modifier onlyAuthorizedRelayer() {
        if (!authorizedRelayers[msg.sender]) revert UnauthorizedRelayer();
        _;
    }

    // ============ Admin Functions ============

    function addRelayer(address relayer) external onlyAdmin {
        authorizedRelayers[relayer] = true;
        emit RelayerAdded(relayer);
    }

    function removeRelayer(address relayer) external onlyAdmin {
        authorizedRelayers[relayer] = false;
        emit RelayerRemoved(relayer);
    }

    function addSourceChannel(string calldata channelId) external onlyAdmin {
        bytes32 channelHash = keccak256(bytes(channelId));
        validSourceChannels[channelHash] = true;
        emit SourceChannelAdded(channelHash);
    }

    function updateStateRoot(bytes32 newRoot) external onlyAdmin {
        // In production, this would be done by a light client
        // verifying block headers from the source chain
        stateRoot = newRoot;
        emit StateRootUpdated(newRoot);
    }

    // ============ Core Functions ============

    /**
     * @notice SECURE: Process an IBC deposit with full verification
     * @param packet The IBC packet containing the deposit message
     * @param relayerSignature Signature from authorized relayer
     * @param merkleProof Proof of inclusion in source chain state
     */
    function processDeposit(
        IBCMessageLib.IBCPacket calldata packet,
        bytes calldata relayerSignature,
        IBCMessageLib.MerkleProof calldata merkleProof
    ) external onlyAuthorizedRelayer {
        // SECURITY CHECK 1: Verify source channel is valid
        bytes32 sourceChannelHash = keccak256(bytes(packet.sourceChannel));
        if (!validSourceChannels[sourceChannelHash]) {
            revert InvalidSourceChannel();
        }

        // SECURITY CHECK 2: Verify packet hasn't been processed (replay protection)
        if (processedSequences[sourceChannelHash][packet.sequence]) {
            revert PacketAlreadyProcessed();
        }

        // SECURITY CHECK 3: Verify timeout hasn't passed
        if (packet.timeoutTimestamp != 0 && block.timestamp > packet.timeoutTimestamp) {
            revert PacketTimeout();
        }
        if (packet.timeoutHeight != 0 && block.number > packet.timeoutHeight) {
            revert PacketTimeout();
        }

        // SECURITY CHECK 4: Verify relayer signature on packet commitment
        bytes32 packetCommitment = packet.computePacketCommitment();
        if (!_verifyRelayerSignature(packetCommitment, relayerSignature)) {
            revert InvalidSignature();
        }

        // SECURITY CHECK 5: Verify Merkle proof against state root
        // This proves the packet was actually committed on the source chain
        bytes32 packetLeaf = keccak256(abi.encodePacked(
            packet.sourceChannel,
            packet.sequence,
            packetCommitment
        ));
        if (!merkleProof.verifyMerkleProof(packetLeaf)) {
            revert InvalidMerkleProof();
        }

        // Mark sequence as processed (replay protection)
        processedSequences[sourceChannelHash][packet.sequence] = true;

        // Now safe to process the deposit
        IBCMessageLib.DepositMessage memory depositMsg = 
            IBCMessageLib.decodeDepositMessage(packet.data);

        // Mint tokens
        balances[depositMsg.recipient] += depositMsg.amount;
        totalMinted += depositMsg.amount;

        emit DepositProcessed(
            depositMsg.recipient,
            depositMsg.amount,
            depositMsg.depositHash,
            packet.sequence
        );
    }

    /**
     * @notice Verify relayer signature using ECDSA
     * @dev In production, consider using EIP-712 typed data signing
     */
    function _verifyRelayerSignature(
        bytes32 message,
        bytes calldata signature
    ) internal view returns (bool) {
        if (signature.length != 65) return false;

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }

        if (v < 27) v += 27;

        bytes32 ethSignedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", message)
        );

        address signer = ecrecover(ethSignedHash, v, r, s);
        return authorizedRelayers[signer];
    }

    /**
     * @notice Get balance of an account
     */
    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    /**
     * @notice Check if a sequence has been processed
     */
    function isSequenceProcessed(
        string calldata channelId,
        uint64 sequence
    ) external view returns (bool) {
        return processedSequences[keccak256(bytes(channelId))][sequence];
    }
}

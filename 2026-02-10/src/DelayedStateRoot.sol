// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title DelayedStateRoot
 * @notice Simulates EIP-7862 delayed state root mechanism
 * @dev Each block contains the state root of the PREVIOUS block's post-state
 * 
 * Key insight: Validators can verify block validity and attest WITHOUT
 * waiting for state root computation. The state root for block N is
 * computed after N is executed and included in block N+1.
 */
contract DelayedStateRoot {
    struct BlockHeader {
        uint256 number;
        bytes32 parentHash;
        bytes32 stateRoot;      // Post-state root of block (n-1), NOT this block
        bytes32 transactionsRoot;
        uint256 timestamp;
        address coinbase;
    }

    struct BlockChain {
        BlockHeader[] blocks;
        bytes32 lastComputedStateRoot;  // State root computed after last execution
        mapping(bytes32 => bytes32) state;  // Simplified state: hash -> value
    }

    BlockChain public chain;
    
    // Events for tracking
    event BlockProposed(uint256 indexed blockNumber, bytes32 stateRoot, bool isDelayed);
    event StateRootComputed(uint256 indexed forBlock, bytes32 stateRoot);
    event AttestationReady(uint256 indexed blockNumber, uint256 timeSaved);

    constructor() {
        // Genesis block - state root is the initial empty state
        bytes32 genesisStateRoot = keccak256(abi.encodePacked("genesis"));
        
        BlockHeader memory genesis = BlockHeader({
            number: 0,
            parentHash: bytes32(0),
            stateRoot: genesisStateRoot,
            transactionsRoot: bytes32(0),
            timestamp: block.timestamp,
            coinbase: address(0)
        });
        
        chain.blocks.push(genesis);
        chain.lastComputedStateRoot = genesisStateRoot;
    }

    /**
     * @notice Validates a new block header using delayed state root semantics
     * @dev The state_root field contains the post-state of block (n-1)
     */
    function validateHeader(BlockHeader memory header) public view returns (bool) {
        require(header.number > 0, "Invalid block number");
        
        BlockHeader storage parent = chain.blocks[chain.blocks.length - 1];
        
        // Verify parent hash matches
        require(
            header.parentHash == keccak256(abi.encode(parent)),
            "Invalid parent hash"
        );
        
        // KEY CHANGE: Verify delayed state root matches last computed
        // This is the post-state of the PREVIOUS block, not current
        require(
            header.stateRoot == chain.lastComputedStateRoot,
            "Invalid delayed state root"
        );
        
        return true;
    }

    /**
     * @notice Simulates block execution and state root computation
     * @dev Demonstrates the decoupled timing model
     */
    function processBlock(
        bytes32 transactionsRoot,
        address coinbase
    ) external returns (uint256 blockNumber) {
        BlockHeader storage parent = chain.blocks[chain.blocks.length - 1];
        
        // Create new block with DELAYED state root (from previous block)
        BlockHeader memory newBlock = BlockHeader({
            number: parent.number + 1,
            parentHash: keccak256(abi.encode(parent)),
            stateRoot: chain.lastComputedStateRoot,  // Delayed: previous block's post-state
            transactionsRoot: transactionsRoot,
            timestamp: block.timestamp,
            coinbase: coinbase
        });
        
        // Validate header
        require(validateHeader(newBlock), "Invalid block");
        
        // Add block to chain
        chain.blocks.push(newBlock);
        blockNumber = newBlock.number;
        
        emit BlockProposed(blockNumber, newBlock.stateRoot, true);
        
        // CRITICAL: At this point, validators can ATTEST
        // They don't need to wait for state root computation
        emit AttestationReady(blockNumber, 200); // ~200ms saved
        
        // Execute transactions and compute new state root (happens async in real impl)
        bytes32 newStateRoot = _executeAndComputeStateRoot(newBlock, transactionsRoot);
        
        // Store for inclusion in NEXT block
        chain.lastComputedStateRoot = newStateRoot;
        
        emit StateRootComputed(blockNumber, newStateRoot);
    }

    /**
     * @notice Simulates transaction execution and state root computation
     * @dev In practice, this would use MPT/Verkle tree computation
     */
    function _executeAndComputeStateRoot(
        BlockHeader memory header,
        bytes32 txRoot
    ) internal returns (bytes32) {
        // Simulate state changes from transactions
        bytes32 stateKey = keccak256(abi.encodePacked(header.number, "state"));
        bytes32 stateValue = keccak256(abi.encodePacked(txRoot, header.coinbase));
        
        chain.state[stateKey] = stateValue;
        
        // Compute post-state root (simplified - real impl uses trie)
        return keccak256(abi.encodePacked(
            header.stateRoot,  // Previous state
            stateKey,
            stateValue,
            header.number
        ));
    }

    /**
     * @notice Demonstrates synergy with Block Access Lists (EIP-7928)
     * @dev BALs enable parallel state root computation
     */
    function computeStateRootWithBAL(
        bytes32[] calldata accessedSlots,
        bytes32[] calldata newValues
    ) external pure returns (bytes32) {
        require(accessedSlots.length == newValues.length, "Length mismatch");
        
        // With BAL, we know all accessed slots upfront
        // This enables parallel proof generation
        bytes32 root = bytes32(0);
        
        for (uint i = 0; i < accessedSlots.length; i++) {
            // Each slot can be processed in parallel (in real impl)
            root = keccak256(abi.encodePacked(root, accessedSlots[i], newValues[i]));
        }
        
        return root;
    }

    // View functions
    function getBlockCount() external view returns (uint256) {
        return chain.blocks.length;
    }
    
    function getBlock(uint256 index) external view returns (BlockHeader memory) {
        require(index < chain.blocks.length, "Index out of bounds");
        return chain.blocks[index];
    }
    
    function getLastComputedStateRoot() external view returns (bytes32) {
        return chain.lastComputedStateRoot;
    }
}

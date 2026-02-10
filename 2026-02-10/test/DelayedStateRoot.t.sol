// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/DelayedStateRoot.sol";

contract DelayedStateRootTest is Test {
    DelayedStateRoot public dsr;
    
    event BlockProposed(uint256 indexed blockNumber, bytes32 stateRoot, bool isDelayed);
    event StateRootComputed(uint256 indexed forBlock, bytes32 stateRoot);
    event AttestationReady(uint256 indexed blockNumber, uint256 timeSaved);

    function setUp() public {
        dsr = new DelayedStateRoot();
    }

    function test_GenesisBlockInitialized() public view {
        assertEq(dsr.getBlockCount(), 1);
        
        DelayedStateRoot.BlockHeader memory genesis = dsr.getBlock(0);
        assertEq(genesis.number, 0);
        assertEq(genesis.parentHash, bytes32(0));
    }

    function test_ProcessBlock_DelayedStateRoot() public {
        bytes32 txRoot1 = keccak256("transactions1");
        address coinbase1 = address(0x1);
        
        // Get initial state root (genesis post-state)
        bytes32 initialStateRoot = dsr.getLastComputedStateRoot();
        
        // Process block 1
        vm.expectEmit(true, false, false, true);
        emit AttestationReady(1, 200);
        
        uint256 blockNum = dsr.processBlock(txRoot1, coinbase1);
        assertEq(blockNum, 1);
        
        // Block 1's state_root should be genesis post-state (delayed)
        DelayedStateRoot.BlockHeader memory block1 = dsr.getBlock(1);
        assertEq(block1.stateRoot, initialStateRoot);
        
        // New state root computed for block 2
        bytes32 newStateRoot = dsr.getLastComputedStateRoot();
        assertTrue(newStateRoot != initialStateRoot);
    }

    function test_ProcessMultipleBlocks_ChainedDelayedRoots() public {
        bytes32[] memory stateRoots = new bytes32[](5);
        
        // Record state roots as we go
        stateRoots[0] = dsr.getLastComputedStateRoot();
        
        for (uint i = 1; i <= 4; i++) {
            bytes32 txRoot = keccak256(abi.encodePacked("tx", i));
            address coinbase = address(uint160(i));
            
            dsr.processBlock(txRoot, coinbase);
            
            // Get block's state root
            DelayedStateRoot.BlockHeader memory blk = dsr.getBlock(i);
            
            // Block i should contain state root from block i-1's execution
            assertEq(blk.stateRoot, stateRoots[i-1], "Delayed state root mismatch");
            
            // Record new state root for next iteration
            stateRoots[i] = dsr.getLastComputedStateRoot();
        }
        
        assertEq(dsr.getBlockCount(), 5);
    }

    function test_ComputeStateRootWithBAL() public view {
        bytes32[] memory slots = new bytes32[](3);
        bytes32[] memory values = new bytes32[](3);
        
        slots[0] = keccak256("slot0");
        slots[1] = keccak256("slot1");
        slots[2] = keccak256("slot2");
        
        values[0] = bytes32(uint256(100));
        values[1] = bytes32(uint256(200));
        values[2] = bytes32(uint256(300));
        
        bytes32 root = dsr.computeStateRootWithBAL(slots, values);
        assertTrue(root != bytes32(0));
        
        // Same inputs should produce same root (deterministic)
        bytes32 root2 = dsr.computeStateRootWithBAL(slots, values);
        assertEq(root, root2);
    }

    function test_TimingModel() public {
        // This test demonstrates the timing advantage
        // In traditional model: Execute -> Compute Root -> Attest (sequential)
        // In EIP-7862: Execute -> Attest (parallel with root computation)
        
        uint256 SLOT_TIME = 12 seconds;
        uint256 EXECUTION_TIME = 2 seconds;
        uint256 STATE_ROOT_TIME = 3 seconds;
        uint256 ATTESTATION_DEADLINE = 4 seconds; // Must attest within first 1/3 of slot
        
        // Traditional timing
        uint256 traditionalAttestTime = EXECUTION_TIME + STATE_ROOT_TIME;
        
        // EIP-7862 timing (state root computed in parallel, using previous slot's result)
        uint256 delayedAttestTime = EXECUTION_TIME;
        
        // Verify EIP-7862 allows attestation within deadline
        assertTrue(delayedAttestTime < ATTESTATION_DEADLINE, "Delayed model meets deadline");
        
        // Traditional might miss deadline under load
        assertTrue(traditionalAttestTime > ATTESTATION_DEADLINE, "Traditional model at risk");
        
        // Time saved
        uint256 timeSaved = traditionalAttestTime - delayedAttestTime;
        assertEq(timeSaved, STATE_ROOT_TIME);
        
        emit log_named_uint("Time saved (seconds)", timeSaved);
    }

    function test_BALSynergy_ParallelComputation() public view {
        // Demonstrates how BAL enables parallel state root computation
        // Each accessed slot can be processed independently
        
        uint256 NUM_SLOTS = 100;
        bytes32[] memory slots = new bytes32[](NUM_SLOTS);
        bytes32[] memory values = new bytes32[](NUM_SLOTS);
        
        for (uint i = 0; i < NUM_SLOTS; i++) {
            slots[i] = keccak256(abi.encodePacked("slot", i));
            values[i] = bytes32(i);
        }
        
        // With BAL, all 100 slots known upfront
        // Can be processed in parallel (10 workers = 10x speedup)
        bytes32 root = dsr.computeStateRootWithBAL(slots, values);
        assertTrue(root != bytes32(0));
    }

    function testFuzz_ProcessBlock(bytes32 txRoot, address coinbase) public {
        vm.assume(coinbase != address(0));
        
        bytes32 prevStateRoot = dsr.getLastComputedStateRoot();
        
        dsr.processBlock(txRoot, coinbase);
        
        DelayedStateRoot.BlockHeader memory blk = dsr.getBlock(1);
        assertEq(blk.stateRoot, prevStateRoot);
        assertEq(blk.transactionsRoot, txRoot);
        assertEq(blk.coinbase, coinbase);
    }
}

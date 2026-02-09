// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/DelayedStateRoot.sol";

contract DelayedStateRootTest is Test {
    DelayedStateRoot public simulator;

    function setUp() public {
        simulator = new DelayedStateRoot();
    }

    function test_GenesisBlockExists() public view {
        assertEq(simulator.getBlockCount(), 1);
        
        DelayedStateRoot.BlockHeader memory genesis = simulator.getBlock(0);
        assertEq(genesis.blockNumber, 0);
        assertEq(genesis.stateRoot, keccak256("genesis_state"));
    }

    function test_TraditionalModel_WaitsForStateRoot() public {
        bytes32[] memory txHashes = new bytes32[](3);
        txHashes[0] = keccak256("tx1");
        txHashes[1] = keccak256("tx2");
        txHashes[2] = keccak256("tx3");

        // Simulate state root computation taking 150ms
        uint256 stateRootComputeTime = 150;
        
        simulator.simulateTraditionalBlock(txHashes, stateRootComputeTime);
        
        // Traditional model: validation time = state root compute + other validation
        // In this case: 150ms + 50ms = 200ms
        (uint256 traditionalMs,,) = simulator.compareTiming();
        assertEq(traditionalMs, 200);
        
        // Block count increased
        assertEq(simulator.getBlockCount(), 2);
    }

    function test_DelayedModel_NoWaitForStateRoot() public {
        bytes32[] memory txHashes = new bytes32[](3);
        txHashes[0] = keccak256("tx1");
        txHashes[1] = keccak256("tx2");
        txHashes[2] = keccak256("tx3");

        // Same state root computation time
        uint256 stateRootComputeTime = 150;
        
        simulator.simulateDelayedBlock(txHashes, stateRootComputeTime);
        
        // Delayed model: validation time = just other validation (state root already known)
        // In this case: 50ms (state root computed in parallel for next block)
        (, uint256 delayedMs,) = simulator.compareTiming();
        assertEq(delayedMs, 50);
        
        // Block count increased
        assertEq(simulator.getBlockCount(), 2);
    }

    function test_TimingSavings() public {
        bytes32[] memory txHashes = new bytes32[](5);
        for (uint256 i = 0; i < 5; i++) {
            txHashes[i] = keccak256(abi.encodePacked("tx", i));
        }

        // Simulate both models with 200ms state root computation
        uint256 stateRootComputeTime = 200;
        
        simulator.simulateTraditionalBlock(txHashes, stateRootComputeTime);
        simulator.simulateDelayedBlock(txHashes, stateRootComputeTime);
        
        (uint256 traditionalMs, uint256 delayedMs, uint256 savedMs) = simulator.compareTiming();
        
        // Should save the state root computation time
        assertEq(savedMs, 200); // 250ms - 50ms = 200ms saved
        assertTrue(delayedMs < traditionalMs);
        
        // Calculate percentage improvement
        uint256 improvementPct = (savedMs * 100) / traditionalMs;
        assertTrue(improvementPct >= 70); // Should be ~80% improvement in this scenario
        
        emit log_named_uint("Traditional validation time (ms)", traditionalMs);
        emit log_named_uint("Delayed validation time (ms)", delayedMs);
        emit log_named_uint("Time saved (ms)", savedMs);
        emit log_named_uint("Improvement (%)", improvementPct);
    }

    function test_DelayedModel_StateRootIsFromPreviousBlock() public {
        // Get initial state root
        bytes32 initialStateRoot = simulator.getLastStateRoot();
        
        bytes32[] memory txHashes = new bytes32[](2);
        txHashes[0] = keccak256("first_tx");
        txHashes[1] = keccak256("second_tx");

        // First delayed block
        bytes32 includedRoot1 = simulator.simulateDelayedBlock(txHashes, 100);
        
        // The included state root should be the genesis state root (previous block's post-state)
        assertEq(includedRoot1, initialStateRoot);
        
        // Get the new state root (computed for next block)
        bytes32 newStateRoot = simulator.getLastStateRoot();
        assertTrue(newStateRoot != initialStateRoot);
        
        // Second delayed block
        txHashes[0] = keccak256("third_tx");
        bytes32 includedRoot2 = simulator.simulateDelayedBlock(txHashes, 100);
        
        // The included state root should be the post-state of block 1 (computed after first block)
        assertEq(includedRoot2, newStateRoot);
    }

    function test_BALSynergySpeedup() public view {
        bytes32[] memory smallAccessList = new bytes32[](50);
        bytes32[] memory largeAccessList = new bytes32[](150);
        
        // Fill access lists
        for (uint256 i = 0; i < 50; i++) {
            smallAccessList[i] = bytes32(i);
        }
        for (uint256 i = 0; i < 150; i++) {
            largeAccessList[i] = bytes32(i);
        }
        
        // With 30% parallelization speedup
        uint256 smallListTime = simulator.simulateBALSynergy(smallAccessList, 30);
        uint256 largeListTime = simulator.simulateBALSynergy(largeAccessList, 30);
        
        // Base: 200ms, with 30% speedup: 140ms
        assertEq(smallListTime, 140);
        
        // Large list gets additional 20% speedup: 140 * 80% = 112ms
        assertEq(largeListTime, 112);
        
        assertTrue(largeListTime < smallListTime);
    }

    function test_MultipleBlockSequence() public {
        // Simulate a sequence of 5 blocks with delayed state roots
        bytes32 previousComputedRoot = simulator.getLastStateRoot();
        
        for (uint256 i = 0; i < 5; i++) {
            bytes32[] memory txHashes = new bytes32[](1);
            txHashes[0] = keccak256(abi.encodePacked("block", i));
            
            bytes32 includedRoot = simulator.simulateDelayedBlock(txHashes, 100);
            
            // Each block's state root should be the previous block's post-state
            assertEq(includedRoot, previousComputedRoot);
            
            // Update for next iteration
            previousComputedRoot = simulator.getLastStateRoot();
        }
        
        // Should have genesis + 5 blocks = 6 total
        assertEq(simulator.getBlockCount(), 6);
    }

    function test_RealisticScenario_12SecondSlot() public {
        // Simulate realistic Ethereum scenario
        // 12 second slot, ~200 transactions, state root computation takes ~300ms
        
        bytes32[] memory txHashes = new bytes32[](200);
        for (uint256 i = 0; i < 200; i++) {
            txHashes[i] = keccak256(abi.encodePacked(i));
        }
        
        // State root computation for 200 txs: ~300ms
        uint256 stateRootComputeTime = 300;
        
        simulator.simulateTraditionalBlock(txHashes, stateRootComputeTime);
        simulator.simulateDelayedBlock(txHashes, stateRootComputeTime);
        
        (uint256 traditionalMs, uint256 delayedMs, uint256 savedMs) = simulator.compareTiming();
        
        // Traditional: 300ms + 50ms = 350ms
        // Delayed: 50ms (state root already known)
        // Savings: 300ms
        
        emit log_named_uint("Realistic scenario - Traditional (ms)", traditionalMs);
        emit log_named_uint("Realistic scenario - Delayed (ms)", delayedMs);
        emit log_named_uint("Realistic scenario - Saved (ms)", savedMs);
        emit log_named_uint("Realistic scenario - Improvement (%)", (savedMs * 100) / traditionalMs);
        
        // In a 12-second (12000ms) slot, saving 300ms is significant
        // Especially during MEV auction where every millisecond counts
        uint256 slotMs = 12000;
        uint256 pctOfSlot = (savedMs * 100) / slotMs;
        emit log_named_uint("Savings as % of 12s slot", pctOfSlot); // ~2.5%
    }
}

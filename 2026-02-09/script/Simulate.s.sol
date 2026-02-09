// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/DelayedStateRoot.sol";

/**
 * @title SimulateScript
 * @notice Interactive simulation demonstrating EIP-7862 benefits
 * @dev Run with: forge script script/Simulate.s.sol -vvvv
 */
contract SimulateScript is Script {
    function run() public {
        console.log("=== EIP-7862: Delayed State Root Simulation ===");
        console.log("");
        
        DelayedStateRoot simulator = new DelayedStateRoot();
        
        // Scenario 1: Light block (few transactions)
        console.log("--- Scenario 1: Light Block (10 transactions) ---");
        simulateScenario(simulator, 10, 50, "Light");
        
        // Scenario 2: Medium block
        console.log("");
        console.log("--- Scenario 2: Medium Block (100 transactions) ---");
        simulateScenario(simulator, 100, 150, "Medium");
        
        // Scenario 3: Heavy block
        console.log("");
        console.log("--- Scenario 3: Heavy Block (500 transactions) ---");
        simulateScenario(simulator, 500, 400, "Heavy");
        
        // Scenario 4: MEV-intensive block during auction
        console.log("");
        console.log("--- Scenario 4: MEV Auction Scenario ---");
        console.log("During MEV auctions, builders need to compute state roots repeatedly");
        console.log("as they try different transaction orderings. With delayed roots,");
        console.log("this computation doesn't block the critical path.");
        console.log("");
        
        // Simulate multiple iterations during MEV auction
        uint256 iterations = 50; // 50 different orderings tried
        uint256 traditionalTotal = 0;
        uint256 delayedTotal = 0;
        
        for (uint256 i = 0; i < iterations; i++) {
            // Each iteration tries a different ordering
            traditionalTotal += 200; // Would need to recompute each time
            delayedTotal += 50;       // Just tx execution, state root computed once
        }
        
        console.log("MEV auction with 50 ordering attempts:");
        console.log("  Traditional total time: %s ms", traditionalTotal);
        console.log("  Delayed total time: %s ms", delayedTotal);
        console.log("  Time saved: %s ms", traditionalTotal - delayedTotal);
        
        // BAL synergy demonstration
        console.log("");
        console.log("--- EIP-7928 (Block Access Lists) Synergy ---");
        demonstrateBALSynergy(simulator);
        
        console.log("");
        console.log("=== Simulation Complete ===");
    }
    
    function simulateScenario(
        DelayedStateRoot simulator,
        uint256 txCount,
        uint256 stateRootTime,
        string memory name
    ) internal {
        bytes32[] memory txHashes = new bytes32[](txCount);
        for (uint256 i = 0; i < txCount; i++) {
            txHashes[i] = keccak256(abi.encodePacked(name, i));
        }
        
        simulator.simulateTraditionalBlock(txHashes, stateRootTime);
        simulator.simulateDelayedBlock(txHashes, stateRootTime);
        
        (uint256 traditionalMs, uint256 delayedMs, uint256 savedMs) = simulator.compareTiming();
        
        console.log("Traditional model: %s ms", traditionalMs);
        console.log("Delayed model: %s ms", delayedMs);
        console.log("Time saved: %s ms (%s%% improvement)", savedMs, (savedMs * 100) / traditionalMs);
    }
    
    function demonstrateBALSynergy(DelayedStateRoot simulator) internal view {
        console.log("With Block Access Lists, clients know which slots are touched.");
        console.log("This enables parallel state root computation:");
        console.log("");
        
        bytes32[] memory accessList = new bytes32[](200);
        for (uint256 i = 0; i < 200; i++) {
            accessList[i] = bytes32(i);
        }
        
        // Different parallelization levels
        uint256 noParallel = simulator.simulateBALSynergy(accessList, 0);
        uint256 lowParallel = simulator.simulateBALSynergy(accessList, 20);
        uint256 highParallel = simulator.simulateBALSynergy(accessList, 50);
        
        console.log("State root compute time (base: 200ms, 200 slots touched):");
        console.log("  No parallelization: %s ms", noParallel);
        console.log("  20%% parallelization: %s ms", lowParallel);
        console.log("  50%% parallelization: %s ms", highParallel);
    }
}

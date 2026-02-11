// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/StateGasSimulator.sol";
import "../src/GasCostCalculator.sol";

contract StateGasTest is Test {
    using GasCostCalculator for uint256;
    
    StateGasSimulator simulator;
    
    uint256 constant GAS_LIMIT_30M = 30_000_000;
    uint256 constant GAS_LIMIT_36M = 36_000_000;
    uint256 constant GAS_LIMIT_60M = 60_000_000;
    uint256 constant GAS_LIMIT_100M = 100_000_000;

    function setUp() public {
        simulator = new StateGasSimulator();
    }

    function test_CostPerStateByte_At30M() public pure {
        uint256 cpsb = GAS_LIMIT_30M.costPerStateByte();
        // At 30M, cost should be relatively low
        assertGt(cpsb, 0, "CPSB should be positive");
        console.log("CPSB at 30M gas limit:", cpsb);
    }

    function test_CostPerStateByte_At60M() public pure {
        uint256 cpsb = GAS_LIMIT_60M.costPerStateByte();
        uint256 cpsb30 = GAS_LIMIT_30M.costPerStateByte();
        // Higher gas limit = higher state costs to limit growth
        assertGt(cpsb, cpsb30, "CPSB should increase with gas limit");
        console.log("CPSB at 60M gas limit:", cpsb);
    }

    function test_CostPerStateByte_At100M() public pure {
        uint256 cpsb = GAS_LIMIT_100M.costPerStateByte();
        console.log("CPSB at 100M gas limit:", cpsb);
        
        // At 100M, SSTORE should cost significantly more
        uint256 sstoreCost = 32 * cpsb;
        console.log("SSTORE state gas at 100M:", sstoreCost);
    }

    function test_ReservoirModel_BasicInitialization() public {
        StateGasSimulator.TransactionParams memory params = StateGasSimulator.TransactionParams({
            txGas: 50_000_000,        // More than TX_MAX_GAS_LIMIT
            intrinsicRegular: 21000,  // Base tx cost
            intrinsicState: 0,        // No intrinsic state (EOA to EOA)
            blockGasLimit: GAS_LIMIT_60M
        });
        
        StateGasSimulator.GasState memory state = simulator.initializeGasState(params);
        
        // gasLeft should be capped at TX_MAX_GAS_LIMIT - intrinsicRegular
        assertEq(state.gasLeft, 30_000_000 - 21000, "gasLeft should be capped");
        
        // Excess goes to reservoir
        uint256 expectedReservoir = 50_000_000 - 21000 - state.gasLeft;
        assertEq(state.stateGasReservoir, expectedReservoir, "reservoir should hold excess");
        
        console.log("gasLeft:", state.gasLeft);
        console.log("stateGasReservoir:", state.stateGasReservoir);
    }

    function test_ReservoirModel_StateGasFromReservoir() public {
        // Setup: tx with gas exceeding TX_MAX_GAS_LIMIT
        StateGasSimulator.TransactionParams memory params = StateGasSimulator.TransactionParams({
            txGas: 40_000_000,
            intrinsicRegular: 21000,
            intrinsicState: 0,
            blockGasLimit: GAS_LIMIT_60M
        });
        
        StateGasSimulator.GasState memory state = simulator.initializeGasState(params);
        uint256 initialReservoir = state.stateGasReservoir;
        uint256 initialGasLeft = state.gasLeft;
        
        // Simulate SSTORE - state gas should come from reservoir
        state = simulator.simulateSSTORE(state, GAS_LIMIT_60M);
        
        // Reservoir should be reduced, gasLeft reduced only by regular gas
        assertLt(state.stateGasReservoir, initialReservoir, "reservoir should decrease");
        assertEq(state.gasLeft, initialGasLeft - 2900, "gasLeft reduced by regular only");
        
        console.log("After SSTORE:");
        console.log("  gasLeft:", state.gasLeft);
        console.log("  reservoir:", state.stateGasReservoir);
        console.log("  stateGasUsed:", state.stateGasUsed);
    }

    function test_ReservoirModel_LargeContractDeployment() public {
        // Deploy a 24KB contract (max size)
        uint256 codeLength = 24576;
        
        StateGasSimulator.TransactionParams memory params = StateGasSimulator.TransactionParams({
            txGas: 80_000_000,        // Large gas allowance
            intrinsicRegular: 21000,
            intrinsicState: 0,        // Simplified - ignoring intrinsic state for demo
            blockGasLimit: GAS_LIMIT_60M
        });
        
        StateGasSimulator.GasState memory state = simulator.initializeGasState(params);
        
        console.log("Before CREATE (24KB contract):");
        console.log("  gasLeft:", state.gasLeft);
        console.log("  reservoir:", state.stateGasReservoir);
        
        state = simulator.simulateCreate(state, GAS_LIMIT_60M, codeLength);
        
        console.log("After CREATE:");
        console.log("  gasLeft:", state.gasLeft);
        console.log("  reservoir:", state.stateGasReservoir);
        console.log("  stateGasUsed:", state.stateGasUsed);
        console.log("  regularGasUsed:", state.regularGasUsed);
        
        // Key insight: large state gas doesn't deplete regular gasLeft much
        // This enables large contract deployments
        uint256 blockGasUsed = simulator.totalGasUsed(state);
        console.log("Block gas_used (max dimension):", blockGasUsed);
    }

    function test_BlockLevelAccounting() public {
        // Simulate multiple transactions in a block
        uint256 blockRegularGas = 0;
        uint256 blockStateGas = 0;
        
        // TX 1: Simple transfer
        StateGasSimulator.TransactionParams memory tx1 = StateGasSimulator.TransactionParams({
            txGas: 21000,
            intrinsicRegular: 21000,
            intrinsicState: 0,
            blockGasLimit: GAS_LIMIT_60M
        });
        StateGasSimulator.GasState memory state1 = simulator.initializeGasState(tx1);
        blockRegularGas += state1.regularGasUsed;
        blockStateGas += state1.stateGasUsed;
        
        // TX 2: Contract deployment (10KB)
        StateGasSimulator.TransactionParams memory tx2 = StateGasSimulator.TransactionParams({
            txGas: 50_000_000,
            intrinsicRegular: 21000,
            intrinsicState: 0,
            blockGasLimit: GAS_LIMIT_60M
        });
        StateGasSimulator.GasState memory state2 = simulator.initializeGasState(tx2);
        state2 = simulator.simulateCreate(state2, GAS_LIMIT_60M, 10000);
        blockRegularGas += state2.regularGasUsed;
        blockStateGas += state2.stateGasUsed;
        
        // TX 3: 100 SSTORE operations
        StateGasSimulator.TransactionParams memory tx3 = StateGasSimulator.TransactionParams({
            txGas: 50_000_000,
            intrinsicRegular: 21000,
            intrinsicState: 0,
            blockGasLimit: GAS_LIMIT_60M
        });
        StateGasSimulator.GasState memory state3 = simulator.initializeGasState(tx3);
        for (uint i = 0; i < 100; i++) {
            state3 = simulator.simulateSSTORE(state3, GAS_LIMIT_60M);
        }
        blockRegularGas += state3.regularGasUsed;
        blockStateGas += state3.stateGasUsed;
        
        console.log("\nBlock Summary:");
        console.log("  Total regular gas:", blockRegularGas);
        console.log("  Total state gas:", blockStateGas);
        console.log("  Block gas_used (max):", blockRegularGas > blockStateGas ? blockRegularGas : blockStateGas);
        
        // The block is "full" when either dimension hits the limit
        // This naturally rate-limits state growth
    }

    function test_GasOpcode_ReturnsOnlyGasLeft() public {
        StateGasSimulator.TransactionParams memory params = StateGasSimulator.TransactionParams({
            txGas: 50_000_000,
            intrinsicRegular: 21000,
            intrinsicState: 0,
            blockGasLimit: GAS_LIMIT_60M
        });
        
        StateGasSimulator.GasState memory state = simulator.initializeGasState(params);
        
        // GAS opcode should NOT include reservoir
        uint256 gasReported = simulator.gasOpcode(state);
        assertEq(gasReported, state.gasLeft, "GAS should return gasLeft only");
        assertLt(gasReported, params.txGas - 21000, "GAS should be less than total execution gas");
        
        console.log("GAS opcode returns:", gasReported);
        console.log("Actual execution gas:", params.txGas - 21000);
        console.log("Difference (hidden in reservoir):", state.stateGasReservoir);
    }

    function test_StateGrowthComparison() public pure {
        // Compare state costs across different gas limits
        console.log("\n=== State Cost Comparison ===\n");
        
        uint256[] memory limits = new uint256[](4);
        limits[0] = GAS_LIMIT_30M;
        limits[1] = GAS_LIMIT_36M;
        limits[2] = GAS_LIMIT_60M;
        limits[3] = GAS_LIMIT_100M;
        
        string[4] memory names = ["30M", "36M", "60M", "100M"];
        
        for (uint i = 0; i < 4; i++) {
            uint256 cpsb = limits[i].costPerStateByte();
            (uint256 createGas, uint256 sstoreGas,) = limits[i].stateOperationCosts();
            
            console.log("Gas Limit:", names[i]);
            console.log("  cost_per_state_byte:", cpsb);
            console.log("  CREATE state gas:", createGas);
            console.log("  SSTORE state gas:", sstoreGas);
            console.log("");
        }
    }
}

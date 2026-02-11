// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./GasCostCalculator.sol";

/// @title EIP-8037 State Gas Reservoir Simulator
/// @notice Simulates the transaction-level gas accounting with reservoir model
/// @dev Demonstrates how state gas and regular gas are metered separately
contract StateGasSimulator {
    using GasCostCalculator for uint256;

    /// @notice Maximum gas limit per transaction (EIP-7825)
    uint256 constant TX_MAX_GAS_LIMIT = 30_000_000;

    struct GasState {
        uint256 gasLeft;           // Regular gas remaining
        uint256 stateGasReservoir; // Excess gas for state operations
        uint256 regularGasUsed;    // Tracking for block accounting
        uint256 stateGasUsed;      // Tracking for block accounting
    }

    struct TransactionParams {
        uint256 txGas;             // Total gas provided
        uint256 intrinsicRegular;  // Base tx cost, calldata, etc
        uint256 intrinsicState;    // Intrinsic state creation costs
        uint256 blockGasLimit;     // Current block gas limit
    }

    event GasCharged(string operation, uint256 regularGas, uint256 stateGas);
    event ReservoirUsed(uint256 amount, uint256 remaining);

    /// @notice Initialize gas state for a transaction (reservoir model)
    /// @param params Transaction parameters
    /// @return state Initial gas state
    function initializeGasState(TransactionParams memory params) 
        public 
        pure 
        returns (GasState memory state) 
    {
        uint256 intrinsicGas = params.intrinsicRegular + params.intrinsicState;
        require(params.txGas >= intrinsicGas, "insufficient gas for intrinsic");
        
        uint256 executionGas = params.txGas - intrinsicGas;
        uint256 regularGasBudget = TX_MAX_GAS_LIMIT - params.intrinsicRegular;
        
        // Gas goes to gasLeft up to budget, rest to reservoir
        if (executionGas <= regularGasBudget) {
            state.gasLeft = executionGas;
            state.stateGasReservoir = 0;
        } else {
            state.gasLeft = regularGasBudget;
            state.stateGasReservoir = executionGas - regularGasBudget;
        }
        
        // Track intrinsic costs
        state.regularGasUsed = params.intrinsicRegular;
        state.stateGasUsed = params.intrinsicState;
    }

    /// @notice Charge regular gas (computation, memory, etc)
    function chargeRegularGas(GasState memory state, uint256 amount) 
        public 
        pure 
        returns (GasState memory) 
    {
        require(state.gasLeft >= amount, "out of gas (regular)");
        state.gasLeft -= amount;
        state.regularGasUsed += amount;
        return state;
    }

    /// @notice Charge state gas (reservoir-first model)
    /// @dev Deducts from reservoir first, then gasLeft when exhausted
    function chargeStateGas(GasState memory state, uint256 amount)
        public
        pure
        returns (GasState memory)
    {
        if (state.stateGasReservoir >= amount) {
            // Fully covered by reservoir
            state.stateGasReservoir -= amount;
        } else {
            // Partially from reservoir, rest from gasLeft
            uint256 fromGasLeft = amount - state.stateGasReservoir;
            state.stateGasReservoir = 0;
            require(state.gasLeft >= fromGasLeft, "out of gas (state)");
            state.gasLeft -= fromGasLeft;
        }
        state.stateGasUsed += amount;
        return state;
    }

    /// @notice Simulate SSTORE to a new slot
    function simulateSSTORE(
        GasState memory state, 
        uint256 blockGasLimit
    ) public pure returns (GasState memory) {
        (,uint256 sstoreStateGas,) = blockGasLimit.stateOperationCosts();
        
        // Regular gas: 2,900 (GAS_STORAGE_UPDATE - GAS_COLD_SLOAD)
        uint256 regularGas = 2900;
        
        state = chargeRegularGas(state, regularGas);
        state = chargeStateGas(state, sstoreStateGas);
        
        return state;
    }

    /// @notice Simulate contract deployment
    function simulateCreate(
        GasState memory state,
        uint256 blockGasLimit,
        uint256 codeLength
    ) public pure returns (GasState memory) {
        (uint256 createStateGas,,) = blockGasLimit.stateOperationCosts();
        (uint256 codeStateGas, uint256 codeRegularGas) = blockGasLimit.codeDeploymentCost(codeLength);
        
        // Regular gas: 9,000 (GAS_CALL_VALUE equivalent) + code hashing
        uint256 regularGas = 9000 + codeRegularGas;
        uint256 stateGas = createStateGas + codeStateGas;
        
        state = chargeRegularGas(state, regularGas);
        state = chargeStateGas(state, stateGas);
        
        return state;
    }

    /// @notice Calculate total gas used for block accounting
    function totalGasUsed(GasState memory state) public pure returns (uint256) {
        // Block gas_used = max(regular_gas_used, state_gas_used)
        return state.regularGasUsed > state.stateGasUsed 
            ? state.regularGasUsed 
            : state.stateGasUsed;
    }

    /// @notice Simulate the GAS opcode (returns gasLeft only, not reservoir)
    function gasOpcode(GasState memory state) public pure returns (uint256) {
        return state.gasLeft;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./FrameTypes.sol";

/// @title MockApprove - Simulates EIP-8141 APPROVE Opcode Behavior
/// @notice Until APPROVE (0xaa) is natively available, this contract simulates its behavior
/// @dev In production EIP-8141, APPROVE would be a native opcode that:
///      1. Validates caller == frame.target
///      2. Updates transaction-scoped approval state
///      3. Handles nonce increment and fee collection for PAYMENT scope
///      4. Returns from the current context

/// @notice Tracks approval state for a transaction
/// @dev In real EIP-8141, this would be transaction-scoped state managed by the EVM
struct ApprovalState {
    bool senderApproved;    // Execution approved by sender
    bool payerApproved;     // Payment approved
    address payer;          // Who will pay for gas
    uint256 collectedFees;  // Fees collected from payer
}

/// @title IFrameValidator
/// @notice Interface that accounts must implement for VERIFY mode frames
interface IFrameValidator {
    /// @notice Validate a frame transaction and call approve
    /// @param sigHash The signature hash of the transaction
    /// @param signature The signature to verify
    /// @param scope What to approve (execution, payment, or both)
    /// @return success True if validation passed
    function validateFrame(
        bytes32 sigHash,
        bytes calldata signature,
        ApprovalScope scope
    ) external returns (bool success);
}

/// @title ApproveSimulator
/// @notice Simulates APPROVE opcode behavior for testing EIP-8141 patterns
/// @dev This is a workaround until the native opcode exists
contract ApproveSimulator {
    /// @notice Emitted when APPROVE is called
    event Approved(
        address indexed caller,
        address indexed target,
        ApprovalScope scope,
        bytes returnData
    );

    /// @notice Emitted when fees are collected
    event FeesCollected(address indexed payer, uint256 amount);

    /// @notice Emitted when nonce is incremented
    event NonceIncremented(address indexed account, uint256 newNonce);

    /// @notice Current approval state (would be transaction-scoped in real EIP-8141)
    ApprovalState public approvalState;

    /// @notice Simulated nonces (would be account state in real implementation)
    mapping(address => uint256) public nonces;

    /// @notice Error when APPROVE is called by wrong address
    error CallerNotTarget(address caller, address target);

    /// @notice Error when approval was already set
    error AlreadyApproved(ApprovalScope scope);

    /// @notice Error when sender approval is required but not set
    error SenderNotApproved();

    /// @notice Error when caller is not the sender for execution approval
    error CallerNotSender(address caller, address sender);

    /// @notice Error when payer has insufficient balance
    error InsufficientBalance(address payer, uint256 required, uint256 available);

    /// @notice Reset approval state (call at start of new transaction simulation)
    function resetApprovalState() external {
        delete approvalState;
    }

    /// @notice Simulate the APPROVE opcode
    /// @param target The frame target (must equal msg.sender in real APPROVE)
    /// @param sender The transaction sender
    /// @param scope What to approve
    /// @param returnData Data to return (like RETURN opcode)
    /// @param totalGasCost Total gas cost for PAYMENT scope
    function approve(
        address target,
        address sender,
        ApprovalScope scope,
        bytes calldata returnData,
        uint256 totalGasCost
    ) external {
        // In real APPROVE: revert if CALLER != frame.target
        // Here we simulate by requiring msg.sender == target
        if (msg.sender != target) {
            revert CallerNotTarget(msg.sender, target);
        }

        if (scope == ApprovalScope.EXECUTION) {
            // Scope 0x0: Approve execution
            if (approvalState.senderApproved) {
                revert AlreadyApproved(scope);
            }
            if (msg.sender != sender) {
                revert CallerNotSender(msg.sender, sender);
            }
            approvalState.senderApproved = true;
        } else if (scope == ApprovalScope.PAYMENT) {
            // Scope 0x1: Approve payment
            if (approvalState.payerApproved) {
                revert AlreadyApproved(scope);
            }
            if (!approvalState.senderApproved) {
                revert SenderNotApproved();
            }
            _collectFees(target, totalGasCost);
            _incrementNonce(sender);
            approvalState.payerApproved = true;
            approvalState.payer = target;
        } else {
            // Scope 0x2: Approve both
            if (approvalState.senderApproved || approvalState.payerApproved) {
                revert AlreadyApproved(scope);
            }
            if (msg.sender != sender) {
                revert CallerNotSender(msg.sender, sender);
            }
            _collectFees(target, totalGasCost);
            _incrementNonce(sender);
            approvalState.senderApproved = true;
            approvalState.payerApproved = true;
            approvalState.payer = target;
        }

        emit Approved(msg.sender, target, scope, returnData);
    }

    /// @notice Collect fees from payer (simplified)
    function _collectFees(address payer, uint256 amount) internal {
        if (payer.balance < amount) {
            revert InsufficientBalance(payer, amount, payer.balance);
        }
        approvalState.collectedFees = amount;
        emit FeesCollected(payer, amount);
    }

    /// @notice Increment account nonce
    function _incrementNonce(address account) internal {
        nonces[account]++;
        emit NonceIncremented(account, nonces[account]);
    }

    /// @notice Check if transaction is fully approved
    function isFullyApproved() external view returns (bool) {
        return approvalState.senderApproved && approvalState.payerApproved;
    }
}

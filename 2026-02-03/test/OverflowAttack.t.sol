// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/VulnerableBondingCurve.sol";
import "../src/SafeBondingCurve.sol";
import "../src/AttackSimulation.sol";

/**
 * @title OverflowAttackTest
 * @notice Test suite proving the overflow vulnerability and fix
 */
contract OverflowAttackTest is Test {
    VulnerableBondingCurve vulnerable;
    SafeBondingCurve safe;
    AttackSimulation attacker;
    
    address alice = address(0x1);
    address bob = address(0x2);
    address eve = address(0xEVE);  // Attacker
    
    function setUp() public {
        // Deploy contracts
        vulnerable = new VulnerableBondingCurve();
        safe = new SafeBondingCurve();
        
        // Seed the vulnerable contract with reserves (simulating real TrueBit)
        vm.deal(address(this), 10000 ether);
        (bool success,) = address(vulnerable).call{value: 10000 ether}("");
        require(success, "Failed to seed reserves");
        
        // Legitimate users mint some tokens to establish price
        vm.deal(alice, 100 ether);
        vm.prank(alice);
        vulnerable.mint{value: 10 ether}(1000000 * 1e18);  // 1M tokens
        
        vm.deal(bob, 100 ether);
        vm.prank(bob);
        vulnerable.mint{value: 20 ether}(2000000 * 1e18);  // 2M tokens
        
        // Attacker deploys attack contract
        vm.prank(eve);
        attacker = new AttackSimulation(address(vulnerable));
        vm.deal(eve, 1 ether);
    }
    
    /**
     * @notice Demonstrate the overflow in getPurchasePrice
     */
    function test_OverflowInPriceCalculation() public view {
        // Normal amount - reasonable price
        uint256 normalAmount = 1000 * 1e18;
        uint256 normalPrice = vulnerable.getPurchasePrice(normalAmount);
        console.log("Normal amount (1000 tokens):", normalAmount);
        console.log("Normal price:", normalPrice);
        
        // Massive amount - price wraps to near zero
        uint256 massiveAmount = type(uint256).max - 1e30;
        uint256 brokenPrice = vulnerable.getPurchasePrice(massiveAmount);
        console.log("Massive amount:", massiveAmount);
        console.log("Broken price (should be astronomical, is tiny):", brokenPrice);
        
        // The vulnerability: massive tokens cost less than small amounts
        assertTrue(brokenPrice < normalPrice, "Overflow should make price tiny");
    }
    
    /**
     * @notice Full attack demonstration
     */
    function test_FullAttack() public {
        uint256 reservesBefore = vulnerable.reserveBalance();
        console.log("Reserves before attack:", reservesBefore / 1e18, "ETH");
        console.log("Attacker balance before:", eve.balance / 1e18, "ETH");
        
        // Execute attack
        vm.prank(eve);
        attacker.attack{value: 0.1 ether}();
        
        uint256 reservesAfter = vulnerable.reserveBalance();
        uint256 attackerBalance = eve.balance;
        
        console.log("Reserves after attack:", reservesAfter / 1e18, "ETH");
        console.log("Attacker balance after:", attackerBalance / 1e18, "ETH");
        console.log("ETH extracted:", (reservesBefore - reservesAfter) / 1e18, "ETH");
        
        // Attacker should have profited
        assertTrue(attackerBalance > 1 ether, "Attacker should profit");
    }
    
    /**
     * @notice Safe contract rejects overflow attempts
     */
    function test_SafeContractRejectsOverflow() public {
        // Seed safe contract
        (bool success,) = address(safe).call{value: 100 ether}("");
        require(success);
        
        // Try massive amount - should revert
        uint256 massiveAmount = type(uint256).max - 1e30;
        
        vm.expectRevert();  // Expects revert due to amount check
        safe.getPurchasePrice(massiveAmount);
    }
    
    /**
     * @notice Safe contract enforces supply cap
     */
    function test_SafeContractEnforcesSupplyCap() public {
        (bool success,) = address(safe).call{value: 1000 ether}("");
        require(success);
        
        // Try to exceed max supply
        uint256 overCapAmount = safe.MAX_SUPPLY() + 1;
        
        vm.expectRevert();
        safe.getPurchasePrice(overCapAmount);
    }
    
    /**
     * @notice Compare safe vs vulnerable for edge cases
     */
    function test_EdgeCaseComparison() public view {
        uint256[] memory testAmounts = new uint256[](5);
        testAmounts[0] = 1e18;           // 1 token
        testAmounts[1] = 1000 * 1e18;    // 1000 tokens
        testAmounts[2] = 1e24;           // 1 million tokens
        testAmounts[3] = 1e27;           // 1 billion tokens
        testAmounts[4] = type(uint256).max / 2;  // Overflow territory
        
        console.log("\n--- Price Comparison ---");
        
        for (uint256 i = 0; i < testAmounts.length; i++) {
            uint256 amount = testAmounts[i];
            uint256 vulnPrice = vulnerable.getPurchasePrice(amount);
            
            console.log("Amount:", amount);
            console.log("Vulnerable price:", vulnPrice);
            
            // Safe contract should revert for huge amounts
            if (amount > safe.MAX_MINT_AMOUNT()) {
                console.log("Safe: REVERTS (too large)");
            } else {
                uint256 safePrice = safe.getPurchasePrice(amount);
                console.log("Safe price:", safePrice);
            }
            console.log("---");
        }
    }
    
    /**
     * @notice Fuzz test to find overflow boundaries
     */
    function testFuzz_FindOverflowBoundary(uint256 amount) public view {
        // Bound to interesting range
        amount = bound(amount, 1e30, type(uint256).max);
        
        uint256 price = vulnerable.getPurchasePrice(amount);
        uint256 normalPrice = vulnerable.getPurchasePrice(1e24);  // 1M tokens baseline
        
        // Log suspicious cases where huge amounts cost less than normal
        if (price < normalPrice) {
            console.log("OVERFLOW FOUND at amount:", amount);
            console.log("Price:", price);
            console.log("vs normal price:", normalPrice);
        }
    }
}

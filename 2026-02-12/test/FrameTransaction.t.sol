// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/FrameTypes.sol";
import "../src/MockApprove.sol";
import "../src/FrameAccount.sol";

/// @title FrameTransactionTest
/// @notice Tests for EIP-8141 Frame Transaction patterns
contract FrameTransactionTest is Test {
    ApproveSimulator public approveSimulator;
    FrameAccountFactory public factory;
    FrameAccount public account;

    // Test accounts
    uint256 ownerKey = 0x1234;
    address owner;
    uint256 coSignerKey = 0x5678;
    address coSigner;

    function setUp() public {
        owner = vm.addr(ownerKey);
        coSigner = vm.addr(coSignerKey);

        // Deploy infrastructure
        approveSimulator = new ApproveSimulator();
        factory = new FrameAccountFactory(address(approveSimulator));

        // Create account
        address accountAddr = factory.createAccount(owner, bytes32(0));
        account = FrameAccount(payable(accountAddr));

        // Fund account for gas simulation
        vm.deal(address(account), 10 ether);
    }

    /// @notice Test account deployment
    function test_AccountDeployment() public view {
        assertEq(account.owner(), owner);
        assertEq(account.threshold(), 1);
        assertEq(address(account).balance, 10 ether);
    }

    /// @notice Test ECDSA signature validation in VERIFY mode frame
    function test_ECDSAValidation() public {
        // Reset approval state for new transaction
        approveSimulator.resetApprovalState();

        // Create signature hash (would come from transaction encoding)
        bytes32 sigHash = keccak256("test transaction");

        // Sign with owner key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, sigHash);

        // Encode signature: type byte + r + s + v
        bytes memory signature = abi.encodePacked(
            uint8(0x00), // ECDSA type
            r,
            s,
            v
        );

        // Simulate VERIFY mode frame execution
        vm.prank(address(account));
        bool success = account.validateFrame(
            sigHash,
            signature,
            ApprovalScope.EXECUTION_PAYMENT // Scope 0x2: approve both
        );

        assertTrue(success, "Validation should succeed");
        assertTrue(approveSimulator.isFullyApproved(), "Should be fully approved");
    }

    /// @notice Test multi-sig validation
    function test_MultiSigValidation() public {
        // Configure multi-sig
        vm.prank(owner);
        account.setMultiSig(coSigner, 2);

        // Reset approval state
        approveSimulator.resetApprovalState();

        bytes32 sigHash = keccak256("multisig transaction");

        // Sign with both keys
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(ownerKey, sigHash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(coSignerKey, sigHash);

        // Encode multi-sig: type byte + sig1 + sig2
        bytes memory signature = abi.encodePacked(
            uint8(0x02), // MultiSig type
            r1, s1, v1,  // Owner signature
            r2, s2, v2   // CoSigner signature
        );

        vm.prank(address(account));
        bool success = account.validateFrame(
            sigHash,
            signature,
            ApprovalScope.EXECUTION_PAYMENT
        );

        assertTrue(success, "Multi-sig validation should succeed");
    }

    /// @notice Test invalid signature rejection
    function test_InvalidSignatureRejected() public {
        approveSimulator.resetApprovalState();

        bytes32 sigHash = keccak256("test transaction");

        // Sign with wrong key
        uint256 wrongKey = 0x9999;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongKey, sigHash);

        bytes memory signature = abi.encodePacked(uint8(0x00), r, s, v);

        vm.prank(address(account));
        bool success = account.validateFrame(
            sigHash,
            signature,
            ApprovalScope.EXECUTION_PAYMENT
        );

        assertFalse(success, "Should reject invalid signature");
        assertFalse(approveSimulator.isFullyApproved(), "Should not be approved");
    }

    /// @notice Test frame transaction structure encoding
    function test_FrameTransactionEncoding() public pure {
        // Build a frame transaction
        Frame[] memory frames = new Frame[](2);

        // Frame 0: VERIFY mode for validation
        frames[0] = Frame({
            mode: FrameMode.VERIFY,
            target: address(0x1234),
            gasLimit: 50000,
            data: hex"deadbeef" // Signature data
        });

        // Frame 1: SENDER mode for actual execution
        frames[1] = Frame({
            mode: FrameMode.SENDER,
            target: address(0x5678),
            gasLimit: 100000,
            data: abi.encodeWithSignature("transfer(address,uint256)", address(0x9abc), 1 ether)
        });

        FrameTransaction memory tx = FrameTransaction({
            chainId: 1,
            nonce: 0,
            sender: address(0x1234),
            frames: frames,
            maxPriorityFeePerGas: 1 gwei,
            maxFeePerGas: 100 gwei,
            maxFeePerBlobGas: 0,
            blobVersionedHashes: new bytes32[](0)
        });

        // Verify structure
        assertEq(tx.frames.length, 2);
        assertEq(uint8(tx.frames[0].mode), uint8(FrameMode.VERIFY));
        assertEq(uint8(tx.frames[1].mode), uint8(FrameMode.SENDER));
    }

    /// @notice Test approval state machine: execution must come before payment
    function test_ApprovalOrdering() public {
        approveSimulator.resetApprovalState();

        // Try to approve payment before execution (should fail)
        vm.prank(address(account));
        vm.expectRevert(ApproveSimulator.SenderNotApproved.selector);
        approveSimulator.approve(
            address(account),
            address(account),
            ApprovalScope.PAYMENT,
            "",
            100000
        );
    }

    /// @notice Test separate execution and payment approval
    function test_SeparateApprovals() public {
        approveSimulator.resetApprovalState();

        // First: approve execution
        vm.prank(address(account));
        approveSimulator.approve(
            address(account),
            address(account),
            ApprovalScope.EXECUTION,
            "",
            0
        );

        (bool senderApproved, bool payerApproved,,) = approveSimulator.approvalState();
        assertTrue(senderApproved, "Sender should be approved");
        assertFalse(payerApproved, "Payer should not yet be approved");

        // Second: approve payment
        vm.prank(address(account));
        approveSimulator.approve(
            address(account),
            address(account),
            ApprovalScope.PAYMENT,
            "",
            100000
        );

        assertTrue(approveSimulator.isFullyApproved(), "Should be fully approved");
    }

    /// @notice Test double approval rejection
    function test_DoubleApprovalRejected() public {
        approveSimulator.resetApprovalState();

        // Approve execution
        vm.prank(address(account));
        approveSimulator.approve(
            address(account),
            address(account),
            ApprovalScope.EXECUTION,
            "",
            0
        );

        // Try to approve execution again
        vm.prank(address(account));
        vm.expectRevert(
            abi.encodeWithSelector(
                ApproveSimulator.AlreadyApproved.selector,
                ApprovalScope.EXECUTION
            )
        );
        approveSimulator.approve(
            address(account),
            address(account),
            ApprovalScope.EXECUTION,
            "",
            0
        );
    }

    /// @notice Test account execution via SENDER mode pattern
    function test_SenderModeExecution() public {
        // Create a target contract to call
        Counter counter = new Counter();

        // Simulate SENDER mode: account executes on behalf of itself
        vm.prank(address(account));
        account.execute(
            address(counter),
            0,
            abi.encodeWithSignature("increment()")
        );

        assertEq(counter.count(), 1, "Counter should be incremented");
    }

    /// @notice Test gas estimation for frame intrinsic cost
    function test_FrameIntrinsicCost() public pure {
        assertEq(FrameConstants.FRAME_TX_INTRINSIC_COST, 15000);
        assertEq(FrameConstants.MAX_FRAMES, 1000);
        assertEq(FrameConstants.ENTRY_POINT, address(0xaa));
    }
}

/// @notice Simple counter for testing execution
contract Counter {
    uint256 public count;

    function increment() external {
        count++;
    }
}

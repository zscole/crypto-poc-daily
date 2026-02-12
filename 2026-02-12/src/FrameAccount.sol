// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./FrameTypes.sol";
import "./MockApprove.sol";

/// @title FrameAccount - EIP-8141 Compatible Smart Account
/// @notice Implements account abstraction using Frame Transaction validation pattern
/// @dev This account supports:
///      - ECDSA signatures (legacy compatibility)
///      - Schnorr signatures (placeholder for PQ transition)
///      - Multi-signature validation
///      - Delegated payment (someone else pays gas)

contract FrameAccount is IFrameValidator {
    /// @notice Account owner's public key (ECDSA)
    address public owner;

    /// @notice Optional co-signer for multi-sig
    address public coSigner;

    /// @notice Threshold for multi-sig (1 = single sig, 2 = both required)
    uint8 public threshold;

    /// @notice Reference to approve simulator (would be native in EIP-8141)
    ApproveSimulator public approveSimulator;

    /// @notice Signature type identifiers
    uint8 constant SIG_TYPE_ECDSA = 0x00;
    uint8 constant SIG_TYPE_SCHNORR = 0x01;
    uint8 constant SIG_TYPE_MULTISIG = 0x02;

    /// @notice Emitted on successful validation
    event ValidationSucceeded(bytes32 indexed sigHash, ApprovalScope scope);

    /// @notice Emitted on failed validation
    event ValidationFailed(bytes32 indexed sigHash, string reason);

    /// @notice Emitted when owner is changed
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    error InvalidSignature();
    error InvalidSignatureType(uint8 sigType);
    error NotOwner();
    error NotAuthorized();

    constructor(address _owner, address _approveSimulator) {
        owner = _owner;
        threshold = 1;
        approveSimulator = ApproveSimulator(_approveSimulator);
    }

    /// @notice Configure multi-sig
    /// @param _coSigner Address of co-signer
    /// @param _threshold Number of signatures required (1 or 2)
    function setMultiSig(address _coSigner, uint8 _threshold) external {
        if (msg.sender != owner && msg.sender != address(this)) {
            revert NotOwner();
        }
        coSigner = _coSigner;
        threshold = _threshold;
    }

    /// @notice Validate a frame and call APPROVE
    /// @dev This is called during VERIFY mode frame execution
    /// @param sigHash Transaction signature hash
    /// @param signature Encoded signature (type byte + signature data)
    /// @param scope What to approve
    /// @return success True if validation passed
    function validateFrame(
        bytes32 sigHash,
        bytes calldata signature,
        ApprovalScope scope
    ) external override returns (bool success) {
        // Extract signature type from first byte
        if (signature.length < 1) {
            emit ValidationFailed(sigHash, "Empty signature");
            return false;
        }

        uint8 sigType = uint8(signature[0]);
        bytes calldata sigData = signature[1:];

        bool valid;
        if (sigType == SIG_TYPE_ECDSA) {
            valid = _validateECDSA(sigHash, sigData);
        } else if (sigType == SIG_TYPE_SCHNORR) {
            valid = _validateSchnorr(sigHash, sigData);
        } else if (sigType == SIG_TYPE_MULTISIG) {
            valid = _validateMultiSig(sigHash, sigData);
        } else {
            emit ValidationFailed(sigHash, "Unknown signature type");
            return false;
        }

        if (!valid) {
            emit ValidationFailed(sigHash, "Signature verification failed");
            return false;
        }

        // Call APPROVE through simulator
        // In real EIP-8141, this would be the native APPROVE opcode
        uint256 gasCost = 100000; // Simplified gas estimation
        approveSimulator.approve(
            address(this), // target
            address(this), // sender (self-sponsored)
            scope,
            "", // return data
            gasCost
        );

        emit ValidationSucceeded(sigHash, scope);
        return true;
    }

    /// @notice Validate ECDSA signature
    function _validateECDSA(bytes32 hash, bytes calldata sig) internal view returns (bool) {
        if (sig.length != 65) return false;

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := calldataload(sig.offset)
            s := calldataload(add(sig.offset, 32))
            v := byte(0, calldataload(add(sig.offset, 64)))
        }

        // Normalize v
        if (v < 27) v += 27;

        address recovered = ecrecover(hash, v, r, s);
        return recovered == owner;
    }

    /// @notice Validate Schnorr signature (placeholder for PQ schemes)
    /// @dev In production, this would implement actual Schnorr or a PQ scheme
    function _validateSchnorr(bytes32 hash, bytes calldata sig) internal view returns (bool) {
        // Placeholder: In real implementation, this would verify a Schnorr signature
        // For POC, we just check the hash matches expected pattern
        if (sig.length < 64) return false;

        // Simulated verification (would be real crypto in production)
        bytes32 expectedR = keccak256(abi.encodePacked(hash, owner, "schnorr"));
        bytes32 providedR;
        assembly {
            providedR := calldataload(sig.offset)
        }

        return providedR == expectedR;
    }

    /// @notice Validate multi-signature
    function _validateMultiSig(bytes32 hash, bytes calldata sig) internal view returns (bool) {
        if (threshold == 1) {
            // Single sig mode, validate owner signature
            return _validateECDSA(hash, sig);
        }

        // threshold == 2: Require both owner and coSigner
        if (sig.length != 130) return false; // Two 65-byte signatures

        // First signature from owner
        bytes calldata sig1 = sig[0:65];
        // Second signature from coSigner
        bytes calldata sig2 = sig[65:130];

        bool ownerValid = _validateECDSAWith(hash, sig1, owner);
        bool coSignerValid = _validateECDSAWith(hash, sig2, coSigner);

        return ownerValid && coSignerValid;
    }

    /// @notice Validate ECDSA against specific signer
    function _validateECDSAWith(
        bytes32 hash,
        bytes calldata sig,
        address expectedSigner
    ) internal pure returns (bool) {
        if (sig.length != 65) return false;

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := calldataload(sig.offset)
            s := calldataload(add(sig.offset, 32))
            v := byte(0, calldataload(add(sig.offset, 64)))
        }

        if (v < 27) v += 27;

        address recovered = ecrecover(hash, v, r, s);
        return recovered == expectedSigner;
    }

    /// @notice Execute arbitrary calls (for SENDER mode frames)
    /// @dev Only callable by the account itself or authorized frame execution
    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) external payable returns (bytes memory) {
        if (msg.sender != address(this) && msg.sender != owner) {
            // In EIP-8141, this would check if we're in SENDER mode frame
            revert NotAuthorized();
        }

        (bool success, bytes memory result) = target.call{value: value}(data);
        require(success, "Execution failed");
        return result;
    }

    /// @notice Receive ETH
    receive() external payable {}
}

/// @title FrameAccountFactory
/// @notice Factory for deploying FrameAccount instances
contract FrameAccountFactory {
    event AccountCreated(address indexed account, address indexed owner);

    ApproveSimulator public immutable approveSimulator;

    constructor(address _approveSimulator) {
        approveSimulator = ApproveSimulator(_approveSimulator);
    }

    /// @notice Deploy a new FrameAccount
    /// @param owner Initial owner address
    /// @param salt Salt for CREATE2
    function createAccount(address owner, bytes32 salt) external returns (address) {
        address account = address(
            new FrameAccount{salt: salt}(owner, address(approveSimulator))
        );
        emit AccountCreated(account, owner);
        return account;
    }

    /// @notice Compute account address before deployment
    function getAddress(address owner, bytes32 salt) external view returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(
                    abi.encodePacked(
                        type(FrameAccount).creationCode,
                        abi.encode(owner, address(approveSimulator))
                    )
                )
            )
        );
        return address(uint160(uint256(hash)));
    }
}

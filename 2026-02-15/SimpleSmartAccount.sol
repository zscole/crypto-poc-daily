// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "@account-abstraction/contracts/interfaces/IAccount.sol";
import "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SimpleSmartAccount
 * @dev Minimal EIP-4337 compliant smart account implementation
 * @dev Demonstrates key AA concepts: signature validation, nonce management, execution
 */
contract SimpleSmartAccount is IAccount, Ownable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    IEntryPoint private immutable _entryPoint;
    
    // Track nonces for replay protection
    mapping(uint256 => uint256) private _nonces;
    
    // Events for debugging and monitoring
    event SimpleAccountInitialized(IEntryPoint indexed entryPoint, address indexed owner);
    event UserOperationExecuted(bytes32 indexed userOpHash, bool success);

    modifier onlyEntryPoint() {
        require(msg.sender == address(_entryPoint), "account: not EntryPoint");
        _;
    }

    constructor(IEntryPoint anEntryPoint, address anOwner) Ownable(anOwner) {
        _entryPoint = anEntryPoint;
        emit SimpleAccountInitialized(anEntryPoint, anOwner);
    }

    /**
     * @dev Initialize the account (for proxy pattern)
     */
    function initialize(address anOwner) public virtual {
        _transferOwnership(anOwner);
    }

    /**
     * @dev Execute a transaction (called by EntryPoint)
     */
    function execute(address dest, uint256 value, bytes calldata func) external onlyEntryPoint {
        _call(dest, value, func);
    }

    /**
     * @dev Execute a batch of transactions
     */
    function executeBatch(
        address[] calldata dest, 
        uint256[] calldata value, 
        bytes[] calldata func
    ) external onlyEntryPoint {
        require(dest.length == func.length && dest.length == value.length, "wrong array lengths");
        for (uint256 i = 0; i < dest.length; i++) {
            _call(dest[i], value[i], func[i]);
        }
    }

    /**
     * @dev Validate user operation signature (EIP-4337 core function)
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external virtual override returns (uint256 validationData) {
        _requireFromEntryPoint();
        validationData = _validateSignature(userOp, userOpHash);
        _validateNonce(userOp.nonce);
        _payPrefund(missingAccountFunds);
    }

    /**
     * @dev Validate the signature of a user operation
     * @param userOp The user operation
     * @param userOpHash The hash of the user operation
     * @return validationData 0 for valid signature, 1 for invalid
     */
    function _validateSignature(
        PackedUserOperation calldata userOp, 
        bytes32 userOpHash
    ) internal view returns (uint256 validationData) {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        
        // Try to recover signer from signature
        address recovered = hash.recover(userOp.signature);
        
        // Check if recovered address matches the owner
        if (recovered != owner()) {
            return SIG_VALIDATION_FAILED;
        }
        return SIG_VALIDATION_SUCCESS;
    }

    /**
     * @dev Validate and update nonce for replay protection
     */
    function _validateNonce(uint256 nonce) internal {
        uint256 key = nonce >> 64;  // Extract nonce key (upper 192 bits)
        uint256 seq = nonce & 0xffffffffffffffff;  // Extract sequence (lower 64 bits)
        
        require(_nonces[key] == seq, "account: invalid nonce");
        _nonces[key]++;
    }

    /**
     * @dev Pay the required prefund to the EntryPoint
     */
    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{
                value: missingAccountFunds, 
                gas: type(uint256).max
            }("");
            (success);
            // Ignore failure (it's EntryPoint's job to verify, not account's)
        }
    }

    /**
     * @dev Internal call function with error handling
     */
    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /**
     * @dev Check that the caller is the EntryPoint
     */
    function _requireFromEntryPoint() internal view {
        require(msg.sender == address(_entryPoint), "account: not EntryPoint");
    }

    /**
     * @dev Get the current nonce for a given key
     */
    function getNonce(uint256 key) public view returns (uint256) {
        return _nonces[key];
    }

    /**
     * @dev Get the EntryPoint address
     */
    function entryPoint() public view returns (IEntryPoint) {
        return _entryPoint;
    }

    /**
     * @dev Accept ETH deposits
     */
    receive() external payable {}

    /**
     * @dev Fallback function for handling arbitrary calls
     */
    fallback() external payable {
        // This allows the account to receive arbitrary calls
        // In production, you might want to restrict this
    }

    // EIP-4337 validation constants
    uint256 internal constant SIG_VALIDATION_FAILED = 1;
    uint256 internal constant SIG_VALIDATION_SUCCESS = 0;
}
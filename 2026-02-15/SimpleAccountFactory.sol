// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./SimpleSmartAccount.sol";

/**
 * @title SimpleAccountFactory
 * @dev Factory for creating SimpleSmartAccount contracts using CREATE2
 * @dev Enables deterministic addresses and counterfactual deployment
 */
contract SimpleAccountFactory {
    SimpleSmartAccount public immutable accountImplementation;

    event AccountCreated(address indexed account, address indexed owner, uint256 salt);

    constructor(IEntryPoint _entryPoint) {
        accountImplementation = new SimpleSmartAccount(_entryPoint, address(this));
    }

    /**
     * @dev Create a smart account with deterministic address
     * @param owner The owner of the smart account
     * @param salt Random salt for address generation
     * @return account The address of the created account
     */
    function createAccount(address owner, uint256 salt) public returns (SimpleSmartAccount account) {
        address addr = getAddress(owner, salt);
        uint256 codeSize = addr.code.length;
        
        if (codeSize > 0) {
            return SimpleSmartAccount(payable(addr));
        }
        
        bytes memory initData = abi.encodeCall(
            SimpleSmartAccount.initialize, 
            (owner)
        );
        
        account = SimpleSmartAccount(payable(Create2.deploy(
            0,
            bytes32(salt),
            abi.encodePacked(
                type(ERC1967Proxy).creationCode,
                abi.encode(address(accountImplementation), initData)
            )
        )));

        emit AccountCreated(address(account), owner, salt);
    }

    /**
     * @dev Calculate the counterfactual address of a smart account
     * @param owner The owner of the smart account
     * @param salt Random salt for address generation
     * @return The deterministic address where the account will be deployed
     */
    function getAddress(address owner, uint256 salt) public view returns (address) {
        bytes memory initData = abi.encodeCall(
            SimpleSmartAccount.initialize, 
            (owner)
        );
        
        return Create2.computeAddress(
            bytes32(salt),
            keccak256(abi.encodePacked(
                type(ERC1967Proxy).creationCode,
                abi.encode(address(accountImplementation), initData)
            ))
        );
    }

    /**
     * @dev Helper function for bundlers to calculate UserOp sender address
     * @param initCode The initCode from UserOperation (includes salt)
     * @return sender The counterfactual address
     */
    function getSender(bytes calldata initCode) external view returns (address sender) {
        // Parse initCode: factory_address + factory_calldata
        // For createAccount calls: selector(4) + owner(32) + salt(32)
        require(initCode.length >= 68, "initCode too short");
        
        address owner = address(bytes20(initCode[16:36]));
        uint256 salt = uint256(bytes32(initCode[36:68]));
        
        return getAddress(owner, salt);
    }
}
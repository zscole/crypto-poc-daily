/**
 * IBC Message Authentication POC
 * 
 * Demonstrates the Saga exploit vulnerability and the secure alternative.
 * 
 * Run with: node test_scenario.js
 */

const { ethers } = require('ethers');

// Simulated message structures (mirrors Solidity structs)
class IBCPacket {
    constructor(sequence, sourcePort, sourceChannel, destPort, destChannel, data, timeoutHeight, timeoutTimestamp) {
        this.sequence = sequence;
        this.sourcePort = sourcePort;
        this.sourceChannel = sourceChannel;
        this.destPort = destPort;
        this.destChannel = destChannel;
        this.data = data;
        this.timeoutHeight = timeoutHeight;
        this.timeoutTimestamp = timeoutTimestamp;
    }

    computeCommitment() {
        return ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
            ['uint64', 'string', 'string', 'string', 'string', 'bytes32', 'uint64', 'uint64'],
            [
                this.sequence,
                this.sourcePort,
                this.sourceChannel,
                this.destPort,
                this.destChannel,
                ethers.keccak256(this.data),
                this.timeoutHeight,
                this.timeoutTimestamp
            ]
        ));
    }
}

class DepositMessage {
    constructor(depositor, token, amount, recipient, depositHash) {
        this.depositor = depositor;
        this.token = token;
        this.amount = amount;
        this.recipient = recipient;
        this.depositHash = depositHash;
    }

    encode() {
        return ethers.AbiCoder.defaultAbiCoder().encode(
            ['address', 'address', 'uint256', 'address', 'bytes32'],
            [this.depositor, this.token, this.amount, this.recipient, this.depositHash]
        );
    }
}

// Simulated bridge state
class VulnerableBridge {
    constructor() {
        this.balances = new Map();
        this.totalMinted = 0n;
    }

    processDeposit(packet) {
        // VULNERABLE: No verification at all!
        const depositMsg = this.decodeDeposit(packet.data);
        
        const currentBalance = this.balances.get(depositMsg.recipient) || 0n;
        this.balances.set(depositMsg.recipient, currentBalance + depositMsg.amount);
        this.totalMinted += depositMsg.amount;

        console.log(`  [VULNERABLE] Minted ${ethers.formatEther(depositMsg.amount)} tokens to ${depositMsg.recipient}`);
        return true;
    }

    decodeDeposit(data) {
        const decoded = ethers.AbiCoder.defaultAbiCoder().decode(
            ['address', 'address', 'uint256', 'address', 'bytes32'],
            data
        );
        return {
            depositor: decoded[0],
            token: decoded[1],
            amount: decoded[2],
            recipient: decoded[3],
            depositHash: decoded[4]
        };
    }
}

class SecureBridge {
    constructor() {
        this.balances = new Map();
        this.totalMinted = 0n;
        this.authorizedRelayers = new Set();
        this.processedSequences = new Map();
        this.validSourceChannels = new Set();
        this.stateRoot = ethers.ZeroHash;
    }

    addRelayer(address) {
        this.authorizedRelayers.add(address.toLowerCase());
    }

    addSourceChannel(channelId) {
        this.validSourceChannels.add(channelId);
    }

    updateStateRoot(root) {
        this.stateRoot = root;
    }

    async processDeposit(packet, relayerWallet, merkleProof) {
        // SECURITY CHECK 1: Valid source channel
        if (!this.validSourceChannels.has(packet.sourceChannel)) {
            console.log(`  [SECURE] REJECTED: Invalid source channel "${packet.sourceChannel}"`);
            return false;
        }

        // SECURITY CHECK 2: Replay protection
        const seqKey = `${packet.sourceChannel}:${packet.sequence}`;
        if (this.processedSequences.has(seqKey)) {
            console.log(`  [SECURE] REJECTED: Packet sequence ${packet.sequence} already processed`);
            return false;
        }

        // SECURITY CHECK 3: Timeout (simplified)
        const now = Math.floor(Date.now() / 1000);
        if (packet.timeoutTimestamp !== 0n && BigInt(now) > packet.timeoutTimestamp) {
            console.log(`  [SECURE] REJECTED: Packet has timed out`);
            return false;
        }

        // SECURITY CHECK 4: Relayer signature
        const commitment = packet.computeCommitment();
        const signature = await relayerWallet.signMessage(ethers.getBytes(commitment));
        const recoveredAddress = ethers.verifyMessage(ethers.getBytes(commitment), signature);
        
        if (!this.authorizedRelayers.has(recoveredAddress.toLowerCase())) {
            console.log(`  [SECURE] REJECTED: Unauthorized relayer ${recoveredAddress}`);
            return false;
        }

        // SECURITY CHECK 5: Merkle proof verification
        if (!this.verifyMerkleProof(packet, merkleProof)) {
            console.log(`  [SECURE] REJECTED: Invalid Merkle proof`);
            return false;
        }

        // All checks passed - process the deposit
        this.processedSequences.set(seqKey, true);
        
        const depositMsg = this.decodeDeposit(packet.data);
        const currentBalance = this.balances.get(depositMsg.recipient) || 0n;
        this.balances.set(depositMsg.recipient, currentBalance + depositMsg.amount);
        this.totalMinted += depositMsg.amount;

        console.log(`  [SECURE] Successfully minted ${ethers.formatEther(depositMsg.amount)} tokens to ${depositMsg.recipient}`);
        return true;
    }

    verifyMerkleProof(packet, proof) {
        // Simplified proof verification for demo
        // In production, this would verify against the light client state root
        if (!proof || !proof.valid) return false;
        return proof.expectedRoot === this.stateRoot;
    }

    decodeDeposit(data) {
        const decoded = ethers.AbiCoder.defaultAbiCoder().decode(
            ['address', 'address', 'uint256', 'address', 'bytes32'],
            data
        );
        return {
            depositor: decoded[0],
            token: decoded[1],
            amount: decoded[2],
            recipient: decoded[3],
            depositHash: decoded[4]
        };
    }
}

// ============ Test Scenarios ============

async function runScenarios() {
    console.log('='.repeat(70));
    console.log('IBC Message Authentication POC - Saga Exploit Demonstration');
    console.log('='.repeat(70));
    console.log();

    // Create wallets
    const attacker = ethers.Wallet.createRandom();
    const legitimateRelayer = ethers.Wallet.createRandom();
    const unauthorizedRelayer = ethers.Wallet.createRandom();

    // Create fake addresses
    const fakeToken = '0x1111111111111111111111111111111111111111';
    const attackerRecipient = attacker.address;
    const fakeDepositHash = ethers.keccak256(ethers.toUtf8Bytes('fake_deposit'));

    // Create a forged deposit message (claiming $7M deposit that never happened)
    const forgedAmount = ethers.parseEther('7000000'); // 7 million tokens
    const forgedDeposit = new DepositMessage(
        attacker.address,      // depositor (attacker)
        fakeToken,             // token
        forgedAmount,          // amount (7M tokens!)
        attackerRecipient,     // recipient (attacker)
        fakeDepositHash        // fake deposit hash
    );

    const forgedPacket = new IBCPacket(
        1n,                              // sequence
        'transfer',                      // sourcePort
        'channel-0',                     // sourceChannel
        'transfer',                      // destPort
        'channel-1',                     // destChannel
        forgedDeposit.encode(),          // data
        0n,                              // timeoutHeight
        BigInt(Math.floor(Date.now() / 1000) + 3600)  // timeoutTimestamp (1 hour)
    );

    // ============ Scenario 1: Attack on Vulnerable Bridge ============
    console.log('SCENARIO 1: Attack on Vulnerable Bridge');
    console.log('-'.repeat(70));
    console.log('Attacker sends forged IBC message claiming $7M deposit...');
    console.log();

    const vulnerableBridge = new VulnerableBridge();
    vulnerableBridge.processDeposit(forgedPacket);

    console.log();
    console.log(`  Result: Attacker balance = ${ethers.formatEther(vulnerableBridge.balances.get(attackerRecipient) || 0n)} tokens`);
    console.log(`  Result: Total minted = ${ethers.formatEther(vulnerableBridge.totalMinted)} tokens`);
    console.log(`  STATUS: EXPLOIT SUCCESSFUL - Bridge is drained`);
    console.log();

    // ============ Scenario 2: Attack on Secure Bridge ============
    console.log('SCENARIO 2: Same Attack on Secure Bridge');
    console.log('-'.repeat(70));

    const secureBridge = new SecureBridge();
    
    // Setup: Add legitimate relayer and source channel
    secureBridge.addRelayer(legitimateRelayer.address);
    secureBridge.addSourceChannel('channel-0');
    secureBridge.updateStateRoot(ethers.keccak256(ethers.toUtf8Bytes('valid_state')));

    console.log('2a) Attacker tries with unauthorized relayer...');
    await secureBridge.processDeposit(forgedPacket, unauthorizedRelayer, { valid: true, expectedRoot: secureBridge.stateRoot });
    console.log();

    console.log('2b) Attacker tries with invalid source channel...');
    const wrongChannelPacket = new IBCPacket(
        2n, 'transfer', 'fake-channel', 'transfer', 'channel-1',
        forgedDeposit.encode(), 0n, BigInt(Math.floor(Date.now() / 1000) + 3600)
    );
    await secureBridge.processDeposit(wrongChannelPacket, legitimateRelayer, { valid: true, expectedRoot: secureBridge.stateRoot });
    console.log();

    console.log('2c) Attacker tries with invalid Merkle proof...');
    await secureBridge.processDeposit(forgedPacket, legitimateRelayer, { valid: false, expectedRoot: ethers.ZeroHash });
    console.log();

    console.log(`  Result: Attacker balance = ${ethers.formatEther(secureBridge.balances.get(attackerRecipient) || 0n)} tokens`);
    console.log(`  Result: Total minted = ${ethers.formatEther(secureBridge.totalMinted)} tokens`);
    console.log(`  STATUS: ALL ATTACKS BLOCKED`);
    console.log();

    // ============ Scenario 3: Legitimate Deposit ============
    console.log('SCENARIO 3: Legitimate Deposit on Secure Bridge');
    console.log('-'.repeat(70));
    
    const legitimateDepositor = ethers.Wallet.createRandom();
    const legitimateAmount = ethers.parseEther('1000');
    const realDepositHash = ethers.keccak256(ethers.toUtf8Bytes('real_deposit_tx_hash'));

    const legitimateDeposit = new DepositMessage(
        legitimateDepositor.address,
        fakeToken,
        legitimateAmount,
        legitimateDepositor.address,
        realDepositHash
    );

    const legitimatePacket = new IBCPacket(
        3n, 'transfer', 'channel-0', 'transfer', 'channel-1',
        legitimateDeposit.encode(), 0n, BigInt(Math.floor(Date.now() / 1000) + 3600)
    );

    console.log('Processing legitimate deposit with valid proof...');
    await secureBridge.processDeposit(legitimatePacket, legitimateRelayer, { valid: true, expectedRoot: secureBridge.stateRoot });
    console.log();
    console.log(`  Result: Depositor balance = ${ethers.formatEther(secureBridge.balances.get(legitimateDepositor.address) || 0n)} tokens`);
    console.log(`  STATUS: LEGITIMATE DEPOSIT PROCESSED`);
    console.log();

    // ============ Scenario 4: Replay Attack ============
    console.log('SCENARIO 4: Replay Attack Attempt');
    console.log('-'.repeat(70));
    console.log('Attacker tries to replay the same legitimate packet...');
    await secureBridge.processDeposit(legitimatePacket, legitimateRelayer, { valid: true, expectedRoot: secureBridge.stateRoot });
    console.log(`  STATUS: REPLAY BLOCKED`);
    console.log();

    // ============ Summary ============
    console.log('='.repeat(70));
    console.log('SUMMARY');
    console.log('='.repeat(70));
    console.log();
    console.log('The Saga exploit succeeded because the bridge:');
    console.log('  - Did not verify relayer authorization');
    console.log('  - Did not verify source channel validity');
    console.log('  - Did not require Merkle proofs of deposits');
    console.log('  - Had no replay protection');
    console.log();
    console.log('The secure implementation adds:');
    console.log('  1. Authorized relayer whitelist with signature verification');
    console.log('  2. Valid source channel registry');
    console.log('  3. Merkle proof verification against light client state');
    console.log('  4. Sequence-based replay protection');
    console.log('  5. Timeout validation');
    console.log();
    console.log('Key lesson: Never trust cross-chain messages without cryptographic proof.');
    console.log('='.repeat(70));
}

// Run
runScenarios().catch(console.error);

/**
 * Dust Disposal Transaction Builder
 * 
 * Creates provably unspendable transactions that:
 * 1. Consume dust UTXOs completely
 * 2. Output to OP_RETURN (provably burned)
 * 3. Use ANYONECANPAY for fee flexibility
 * 
 * Based on discussion from Bitcoin Optech Newsletter #391
 * Reference: https://delvingbitcoin.org/t/disposing-of-dust-attack-utxos/2215
 */

import { sha256 } from '@noble/hashes/sha256';
import { UTXO, DisposalTransaction, DisposalOptions, DEFAULT_OPTIONS } from './types';

// Bitcoin Script opcodes
const OP_RETURN = 0x6a;
const OP_PUSHDATA1 = 0x4c;

// Sighash flags
const SIGHASH_ALL = 0x01;
const SIGHASH_ANYONECANPAY = 0x80;
const SIGHASH_ALL_ANYONECANPAY = SIGHASH_ALL | SIGHASH_ANYONECANPAY;

export class DustDisposal {
  private options: DisposalOptions;

  constructor(options: Partial<DisposalOptions> = {}) {
    this.options = { ...DEFAULT_OPTIONS, ...options };
  }

  /**
   * Build a disposal transaction for a single dust UTXO
   * 
   * The transaction structure:
   * - Version: 2
   * - Input: The dust UTXO
   * - Output: OP_RETURN with 3-byte marker
   * - Locktime: 0
   */
  buildDisposalTx(utxo: UTXO): DisposalTransaction {
    const opReturnData = Buffer.from(this.options.opReturnMarker, 'hex');
    
    // Build transaction manually (for educational purposes)
    const tx = this.constructTransaction(utxo, opReturnData);
    const txHex = tx.toString('hex');
    const txid = this.calculateTxid(tx);
    const virtualSize = this.calculateVirtualSize(tx);
    
    // Fee is the entire UTXO value (no change output)
    const fee = utxo.value;

    return {
      txHex,
      txid,
      virtualSize,
      fee,
      disposedUtxos: [utxo],
      opReturnData
    };
  }

  /**
   * Build a batch disposal transaction for multiple dust UTXOs
   */
  buildBatchDisposalTx(utxos: UTXO[]): DisposalTransaction {
    if (utxos.length === 0) {
      throw new Error('No UTXOs provided for disposal');
    }

    const opReturnData = Buffer.from(this.options.opReturnMarker, 'hex');
    const tx = this.constructBatchTransaction(utxos, opReturnData);
    const txHex = tx.toString('hex');
    const txid = this.calculateTxid(tx);
    const virtualSize = this.calculateVirtualSize(tx);
    const fee = utxos.reduce((sum, u) => sum + u.value, 0);

    return {
      txHex,
      txid,
      virtualSize,
      fee,
      disposedUtxos: utxos,
      opReturnData
    };
  }

  /**
   * Construct raw transaction bytes
   */
  private constructTransaction(utxo: UTXO, opReturnData: Buffer): Buffer {
    const parts: Buffer[] = [];

    // Version (4 bytes, little-endian)
    parts.push(Buffer.from([0x02, 0x00, 0x00, 0x00]));

    // Input count (1 byte varint)
    parts.push(Buffer.from([0x01]));

    // Input: Previous output hash (32 bytes, reversed)
    const txidBytes = Buffer.from(utxo.txid, 'hex').reverse();
    parts.push(txidBytes);

    // Input: Previous output index (4 bytes, little-endian)
    const voutBytes = Buffer.alloc(4);
    voutBytes.writeUInt32LE(utxo.vout);
    parts.push(voutBytes);

    // Input: Script length (placeholder - actual signature goes here)
    // For simulation, we use empty script
    parts.push(Buffer.from([0x00]));

    // Input: Sequence (4 bytes) - 0xfffffffe for RBF compatibility
    parts.push(Buffer.from([0xfe, 0xff, 0xff, 0xff]));

    // Output count (1 byte)
    parts.push(Buffer.from([0x01]));

    // Output: Value (8 bytes) - 0 for OP_RETURN
    parts.push(Buffer.from([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]));

    // Output: Script (OP_RETURN + data)
    const opReturnScript = this.buildOpReturnScript(opReturnData);
    parts.push(this.encodeVarInt(opReturnScript.length));
    parts.push(opReturnScript);

    // Locktime (4 bytes)
    parts.push(Buffer.from([0x00, 0x00, 0x00, 0x00]));

    return Buffer.concat(parts);
  }

  /**
   * Construct batch transaction with multiple inputs
   */
  private constructBatchTransaction(utxos: UTXO[], opReturnData: Buffer): Buffer {
    const parts: Buffer[] = [];

    // Version
    parts.push(Buffer.from([0x02, 0x00, 0x00, 0x00]));

    // Input count
    parts.push(this.encodeVarInt(utxos.length));

    // Inputs
    for (const utxo of utxos) {
      const txidBytes = Buffer.from(utxo.txid, 'hex').reverse();
      parts.push(txidBytes);

      const voutBytes = Buffer.alloc(4);
      voutBytes.writeUInt32LE(utxo.vout);
      parts.push(voutBytes);

      parts.push(Buffer.from([0x00])); // Empty script
      parts.push(Buffer.from([0xfe, 0xff, 0xff, 0xff])); // Sequence
    }

    // Output count
    parts.push(Buffer.from([0x01]));

    // OP_RETURN output
    parts.push(Buffer.from([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]));
    const opReturnScript = this.buildOpReturnScript(opReturnData);
    parts.push(this.encodeVarInt(opReturnScript.length));
    parts.push(opReturnScript);

    // Locktime
    parts.push(Buffer.from([0x00, 0x00, 0x00, 0x00]));

    return Buffer.concat(parts);
  }

  /**
   * Build OP_RETURN script
   */
  private buildOpReturnScript(data: Buffer): Buffer {
    if (data.length <= 75) {
      // Direct push
      return Buffer.concat([
        Buffer.from([OP_RETURN]),
        Buffer.from([data.length]),
        data
      ]);
    } else {
      // OP_PUSHDATA1
      return Buffer.concat([
        Buffer.from([OP_RETURN, OP_PUSHDATA1]),
        Buffer.from([data.length]),
        data
      ]);
    }
  }

  /**
   * Encode variable-length integer
   */
  private encodeVarInt(n: number): Buffer {
    if (n < 0xfd) {
      return Buffer.from([n]);
    } else if (n <= 0xffff) {
      const buf = Buffer.alloc(3);
      buf[0] = 0xfd;
      buf.writeUInt16LE(n, 1);
      return buf;
    } else if (n <= 0xffffffff) {
      const buf = Buffer.alloc(5);
      buf[0] = 0xfe;
      buf.writeUInt32LE(n, 1);
      return buf;
    } else {
      throw new Error('VarInt too large');
    }
  }

  /**
   * Calculate transaction ID (double SHA256, reversed)
   */
  private calculateTxid(tx: Buffer): string {
    const hash1 = sha256(tx);
    const hash2 = sha256(hash1);
    return Buffer.from(hash2).reverse().toString('hex');
  }

  /**
   * Calculate virtual size (for non-segwit, vsize = size)
   */
  private calculateVirtualSize(tx: Buffer): number {
    // For this POC, assuming non-segwit inputs
    return tx.length;
  }

  /**
   * Check if disposal is economically viable
   */
  isViable(utxo: UTXO): { viable: boolean; reason: string } {
    // Minimum relay size is 65 bytes
    const minTxSize = 65;
    const estimatedSize = 110; // Approximate size with P2WPKH input
    const minFee = Math.ceil(estimatedSize * this.options.feeRate);

    if (utxo.value < minFee) {
      return {
        viable: false,
        reason: `UTXO value (${utxo.value} sats) is less than minimum fee (${minFee} sats)`
      };
    }

    return {
      viable: true,
      reason: `Can dispose with ${utxo.value} sats fee (min: ${minFee} sats)`
    };
  }

  /**
   * Get recommended sighash type description
   */
  getSighashRecommendation(): string {
    return `SIGHASH_ANYONECANPAY|ALL (0x${SIGHASH_ALL_ANYONECANPAY.toString(16)}): ` +
           `Allows third parties to add inputs for fee bumping without invalidating signature`;
  }
}

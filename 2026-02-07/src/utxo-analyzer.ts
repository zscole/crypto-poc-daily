/**
 * UTXO Analyzer - Dust Detection
 * 
 * Identifies UTXOs that are likely dust attack vectors based on:
 * - Value below dust threshold
 * - Output type patterns
 * - Confirmation timing
 * - Correlation with other small UTXOs
 */

import { UTXO, DustAnalysis, DustHeuristics, DEFAULT_HEURISTICS } from './types';

export class UTXOAnalyzer {
  private heuristics: DustHeuristics;

  constructor(heuristics: Partial<DustHeuristics> = {}) {
    this.heuristics = { ...DEFAULT_HEURISTICS, ...heuristics };
  }

  /**
   * Analyze a single UTXO for dust characteristics
   */
  analyze(utxo: UTXO): DustAnalysis {
    const reasons: string[] = [];
    let score = 0;

    // Check absolute dust limit
    if (utxo.value <= this.heuristics.absoluteDustLimit) {
      score += 50;
      reasons.push(`Value ${utxo.value} sats is at or below dust limit (${this.heuristics.absoluteDustLimit})`);
    } else if (utxo.value < this.heuristics.absoluteDustLimit * 2) {
      score += 25;
      reasons.push(`Value ${utxo.value} sats is near dust threshold`);
    }

    // Check output type
    const outputType = this.detectOutputType(utxo.scriptPubKey);
    if (this.heuristics.suspiciousOutputTypes.includes(outputType)) {
      score += 15;
      reasons.push(`Output type ${outputType} commonly used in dust attacks`);
    }

    // Check confirmation count (recent = more suspicious for dust)
    if (utxo.confirmations !== undefined && 
        utxo.confirmations < this.heuristics.recentConfirmationThreshold) {
      score += 10;
      reasons.push(`Recent UTXO with only ${utxo.confirmations} confirmations`);
    }

    // Economic analysis: is it worth spending?
    const spendCost = this.estimateSpendCost(utxo);
    if (spendCost > utxo.value * 0.5) {
      score += 20;
      reasons.push(`Spending cost (${spendCost} sats) exceeds 50% of value`);
    }

    return {
      utxo,
      isDust: score >= 50,
      dustScore: Math.min(100, score),
      reasons
    };
  }

  /**
   * Analyze multiple UTXOs with correlation detection
   */
  analyzeSet(utxos: UTXO[]): DustAnalysis[] {
    const analyses = utxos.map(u => this.analyze(u));
    
    // Check for correlated dust (same-block, similar values)
    const dustUtxos = analyses.filter(a => a.isDust);
    if (dustUtxos.length > 3) {
      // Multiple dust UTXOs suggest coordinated attack
      dustUtxos.forEach(a => {
        a.dustScore = Math.min(100, a.dustScore + this.heuristics.sameBlockBonus);
        a.reasons.push(`Part of ${dustUtxos.length} dust UTXOs (possible coordinated attack)`);
      });
    }

    return analyses;
  }

  /**
   * Detect output type from scriptPubKey
   */
  private detectOutputType(scriptPubKey: string): string {
    const script = Buffer.from(scriptPubKey, 'hex');
    
    // P2PKH: OP_DUP OP_HASH160 <20 bytes> OP_EQUALVERIFY OP_CHECKSIG
    if (script.length === 25 && script[0] === 0x76 && script[1] === 0xa9) {
      return 'p2pkh';
    }
    
    // P2SH: OP_HASH160 <20 bytes> OP_EQUAL
    if (script.length === 23 && script[0] === 0xa9) {
      return 'p2sh';
    }
    
    // P2WPKH: OP_0 <20 bytes>
    if (script.length === 22 && script[0] === 0x00 && script[1] === 0x14) {
      return 'p2wpkh';
    }
    
    // P2WSH: OP_0 <32 bytes>
    if (script.length === 34 && script[0] === 0x00 && script[1] === 0x20) {
      return 'p2wsh';
    }
    
    // P2TR: OP_1 <32 bytes>
    if (script.length === 34 && script[0] === 0x51 && script[1] === 0x20) {
      return 'p2tr';
    }
    
    return 'unknown';
  }

  /**
   * Estimate cost to spend this UTXO
   */
  private estimateSpendCost(utxo: UTXO): number {
    const outputType = this.detectOutputType(utxo.scriptPubKey);
    
    // Approximate input sizes (vbytes) by type
    const inputSizes: Record<string, number> = {
      'p2pkh': 148,
      'p2sh': 91,  // Assuming P2SH-P2WPKH
      'p2wpkh': 68,
      'p2wsh': 105,
      'p2tr': 58,
      'unknown': 148
    };
    
    const inputVbytes = inputSizes[outputType] || 148;
    // At 1 sat/vbyte (conservative estimate for actual spending)
    return inputVbytes;
  }

  /**
   * Get disposal priority (higher = dispose first)
   */
  getDisposalPriority(analysis: DustAnalysis): number {
    if (!analysis.isDust) return 0;
    
    // Prioritize by: score, then lower value (cheaper to dispose)
    return analysis.dustScore + (1000 - analysis.utxo.value) / 1000;
  }
}

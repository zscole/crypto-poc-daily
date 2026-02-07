/**
 * Dust Disposal POC - CLI Demonstration
 * 
 * Based on Bitcoin Optech Newsletter #391 discussion
 * about disposing of dust attack UTXOs via OP_RETURN
 */

import { UTXOAnalyzer } from './utxo-analyzer';
import { DustDisposal } from './dust-disposal';
import { UTXO, DEFAULT_OPTIONS } from './types';

// Simulated UTXO set for demonstration
const SAMPLE_UTXOS: UTXO[] = [
  {
    txid: 'a'.repeat(64),
    vout: 0,
    value: 546,  // Exactly at dust limit - suspicious
    scriptPubKey: '76a914' + '0'.repeat(40) + '88ac', // P2PKH
    confirmations: 2
  },
  {
    txid: 'b'.repeat(64),
    vout: 1,
    value: 330,  // Below dust limit - definitely dust
    scriptPubKey: '76a914' + '1'.repeat(40) + '88ac',
    confirmations: 1
  },
  {
    txid: 'c'.repeat(64),
    vout: 0,
    value: 1000, // Near dust - marginal
    scriptPubKey: '0014' + '2'.repeat(40), // P2WPKH
    confirmations: 100
  },
  {
    txid: 'd'.repeat(64),
    vout: 2,
    value: 500,  // Dust, older output type
    scriptPubKey: 'a914' + '3'.repeat(40) + '87', // P2SH
    confirmations: 5
  },
  {
    txid: 'e'.repeat(64),
    vout: 0,
    value: 100000, // Normal UTXO - not dust
    scriptPubKey: '5120' + '4'.repeat(64), // P2TR
    confirmations: 50
  }
];

function printHeader(text: string): void {
  console.log('\n' + '='.repeat(60));
  console.log(text);
  console.log('='.repeat(60));
}

function printDivider(): void {
  console.log('-'.repeat(60));
}

async function main(): Promise<void> {
  console.log('Dust Disposal POC');
  console.log('Based on Bitcoin Optech Newsletter #391');
  console.log('Reference: https://delvingbitcoin.org/t/disposing-of-dust-attack-utxos/2215');

  // Initialize components
  const analyzer = new UTXOAnalyzer();
  const disposal = new DustDisposal({
    dustThreshold: parseInt(process.env.DUST_THRESHOLD || '546'),
    feeRate: 0.1 // Bitcoin Core v30+ minimum
  });

  // Step 1: Analyze UTXOs
  printHeader('STEP 1: UTXO ANALYSIS');
  
  const analyses = analyzer.analyzeSet(SAMPLE_UTXOS);
  
  for (const analysis of analyses) {
    console.log(`\nUTXO: ${analysis.utxo.txid.substring(0, 8)}...:${analysis.utxo.vout}`);
    console.log(`  Value: ${analysis.utxo.value} sats`);
    console.log(`  Is Dust: ${analysis.isDust ? 'YES' : 'NO'}`);
    console.log(`  Dust Score: ${analysis.dustScore}/100`);
    if (analysis.reasons.length > 0) {
      console.log(`  Reasons:`);
      analysis.reasons.forEach(r => console.log(`    - ${r}`));
    }
  }

  // Step 2: Filter dust UTXOs
  printHeader('STEP 2: DUST UTXOs IDENTIFIED');
  
  const dustUtxos = analyses
    .filter(a => a.isDust)
    .sort((a, b) => analyzer.getDisposalPriority(b) - analyzer.getDisposalPriority(a))
    .map(a => a.utxo);

  console.log(`\nFound ${dustUtxos.length} dust UTXOs to dispose:`);
  dustUtxos.forEach(u => {
    console.log(`  - ${u.value} sats (txid: ${u.txid.substring(0, 8)}...)`);
  });

  // Step 3: Check viability
  printHeader('STEP 3: DISPOSAL VIABILITY CHECK');
  
  for (const utxo of dustUtxos) {
    const viability = disposal.isViable(utxo);
    console.log(`\nUTXO ${utxo.txid.substring(0, 8)}...: ${utxo.value} sats`);
    console.log(`  Viable: ${viability.viable ? 'YES' : 'NO'}`);
    console.log(`  Reason: ${viability.reason}`);
  }

  // Step 4: Build disposal transactions
  printHeader('STEP 4: DISPOSAL TRANSACTION CONSTRUCTION');
  
  console.log('\nSingle UTXO disposal example:');
  const singleDisposal = disposal.buildDisposalTx(dustUtxos[0]);
  console.log(`  TXID: ${singleDisposal.txid}`);
  console.log(`  Size: ${singleDisposal.virtualSize} vbytes`);
  console.log(`  Fee: ${singleDisposal.fee} sats`);
  console.log(`  OP_RETURN data: ${singleDisposal.opReturnData.toString('hex')}`);

  printDivider();
  
  console.log('\nBatch disposal example (all dust UTXOs):');
  const batchDisposal = disposal.buildBatchDisposalTx(dustUtxos);
  console.log(`  TXID: ${batchDisposal.txid}`);
  console.log(`  Size: ${batchDisposal.virtualSize} vbytes`);
  console.log(`  Total Fee: ${batchDisposal.fee} sats`);
  console.log(`  UTXOs disposed: ${batchDisposal.disposedUtxos.length}`);

  // Step 5: Privacy considerations
  printHeader('STEP 5: PRIVACY CONSIDERATIONS');
  
  console.log(`
Privacy risks when disposing dust:

1. FINGERPRINTING: If only a few wallets implement this technique,
   disposal transactions become identifiable patterns.

2. CORRELATION: Broadcasting multiple dust disposals simultaneously
   can link addresses together - defeating the purpose.

3. TIMING: Consider disposing dust during high-fee periods when
   your transactions blend in with other small transactions.

Recommendations:
- Wait for broader wallet adoption before using
- Dispose one UTXO at a time with random delays
- Use Tor or similar for broadcast
- Consider using ${disposal.getSighashRecommendation()}
`);

  // Summary
  printHeader('SUMMARY');
  
  const totalDust = dustUtxos.reduce((sum, u) => sum + u.value, 0);
  const normalUtxos = analyses.filter(a => !a.isDust);
  const totalNormal = normalUtxos.reduce((sum, a) => sum + a.utxo.value, 0);
  
  console.log(`
Analysis Results:
  - Total UTXOs analyzed: ${SAMPLE_UTXOS.length}
  - Dust UTXOs found: ${dustUtxos.length}
  - Normal UTXOs: ${normalUtxos.length}
  - Total dust value: ${totalDust} sats
  - Total normal value: ${totalNormal} sats
  - Dust as % of total: ${((totalDust / (totalDust + totalNormal)) * 100).toFixed(2)}%

Disposal Cost:
  - At ${DEFAULT_OPTIONS.feeRate} sat/vbyte fee rate
  - All dust can be disposed for ${batchDisposal.fee} sats total
  - This permanently prevents dust attack linkage
`);

  console.log('\nPOC complete. This is a simulation - no real transactions were broadcast.');
}

main().catch(console.error);

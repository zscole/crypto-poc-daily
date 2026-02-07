/**
 * Dust Disposal POC - Type Definitions
 */

export interface UTXO {
  txid: string;
  vout: number;
  value: number; // satoshis
  scriptPubKey: string;
  address?: string;
  confirmations?: number;
}

export interface DustAnalysis {
  utxo: UTXO;
  isDust: boolean;
  dustScore: number; // 0-100, higher = more likely dust attack
  reasons: string[];
}

export interface DisposalTransaction {
  txHex: string;
  txid: string;
  virtualSize: number;
  fee: number;
  disposedUtxos: UTXO[];
  opReturnData: Buffer;
}

export interface DisposalOptions {
  dustThreshold: number; // satoshis
  feeRate: number; // sat/vbyte
  opReturnMarker: string; // 3-byte hex marker
  network: 'mainnet' | 'testnet' | 'regtest';
}

export const DEFAULT_OPTIONS: DisposalOptions = {
  dustThreshold: 546, // Standard dust limit
  feeRate: 0.1, // Bitcoin Core v30+ minimum
  opReturnMarker: '445553', // "DUS" in hex (dust)
  network: 'mainnet'
};

// Dust heuristics
export interface DustHeuristics {
  // UTXOs below this are definitely dust
  absoluteDustLimit: number;
  // UTXOs from these output types are suspicious
  suspiciousOutputTypes: string[];
  // Recent UTXOs (< N confirmations) are more suspicious
  recentConfirmationThreshold: number;
  // Multiple dust UTXOs in same block = likely attack
  sameBlockBonus: number;
}

export const DEFAULT_HEURISTICS: DustHeuristics = {
  absoluteDustLimit: 546,
  suspiciousOutputTypes: ['p2pkh', 'p2sh'], // Older formats used in dust attacks
  recentConfirmationThreshold: 6,
  sameBlockBonus: 20
};

/**
 * EIP-7862 Delayed State Root - Timing Simulator
 * 
 * Demonstrates the timing benefits of decoupling state root computation
 * from block validation.
 */

interface BlockHeader {
  number: number;
  parentHash: string;
  stateRoot: string;  // Post-state of block (n-1)
  transactionsRoot: string;
  timestamp: number;
}

interface TimingResult {
  traditional: {
    executeTime: number;
    stateRootTime: number;
    totalToAttest: number;
    meetsDeadline: boolean;
  };
  delayed: {
    executeTime: number;
    totalToAttest: number;
    meetsDeadline: boolean;
  };
  timeSaved: number;
  percentImprovement: number;
}

class DelayedStateRootSimulator {
  private blocks: BlockHeader[] = [];
  private lastComputedStateRoot: string;
  private readonly SLOT_TIME_MS = 12000;  // 12 seconds
  private readonly ATTESTATION_DEADLINE_MS = 4000;  // First 1/3 of slot

  constructor() {
    // Genesis block
    this.lastComputedStateRoot = this.hash('genesis');
    this.blocks.push({
      number: 0,
      parentHash: '0x0',
      stateRoot: this.lastComputedStateRoot,
      transactionsRoot: '0x0',
      timestamp: Date.now(),
    });
  }

  /**
   * Simulates block processing with delayed state root
   */
  processBlock(transactions: string[]): BlockHeader {
    const parent = this.blocks[this.blocks.length - 1];
    
    // Create block with DELAYED state root
    const newBlock: BlockHeader = {
      number: parent.number + 1,
      parentHash: this.hash(JSON.stringify(parent)),
      stateRoot: this.lastComputedStateRoot,  // Previous block's post-state
      transactionsRoot: this.hash(transactions.join('')),
      timestamp: Date.now(),
    };

    this.blocks.push(newBlock);

    // Compute new state root (for next block)
    this.lastComputedStateRoot = this.hash(
      newBlock.stateRoot + newBlock.transactionsRoot + newBlock.number
    );

    return newBlock;
  }

  /**
   * Simulates timing comparison between traditional and delayed models
   */
  simulateTiming(
    numTransactions: number,
    avgTxExecutionMs: number = 5,
    stateRootComplexity: number = 1.0
  ): TimingResult {
    // Base times
    const executeTime = numTransactions * avgTxExecutionMs;
    const baseStateRootTime = 2000;  // 2 seconds base
    const stateRootTime = baseStateRootTime * stateRootComplexity;

    // Traditional: Sequential execution -> state root -> attest
    const traditionalTotal = executeTime + stateRootTime;

    // EIP-7862: Execute -> Attest (state root computed for next block)
    const delayedTotal = executeTime;

    const timeSaved = traditionalTotal - delayedTotal;
    const percentImprovement = (timeSaved / traditionalTotal) * 100;

    return {
      traditional: {
        executeTime,
        stateRootTime,
        totalToAttest: traditionalTotal,
        meetsDeadline: traditionalTotal < this.ATTESTATION_DEADLINE_MS,
      },
      delayed: {
        executeTime,
        totalToAttest: delayedTotal,
        meetsDeadline: delayedTotal < this.ATTESTATION_DEADLINE_MS,
      },
      timeSaved,
      percentImprovement,
    };
  }

  /**
   * Simulates Block Access List (BAL) parallel computation benefits
   */
  simulateBALParallelization(
    numAccessedSlots: number,
    numWorkers: number = 1
  ): { sequential: number; parallel: number; speedup: number } {
    const perSlotTime = 10;  // 10ms per slot proof
    
    const sequential = numAccessedSlots * perSlotTime;
    const parallel = Math.ceil(numAccessedSlots / numWorkers) * perSlotTime;
    const speedup = sequential / parallel;

    return { sequential, parallel, speedup };
  }

  private hash(input: string): string {
    // Simple hash simulation
    let hash = 0;
    for (let i = 0; i < input.length; i++) {
      const char = input.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return '0x' + Math.abs(hash).toString(16).padStart(64, '0');
  }

  getBlocks(): BlockHeader[] {
    return [...this.blocks];
  }
}

// Run simulation
function main() {
  console.log('='.repeat(60));
  console.log('EIP-7862: Delayed State Root Simulator');
  console.log('='.repeat(60));
  console.log();

  const sim = new DelayedStateRootSimulator();

  // Process some blocks
  console.log('Processing blocks with delayed state roots...');
  console.log();

  for (let i = 1; i <= 5; i++) {
    const txs = Array(100).fill(null).map((_, j) => `tx-${i}-${j}`);
    const block = sim.processBlock(txs);
    console.log(`Block ${block.number}:`);
    console.log(`  state_root: ${block.stateRoot.slice(0, 18)}... (from block ${block.number - 1})`);
  }

  console.log();
  console.log('-'.repeat(60));
  console.log('Timing Comparison');
  console.log('-'.repeat(60));
  console.log();

  // Test various load scenarios
  const scenarios = [
    { name: 'Light load', txCount: 100, complexity: 0.5 },
    { name: 'Normal load', txCount: 300, complexity: 1.0 },
    { name: 'Heavy load', txCount: 500, complexity: 1.5 },
    { name: 'Extreme load', txCount: 800, complexity: 2.0 },
  ];

  for (const scenario of scenarios) {
    const result = sim.simulateTiming(scenario.txCount, 5, scenario.complexity);
    
    console.log(`${scenario.name} (${scenario.txCount} txs):`);
    console.log(`  Traditional: ${result.traditional.totalToAttest}ms to attest`);
    console.log(`    - Execute: ${result.traditional.executeTime}ms`);
    console.log(`    - State root: ${result.traditional.stateRootTime}ms`);
    console.log(`    - Meets deadline: ${result.traditional.meetsDeadline ? 'YES' : 'NO'}`);
    console.log(`  EIP-7862 Delayed: ${result.delayed.totalToAttest}ms to attest`);
    console.log(`    - Meets deadline: ${result.delayed.meetsDeadline ? 'YES' : 'NO'}`);
    console.log(`  Time saved: ${result.timeSaved}ms (${result.percentImprovement.toFixed(1)}% improvement)`);
    console.log();
  }

  console.log('-'.repeat(60));
  console.log('BAL Parallelization Benefits');
  console.log('-'.repeat(60));
  console.log();

  const slotCounts = [100, 500, 1000, 5000];
  const workerCounts = [1, 4, 8, 16];

  console.log('State root computation time (ms) by slot count and workers:');
  console.log();
  
  // Header
  console.log('Slots\\Workers |', workerCounts.map(w => w.toString().padStart(6)).join(' |'));
  console.log('-'.repeat(50));

  for (const slots of slotCounts) {
    const times = workerCounts.map(workers => {
      const result = sim.simulateBALParallelization(slots, workers);
      return result.parallel.toString().padStart(6);
    });
    console.log(`${slots.toString().padStart(12)} |`, times.join(' |'));
  }

  console.log();
  console.log('='.repeat(60));
  console.log('Key Insights:');
  console.log('='.repeat(60));
  console.log();
  console.log('1. Delayed state roots allow attestation ~2-4 seconds earlier');
  console.log('2. Under heavy load, traditional model may miss attestation deadline');
  console.log('3. BAL enables parallel state root computation (up to 16x speedup)');
  console.log('4. Combined benefit: validators can reliably meet timing requirements');
  console.log();
}

main();

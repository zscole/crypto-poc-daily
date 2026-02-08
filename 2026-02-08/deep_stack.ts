/**
 * EIP-8024: Deep Stack Manipulation Opcodes
 * TypeScript implementation with EVM stack simulation
 */

// Opcodes
const DUPN = 0xe6;
const SWAPN = 0xe7;
const EXCHANGE = 0xe8;

// Reserved range for JUMPDEST compatibility (91-127 = 0x5b-0x7f)
const RESERVED_START = 91;
const RESERVED_END = 127;

/**
 * Encode a single stack depth for DUPN or SWAPN
 * Valid range: n in [17, 235]
 */
function encodeSingle(n: number): number {
  if (n < 17 || n > 235) {
    throw new Error(`Invalid stack depth: ${n}. Must be in [17, 235]`);
  }

  if (n <= 107) {
    // n in [17, 107] -> immediate in [0, 90]
    return n - 17;
  } else {
    // n in [108, 235] -> immediate in [128, 255]
    return n + 20;
  }
}

/**
 * Decode a single operand immediate
 */
function decodeSingle(x: number): number {
  if (x > 90 && x < 128) {
    throw new Error(`Invalid immediate: ${x}. Falls in reserved range [91, 127]`);
  }

  if (x <= 90) {
    return x + 17;
  } else {
    return x - 20;
  }
}

/**
 * Encode a pair of stack positions for EXCHANGE
 * Returns immediate byte and normalizes (n, m) so n < m
 */
function encodePair(n: number, m: number): number {
  // Normalize so n < m
  if (n > m) {
    [n, m] = [m, n];
  }
  if (n === m) {
    throw new Error("Cannot exchange same position");
  }

  let k: number;
  if (n + m <= 29) {
    // Lower triangle: encode as q*16 + r where q = n-1, r = m-1
    k = (n - 1) * 16 + (m - 1);
  } else {
    // Upper triangle: k = (29 - m) * 16 + (n - 1)
    k = (29 - m) * 16 + (n - 1);
  }

  // Skip reserved range
  if (k <= 79) {
    return k;
  } else {
    return k + 48;
  }
}

/**
 * Decode a pair of stack positions from EXCHANGE immediate
 */
function decodePair(x: number): [number, number] {
  if (x > 79 && x < 128) {
    throw new Error(`Invalid immediate: ${x}. Falls in reserved range`);
  }

  const k = x <= 79 ? x : x - 48;
  const q = Math.floor(k / 16);
  const r = k % 16;

  if (q < r) {
    return [q + 1, r + 1];
  } else {
    return [r + 1, 29 - q];
  }
}

/**
 * Simple EVM stack simulator demonstrating EIP-8024 opcodes
 */
class EVMStackSimulator {
  private stack: bigint[] = [];
  private pc: number = 0;
  private code: Uint8Array;

  constructor(bytecode: Uint8Array) {
    this.code = bytecode;
  }

  // Push value onto stack
  push(value: bigint): void {
    if (this.stack.length >= 1024) {
      throw new Error("Stack overflow");
    }
    this.stack.push(value);
  }

  // Get stack for inspection
  getStack(): bigint[] {
    return [...this.stack];
  }

  // Execute one instruction
  step(): boolean {
    if (this.pc >= this.code.length) {
      return false; // End of code
    }

    const opcode = this.code[this.pc];

    switch (opcode) {
      case DUPN: {
        const imm = this.code[this.pc + 1] ?? 0;
        const n = decodeSingle(imm);
        
        if (n > this.stack.length) {
          throw new Error(`Stack underflow: DUPN ${n} but stack size is ${this.stack.length}`);
        }
        
        // DUP the nth item (1-indexed from top)
        const value = this.stack[this.stack.length - n];
        this.push(value);
        this.pc += 2;
        console.log(`DUPN ${n}: duplicated ${value} to top`);
        break;
      }

      case SWAPN: {
        const imm = this.code[this.pc + 1] ?? 0;
        const n = decodeSingle(imm);
        
        if (n + 1 > this.stack.length) {
          throw new Error(`Stack underflow: SWAPN ${n}`);
        }
        
        // Swap top with (n+1)th item
        const topIdx = this.stack.length - 1;
        const swapIdx = this.stack.length - n - 1;
        
        const temp = this.stack[topIdx];
        this.stack[topIdx] = this.stack[swapIdx];
        this.stack[swapIdx] = temp;
        
        this.pc += 2;
        console.log(`SWAPN ${n}: swapped positions 1 and ${n + 1}`);
        break;
      }

      case EXCHANGE: {
        const imm = this.code[this.pc + 1] ?? 0;
        const [n, m] = decodePair(imm);
        
        if (m > this.stack.length) {
          throw new Error(`Stack underflow: EXCHANGE ${n} ${m}`);
        }
        
        // Swap positions n and m (1-indexed from top)
        const idxN = this.stack.length - n;
        const idxM = this.stack.length - m;
        
        const temp = this.stack[idxN];
        this.stack[idxN] = this.stack[idxM];
        this.stack[idxM] = temp;
        
        this.pc += 2;
        console.log(`EXCHANGE ${n} ${m}: swapped positions ${n} and ${m}`);
        break;
      }

      default:
        throw new Error(`Unknown opcode: 0x${opcode.toString(16)}`);
    }

    return true;
  }

  // Run until end
  run(): void {
    while (this.step()) {}
  }
}

// ============ Demo ============

function main() {
  console.log("=== EIP-8024: Deep Stack Manipulation Demo ===\n");

  // 1. Single encoding examples
  console.log("--- Single Encoding (DUPN/SWAPN) ---");
  const testDepths = [17, 50, 100, 107, 108, 200, 235];
  for (const n of testDepths) {
    const imm = encodeSingle(n);
    const decoded = decodeSingle(imm);
    console.log(`n=${n} -> immediate=0x${imm.toString(16).padStart(2, "0")} (${imm}) -> decoded=${decoded}`);
  }

  // 2. Pair encoding examples
  console.log("\n--- Pair Encoding (EXCHANGE) ---");
  const testPairs: [number, number][] = [[1, 2], [3, 15], [5, 20], [1, 28]];
  for (const [n, m] of testPairs) {
    const imm = encodePair(n, m);
    const [dn, dm] = decodePair(imm);
    console.log(`(${n}, ${m}) -> immediate=0x${imm.toString(16).padStart(2, "0")} -> decoded=(${dn}, ${dm})`);
  }

  // 3. Reserved range demonstration
  console.log("\n--- Reserved Range (JUMPDEST Compatibility) ---");
  console.log("Values 91-127 (0x5b-0x7f) are reserved because 0x5b = JUMPDEST");
  console.log("This ensures backward-compatible disassembly");

  // 4. Stack simulation
  console.log("\n--- EVM Stack Simulation ---");
  
  // Build a small program:
  // 1. DUPN 20 (duplicate the 20th stack item)
  // 2. SWAPN 17 (swap top with 18th item)
  // 3. EXCHANGE 3, 10 (swap 3rd and 10th items)
  
  const bytecode = new Uint8Array([
    DUPN, encodeSingle(20),
    SWAPN, encodeSingle(17),
    EXCHANGE, encodePair(3, 10)
  ]);
  
  console.log(`Bytecode: ${Array.from(bytecode).map(b => "0x" + b.toString(16).padStart(2, "0")).join(" ")}`);
  
  // Initialize simulator with a 25-element stack
  const sim = new EVMStackSimulator(bytecode);
  for (let i = 1; i <= 25; i++) {
    sim.push(BigInt(i * 100)); // Stack: [100, 200, 300, ..., 2500]
  }
  
  console.log("\nInitial stack (bottom to top, last 10):");
  console.log(sim.getStack().slice(-10).map(v => v.toString()).join(", "));
  
  console.log("\nExecuting instructions:");
  sim.run();
  
  console.log("\nFinal stack (bottom to top, last 10):");
  console.log(sim.getStack().slice(-10).map(v => v.toString()).join(", "));

  // 5. Bytecode generation helpers
  console.log("\n--- Bytecode Generation ---");
  console.log(`DUPN(50):  0x${DUPN.toString(16)} 0x${encodeSingle(50).toString(16).padStart(2, "0")}`);
  console.log(`SWAPN(100): 0x${SWAPN.toString(16)} 0x${encodeSingle(100).toString(16).padStart(2, "0")}`);
  console.log(`EXCHANGE(5,20): 0x${EXCHANGE.toString(16)} 0x${encodePair(5, 20).toString(16).padStart(2, "0")}`);

  console.log("\n=== Done ===");
}

main();

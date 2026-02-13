/**
 * Test suite for Multi-Point KZG Evaluation POC
 * Demonstrates EIP-8141 efficiency gains
 */

const { MultiPointKZG } = require('./multi-eval');

function runTests() {
    console.log('=== Multi-Point KZG Evaluation POC ===\n');
    console.log('Based on EIP-8141: Multi KZG Point Evaluation Precompile\n');

    const kzg = new MultiPointKZG();
    
    // Test polynomial: P(x) = 1 + 2x + 3x^2 + x^3
    const polynomial = [1, 2, 3, 1];
    console.log('Test polynomial: P(x) = 1 + 2x + 3x^2 + x^3');

    // Generate test evaluations
    const testPoints = [5, 10, 15, 20, 25];
    const evaluations = testPoints.map(x => ({
        x: x,
        y: kzg.evaluatePolynomial(polynomial, x)
    }));

    console.log('\nTest evaluation points:');
    evaluations.forEach(eval => {
        console.log(`  P(${eval.x}) = ${eval.y}`);
    });

    // Compare single-point vs multi-point approaches
    const comparison = kzg.compareApproaches(evaluations);
    
    // Test with different batch sizes
    console.log('\n=== Scaling Analysis ===');
    console.log('Points\tSingle-Point\tMulti-Point\tSavings');
    console.log('-----\t------------\t-----------\t-------');
    
    for (let numPoints = 1; numPoints <= 20; numPoints += 3) {
        const testEvals = evaluations.slice(0, Math.min(numPoints, evaluations.length));
        while (testEvals.length < numPoints) {
            const x = 30 + testEvals.length;
            testEvals.push({
                x: x,
                y: kzg.evaluatePolynomial(polynomial, x)
            });
        }
        
        const singleCost = kzg.estimateSinglePointOps() * numPoints;
        const batchCost = kzg.estimateBatchOps(numPoints);
        const savings = ((singleCost - batchCost) / singleCost * 100).toFixed(1);
        
        console.log(`${numPoints}\t${singleCost}\t\t${batchCost}\t\t${savings}%`);
    }

    console.log('\n=== Key Insights ===');
    console.log('1. Multi-point evaluation reduces verification overhead');
    console.log('2. Gas savings increase with number of evaluation points');
    console.log('3. Batch verification is O(log n + m) vs O(n * m) for single-point');
    console.log('4. Critical for L2 rollup efficiency and DA sampling');
    
    console.log('\n=== EIP-8141 Benefits ===');
    console.log('- Reduces gas costs for multi-point KZG verifications');
    console.log('- Enables efficient DA sampling in rollups');
    console.log('- Supports Danksharding polynomial commitments');
    console.log('- Improves zkEVM polynomial proof verification');
    
    return comparison;
}

if (require.main === module) {
    runTests();
}

module.exports = { runTests };
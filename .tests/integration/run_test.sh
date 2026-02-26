#!/bin/bash

# Integration test script for wp3_validation_workflow
# This script generates test checksums and validates them

set -euo pipefail

# Change to the repository root
cd "$(dirname "$0")/../.."

echo "=== WP3 Validation Workflow Integration Test ==="
echo "Setting up test environment..."

# Create results directory
mkdir -p .tests/integration/results

echo "Step 1: Generate checksums for test data..."
# Use create_validation_data to generate real checksums for our test files
snakemake create_validation_data \
    --configfile .tests/integration/test_config.yaml \
    --use-singularity \
    --singularity-args "--bind $(pwd)" \
    --cores 1 \
    --quiet

# Copy the generated checksums to our test input
echo "Step 2: Update test input with real checksums..."
cp .tests/integration/results/new_validation_data.tsv .tests/integration/test_input.tsv

echo "Step 3: Run validation workflow..."
# Now run the actual validation
snakemake \
    --configfile .tests/integration/test_config.yaml \
    --use-singularity \
    --singularity-args "--bind $(pwd)" \
    --cores 1 \
    --quiet

echo "Step 4: Check results..."
# Verify validation results
if [ -f ".tests/integration/results/validation_summary.txt" ]; then
    echo "✓ Validation summary generated"
    echo "--- Validation Summary ---"
    cat .tests/integration/results/validation_summary.txt
    echo "--- End Summary ---"
    
    # Check if all files passed
    if grep -q "Failed: 0" .tests/integration/results/validation_summary.txt; then
        echo "✓ All files passed validation!"
        exit_code=0
    else
        echo "✗ Some files failed validation"
        exit_code=1
    fi
else
    echo "✗ Validation summary not found"
    exit_code=1
fi

echo "=== Integration Test Complete ==="
exit $exit_code
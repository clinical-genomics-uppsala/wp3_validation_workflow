#!/bin/bash

# Integration test for validation failures
# This test verifies that the workflow correctly detects and reports validation failures

set -euo pipefail

# Change to the repository root
cd "$(dirname "$0")/../.."

echo "=== WP3 Validation Workflow Failure Test ==="
echo "Testing that validation failures are properly detected..."

# Create results directory
mkdir -p .tests/integration/results_failures

echo "Step 1: Run validation with intentionally wrong checksums..."
# Run validation with wrong checksums (should fail for some files)
# Use --keep-going to ensure we get results even with failures
set +e  # Allow failures
snakemake \
    --configfile .tests/integration/test_config_failures.yaml \
    --use-singularity \
    --singularity-args "--bind $(pwd)" \
    --cores 1 \
    --keep-going \
    --quiet
validation_exit_code=$?
set -e

echo "Step 2: Verify that failures were detected..."

# Check that validation summary was created
if [ -f ".tests/integration/results_failures/validation_summary.txt" ]; then
    echo "✓ Validation summary generated"
    echo "--- Validation Summary ---"
    cat .tests/integration/results_failures/validation_summary.txt
    echo "--- End Summary ---"
    
    # Check that some files failed (we expect 2 failures)
    failed_count=$(grep "Failed:" .tests/integration/results_failures/validation_summary.txt | sed 's/.*Failed: \([0-9]*\).*/\1/')
    passed_count=$(grep "Passed:" .tests/integration/results_failures/validation_summary.txt | sed 's/.*Passed: \([0-9]*\).*/\1/')
    
    if [ "$failed_count" -eq 2 ]; then
        echo "✓ Expected 2 failures detected: $failed_count failures, $passed_count passes"
        
        # Verify that the failed files are the ones with wrong checksums
        if grep -q "test_sample.vcf.gz" .tests/integration/results_failures/validation_summary.txt && \
           grep -q "test_sample.alignment_summary_metrics.txt" .tests/integration/results_failures/validation_summary.txt; then
            echo "✓ Correct files identified as failed"
        else
            echo "✗ Wrong files identified as failed"
            exit 1
        fi
        
        # Check that detailed error messages are present
        if grep -q "INTENTIONALLY_WRONG_CHECKSUM" .tests/integration/results_failures/validation_summary.txt; then
            echo "✓ Detailed error messages present"
        else
            echo "✗ Missing detailed error messages"
            exit 1
        fi
        
        echo "✓ Failure detection test passed!"
        exit_code=0
    else
        echo "✗ Expected 2 failures but got $failed_count"
        exit_code=1
    fi
    
    # Verify workflow exited with non-zero code due to failures
    if [ "$validation_exit_code" -ne 0 ]; then
        echo "✓ Workflow correctly exited with error code due to validation failures"
    else
        echo "⚠ Warning: Workflow should exit with non-zero code when validations fail"
    fi
    
else
    echo "✗ Validation summary not found"
    exit_code=1
fi

echo "=== Failure Detection Test Complete ==="
exit $exit_code
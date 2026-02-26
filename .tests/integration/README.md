# Integration Test

This directory contains integration tests for the WP3 validation workflow, including both success and failure scenarios.

## Test Files

### Test Data (`data/`)
- **`test_sample.vcf.gz`**: Small VCF file with 3 variants for testing VCF validation
- **`test_sample.alignment_summary_metrics.txt`**: Picard alignment summary metrics file  
- **`test_sample.samtools-stats.txt`**: Samtools stats output file
- **`test_sample.cram`**: Placeholder CRAM file (not used in tests due to binary format requirements)

### Configuration Files
- **`test_config.yaml`**: Test configuration with reduced resource requirements (success case)
- **`test_config_failures.yaml`**: Test configuration for failure detection tests
- **`test_input.tsv`**: Input file listing test files with placeholder checksums (success case)
- **`test_input_failures.tsv`**: Input file with intentionally wrong checksums (failure case)

### Test Scripts
- **`run_test.sh`**: Basic integration test (all validations should pass)
- **`test_failures.sh`**: Failure detection test (some validations should fail)
- **`run_all_tests.sh`**: Complete test suite running both success and failure tests

### Infrastructure
- **`README.md`**: This documentation
- **`Makefile`**: Convenient targets for running different test scenarios

## Running Tests

### Complete Test Suite
```bash
# Run all tests (success + failure detection)
./.tests/integration/run_all_tests.sh

# Or using make
cd .tests/integration && make test-all
```

### Individual Tests
```bash
# Test normal validation (should pass)
./.tests/integration/run_test.sh
cd .tests/integration && make test

# Test failure detection (should detect failures)  
./.tests/integration/test_failures.sh
cd .tests/integration && make test-failures
```

## Test Scenarios

### Test 1: Success Case (`run_test.sh`)
1. **Generate Reference Checksums**: Uses `create_validation_data` to generate checksums for test files
2. **Update Test Input**: Copies generated checksums to the test input TSV
3. **Run Validation**: Executes the full validation workflow against the test data
4. **Verify Results**: Checks that all files pass validation

**Expected Output**: All files pass validation
```
✓ All files passed validation!
```

### Test 2: Failure Detection (`test_failures.sh`)
1. **Generate Correct Checksums**: Creates reference checksums for comparison
2. **Use Wrong Checksums**: Runs validation with intentionally incorrect checksums
3. **Verify Failure Detection**: Confirms that failures are properly detected and reported
4. **Check Error Details**: Verifies detailed error messages are provided

**Expected Output**: Specific failures detected
```
✓ Expected 2 failures detected: 2 failures, 1 passes
✓ Correct files identified as failed
✓ Detailed error messages present
```

## Expected Results

### Success Test Should Show:
- Total files: 3
- Passed: 3  
- Failed: 0
- All files listed under "PASSED FILES"

### Failure Test Should Show:
- Total files: 3
- Passed: 1
- Failed: 2
- VCF and metrics files listed under "FAILED FILES" with checksum mismatches
- Detailed error messages showing expected vs calculated checksums

## Test Coverage

This integration test suite covers:
- **File Type Validation**: VCF (compressed), metrics files, samtools stats
- **Success Path**: Normal workflow execution with correct checksums
- **Failure Detection**: Verification that checksum mismatches are caught
- **Error Reporting**: Detailed failure messages in summary reports
- **Workflow Robustness**: Using `--keep-going` to complete validation despite failures
- **Result Generation**: Both raw results and human-readable summaries

## Manual Testing

You can also run components manually:

```bash
# Generate test checksums (success case)
snakemake create_validation_data --configfile .tests/integration/test_config.yaml --use-singularity --singularity-args "--bind $(pwd)" --cores 1

# Run validation with correct checksums
snakemake --configfile .tests/integration/test_config.yaml --use-singularity --singularity-args "--bind $(pwd)" --cores 1

# Run validation with wrong checksums (expect failures)
snakemake --configfile .tests/integration/test_config_failures.yaml --use-singularity --singularity-args "--bind $(pwd)" --cores 1 --keep-going
```

Results will be written to:
- `.tests/integration/results/` (success case)
- `.tests/integration/results_failures/` (failure case)
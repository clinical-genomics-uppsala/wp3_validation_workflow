# Output

## Validation Workflow Output

### Primary Result Files
- **`validation_results/validation_results.txt`**: Raw consolidated validation results
  - Contains concatenated contents of all individual validation files
  - Each line shows either "Validated: filename" or "Failed validation: filename: expected != calculated"
  - Useful for scripts and detailed programmatic analysis

- **`validation_results/validation_summary.txt`**: Human-readable validation summary report
  - **SUMMARY section**: Shows total files processed, number passed/failed
  - **PASSED FILES section**: Lists all files that passed validation with ✓ marks
  - **FAILED FILES section**: Lists failed files with ✗ marks and detailed error messages
  - **Error details include**: Expected vs calculated checksums, missing validation outputs
  - Primary file for reviewing validation results

### Individual File Outputs
- `validation/{file}.validated`: Individual validation results per file
- `checksums/{file}.checksum`: Calculated checksums per file

### Example `validation_summary.txt` Format

```
VALIDATION SUMMARY REPORT
=========================

SUMMARY:
  Total files: 15
  Passed: 12
  Failed: 3

PASSED FILES:
-------------
  ✓ sample1.vcf.gz
  ✓ sample2.cram
  ✓ metrics.alignment_summary_metrics.txt

FAILED FILES:
-------------
  ✗ sample3.vcf.gz
    Failed validation: sample3.vcf.gz: expected_hash != calculated_hash
  
  ✗ sample4.bam: No validation output (job failed)
```


## `create_validation_data` Workflow Output

- `validation_results/new_validation_data.tsv`: New validation data file with calculated checksums
- `checksums/{file}.checksum`: Individual checksum files for each processed file

The `new_validation_data.tsv` file can be used as input for subsequent validation runs by copying it to your input file (e.g., `test_input.tsv`).

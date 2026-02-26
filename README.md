# WP3 Pipeline Validation Workflow 

Validate the output files from CGUs WP3 pipelines. This is used to track changes in pipeline results and to guard against any unexpected changes during pipeline updates.

## Overview

The pipeline validates various bioinformatics file types by calculating checksums and comparing them to expected values. It supports:

- VCF files
- BAM or CRAM files 
- Metrics files (insert_size_metrics, HsMetrics, alignment_summary_metrics, duplication_metrics etc.)
- MultiQC HTML reports
- Samtools stats files
- Various other file types

## File Structure

```
wp3_validation_workflow/
├── Snakefile                    # Main workflow file
├── config.yaml                 # Configuration parameters
├── test_input.tsv              # Example input file
├── requirements.txt            # Python dependencies
├── setup_slurm.sh              # Setup script for SLURM environment
├── profiles/
│   └── slurm/                  # SLURM executor profile
│       └── config.yaml         # SLURM profile configuration
└── rules/
    |── common-smk              # rule input functions 
    ├── vcf_validation.smk      # VCF file validation rules
    ├── bam_validation.smk      # BAM file validation rules
    ├── metrics_validation.smk  # Metrics file validation rules
    └── misc_validation.smk     # Other file type validation rules
```

## Usage

### 1. Setup Environment

Install Snakemake and dependencies:

```bash
python3.11 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

**Note**: The requirements include the SLURM executor plugin for cluster execution.


### 2. Prepare Input File

Create a tab-separated file (`test_input.tsv`) with columns:
- `file`: Path to the file to validate
- `checksum`: Expected MD5 checksum

Example:
```
file	checksum
data/sample.vcf	d41d8cd98f00b204e9800998ecf8427e
results/sample.T.bam	e3b0c44298fc1c149afbf4c8996fb924
```

#### For `create_validation_data` Workflow

When using the `create_validation_data` target to generate new checksums, the input file format is the same, but the `checksum` column values are ignored (can be placeholder values). The workflow will:

1. Read the `file` column to identify which files to process
2. Generate new checksums for each file using the same logic as validation
3. Output a new TSV file (`results/new_validation_data.tsv`) with updated checksums

Example input for checksum generation:
```
file	checksum
data/sample.vcf	PLACEHOLDER
results/sample.T.bam	PLACEHOLDER
metrics/sample.alignment_summary_metrics.txt	PLACEHOLDER
```

The generated output will contain the actual calculated checksums:
```
data/sample.vcf	a1b2c3d4e5f6789012345678901234567
results/sample.T.bam	b2c3d4e5f6789012345678901234567a1
metrics/sample.alignment_summary_metrics.txt	c3d4e5f6789012345678901234567a1b2
```

### 3. Configure Workflow

Edit [config.yaml](config.yaml) to set:
- `input`: Path to your input TSV file
- `publish_dir`: Directory for output results
- `resources`: Resource requirements for different rule types (memory, runtime, CPUs)

**Resource Configuration**: The workflow uses configurable resources for different validation tasks:
- `vcf_validation`: For VCF file processing (default: 8GB RAM, 4 hours)
- `bam_validation`: For BAM/CRAM processing (default: 6GB RAM, 4 hours) 
- `metrics_validation`: For metrics files (default: 2GB RAM, 4 hours)
- `misc_validation`: For other file types (default: 4GB RAM, 4 hours)
- `summary_tasks`: For result collection (default: 2GB RAM, 4 hours)

You can customize these in [config.yaml](config.yaml) to match your cluster's requirements and file sizes.

### 4. Run Validation

```bash
# Dry run to check workflow
snakemake -n --configfiles config/config.yaml config/config_${pipeline}.yaml

# Run locally 
snakemake  --configfiles config/config.yaml config/config_${pipeline}.yaml--use-singularity --singularity-args "--bind $(pwd)" --keep-going -j 2

# Run on SLURM cluster using the provided profile
# (executor: slurm, singularity settings, and keep-going are specified in profiles/slurm/config.yaml)
snakemake --profile profiles/slurm --configfiles config/config.yaml config/config_${pipeline}.yaml

# Generate a new md5sum tsv file from a directory of results (checksum generation mode)
snakemake create_validation_data --configfiles config/config.yaml config/config_${pipeline}.yaml --use-singularity --singularity-args "--bind $(pwd)" 

# Generate a new md5sum tsv file instead of validating on SLURM
snakemake create_validation_data --profile profiles/slurm --configfiles config/config.yaml config/config_${pipeline}.yaml
```

**Note on `create_validation_data`**: This target generates new checksums for the files listed in your input TSV, rather than validating against existing checksums. Use this when:
- Setting up validation data for the first time
- Files have been updated and you need new reference checksums
- Creating checksums for a new dataset

The workflow will create `results/new_validation_data.tsv` with the format needed for subsequent validation runs.


### 5. SLURM Cluster Usage

The pipeline includes a SLURM profile for cluster execution:

- **Profile location**: `profiles/slurm/`
- **Configuration**: Edit `profiles/slurm/config.yaml`
- **Default resources**: 4GB RAM, 4 hour runtime, 1 CPU per job
- **Partition**: `low` (modify in `config.yaml` if needed)

To customize for your cluster:
1. Edit `profiles/slurm/config.yaml` to set your partition in `default-resources`
2. Adjust default resources in `profiles/slurm/config.yaml`  
3. Modify resource requirements in `config.yaml` for different rule types
4. Individual rules can override resources using the `resources:` directive

Example resource customization in [config.yaml](config.yaml):
```yaml
resources:
  vcf_validation:
    mem_mb: 16000  # Increase for large VCF files
    runtime: 60    # Increase timeout for complex processing
    cpus_per_task: 2
```

## Output

### Validation Workflow Output

#### Primary Result Files
- **`results/validation_results.txt`**: Raw consolidated validation results
  - Contains concatenated contents of all individual validation files
  - Each line shows either "Validated: filename" or "Failed validation: filename: expected != calculated"
  - Useful for scripts and detailed programmatic analysis
  
- **`results/validation_summary.txt`**: Human-readable validation summary report
  - **SUMMARY section**: Shows total files processed, number passed/failed
  - **PASSED FILES section**: Lists all files that passed validation with ✓ marks
  - **FAILED FILES section**: Lists failed files with ✗ marks and detailed error messages
  - **Error details include**: Expected vs calculated checksums, missing validation outputs
  - Primary file for reviewing validation results

#### Individual File Outputs  
- `validation/{file}.validated`: Individual validation results per file
- `checksums/{file}.checksum`: Calculated checksums per file

#### Example `validation_summary.txt` Format:
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

### `create_validation_data` Workflow Output
- `validatiion_results/new_validation_data.tsv`: New validation data file with calculated checksums
- `checksums/{file}.checksum`: Individual checksum files for each processed file

The `new_validation_data.tsv` file can be used as input for subsequent validation runs by copying it to your input file (e.g., `test_input.tsv`).

## Validation Logic

The pipeline replicates the exact validation logic from the Nextflow workflow:

1. **VCF files**: Extracts content after #CHROM header, sorts INFO field annotations
2. **BAM files**: Uses samtools view to extract alignments
3. **Metrics files**: Extracts content after "## METRICS" marker
4. **MultiQC reports**: Normalizes timestamp and path information
5. **Other files**: Direct MD5 checksum calculation

## File Type Detection

Files are processed based on filename patterns:
- `.vcf.gz$`: Compressed VCF validation  
- `.bam|.cram$`: DNA CRAM validation
- Various metrics and report file patterns

## Error Handling

- Files that don't match any pattern use default validation
- Validation failures exit with error code 1
- Missing files or invalid checksums are reported in output
- The pipeline is run with --keep-going and generates a validation_summary.txt under validation_results which lists which files have failed the validation
- The pipeline will have an exit 1 when a validation error is detected

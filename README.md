# Validation Workflow - Snakemake Version

This Snakemake pipeline replicates the functionality of the Nextflow validation workflow in `validate_result.nf`.

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

### 3. Configure Workflow

Edit `config.yaml` to set:
- `input`: Path to your input TSV file
- `publish_dir`: Directory for output results

### 4. Run Validation

```bash
# Dry run to check workflow
snakemake -n

# Generate a new md5sum tsv file from a directory of results
snakemake create_validation_data --use-singularity --singularity-args "--bind $(pwd)" 

# Generate validation data (checksums) instead of validating
snakemake --use-singularity --singularity-args "--bind $(pwd)" --keep-going -j 2
```

## Output

- `results/validation_results.txt`: Consolidated validation results
-  `results/validation_summary .txt`:  Summary if files that passed or failed validation
- `validation/{file}.validated`: Individual validation results per file
- `checksums/{file}.checksum`: Calculated checksums per file
- `results/new_validation_data.tsv`: New validation data file (when using create_validation_data target)

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

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

In addition, when **Genome in a Bottle (GIAB)** control samples are detected in the input TSV, the workflow automatically runs accuracy benchmarking:

- **SNV/Indel benchmarking** using [hap.py](https://github.com/Illumina/hap.py) against GIAB v4.2.1 truth sets for HG001 and/or HG002 (and their aliases NA12878, HM12878, NA24385, HM24385).
- **Structural variant (SV) benchmarking** using [Truvari](https://github.com/ACEnglish/truvari) against the GIAB T2T HG002 SV truth set for HG002 samples.

Multiple replicates of the same GIAB sample (e.g. `HM24385-1` and `HM24385-2`) are each benchmarked independently with results written to separate output directories.

## File Structure

```
wp3_validation_workflow/
├── requirements.txt             # Python dependencies
├── config/
│   ├── config.yaml             # Base configuration
│   ├── resources.yaml          # Resource requirements (mem, runtime, CPUs per rule type)
│   └── config_<pipeline>.yaml  # Pipeline-specific configuration
├── profiles/
│   └── slurm/                  # SLURM executor profile
│       └── config.yaml         # SLURM profile configuration
├── scripts/
│   └── process_truvari_ga4gh_vcfs.py  # Truvari GA4GH summary script
└── workflow/
    ├── Snakefile               # Main workflow file
    └── rules/
        ├── common.smk              # Shared input functions and helpers
        ├── vcf_validation.smk      # VCF file validation rules
        ├── bam_validation.smk      # BAM/CRAM file validation rules
        ├── metrics_validation.smk  # Metrics file validation rules
        ├── misc_validation.smk     # Other file type validation rules
        ├── happy_benchmarking.smk  # SNV/Indel GIAB benchmarking (hap.py)
        └── truvari_benchmarking.smk  # SV GIAB benchmarking (Truvari)
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
- `checksum`: Expected MD5 checksum *(optional — rows without a checksum are still used as inputs to benchmarking rules but are skipped for checksum validation)*

Example:
```
file	checksum
data/sample.vcf	d41d8cd98f00b204e9800998ecf8427e
results/sample.T.bam	e3b0c44298fc1c149afbf4c8996fb924
results/HG002.snv_indels.vcf.gz
results/HG002.svdb_merged.vcf.gz
```

#### For `create_validation_data` Workflow

When using the `create_validation_data` target to generate new checksums, the `checksum` column is optional. The workflow will:

1. Read the `file` column to identify which files to process
2. Generate new checksums for each file using the same logic as validation
3. Output a new TSV file (`validation_results/new_validation_data.tsv`) with updated checksums

Example input for checksum generation:
```
file
data/sample.vcf
results/sample.T.bam
metrics/sample.alignment_summary_metrics.txt
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
- `happy_benchmarking`: For hap.py SNV/Indel benchmarking (default: 20GB RAM, 12 hours, 16 CPUs)
- `truvari_benchmarking`: For Truvari SV benchmarking (default: 96GB RAM, 4 hours, 16 CPUs)

You can customize these in `config/config.yaml` to match your cluster's requirements and file sizes.

**GIAB Benchmarking Configuration**: The following settings control automatic GIAB sample detection and benchmarking:

```yaml
# File suffix used to identify SNV/Indel VCFs for hap.py
happy_vcf_suffix: "snv_indels.vcf.gz"

# File suffix used to identify SV VCFs for Truvari
truvari_vcf_suffix: "svdb_merged.vcf.gz"

# Path to reference genome FASTA (required for benchmarking)
reference_genome: "/path/to/GRCh38.fasta"

# Container images
happy_benchmarking:
  container: "docker://hydragenetics/hap.py:0.3.15"
  # Optional: path to a pre-built RTG SDF template for vcfeval (avoids rebuilding on every run)
  # vcfeval_template: "/path/to/reference.sdf"

truvari_benchmarking:
  container: "docker://quay.io/biocontainers/truvari:5.3.0--pyhdfd78af_0"
  # Optional: override Truvari bench parameters (Truvari defaults shown)
  # refdist: 500
  # pctseq: 0.7
  # pctsize: 0.7
  # pctovl: 0.0
  # pick: single
  # bnddist: 100
  # chunksize: 1000
  # max_resolve: 25000
  # typeignore: false
  # no_roll: false
  # dup_to_ins: false
  # no_decompose: false
```

### 4. Run Validation

```bash
# Dry run to check workflow
snakemake -n --configfiles config/config.yaml config/config_${pipeline}.yaml

# Run locally
snakemake --configfiles config/config.yaml config/config_${pipeline}.yaml \
  --use-singularity --singularity-args "--bind $(pwd)" --keep-going -j 2

# Run on SLURM cluster using the provided profile
# (executor: slurm, singularity settings, and keep-going are specified in profiles/slurm/config.yaml)
snakemake --profile profiles/slurm --configfiles config/config.yaml config/config_${pipeline}.yaml

# Run only the GIAB hap.py benchmarking
snakemake run_happy_benchmarking --profile profiles/slurm \
  --configfiles config/config.yaml config/config_${pipeline}.yaml

# Run only the GIAB Truvari SV benchmarking
snakemake run_truvari_benchmarking --profile profiles/slurm \
  --configfiles config/config.yaml config/config_${pipeline}.yaml

# Run both hap.py and Truvari GIAB benchmarking together
snakemake run_giab_benchmarking --profile profiles/slurm \
  --configfiles config/config.yaml config/config_${pipeline}.yaml

# Generate a new md5sum tsv file from a directory of results (checksum generation mode)
snakemake create_validation_data --configfiles config/config.yaml config/config_${pipeline}.yaml \
  --use-singularity --singularity-args "--bind $(pwd)"

# Generate a new md5sum tsv file instead of validating on SLURM
snakemake create_validation_data --profile profiles/slurm \
  --configfiles config/config.yaml config/config_${pipeline}.yaml
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
- **Partition**: `low_bkup` (modify in `profiles/slurm/config.yaml` if needed)

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
- `validation_results/new_validation_data.tsv`: New validation data file with calculated checksums
- `checksums/{file}.checksum`: Individual checksum files for each processed file

The `new_validation_data.tsv` file can be used as input for subsequent validation runs by copying it to your input file (e.g., `test_input.tsv`).

### GIAB Benchmarking Output

Benchmarking runs automatically when a GIAB sample is detected in the input TSV. Each sample gets its own output directory named after the sample identifier found in the file path.

#### hap.py SNV/Indel Benchmarking

Triggered when any input file path contains `HG001`, `NA12878`, `HM12878`, `HG002`, `NA24385`, or `HM24385` **and** the file ends with `happy_vcf_suffix` (default: `snv_indels.vcf.gz`).

```
validation_results/
└── happy_{sample}/
    ├── {sample}_happy.out.summary.csv              # Per-type precision/recall/F1 summary
    ├── {sample}_happy.out.extended.csv             # Extended per-region stats
    ├── {sample}_happy.out.vcf.gz                   # Annotated VCF
    ├── {sample}_happy.out.vcf.gz.tbi               # VCF index
    ├── {sample}_happy.out.metrics.json.gz          # Run metrics
    ├── {sample}_happy.out.runinfo.json             # Run info
    ├── {sample}_happy.out.roc.all.csv.gz           # ROC curve (all variants)
    ├── {sample}_happy.out.roc.Locations.INDEL.csv.gz
    ├── {sample}_happy.out.roc.Locations.INDEL.PASS.csv.gz
    ├── {sample}_happy.out.roc.Locations.SNP.csv.gz
    └── {sample}_happy.out.roc.Locations.SNP.PASS.csv.gz
```

A shared RTG SDF index is built once from the reference FASTA and reused across all samples:
```
benchmark_happy/
└── reference.sdf/   # RTG vcfeval template (built by build_vcfeval_template rule)
```

The truth sets used are GIAB NIST v4.2.1:
- **HG001**: `HG001_GRCh38_1_22_v4.2.1_benchmark.vcf.gz`
- **HG002**: `HG002_GRCh38_1_22_v4.2.1_benchmark.vcf.gz`

#### Truvari SV Benchmarking

Triggered when any input file path contains `HG002`, `NA24385`, or `HM24385` **and** the file ends with `truvari_vcf_suffix` (default: `svs.vcf.gz`; set to `svdb_merged.vcf.gz` in `config/config.yaml`). Currently only HG002 truth sets are available.

```
validation_results/
└── truvari_{sample}/
    ├── ga4gh_with_refine.size_stratified.accuracy.stats.txt  # Size-stratified summary
    ├── ga4gh_with_refine.base.vcf.gz                         # GA4GH-labelled truth VCF
    ├── ga4gh_with_refine.comp.vcf.gz                         # GA4GH-labelled query VCF
    └── ...                                                   # bench/refine working files
```

The Truvari pipeline runs three steps:
1. `truvari bench` — compares the query SV VCF against the GIAB T2T HG002 truth set
2. `truvari refine` — sequence-resolves candidate regions using MAFFT
3. `truvari ga4gh` — converts results to GA4GH format for standardised reporting

The truth set used is the GIAB T2T draft benchmark:
- `GRCh38_HG2-T2TQ100-V1.1_stvar.vcf.gz` (autosomes only, SVTYPE-filtered)

The size-stratified summary (`*.accuracy.stats.txt`) reports precision, recall and F1 for all SVs and broken down by size bins and variant type (DEL/INS).

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

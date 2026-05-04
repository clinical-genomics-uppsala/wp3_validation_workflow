# Usage

## 1. Setup Environment

Install Snakemake and dependencies:

```bash
python3.11 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

**Note**: The requirements include the SLURM executor plugin for cluster execution.


## 2. Prepare Input File

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

### For `create_validation_data` Workflow

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


## 3. Configure Workflow

Edit [config.yaml](../config/config.yaml) to set:
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


## 4. Run Validation

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


## 5. SLURM Cluster Usage

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

Example resource customization in [config.yaml](../config/config.yaml):
```yaml
resources:
  vcf_validation:
    mem_mb: 16000  # Increase for large VCF files
    runtime: 60    # Increase timeout for complex processing
    cpus_per_task: 2
```

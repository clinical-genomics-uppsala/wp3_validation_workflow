# Overview

The pipeline validates various bioinformatics file types by calculating checksums and comparing them to expected values. It supports:

- VCF files
- BAM or CRAM files
- Metrics files (insert_size_metrics, HsMetrics, alignment_summary_metrics, duplication_metrics etc.)
- Samtools stats files
- Various other file types

In addition, when **Genome in a Bottle (GIAB)** control samples are detected in the input TSV, the workflow automatically runs accuracy benchmarking.

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

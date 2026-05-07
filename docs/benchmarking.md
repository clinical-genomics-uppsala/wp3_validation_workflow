# GIAB Benchmarking

The workflow includes automatic benchmarking against GIAB (Genome in a Bottle) reference samples when VCF files from known GIAB samples are detected in the input. This provides standardized performance metrics for variant calling pipelines.

## Supported Samples

**For SNV/Indel Benchmarking (hap.py):**
- HG001 / NA12878 (CEPH/Utah Female)
- HG002 / NA24385 (Ashkenazi Trio Son)

**For SV Benchmarking (Truvari):**
- HG002 / NA24385 (Ashkenazi Trio Son)

## Benchmark Sets and Evaluation Tools

- **SNV/Indel benchmarking** using [hap.py](https://github.com/Illumina/hap.py) against GIAB v4.2.1 truth sets for HG001 and/or HG002 (and their aliases NA12878, HM12878, NA24385, HM24385).
- **Structural variant (SV) benchmarking** using [Truvari](https://github.com/ACEnglish/truvari) against the GIAB T2T HG002 SV truth set for HG002 samples.

## Automatic Detection

Benchmarking is triggered automatically when:
1. Input files contain GIAB sample identifiers (HG001, NA12878, HM12878, HG002, NA24385, HM24385)
2. Files match the configured VCF suffix patterns:
For example:
   - `happy_vcf_suffix`: For SNV/indel VCFs (default: `snv_indels.vcf.gz`)
   - `truvari_vcf_suffix`: For SV VCFs (default: `svdb_merged.vcf.gz`)
These suffices can be customised in the config file for the pipeline being validated. See documentation on Configuration in the next section.

## Configuration

Configure benchmarking in your pipeline-specific config file:

```yaml
# Reference genome (required for benchmarking)
reference_genome: "/path/to/GRCh38.fasta"

# VCF file suffixes to identify benchmarking candidates
happy_vcf_suffix: "_snvs_annotated_research.vcf.gz"
truvari_vcf_suffix: "_svs_annotated_research.vcf.gz"

# Happy benchmarking configuration
happy_benchmarking:
  container: "docker://hydragenetics/hap.py:0.3.15"

# Truvari benchmarking configuration
truvari_benchmarking:
  container: "docker://quay.io/biocontainers/truvari:5.3.0--pyhdfd78af_0"
  refdist: 2000        # Reference distance threshold
  pctseq: 0.7          # Percent sequence similarity
  pctsize: 0.7         # Percent size similarity
  pctovl: 0.0          # Percent reciprocal overlap
  passonly: false      # Only compare PASS variants
  chunksize: 5000      # Chunk size for parallelization

# Benchmarking report container
benchmarking_report:
  container: "docker://hydragenetics/quarto:1.8.27"
```

## Benchmarking Outputs

### SNV/Indel Benchmarking (hap.py)
Located in `{publish_dir}/happy_{sample}/`:
- `{sample}_happy.out.summary.csv`: Summary statistics (precision, recall, F1-score)
- `{sample}_happy.out.extended.csv`: Detailed per-variant type metrics
- `{sample}_happy.out.metrics.json.gz`: Full metrics in JSON format
- `{sample}_happy.out.vcf.gz`: Annotated comparison VCF
- ROC curve data files for quality score analysis

### SV Benchmarking (Truvari)
Located in `{publish_dir}/truvari_{sample}_{caller}/`:
- `ga4gh_with_refine.size_stratified.accuracy.stats.txt`: Size-stratified SV metrics
- `ga4gh_with_refine.base.vcf.gz`: Benchmark truth set with match annotations
- `ga4gh_with_refine.comp.vcf.gz`: Query VCF with match annotations
- Statistics for SV types: DEL, INS stratified by size ranges:
  - [0,50): Small indels
  - [50,500): Medium SVs
  - [500,5000): Large SVs
  - 5000+: Very large SVs

### Benchmarking Report
Located in `{publish_dir}/`:
- `variant_benchmarking_report.html`: Combined HTML report with:
  - Performance comparison across samples and SV callers
  - Size-stratified metrics visualization
  - Precision-Recall tradeoffs
  - Interactive plots for detailed analysis

## Running Benchmarking

Benchmarking runs automatically as part of the main workflow when GIAB samples are detected. However, if only benchmarking is required it can be run on its own.

```bash
# Dry run to see which benchmarking jobs will be triggered
snakemake run_giab_benchmarking -n --configfiles config/config.yaml config/config_pipeline.yaml

# Run with benchmarking and use SLURM for job submission
snakemake run_giab_benchmarking --profile profiles/slurm --configfiles config/config.yaml config/config_pipeline.yaml
```

The workflow will:
1. Download GIAB reference data (truth VCFs and confident regions BED files)
2. Create reference genome index files if needed
3. Run hap.py for SNV/indel samples
4. Run Truvari for SV samples
5. Generate size-stratified statistics
6. Render a combined HTML report (if Jupyter notebook template exists)

## Containers

The benchmarking workflow uses specialized containers:
- **hap.py container**: Contains Illumina's hap.py tool for SNV/indel comparison
- **Truvari container**: Contains Truvari toolkit for SV benchmarking
- **Quarto container**: For rendering the final HTML report (requires working Quarto installation with deno runtime)

## Troubleshooting

**No benchmarking jobs triggered:**
- Check that sample names contain GIAB identifiers (case-sensitive)
- Verify VCF file suffixes match `happy_vcf_suffix` or `truvari_vcf_suffix`
- Ensure files are listed in the input TSV

**Truvari benchmarking fails:**
- Verify `reference_genome` is correctly configured
- Check that reference FASTA is accessible and indexed
- Review Truvari parameters for your data characteristics

**Report rendering fails:**
- Ensure the quarto container has a complete installation
- Check that the notebook template exists
- Verify all required statistics files were generated

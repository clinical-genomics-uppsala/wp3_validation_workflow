# Validation Logic

The pipeline replicates the exact validation logic from the Nextflow workflow:

1. **VCF files**: Extracts content after `#CHROM` header, sorts INFO field annotations
2. **BAM files**: Uses `samtools view` to extract alignments
3. **Metrics files**: Extracts content after the `## METRICS` marker
4. **MultiQC reports**: Normalizes timestamp and path information
5. **Other files**: Direct MD5 checksum calculation

## VCF Normalization Details

The following normalizations are applied to VCF files before hashing, so that cosmetic differences between otherwise identical files produce the same checksum:

- **Header lines** up to (but not including) the `#CHROM` line are skipped — only the column-header line and data lines are hashed.
- **VEP annotation keys** (`CSQ` / `ANN`): comma-separated transcript entries are sorted alphabetically; ampersand-delimited consequence terms within a sub-field are sorted and re-joined with `&`.
- **`most_severe_consequence`**: comma-separated entries are sorted alphabetically.
- **`skip_info_keys`** (config): INFO keys listed here are removed entirely before hashing.
- **`skip_sample_columns`** (config): when set to `true`, the FORMAT column and all genotype columns are dropped before hashing.

### Configuration

```yaml
# INFO keys to exclude from the hash (e.g. run-specific annotation fields)
skip_info_keys:
  - CSQ
  - most_severe_consequence

# Drop FORMAT + sample genotype columns before hashing
skip_sample_columns: true
```

# File Type Detection & Error Handling

## File Type Detection

Files are processed based on filename patterns:

| Pattern | Handler |
|---------|---------|
| `.vcf.gz` | Compressed VCF validation (normalized MD5) |
| `.bam`, `.cram` | DNA CRAM validation via `samtools view` |
| `_metrics.txt`, `.alignment_summary_metrics`, etc. | Metrics file validation (after `## METRICS` marker) |
| `multiqc_report.html` | MultiQC HTML (timestamp/path normalization) |
| `*.stats` (samtools) | Samtools stats validation |
| All other files | Default direct MD5 checksum |

## Error Handling

- Files that don't match any pattern use default validation
- Validation failures exit with error code 1
- Missing files or invalid checksums are reported in `validation_results/validation_summary.txt`
- The pipeline runs with `--keep-going` so a single failure does not stop the rest
- The pipeline exits with code 1 when any validation error is detected

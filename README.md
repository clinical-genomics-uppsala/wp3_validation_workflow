# WP3 Pipeline Validation Workflow

Validate the output files from CGUs WP3 pipelines. This is used to track changes in pipeline results and to guard against any unexpected changes during pipeline updates.

## Documentation

- [Overview & File Structure](docs/overview.md)
- [Usage](docs/usage.md) — setup, input file, configuration, running, SLURM
- [Output](docs/output.md) — validation results, checksums, summary report
- [Validation Logic](docs/validation-logic.md) — VCF normalization, skip options
- [GIAB Benchmarking](docs/benchmarking.md) — hap.py, Truvari, report
- [File Type Detection & Error Handling](docs/file-type-detection.md)
- [Validating WP3 Pipelines](docs/validating_wp3_pipelines.md) - An example on how to use the wp3 validation pipeline with wp3 pipelines on marvin

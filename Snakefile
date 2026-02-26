import pandas as pd
from pathlib import Path
import re

# Configuration
configfile: "config.yaml"

# Default parameters
INPUT_FILE = config.get("input", "test_input.tsv")
PUBLISH_DIR = config.get("publish_dir", "results")

# Read input file with file paths and checksums
input_df = pd.read_csv(INPUT_FILE, sep='\t')
FILES_AND_CHECKSUMS = dict(zip(input_df['file'], input_df['checksum']))

# Include rule files
include: "rules/common.smk"
include: "rules/vcf_validation.smk"
include: "rules/metrics_validation.smk" 
include: "rules/bam_validation.smk"
include: "rules/misc_validation.smk"
include: "rules/happy_benchmarking.smk"

# Rule order to resolve ambiguous rules - prioritize specific rules over general ones
ruleorder: checksum_vcf_gz > checksum_dna_cram > checksum_metrics > checksum_multiqc > checksum_samtools_stats > checksum_collection_of_files > checksum_default > validate_vcf_gz > validate_dna_cram > validate_metrics > validate_multiqc > validate_samtools_stats > validate_collection_of_files > validate_default

# Determine which happy benchmarking targets to include based on input files
happy_targets = []
if any(any(name in f for name in ["HG001", "NA12878", "HM12878"]) and f.endswith(".vcf.gz") for f in FILES_AND_CHECKSUMS.keys()):
    happy_targets.append(f"{PUBLISH_DIR}/happy_HG001_v4_2_1/HG001_happy.out.summary.csv")
if any(any(name in f for name in ["HG002", "NA24385", "HM24385"]) and f.endswith(".vcf.gz") for f in FILES_AND_CHECKSUMS.keys()):
    happy_targets.append(f"{PUBLISH_DIR}/happy_HG002_v4_2_1/HG002_happy.out.summary.csv")

# Target rule
rule all:
    input:
        f"{PUBLISH_DIR}/validation_results.txt",
        f"{PUBLISH_DIR}/validation_summary.txt",
        f"{PUBLISH_DIR}/.workflow_status",
        happy_targets

# Collect all validation results
rule collect_results:
    input:
        expand("validation/{file}.validated", file=[Path(f).name for f in FILES_AND_CHECKSUMS.keys()])
    output:
        f"{PUBLISH_DIR}/validation_results.txt"
    resources:
        mem_mb=get_resource("summary_tasks", "mem_mb", 2000),
        runtime=get_resource("summary_tasks", "runtime", 10),
        cpus_per_task=get_resource("summary_tasks", "cpus_per_task", 1)
    shell:
        """
        cat {input} > {output}
        """

# Create validation summary report showing pass/fail status
rule validation_summary:
    input:
        expand("validation/{file}.validated", file=[Path(f).name for f in FILES_AND_CHECKSUMS.keys()])
    output:
        f"{PUBLISH_DIR}/validation_summary.txt"
    params:
        expected_files=[Path(f).name for f in FILES_AND_CHECKSUMS.keys()]
    resources:
        mem_mb=get_resource("summary_tasks", "mem_mb", 2000),
        runtime=get_resource("summary_tasks", "runtime", 10),
        cpus_per_task=get_resource("summary_tasks", "cpus_per_task", 1)
    shell:
        """
        echo "VALIDATION SUMMARY REPORT" > {output}
        echo "=========================" >> {output}
        echo "" >> {output}
        
        # Count totals
        total_files=0
        passed_files=0
        failed_files=0
        
        for expected_file in {params.expected_files}; do
            total_files=$((total_files + 1))
            validation_file="validation/${{expected_file}}.validated"
            
            if [ -f "$validation_file" ]; then
                if grep -q "^Validated:" "$validation_file"; then
                    passed_files=$((passed_files + 1))
                elif grep -q "^Failed validation:" "$validation_file"; then
                    failed_files=$((failed_files + 1))
                fi
            else
                failed_files=$((failed_files + 1))
            fi
        done
        
        echo "SUMMARY:" >> {output}
        echo "  Total files: $total_files" >> {output}
        echo "  Passed: $passed_files" >> {output}
        echo "  Failed: $failed_files" >> {output}
        echo "" >> {output}
        
        # List passed files
        echo "PASSED FILES:" >> {output}
        echo "-------------" >> {output}
        for expected_file in {params.expected_files}; do
            validation_file="validation/${{expected_file}}.validated"
            if [ -f "$validation_file" ] && grep -q "^Validated:" "$validation_file"; then
                echo "  ✓ $expected_file" >> {output}
            fi
        done
        echo "" >> {output}
        
        # List failed files with details
        echo "FAILED FILES:" >> {output}
        echo "-------------" >> {output}
        has_failures=false
        for expected_file in {params.expected_files}; do
            validation_file="validation/${{expected_file}}.validated"
            if [ -f "$validation_file" ] && grep -q "^Failed validation:" "$validation_file"; then
                has_failures=true
                error_msg=$(cat "$validation_file")
                echo "  ✗ $expected_file" >> {output}
                echo "    $error_msg" >> {output}
                echo "" >> {output}
            elif [ ! -f "$validation_file" ]; then
                has_failures=true
                echo "  ✗ $expected_file: No validation output (job failed)" >> {output}
            fi
        done
        
        if [ "$has_failures" = false ]; then
            echo "  None - All files passed validation! ✓" >> {output}
        fi
        """

# Rule to check final status and fail workflow if any validations failed
rule check_workflow_status:
    input:
        summary=f"{PUBLISH_DIR}/validation_summary.txt"
    output:
        touch(f"{PUBLISH_DIR}/.workflow_status")
    localrule: True
    shell:
        """
        if grep -q "Failed: [1-9]" {input.summary}; then
            echo "Validation failures detected. Failing workflow." >&2
            exit 1
        fi
        """

# Rule to create validation data (checksums) instead of validating
rule create_validation_data:
    input:
        expand("checksums/{file}.checksum", file=[Path(f).name for f in FILES_AND_CHECKSUMS.keys()])
    output:
        f"{PUBLISH_DIR}/new_validation_data.tsv"
    resources:
        mem_mb=get_resource("summary_tasks", "mem_mb", 2000),
        runtime=get_resource("summary_tasks", "runtime", 10),
        cpus_per_task=get_resource("summary_tasks", "cpus_per_task", 1)
    run:
        with open(output[0], 'w') as f:
            f.write("file\tchecksum\n")
            for file_path in FILES_AND_CHECKSUMS.keys():
                file_name = Path(file_path).name
                checksum_file = f"checksums/{file_name}.checksum"
                if Path(checksum_file).exists():
                    with open(checksum_file) as cf:
                        checksum = cf.read().strip()
                        f.write(f"{file_path}\t{checksum}\n")


# Target rule for happy benchmarking
rule run_happy_benchmarking:
    input:
        happy_targets
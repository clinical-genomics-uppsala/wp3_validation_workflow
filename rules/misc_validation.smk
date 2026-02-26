# Miscellaneous file validation rules

# Create checksums for collection of various file types
rule checksum_collection_of_files:
    input:
        file=get_matching_file_for_pattern
    output:
        "checksums/{file}.checksum"
    params:
        patterns=config.get("file_patterns", [])
    wildcard_constraints:
        file="^(?!.*\.vcf(\.gz)?$)(?!.*\.cram$)(?!.*\.(insert_size_metrics|WGSMetrics|alignment_summary_metrics|duplication_metrics)\.txt$)(?!.*samtools-stats\.txt$)(?!.*coverage_and_mutations.*$)(?!multiqc_.*\.html$).*"
    resources:
        mem_mb=get_resource("misc_validation", "mem_mb", 4000),
        runtime=get_resource("misc_validation", "runtime", 20),
        cpus_per_task=get_resource("misc_validation", "cpus_per_task", 1)
    container:
        config.get("default_container")
    shell:
        """
        # Create checksum for files matching patterns
        md5=$(cat {input.file} | md5sum | awk '{{print($1)}}')
        echo $md5 > {output}
        """

# Create checksums for files that don't match specific patterns
rule checksum_default:
    input:
        file=lambda wildcards: [f for f in FILES_AND_CHECKSUMS.keys() if Path(f).name == wildcards.file][0]
    output:
        "checksums/{file}.checksum"
    resources:
        mem_mb=get_resource("misc_validation", "mem_mb", 4000),
        runtime=get_resource("misc_validation", "runtime", 20),
        cpus_per_task=get_resource("misc_validation", "cpus_per_task", 1)
    container:
        config.get("default_container")
    shell:
        """
        # Default checksum - simple file checksum
        md5=$(cat {input.file} | md5sum | awk '{{print($1)}}')
        echo $md5 > {output}
        """

# Validate collection of various file types using pre-calculated checksums
rule validate_collection_of_files:
    input:
        file=get_matching_file_for_pattern,
        checksum="checksums/{file}.checksum"
    output:
        "validation/{file}.validated"
    params:
        expected_checksum=lambda wildcards: FILES_AND_CHECKSUMS[[f for f in FILES_AND_CHECKSUMS.keys() if Path(f).name == wildcards.file][0]],
        patterns=config.get("file_patterns", [])
    resources:
        mem_mb=get_resource("misc_validation", "mem_mb", 4000),
        runtime=get_resource("misc_validation", "runtime", 20),
        cpus_per_task=get_resource("misc_validation", "cpus_per_task", 1)
    container:
        config.get("default_container")
    shell:
        """
        calculated_md5=$(cat {input.checksum})
        
        if [ "$calculated_md5" = "{params.expected_checksum}" ]; then
            echo "Validated: {wildcards.file}" > {output}
        else
            echo "Failed validation: {wildcards.file}: {params.expected_checksum} != $calculated_md5" > {output}
            exit 1
        fi
        """

# Validate files that don't match specific patterns using pre-calculated checksums
rule validate_default:
    input:
        file=lambda wildcards: [f for f in FILES_AND_CHECKSUMS.keys() if Path(f).name == wildcards.file][0],
        checksum="checksums/{file}.checksum"
    output:
        "validation/{file}.validated"
    params:
        expected_checksum=lambda wildcards: FILES_AND_CHECKSUMS[[f for f in FILES_AND_CHECKSUMS.keys() if Path(f).name == wildcards.file][0]]
    resources:
        mem_mb=get_resource("misc_validation", "mem_mb", 4000),
        runtime=get_resource("misc_validation", "runtime", 20),
        cpus_per_task=get_resource("misc_validation", "cpus_per_task", 1)
    container:
        config.get("default_container")
    shell:
        """
        calculated_md5=$(cat {input.checksum})
        
        if [ "$calculated_md5" = "{params.expected_checksum}" ]; then
            echo "Validated: {wildcards.file}" > {output}
        else
            echo "Failed validation: {wildcards.file}: {params.expected_checksum} != $calculated_md5" > {output}
            exit 1
        fi
        """
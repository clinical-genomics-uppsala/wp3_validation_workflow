# Metrics validation rules

# Create checksums for metrics files (for checksum generation)
rule checksum_metrics:
    input:
        file=lambda wildcards: [f for f in FILES_AND_CHECKSUMS.keys() if Path(f).name == wildcards.file and any(wildcards.file.endswith(pattern) for pattern in ['insert_size_metrics.txt', 'WGSMetrics.txt', 'alignment_summary_metrics.txt', 'duplication_metrics.txt'])][0]
    output:
        "checksums/{file}.checksum"
    wildcard_constraints:
        file=".*\.(insert_size_metrics|WGSMetrics|alignment_summary_metrics|duplication_metrics)\.txt"
    resources:
        mem_mb=get_resource("metrics_validation", "mem_mb", 2000),
        runtime=get_resource("metrics_validation", "runtime", 15),
        cpus_per_task=get_resource("metrics_validation", "cpus_per_task", 1)
    container:
        config.get("default_container")
    shell:
        """
        md5=$(cat {input.file} | \
              awk 'BEGIN{{START_PRINT=0}}{{if(/## METRICS/) START_PRINT=1; if(START_PRINT) print($0);}}' | \
              md5sum | \
              awk '{{print($1)}}')
        
        echo $md5 > {output}
        """

# Validate various metrics files (for validation workflow)
rule validate_metrics:
    input:
        file=lambda wildcards: [f for f in FILES_AND_CHECKSUMS.keys() if Path(f).name == wildcards.file and any(wildcards.file.endswith(pattern) for pattern in ['insert_size_metrics.txt', 'WGSMetrics.txt', 'alignment_summary_metrics.txt', 'duplication_metrics.txt'])][0],
        checksum="checksums/{file}.checksum"
    output:
        "validation/{file}.validated"
    params:
        expected_checksum=lambda wildcards: FILES_AND_CHECKSUMS[[f for f in FILES_AND_CHECKSUMS.keys() if Path(f).name == wildcards.file and any(wildcards.file.endswith(pattern) for pattern in ['insert_size_metrics.txt', 'WGSMetrics.txt', 'alignment_summary_metrics.txt', 'duplication_metrics.txt'])][0]]
    wildcard_constraints:
        file=".*\.(insert_size_metrics|WGSMetrics|alignment_summary_metrics|duplication_metrics)\.txt"
    resources:
        mem_mb=get_resource("metrics_validation", "mem_mb", 2000),
        runtime=get_resource("metrics_validation", "runtime", 15),
        cpus_per_task=get_resource("metrics_validation", "cpus_per_task", 1)
    container:
        config.get("default_container")
    shell:
        """
        calculated_md5=$(cat {input.checksum})
        
        if [ "$calculated_md5" = "{params.expected_checksum}" ]; then
            echo "Validated: {wildcards.file}" > {output}
        else
            echo "Failed validation: {wildcards.file}: {params.expected_checksum} != $calculated_md5" > {output}
        fi
        """

# Create checksums for MultiQC files (for checksum generation)
rule checksum_multiqc:
    input:
        file=lambda wildcards: [f for f in FILES_AND_CHECKSUMS.keys() if Path(f).name == wildcards.file][0]
    output:
        "checksums/{file}.checksum"
    wildcard_constraints:
        file="multiqc_.*\.html"
    resources:
        mem_mb=get_resource("misc_validation", "mem_mb", 4000),
        runtime=get_resource("misc_validation", "runtime", 20),
        cpus_per_task=get_resource("misc_validation", "cpus_per_task", 1)
    container:
        config.get("default_container")
    shell:
        """
        md5=$(cat {input.file} | \
              sed 's/generated on [0-9:, -]*//' | \
              sed 's/mqc_analysis_path.*code/mqc_analysis_pathcode/g' | \
              sed 's/able[A-Za-zw_ ]*/able/g' | \
              md5sum | \
              awk '{{print($1)}}')
        
        echo $md5 > {output}
        """

# Validate MultiQC HTML files (for validation workflow)
rule validate_multiqc:
    input:
        file=lambda wildcards: [f for f in FILES_AND_CHECKSUMS.keys() if Path(f).name == wildcards.file][0],
        checksum="checksums/{file}.checksum"
    output:
        "validation/{file}.validated"
    params:
        expected_checksum=lambda wildcards: FILES_AND_CHECKSUMS[[f for f in FILES_AND_CHECKSUMS.keys() if Path(f).name == wildcards.file][0]]
    wildcard_constraints:
        file="multiqc_.*\.html"
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
        fi
        """

# Create checksums for samtools stats files (for checksum generation)
rule checksum_samtools_stats:
    input:
        file=lambda wildcards: [f for f in FILES_AND_CHECKSUMS.keys() if Path(f).name == wildcards.file][0]
    output:
        "checksums/{file}.checksum"
    wildcard_constraints:
        file=".*samtools-stats\.txt"
    resources:
        mem_mb=get_resource("metrics_validation", "mem_mb", 2000),
        runtime=get_resource("metrics_validation", "runtime", 15),
        cpus_per_task=get_resource("metrics_validation", "cpus_per_task", 1)
    container:
        config.get("default_container")
    shell:
        """
        md5=$(cat {input.file} | \
              awk 'BEGIN{{START_PRINT=0}}{{if(START_PRINT) print($0); if(/command line was/) START_PRINT=1; }}' | \
              md5sum | \
              awk '{{print($1)}}')
        
        echo $md5 > {output}
        """

# Validate samtools stats files (for validation workflow)
rule validate_samtools_stats:
    input:
        file=lambda wildcards: [f for f in FILES_AND_CHECKSUMS.keys() if Path(f).name == wildcards.file][0],
        checksum="checksums/{file}.checksum"
    output:
        "validation/{file}.validated"
    params:
        expected_checksum=lambda wildcards: FILES_AND_CHECKSUMS[[f for f in FILES_AND_CHECKSUMS.keys() if Path(f).name == wildcards.file][0]]
    wildcard_constraints:
        file=".*samtools-stats\.txt"
    resources:
        mem_mb=get_resource("metrics_validation", "mem_mb", 2000),
        runtime=get_resource("metrics_validation", "runtime", 15),
        cpus_per_task=get_resource("metrics_validation", "cpus_per_task", 1)
    container:
        config.get("default_container")
    shell:
        """
        calculated_md5=$(cat {input.checksum})
        
        if [ "$calculated_md5" = "{params.expected_checksum}" ]; then
            echo "Validated: {wildcards.file}" > {output}
        else
            echo "Failed validation: {wildcards.file}: {params.expected_checksum} != $calculated_md5" > {output}
        fi
        """

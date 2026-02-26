# VCF validation rules

# Create checksums for compressed VCF files
rule checksum_vcf_gz:
    input:
        file=lambda wildcards: [f for f in FILES_AND_CHECKSUMS.keys() if Path(f).name == wildcards.file][0]
    output:
        "checksums/{file}.checksum"
    wildcard_constraints:
        file=".*\.vcf\.gz"
    resources:
        mem_mb=get_resource("vcf_validation", "mem_mb", 8000),
        runtime=get_resource("vcf_validation", "runtime", 30),
        cpus_per_task=get_resource("vcf_validation", "cpus_per_task", 1)
    container:
        config.get("default_container")
    shell:
        """
        md5=$(zcat {input.file} | \
              awk 'BEGIN{{START_PRINT=0}}{{if(START_PRINT) print($0); if(/^#CHROM/) START_PRINT=1; }}' | \
              awk '{{if($8 ~/&/) {{split($8, arr, "[&|]"); joined=""; for (i in arr) joined=joined"&"arr[i]; gsub(/^&/, "", joined); $8=joined}}; print($0)}}' | \
              md5sum | \
              awk '{{print($1)}}')
        echo $md5 > {output}
        """

# Validate compressed VCF files using pre-calculated checksums
rule validate_vcf_gz:
    input:
        file=lambda wildcards: [f for f in FILES_AND_CHECKSUMS.keys() if Path(f).name == wildcards.file][0],
        checksum="checksums/{file}.checksum"
    output:
        "validation/{file}.validated"
    resources:
        mem_mb=get_resource("vcf_validation", "mem_mb", 8000),
        runtime=get_resource("vcf_validation", "runtime", 30),
        cpus_per_task=get_resource("vcf_validation", "cpus_per_task", 1)
    params:
        expected_checksum=lambda wildcards: FILES_AND_CHECKSUMS[[f for f in FILES_AND_CHECKSUMS.keys() if Path(f).name == wildcards.file][0]]
    wildcard_constraints:
        file=".*\.vcf\.gz"
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

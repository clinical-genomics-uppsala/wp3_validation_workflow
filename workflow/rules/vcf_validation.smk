# VCF validation rules

# Create checksums for compressed VCF files
rule checksum_vcf_gz:
    input:
        file=lambda wildcards: [f for f in FILES_AND_CHECKSUMS.keys() if Path(f).name == wildcards.file][0]
    output:
        "checksums/{file}.checksum"
    wildcard_constraints:
        file=".*\.vcf\.gz"
    log:
        "logs/checksum_vcf_gz/{file}.log"
    resources:
        mem_mb=get_resource("vcf_validation", "mem_mb", 8000),
        runtime=get_resource("vcf_validation", "runtime", 30),
        cpus_per_task=get_resource("vcf_validation", "cpus_per_task", 1)
    container:
        config.get("checksum_vcf_gz", {}).get("container", "")
    script:
        "../scripts/compute_vcf_md5.py"

# Validate compressed VCF files using pre-calculated checksums
rule validate_vcf_gz:
    input:
        file=lambda wildcards: [f for f in FILES_AND_CHECKSUMS.keys() if Path(f).name == wildcards.file][0],
        checksum="checksums/{file}.checksum"
    output:
        "validation/{file}.validated"
    log:
        "logs/validate_vcf_gz/{file}.log"
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
        exec 2> {log}
        calculated_md5=$(cat {input.checksum})
        
        if [ "$calculated_md5" = "{params.expected_checksum}" ]; then
            echo "Validated: {wildcards.file}" > {output}
        else
            echo "Failed validation: {wildcards.file}: {params.expected_checksum} != $calculated_md5" > {output}
        fi
        """

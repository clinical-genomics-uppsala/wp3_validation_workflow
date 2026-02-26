# BAM file validation rules

# Create checksums for DNA CRAM files
rule checksum_dna_cram:
    input:
        file=lambda wildcards: get_bam_file(wildcards),
        reference=config.get("reference_genome")
    output:
        "checksums/{file}.checksum"
    wildcard_constraints:
        file=".*\.(cram|bam)"
    resources:
        mem_mb=get_resource("bam_validation", "mem_mb", 6000),
        runtime=get_resource("bam_validation", "runtime", 45),
        cpus_per_task=get_resource("bam_validation", "cpus_per_task", 1)
    container:
        config.get("default_container")
    shell:
        """
        md5=$(samtools view  -T {input.reference} {input.file} | \
              md5sum | \
              awk '{{print($1)}}')
        echo $md5 > {output}
        """

# Validate DNA CRAM files using pre-calculated checksums
rule validate_dna_cram:
    input:
        file=lambda wildcards: get_bam_file(wildcards),
        checksum="checksums/{file}.checksum"
    output:
        "validation/{file}.validated"
    params:
        expected_checksum=lambda wildcards: FILES_AND_CHECKSUMS[get_bam_file(wildcards)]
    wildcard_constraints:
        file=".*\.(cram|bam)"
    resources:
        mem_mb=get_resource("bam_validation", "mem_mb", 6000),
        runtime=get_resource("bam_validation", "runtime", 45),
        cpus_per_task=get_resource("bam_validation", "cpus_per_task", 1)
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


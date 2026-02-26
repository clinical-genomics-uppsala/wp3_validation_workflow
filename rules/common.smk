# Common functions and utilities for validation rules

def get_resource(resource_type, resource_name, default_value=None):
    """Get resource value from config with fallback to default"""
    try:
        return config["resources"][resource_type][resource_name]
    except KeyError:
        if default_value is not None:
            return default_value
        raise ValueError(f"Resource {resource_type}.{resource_name} not found in config and no default provided")

def get_matching_file_for_pattern(wildcards):
    """Get file that matches wildcards.file and one of the file_patterns"""
    import re
    patterns = config.get("file_patterns", [])
    for f in FILES_AND_CHECKSUMS.keys():
        if Path(f).name == wildcards.file:
            # Check if this file matches any of the patterns
            for pattern in patterns:
                if re.search(pattern, wildcards.file):
                    return f
    # If no pattern matches, raise an error instead of fallback
    raise ValueError(f"No file matching pattern found for {wildcards.file}")

def get_vcf_file(wildcards):
    """Get VCF file that matches wildcards.file"""
    for f in FILES_AND_CHECKSUMS.keys():
        if Path(f).name == wildcards.file:
            # Ensure it's a VCF file
            if wildcards.file.endswith('.vcf') or wildcards.file.endswith('.vcf.gz'):
                return f
    # If no VCF file matches, raise an error
    raise ValueError(f"No VCF file found for {wildcards.file}")

def get_bam_file(wildcards):
    """Get BAM/CRAM/SAM file that matches wildcards.file"""
    for f in FILES_AND_CHECKSUMS.keys():
        if Path(f).name == wildcards.file:
            # Ensure it's a BAM/CRAM/SAM file
            if wildcards.file.endswith(('.bam', '.cram', '.sam')):
                return f
    # If no BAM/CRAM/SAM file matches, raise an error
    raise ValueError(f"No BAM/CRAM/SAM file found for {wildcards.file}")
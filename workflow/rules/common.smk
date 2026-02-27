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
    
    # If no patterns are defined, just return the file if it exists in the dictionary
    if not patterns:
        for f in FILES_AND_CHECKSUMS.keys():
            if Path(f).name == wildcards.file:
                return f
                
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

def get_sample_name(file_path, suffix):
    name = Path(file_path).name
    if name == suffix:
        return Path(file_path).parent.name
    if name.endswith(suffix):
        name = name[:-len(suffix)]
    return name.strip("._-")

def get_happy_truth_vcf(wildcards):
    if any(name in wildcards.sample for name in ["HG001", "NA12878", "HM12878"]):
        return "benchmark_happy/HG001_GRCh38_1_22_v4.2.1_benchmark.vcf.gz"
    return "benchmark_happy/HG002_GRCh38_1_22_v4.2.1_benchmark.vcf.gz"

def get_happy_truth_tbi(wildcards):
    if any(name in wildcards.sample for name in ["HG001", "NA12878", "HM12878"]):
        return "benchmark_happy/HG001_GRCh38_1_22_v4.2.1_benchmark.vcf.gz.tbi"
    return "benchmark_happy/HG002_GRCh38_1_22_v4.2.1_benchmark.vcf.gz.tbi"

def get_happy_truth_bed(wildcards):
    if any(name in wildcards.sample for name in ["HG001", "NA12878", "HM12878"]):
        return "benchmark_happy/HG001_GRCh38_1_22_v4.2.1_benchmark.bed"
    return "benchmark_happy/HG002_GRCh38_1_22_v4.2.1_benchmark_noinconsistent.bed"
# Happy benchmarking rules

# Rule to download and extract stratification files
rule get_stratifications:
    output:
        directory("stratification/GRCh38@all")
    params:
        stratification_dir="stratification"
    shell:
        """
        mkdir -p {params.stratification_dir}
        wget -c -P {params.stratification_dir} https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/genome-stratifications/v3.5/genome-stratifications-GRCh38@all.tar.gz
        
        cd {params.stratification_dir}
        tar -xf genome-stratifications-GRCh38@all.tar.gz
        """

# Rule to download benchmarking files for HG001
rule get_benchmark_hg001:
    output:
        vcf="benchmark/HG001_GRCh38_1_22_v4.2.1_benchmark.vcf.gz",
        tbi="benchmark/HG001_GRCh38_1_22_v4.2.1_benchmark.vcf.gz.tbi",
        bed="benchmark/HG001_GRCh38_1_22_v4.2.1_benchmark.bed"
    params:
        benchmark_dir="benchmark"
    shell:
        """
        mkdir -p {params.benchmark_dir}
        wget -c -P {params.benchmark_dir} https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/NA12878_HG001/NISTv4.2.1/GRCh38/HG001_GRCh38_1_22_v4.2.1_benchmark.bed
        wget -c -P {params.benchmark_dir} https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/NA12878_HG001/NISTv4.2.1/GRCh38/HG001_GRCh38_1_22_v4.2.1_benchmark.vcf.gz
        wget -c -P {params.benchmark_dir} https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/NA12878_HG001/NISTv4.2.1/GRCh38/HG001_GRCh38_1_22_v4.2.1_benchmark.vcf.gz.tbi
        """

# Rule to download benchmarking files for HG002
rule get_benchmark_hg002:
    output:
        vcf="benchmark/HG002_GRCh38_1_22_v4.2.1_benchmark.vcf.gz",
        tbi="benchmark/HG002_GRCh38_1_22_v4.2.1_benchmark.vcf.gz.tbi",
        bed="benchmark/HG002_GRCh38_1_22_v4.2.1_benchmark_noinconsistent.bed"
    params:
        benchmark_dir="benchmark"
    shell:
        """
        mkdir -p {params.benchmark_dir}
        wget -c -P {params.benchmark_dir} https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/AshkenazimTrio/HG002_NA24385_son/NISTv4.2.1/GRCh38/HG002_GRCh38_1_22_v4.2.1_benchmark.vcf.gz
        wget -c -P {params.benchmark_dir} https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/AshkenazimTrio/HG002_NA24385_son/NISTv4.2.1/GRCh38/HG002_GRCh38_1_22_v4.2.1_benchmark.vcf.gz.tbi
        wget -c -P {params.benchmark_dir} https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/AshkenazimTrio/HG002_NA24385_son/NISTv4.2.1/GRCh38/HG002_GRCh38_1_22_v4.2.1_benchmark_noinconsistent.bed
        """

# Rule to run happy benchmarking for HG001 (NA12878)
rule happy_benchmarking_hg001_v4_2_1:
    input:
        vcf=lambda wildcards: [f for f in FILES_AND_CHECKSUMS.keys() if any(name in f for name in ["HG001", "NA12878", "HM12878"]) and f.endswith(".vcf.gz")][0],
        strat_dir="stratification/GRCh38@all",
        bench_vcf="benchmark/HG001_GRCh38_1_22_v4.2.1_benchmark.vcf.gz",
        bench_tbi="benchmark/HG001_GRCh38_1_22_v4.2.1_benchmark.vcf.gz.tbi",
        bench_bed="benchmark/HG001_GRCh38_1_22_v4.2.1_benchmark.bed"
    output:
        f"{PUBLISH_DIR}/happy_HG001_v4_2_1/HG001_happy.out.summary.csv"
    params:
        sample="HG001",
        ref_fasta=config.get("reference_genome", "")
    resources:
        mem_mb=get_resource("happy_benchmarking", "mem_mb", 20000),
        runtime=get_resource("happy_benchmarking", "runtime", 720),
        cpus_per_task=get_resource("happy_benchmarking", "cpus_per_task", 16)
    container:
        "docker://hydragenetics/hap.py:0.3.15"
    shell:
        """
        mkdir -p {PUBLISH_DIR}/happy_{params.sample}

        /opt/hap.py/bin/hap.py \
          {input.bench_vcf} \
          {input.vcf} \
          -f {input.bench_bed} \
          --reference {params.ref_fasta} \
          --stratification {input.strat_dir}/GRCh38-all-stratifications.tsv  \
          -o {PUBLISH_DIR}/happy_{params.sample}/{params.sample}_happy.out \
          --pass-only --engine=vcfeval --threads {resources.cpus_per_task}
        """

# Rule to run happy benchmarking for HG002 (NA24385)
rule happy_benchmarking_hg002_v4_2_1:
    input:
        vcf=lambda wildcards: [f for f in FILES_AND_CHECKSUMS.keys() if any(name in f for name in ["HG002", "NA24385", "HM24385"]) and f.endswith(".vcf.gz")][0],
        strat_dir="stratification/GRCh38@all",
        bench_vcf="benchmark/HG002_GRCh38_1_22_v4.2.1_benchmark.vcf.gz",
        bench_tbi="benchmark/HG002_GRCh38_1_22_v4.2.1_benchmark.vcf.gz.tbi",
        bench_bed="benchmark/HG002_GRCh38_1_22_v4.2.1_benchmark_noinconsistent.bed"
    output:
        f"{PUBLISH_DIR}/happy_HG002_v4_2_1/HG002_happy.out.summary.csv"
    params:
        sample="HG002",
        ref_fasta=config.get("reference_genome", "")
    resources:
        mem_mb=get_resource("happy_benchmarking", "mem_mb", 20000),
        runtime=get_resource("happy_benchmarking", "runtime", 720),
        cpus_per_task=get_resource("happy_benchmarking", "cpus_per_task", 16)
    container:
        "docker://hydragenetics/hap.py:0.3.15"
    shell:
        """
        mkdir -p {PUBLISH_DIR}/happy_{params.sample}

        /opt/hap.py/bin/hap.py \
          {input.bench_vcf} \
          {input.vcf}  \
          -f {input.bench_bed} \
          --reference {params.ref_fasta} \
          --stratification {input.strat_dir}/GRCh38-all-stratifications.tsv \
          -o {PUBLISH_DIR}/happy_{params.sample}/{params.sample}_happy.out \
          --pass-only --engine=vcfeval --threads {resources.cpus_per_task}
        """

 

# Happy benchmarking rules

# Rule to download and extract stratification files
rule get_stratifications:
    output:
        directory("stratification/GRCh38@all")
    params:
        stratification_dir="stratification"
    log:
        "logs/get_stratifications_log.log"
    shell:
        """
        exec 2> {log}
        mkdir -p {params.stratification_dir}
        wget -c -P {params.stratification_dir} https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/genome-stratifications/v3.5/genome-stratifications-GRCh38@all.tar.gz
        
        cd {params.stratification_dir}
        tar -xf genome-stratifications-GRCh38@all.tar.gz
        """

# Rule to download benchmarking files for HG001
rule get_benchmark_hg001:
    output:
        vcf="benchmark_happy/HG001_GRCh38_1_22_v4.2.1_benchmark.vcf.gz",
        tbi="benchmark_happy/HG001_GRCh38_1_22_v4.2.1_benchmark.vcf.gz.tbi",
        bed="benchmark_happy/HG001_GRCh38_1_22_v4.2.1_benchmark.bed"
    params:
        benchmark_dir="benchmark_happy"
    log:
        "logs/get_benchmark_hg001.log"
    shell:
        """
        exec 2> {log}
        mkdir -p {params.benchmark_dir}
        wget -c -P {params.benchmark_dir} https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/NA12878_HG001/NISTv4.2.1/GRCh38/HG001_GRCh38_1_22_v4.2.1_benchmark.bed
        wget -c -P {params.benchmark_dir} https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/NA12878_HG001/NISTv4.2.1/GRCh38/HG001_GRCh38_1_22_v4.2.1_benchmark.vcf.gz
        wget -c -P {params.benchmark_dir} https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/NA12878_HG001/NISTv4.2.1/GRCh38/HG001_GRCh38_1_22_v4.2.1_benchmark.vcf.gz.tbi
        """

# Rule to download benchmarking files for HG002
rule get_benchmark_hg002:
    output:
        vcf="benchmark_happy/HG002_GRCh38_1_22_v4.2.1_benchmark.vcf.gz",
        tbi="benchmark_happy/HG002_GRCh38_1_22_v4.2.1_benchmark.vcf.gz.tbi",
        bed="benchmark_happy/HG002_GRCh38_1_22_v4.2.1_benchmark_noinconsistent.bed"
    params:
        benchmark_dir="benchmark_happy"
    log:
        "logs/get_benchmark_hg002.log"
    shell:
        """
        exec 2> {log}
        mkdir -p {params.benchmark_dir}
        wget -c -P {params.benchmark_dir} https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/AshkenazimTrio/HG002_NA24385_son/NISTv4.2.1/GRCh38/HG002_GRCh38_1_22_v4.2.1_benchmark.vcf.gz
        wget -c -P {params.benchmark_dir} https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/AshkenazimTrio/HG002_NA24385_son/NISTv4.2.1/GRCh38/HG002_GRCh38_1_22_v4.2.1_benchmark.vcf.gz.tbi
        wget -c -P {params.benchmark_dir} https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/AshkenazimTrio/HG002_NA24385_son/NISTv4.2.1/GRCh38/HG002_GRCh38_1_22_v4.2.1_benchmark_noinconsistent.bed
        """


# Rule to build an RTG SDF template from the reference FASTA (speeds up vcfeval)
rule build_vcfeval_template:
    output:
        sdf=directory("benchmark_happy/reference.sdf")
    params:
        ref_fasta=config.get("reference_genome", "")
    log:
        "logs/build_vcfeval_template.log"
    container:
        config.get("happy_benchmarking", {}).get("container", config["default_container"])
    shell:
        """
        exec 2> {log}
        /opt/hap.py/libexec/rtg-tools-install/rtg format -o {output.sdf} {params.ref_fasta}
        """


# Rule to run happy benchmarking for a given sample
rule run_happy_benchmarking_sample:
    input:
        vcf=lambda wildcards: HAPPY_SAMPLES[wildcards.sample],
        strat_dir="stratification/GRCh38@all",
        bench_vcf=get_happy_truth_vcf,
        bench_tbi=get_happy_truth_tbi,
        bench_bed=get_happy_truth_bed,
        sdf="benchmark_happy/reference.sdf"
    output:
        summary=f"{HAPPY_RESULTS_DIR}/happy_{{sample}}/{{sample}}_happy.out.summary.csv",
        extended=f"{HAPPY_RESULTS_DIR}/happy_{{sample}}/{{sample}}_happy.out.extended.csv",
        metrics=f"{HAPPY_RESULTS_DIR}/happy_{{sample}}/{{sample}}_happy.out.metrics.json.gz",
        runinfo=f"{HAPPY_RESULTS_DIR}/happy_{{sample}}/{{sample}}_happy.out.runinfo.json",
        vcf=f"{HAPPY_RESULTS_DIR}/happy_{{sample}}/{{sample}}_happy.out.vcf.gz",
        vcf_tbi=f"{HAPPY_RESULTS_DIR}/happy_{{sample}}/{{sample}}_happy.out.vcf.gz.tbi",
        roc_all=f"{HAPPY_RESULTS_DIR}/happy_{{sample}}/{{sample}}_happy.out.roc.all.csv.gz",
        roc_indel=f"{HAPPY_RESULTS_DIR}/happy_{{sample}}/{{sample}}_happy.out.roc.Locations.INDEL.csv.gz",
        roc_indel_pass=f"{HAPPY_RESULTS_DIR}/happy_{{sample}}/{{sample}}_happy.out.roc.Locations.INDEL.PASS.csv.gz",
        roc_snp=f"{HAPPY_RESULTS_DIR}/happy_{{sample}}/{{sample}}_happy.out.roc.Locations.SNP.csv.gz",
        roc_snp_pass=f"{HAPPY_RESULTS_DIR}/happy_{{sample}}/{{sample}}_happy.out.roc.Locations.SNP.PASS.csv.gz"
    params:
        ref_fasta=config.get("reference_genome", "")
    log:
        "logs/run_happy_benchmarking_sample/{sample}.log"
    resources:
        mem_mb=get_resource("happy_benchmarking", "mem_mb", 20000),
        runtime=get_resource("happy_benchmarking", "runtime", 720),
        cpus_per_task=get_resource("happy_benchmarking", "cpus_per_task", 16)
    container:
        config.get("happy_benchmarking", {}).get("container", config["default_container"])
    shell:
        """
        exec 2> {log}
        mkdir -p {HAPPY_RESULTS_DIR}/happy_{wildcards.sample}

        export HGREF={params.ref_fasta}

        /opt/hap.py/bin/hap.py \
          {input.bench_vcf} \
          {input.vcf} \
          -f {input.bench_bed} \
          --reference {params.ref_fasta} \
          --stratification {input.strat_dir}/GRCh38-all-stratifications.tsv  \
          -o {HAPPY_RESULTS_DIR}/happy_{wildcards.sample}/{wildcards.sample}_happy.out \
          --pass-only --engine=vcfeval --threads {resources.cpus_per_task} \
          --engine-vcfeval-template {input.sdf}
        """

 

# Truvari benchmarking rules for SVs

# Rule to download benchmarking files for HG002 SVs
rule get_truvari_benchmark_files:
    output:
        vcf="benchmark_truvari/GRCh38_HG2-T2TQ100-V1.1_stvar.vcf.gz",
        tbi="benchmark_truvari/GRCh38_HG2-T2TQ100-V1.1_stvar.vcf.gz.tbi",
        bed="benchmark_truvari/GRCh38_HG2-T2TQ100-V1.1_stvar.benchmark.bed"
    params:
        benchmark_dir="benchmark_truvari"
    log:
        "logs/get_truvari_benchmark_files.log"
    shell:
        """
        exec 2> {log}
        mkdir -p {params.benchmark_dir}
        wget -c -P {params.benchmark_dir} https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/data/AshkenazimTrio/analysis/NIST_HG002_DraftBenchmark_defrabbV0.019-20241113/GRCh38_HG2-T2TQ100-V1.1_stvar.vcf.gz
        wget -c -P {params.benchmark_dir} https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/data/AshkenazimTrio/analysis/NIST_HG002_DraftBenchmark_defrabbV0.019-20241113/GRCh38_HG2-T2TQ100-V1.1_stvar.vcf.gz.tbi
        wget -c -P {params.benchmark_dir} https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/data/AshkenazimTrio/analysis/NIST_HG002_DraftBenchmark_defrabbV0.019-20241113/GRCh38_HG2-T2TQ100-V1.1_stvar.benchmark.bed
        """

# Rule to prepare the benchmark files (filter SVTYPE and autosomes)
rule prepare_truvari_benchmark_files:
    input:
        vcf="benchmark_truvari/GRCh38_HG2-T2TQ100-V1.1_stvar.vcf.gz",
        bed="benchmark_truvari/GRCh38_HG2-T2TQ100-V1.1_stvar.benchmark.bed"
    output:
        vcf="benchmark_truvari/GRCh38_HG2-T2TQ100-V1.1_stvar.svtype.vcf.gz",
        tbi="benchmark_truvari/GRCh38_HG2-T2TQ100-V1.1_stvar.svtype.vcf.gz.tbi",
        bed="benchmark_truvari/GRCh38_HG2-T2TQ100-V1.1_stvar.benchmark.only_autosomes.bed"
    log:
        "logs/prepare_truvari_benchmark_files.log"
    container:
        config.get("default_container")
    shell:
        """
        exec 2> {log}
        bcftools view -i 'INFO/SVTYPE!="."' -Oz -o {output.vcf} {input.vcf}
        bcftools index -t {output.vcf}
        grep -v chr[XY] {input.bed} > {output.bed}
        """


# Rule to run truvari benchmarking for a given sample
rule run_truvari_benchmarking_sample:
    input:
        vcf=lambda wildcards: TRUVARI_SAMPLES[wildcards.sample],
        bench_vcf="benchmark_truvari/GRCh38_HG2-T2TQ100-V1.1_stvar.svtype.vcf.gz",
        bench_tbi="benchmark_truvari/GRCh38_HG2-T2TQ100-V1.1_stvar.svtype.vcf.gz.tbi",
        bench_bed="benchmark_truvari/GRCh38_HG2-T2TQ100-V1.1_stvar.benchmark.only_autosomes.bed"
    output:
        ga4gh_base=f"{PUBLISH_DIR}/truvari_{{sample}}/ga4gh_with_refine.base.vcf.gz",
        ga4gh_comp=f"{PUBLISH_DIR}/truvari_{{sample}}/ga4gh_with_refine.comp.vcf.gz"
    params:
        out_dir=f"{PUBLISH_DIR}/truvari_{{sample}}",
        ref_fasta=config.get("reference_genome", ""),
        refdist=config.get("truvari_benchmarking", {}).get("refdist", 500),
        pctseq=config.get("truvari_benchmarking", {}).get("pctseq", 0.7),
        pctsize=config.get("truvari_benchmarking", {}).get("pctsize", 0.7),
        pctovl=config.get("truvari_benchmarking", {}).get("pctovl", 0.0),
        typeignore="--typeignore" if config.get("truvari_benchmarking", {}).get("typeignore", False) else "",
        no_roll="--no-roll" if config.get("truvari_benchmarking", {}).get("no_roll", False) else "",
        pick=config.get("truvari_benchmarking", {}).get("pick", "single"),
        dup_to_ins="--dup-to-ins" if config.get("truvari_benchmarking", {}).get("dup_to_ins", False) else "",
        bnddist=config.get("truvari_benchmarking", {}).get("bnddist", 100),
        chunksize=config.get("truvari_benchmarking", {}).get("chunksize", 1000),
        no_decompose="--no-decompose" if config.get("truvari_benchmarking", {}).get("no_decompose", False) else "",
        max_resolve=config.get("truvari_benchmarking", {}).get("max_resolve", 25000)
    log:
        "logs/run_truvari_benchmarking_sample/{sample}.log"
    resources:
        mem_mb=get_resource("truvari_benchmarking", "mem_mb", 96000),
        runtime=get_resource("truvari_benchmarking", "runtime", 240),
        cpus_per_task=get_resource("truvari_benchmarking", "cpus_per_task", 16)
    container:
        config.get("truvari_benchmarking", {}).get("container", config["default_container"])
    shell:
        """
        exec 2> {log}
        # Truvari bench requires that the output directory does not already exist
        rm -rf {params.out_dir}
        
        # MAFFT (used in the refine step) can be sensitive to the space available in the default tmp directory
        tmp_dir=$(mktemp -d)
        trap 'rm -rf $tmp_dir' EXIT
        
        # Step 1: Run bench
        truvari bench \
            --reference {params.ref_fasta} \
            --includebed {input.bench_bed} \
            --base {input.bench_vcf} \
            --comp {input.vcf} \
            --output {params.out_dir} \
            --passonly \
            --refdist {params.refdist} \
            --pctseq {params.pctseq} \
            --pctsize {params.pctsize} \
            --pctovl {params.pctovl} \
            --pick {params.pick} \
            --bnddist {params.bnddist} \
            --chunksize {params.chunksize} \
            --max-resolve {params.max_resolve} \
            {params.typeignore} \
            {params.no_roll} \
            {params.dup_to_ins} \
            {params.no_decompose}
            
        # Step 2: Run refine
        export TMPDIR=$tmp_dir
        truvari refine \
            --reference {params.ref_fasta} \
            --regions {params.out_dir}/candidate.refine.bed \
            --use-original-vcfs \
            --threads {resources.cpus_per_task} \
            --align mafft \
            {params.out_dir}
            
        # Step 3: Produce final assessment VCF outputs
        ga4gh_prefix={params.out_dir}/ga4gh_with_refine
        truvari ga4gh \
            --input {params.out_dir} \
            --output $ga4gh_prefix 
        """

# Rule to summarize truvari performance
rule summarize_truvari_performance:
    input:
        base_vcf=f"{PUBLISH_DIR}/truvari_{{sample}}/ga4gh_with_refine.base.vcf.gz",
        comp_vcf=f"{PUBLISH_DIR}/truvari_{{sample}}/ga4gh_with_refine.comp.vcf.gz"
    output:
        stats=f"{PUBLISH_DIR}/truvari_{{sample}}/ga4gh_with_refine.size_stratified.accuracy.stats.txt"
    log:
        "logs/summarize_truvari_performance/{sample}.log"
    script:
        "../../scripts/process_truvari_ga4gh_vcfs.py"
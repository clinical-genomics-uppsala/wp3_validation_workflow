rule render_benchmarking_report:
    input:
        notebook="compare_truvari_metrics.ipynb",
        truvari_stats=lambda wildcards: [f"{PUBLISH_DIR}/truvari_{sample}/ga4gh_with_refine.size_stratified.accuracy.stats.csv" for sample in TRUVARI_SAMPLES],
        happy_stats=lambda wildcards: [f"{PUBLISH_DIR}/happy_{sample}/{sample}_happy.out.extended.csv" for sample in HAPPY_SAMPLES]
    output:
        html=f"{PUBLISH_DIR}/variant_benchmarking_report.html"
    log:
        "logs/render_truvari_comparison_report.log"
    resources:
        mem_mb=get_resource("summary_tasks", "mem_mb", 2000),
        runtime=get_resource("summary_tasks", "runtime", 10),
        cpus_per_task=get_resource("summary_tasks", "cpus_per_task", 1)
    container:
        config.get("benchmarking_report", {}).get("container", config["default_container"])
    shell:
        """
        exec 2> {log}
        
        OUT_FILENAME=$(basename {output.html})
        OUT_DIR=$(dirname $(realpath {output.html}))

        # Pass the input file lists directly as Quarto parameters
        quarto render {input.notebook} \\
            --to html \\
            --output "$OUT_FILENAME" \\
            --output-dir "$OUT_DIR"  \\
            -P truvari_input_files:"{input.truvari_stats}" \\
            -P happy_input_files:"{input.happy_stats}"
        
        """

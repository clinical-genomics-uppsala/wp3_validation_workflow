
rule render_benchmarking_report:
    input:
        notebook=workflow.source_path("../notebooks/benchmarking_report.ipynb"),
        truvari_stats=lambda wildcards: [f"{TRUVARI_RESULTS_DIR}/truvari_{sample}/ga4gh_with_refine.size_stratified.accuracy.stats.csv" for sample in TRUVARI_SAMPLES],
        happy_stats=lambda wildcards: [f"{HAPPY_RESULTS_DIR}/happy_{sample}/{sample}_happy.out.extended.csv" for sample in HAPPY_SAMPLES]
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
    script:
        "../scripts/render_report.py"

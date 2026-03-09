
rule render_benchmarking_report:
    input:
        notebook="workflow/notebooks/benchmarking_report.ipynb",
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
    shell:
        """
        exec 2> {log}

        OUT_FILENAME=$(basename {output.html})
        OUT_DIR=$(realpath $(dirname {output.html}))
        NOTEBOOK_ABS=$(realpath {input.notebook})
        WORKFLOW_ROOT=$(pwd)
        
        # Create temporary directory for rendering
        TEMP_OUT_DIR=$(mktemp -d)
        trap "rm -rf $TEMP_OUT_DIR" EXIT
        
        echo "Rendering to temporary location: $TEMP_OUT_DIR/$OUT_FILENAME" >&2
        
        # Copy notebook to temp directory and render there
        cp "$NOTEBOOK_ABS" "$TEMP_OUT_DIR/report.ipynb"
        cd "$TEMP_OUT_DIR"

        quarto render report.ipynb \\
            --to html \\
            --output "$OUT_FILENAME" \\
            --execute-dir "$WORKFLOW_ROOT"
        
        # Move output to final location
        mkdir -p "$OUT_DIR"
        mv "$OUT_FILENAME" "$OUT_DIR"
        mv 
        
        echo "Report generated: {output.html}" >&2
        """
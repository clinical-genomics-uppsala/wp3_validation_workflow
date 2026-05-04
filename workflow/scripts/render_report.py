#!/usr/bin/env python3
"""Render Jupyter notebook to HTML using Quarto."""

import os
import shutil
import subprocess
import tempfile
import yaml

# Get inputs from Snakemake
notebook = snakemake.input.notebook
output_html = snakemake.output.html
log_file = snakemake.log[0]
workflow_root = os.getcwd()

with open(log_file, 'w') as log:
    # Create temporary directory
    temp_dir = tempfile.mkdtemp()
    
    try:
        log.write(f"Rendering to temporary location: {temp_dir}\n")
        
        # Copy notebook to temp directory
        shutil.copy(notebook, f"{temp_dir}/report.ipynb")
        
        # Write config to temp directory for notebook to load
        os.makedirs(f"{temp_dir}/config", exist_ok=True)
        with open(f"{temp_dir}/config/config.yaml", 'w') as f:
            yaml.dump(dict(snakemake.config), f)
        
        # Change to temp directory and render
        os.chdir(temp_dir)
        
        result = subprocess.run(
            ["quarto", "render", "report.ipynb",
             "--to", "html",
             "--output", os.path.basename(output_html),
             "--execute-dir", workflow_root],
            capture_output=True,
            text=True
        )
        
        log.write(result.stdout)
        log.write(result.stderr)
        
        if result.returncode != 0:
            raise Exception(f"Quarto rendering failed with exit code {result.returncode}")
        
        # Move output to final location
        os.makedirs(os.path.dirname(output_html), exist_ok=True)
        shutil.move(os.path.basename(output_html), output_html)
        
        log.write(f"Report generated: {output_html}\n")
    
    finally:
        # Clean up temp directory
        os.chdir(workflow_root)
        shutil.rmtree(temp_dir, ignore_errors=True)

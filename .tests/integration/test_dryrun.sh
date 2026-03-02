#!/bin/bash

# Dry-run test for wp3_validation_workflow
#
# Verifies that Snakemake can resolve the complete DAG (including happy and
# truvari benchmarking) without executing any jobs.  No real data or reference
# genome is required.
#
# Usage:
#   bash .tests/integration/test_dryrun.sh

set -euo pipefail

# Always run from the repository root
cd "$(dirname "$0")/../.."

CONFIGFILE=".tests/integration/test_config_dryrun.yaml"
DATA_DIR=".tests/integration/data"
PASS=0
FAIL=0

# ---------------------------------------------------------------------------
# Create placeholder input files so Snakemake's DAG check does not fail with
# MissingInputException (files don't need real content for a dry-run).
# ---------------------------------------------------------------------------
PLACEHOLDER_FILES=(
    "$DATA_DIR/HG001.snv_indels.vcf.gz"
    "$DATA_DIR/HG002.snv_indels.vcf.gz"
    "$DATA_DIR/HG002.svdb_merged.vcf.gz"
    "$DATA_DIR/HM24385-1.snv_indels.vcf.gz"
    "$DATA_DIR/HM24385-1.svdb_merged.vcf.gz"
    "$DATA_DIR/HM24385-2.snv_indels.vcf.gz"
    "$DATA_DIR/HM24385-2.svdb_merged.vcf.gz"
)

echo "Creating placeholder input files for dry-run..."
for f in "${PLACEHOLDER_FILES[@]}"; do
    touch "$f"
done

cleanup() {
    echo "Removing placeholder input files..."
    for f in "${PLACEHOLDER_FILES[@]}"; do
        rm -f "$f"
    done
}
trap cleanup EXIT

run_dryrun() {
    local label="$1"; shift
    echo ""
    echo "--- $label ---"
    # Use -- to end option parsing so rule names aren't treated as extra
    # --configfile arguments (Snakemake 9 behaviour)
    if snakemake --dry-run --configfile "$CONFIGFILE" --cores 1 -- "$@" 2>&1; then
        echo "✓ PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "✗ FAIL: $label"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== WP3 Validation Workflow – Dry-Run Tests ==="

# 1. Full workflow (all rule)
run_dryrun "Full workflow (all)"

# 2. Validation-only targets
run_dryrun "Validation only (collect_results)" \
    collect_results

# 3. Happy benchmarking targets only
run_dryrun "Happy benchmarking targets" \
    run_happy_benchmarking

# 4. Truvari benchmarking targets only
run_dryrun "Truvari benchmarking targets" \
    run_truvari_benchmarking

echo ""
echo "=== Dry-Run Test Summary ==="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"

if [ "$FAIL" -gt 0 ]; then
    echo "Some dry-run tests FAILED – see output above."
    exit 1
fi

echo "All dry-run tests passed!"
exit 0

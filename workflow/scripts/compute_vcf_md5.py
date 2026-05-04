"""
Snakemake script: compute a deterministic MD5 checksum from a bgzipped VCF.

Normalizations applied before hashing so that cosmetic differences between
otherwise identical VCF files produce the same checksum:

  1. Header lines up to (but not including) the #CHROM line are skipped —
     only the column-header line and data lines are hashed.
  2. In the INFO field, VEP annotation keys (CSQ / ANN) are normalized:
       a. Comma-separated transcript entries are sorted alphabetically.
       b. Pipe-delimited sub-fields are preserved; ampersand-delimited
          consequence terms *within* a sub-field are sorted and re-joined
          with '&' only (replacing any mixed '&'/'|' usage).
  3. The most_severe_consequence field is normalized by sorting its
     comma-separated entries alphabetically.
  4. INFO keys specified in skip_info_keys are removed before hashing.
  5. Sample columns (FORMAT + all genotype columns) are optionally removed
     before hashing when skip_sample_columns is set to true in the config.
"""

import gzip
import hashlib
import logging
import re
import sys
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    # 'snakemake' is injected at runtime by Snakemake; this stub silences linters.
    from snakemake.script import Snakemake
    snakemake: Snakemake

# ---------------------------------------------------------------------------
# Logging — configured only when running inside Snakemake
# ---------------------------------------------------------------------------
def _configure_logging(log_path: str) -> None:
    logging.basicConfig(
        filename=log_path,
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )


log = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
VEP_KEYS = {"CSQ", "ANN"}
SIMPLE_SORT_KEYS = {"most_severe_consequence"}
DELIM_RE = re.compile(r"[&|]")


# ---------------------------------------------------------------------------
# Normalisation helpers
# ---------------------------------------------------------------------------

def normalize_consequence_subfield(sf: str) -> str:
    """Sort & normalize consequence terms within a single '|'-delimited sub-field.

    VEP uses '&' to join multiple consequences in the same sub-field, e.g.
    ``missense_variant&splice_region_variant``.  Some tools also use '|' here
    by mistake.  We split on either, sort, and rejoin with '&' only.
    """
    if not DELIM_RE.search(sf):
        return sf
    tokens = sorted(t for t in DELIM_RE.split(sf) if t)
    return "&".join(tokens)


def normalize_vep_value(val: str) -> str:
    """Sort comma-separated transcript entries and normalize each sub-field."""
    entries = val.split(",")
    normalized = []
    for entry in entries:
        subfields = entry.split("|")
        normalized.append("|".join(normalize_consequence_subfield(sf) for sf in subfields))
    return ",".join(sorted(normalized))


def normalize_info(info: str, skip_keys: set[str] | None = None) -> str:
    """Normalize all VEP keys and other sortable fields found in a VCF INFO string.
    
    Args:
        info: The INFO field string
        skip_keys: Set of INFO keys to exclude from the output
    """
    if skip_keys is None:
        skip_keys = set()
    
    parts = info.split(";")
    new_parts = []
    for part in parts:
        if "=" in part:
            key, _, val = part.partition("=")
            # Skip keys that should be excluded
            if key in skip_keys:
                continue
            if key in VEP_KEYS:
                part = f"{key}={normalize_vep_value(val)}"
            elif key in SIMPLE_SORT_KEYS:
                # Simple comma-separated sorting
                sorted_val = ",".join(sorted(val.split(",")))
                part = f"{key}={sorted_val}"
        new_parts.append(part)
    return ";".join(new_parts)


def normalize_line(
    line: str,
    skip_keys: set[str] | None = None,
    skip_sample_columns: bool = False,
) -> str:
    """Normalize the INFO field of a single VCF data line (tab-delimited).

    Args:
        line: The VCF data line
        skip_keys: Set of INFO keys to exclude from the output
        skip_sample_columns: If True, FORMAT and sample columns are dropped
    """
    fields = line.split("\t")
    if len(fields) >= 8:
        fields[7] = normalize_info(fields[7], skip_keys)
    if skip_sample_columns:
        fields = fields[:8]
    return "\t".join(fields)


def compute_md5(
    input_file: str,
    skip_keys: set[str] | None = None,
    skip_sample_columns: bool = False,
) -> tuple[str, int]:
    """Open a bgzipped VCF, normalize, and return (hex_digest, lines_hashed).

    Args:
        input_file: Path to the bgzipped VCF file
        skip_keys: Set of INFO keys to exclude from hashing
        skip_sample_columns: If True, FORMAT and sample columns are dropped
    """
    md5 = hashlib.md5()
    past_header = False
    lines_hashed = 0

    with gzip.open(input_file, "rt", encoding="utf-8", errors="replace") as vcf:
        for raw_line in vcf:
            line = raw_line.rstrip("\n")

            if not past_header:
                if line.startswith("#CHROM"):
                    past_header = True
                    hdr = "\t".join(line.split("\t")[:8]) if skip_sample_columns else line
                    md5.update((hdr + "\n").encode())
                    lines_hashed += 1
                continue

            normalized = normalize_line(line, skip_keys, skip_sample_columns)
            md5.update((normalized + "\n").encode())
            lines_hashed += 1

    return md5.hexdigest(), lines_hashed


# ---------------------------------------------------------------------------
# Main — only executed inside a Snakemake run
# ---------------------------------------------------------------------------

def main() -> None:
    _configure_logging(snakemake.log[0])  # noqa: F821
    input_file: str = snakemake.input.file  # noqa: F821
    output_file: str = snakemake.output[0]  # noqa: F821
    
    # Get skip_info_keys from config if specified
    skip_keys_list = snakemake.config.get("skip_info_keys", [])  # noqa: F821
    skip_keys = set(skip_keys_list) if skip_keys_list else None
    skip_sample_columns: bool = snakemake.config.get("skip_sample_columns", False)  # noqa: F821

    if skip_keys:
        log.info("Skipping INFO keys: %s", ", ".join(sorted(skip_keys)))
    if skip_sample_columns:
        log.info("Skipping sample columns (FORMAT + genotype data)")

    log.info("Computing MD5 for %s", input_file)
    checksum, lines_hashed = compute_md5(input_file, skip_keys, skip_sample_columns)
    log.info("Hashed %d lines → %s", lines_hashed, checksum)

    with open(output_file, "w") as out:
        out.write(checksum + "\n")


# Guard: only call main() when Snakemake has injected its global.
if "snakemake" in dir():
    main()

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


def normalize_info(info: str) -> str:
    """Normalize all VEP keys found in a VCF INFO string."""
    parts = info.split(";")
    new_parts = []
    for part in parts:
        if "=" in part:
            key, _, val = part.partition("=")
            if key in VEP_KEYS:
                part = f"{key}={normalize_vep_value(val)}"
        new_parts.append(part)
    return ";".join(new_parts)


def normalize_line(line: str) -> str:
    """Normalize the INFO field of a single VCF data line (tab-delimited)."""
    fields = line.split("\t")
    if len(fields) >= 8:
        fields[7] = normalize_info(fields[7])
    return "\t".join(fields)


def compute_md5(input_file: str) -> tuple[str, int]:
    """Open a bgzipped VCF, normalize, and return (hex_digest, lines_hashed)."""
    md5 = hashlib.md5()
    past_header = False
    lines_hashed = 0

    with gzip.open(input_file, "rt", encoding="utf-8", errors="replace") as vcf:
        for raw_line in vcf:
            line = raw_line.rstrip("\n")

            if not past_header:
                if line.startswith("#CHROM"):
                    past_header = True
                    md5.update((line + "\n").encode())
                    lines_hashed += 1
                continue

            normalized = normalize_line(line)
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

    log.info("Computing MD5 for %s", input_file)
    checksum, lines_hashed = compute_md5(input_file)
    log.info("Hashed %d lines → %s", lines_hashed, checksum)

    with open(output_file, "w") as out:
        out.write(checksum + "\n")


# Guard: only call main() when Snakemake has injected its global.
if "snakemake" in dir():
    main()

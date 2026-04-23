"""
Tests for workflow/scripts/normalize_vcf_info.py

Uses real sawfish SV VCF data lines to cover:
  - INFO fields with pipe-delimited custom sub-field values that must NOT be modified
  - CSQ/ANN normalization (sort transcript entries, normalize & vs |)
  - Header-skipping and MD5 consistency via compute_md5()
"""

import gzip
import hashlib
import sys
import textwrap
from pathlib import Path

import pytest

# Make the script importable without Snakemake present
sys.path.insert(0, str(Path(__file__).parent.parent / "workflow" / "scripts"))
import normalize_vcf_info as nvi

# ---------------------------------------------------------------------------
# Shared VCF fixtures — real sawfish lines trimmed to a consistent length
# ---------------------------------------------------------------------------

CHROM_HEADER = (
    "#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\tSAMPLE"
)

# Each tuple is (description, full tab-delimited VCF data line)
SAWFISH_LINES = [
    (
        "ins_103bp",
        (
            "chr1\t1924223\tsawfish:0:106:0:0\tG\t"
            "GACCACCCCCCAGCTCACAGCCCACCCCCCCATCTCACCGCCCAGCCCCCCCATCTCACCAGCTGCCCCCTCCCGGGCACACCGCCCACCCCCCCATCTCACCA"
            "\t187\tPASS\t"
            "SVTYPE=INS;END=1924223;SVLEN=103;HOMLEN=10;HOMSEQ=ACCACCCCCC;INSLEN=103;"
            "FOUND_IN=sawfish;set=Intersection;FOUNDBY=1;"
            "HM24385_sawfish_found_in_CHROM=sawfish_0_106_0_0|chr1;"
            "HM24385_sawfish_found_in_POS=sawfish_0_106_0_0|1924223"
            "\tGT\t0/1"
        ),
    ),
    (
        "ins_110bp",
        (
            "chr1\t1948942\tsawfish:0:111:0:0\tT\t"
            "TCTTTCCTTCCCTTTCCCTCCCTCCCTTCCTTCCTCTTTCCTTCCTTCCTTTCCCTCCCTTACTCCTTCCTTCCTTCCCTTCCCCTTCCTTCTTCCTTCTCTCCCTCCCTC"
            "\t466\tPASS\t"
            "SVTYPE=INS;END=1948942;SVLEN=110;HOMLEN=1;HOMSEQ=C;INSLEN=110;"
            "FOUND_IN=sawfish;set=Intersection;FOUNDBY=1;"
            "HM24385_sawfish_found_in_CHROM=sawfish_0_111_0_0|chr1;"
            "HM24385_sawfish_found_in_POS=sawfish_0_111_0_0|1948942"
            "\tGT\t0/1"
        ),
    ),
    (
        "ins_36bp",
        (
            "chr1\t1955080\tsawfish:0:112:0:0\tC\t"
            "CGGCTCACACCGGAAGTGAGGCTCACACCGGAAGTGA"
            "\t999\tPASS\t"
            "SVTYPE=INS;END=1955080;SVLEN=36;HOMLEN=9;HOMSEQ=GGCTCACAC;INSLEN=36;"
            "FOUND_IN=sawfish;set=Intersection;FOUNDBY=1;"
            "HM24385_sawfish_found_in_CHROM=sawfish_0_112_0_0|chr1;"
            "HM24385_sawfish_found_in_FILTERS=sawfish_0_112_0_0|PASS"
            "\tGT\t0/1"
        ),
    ),
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def make_bgzipped_vcf(tmp_path: Path, data_lines: list[str], extra_headers: list[str] | None = None) -> Path:
    """Write a minimal bgzipped VCF to tmp_path and return its path."""
    vcf_path = tmp_path / "test.vcf.gz"
    headers = ["##fileformat=VCFv4.2", "##source=sawfish"]
    if extra_headers:
        headers.extend(extra_headers)
    headers.append(CHROM_HEADER)

    with gzip.open(vcf_path, "wt") as fh:
        for h in headers:
            fh.write(h + "\n")
        for line in data_lines:
            fh.write(line + "\n")
    return vcf_path


# ---------------------------------------------------------------------------
# normalize_consequence_subfield
# ---------------------------------------------------------------------------

class TestNormalizeConsequenceSubfield:

    def test_no_delimiter_passthrough(self):
        """Plain sub-fields (no & or |) are returned unchanged."""
        assert nvi.normalize_consequence_subfield("missense_variant") == "missense_variant"

    def test_sorts_ampersand_delimited(self):
        """Consequences joined by & are sorted alphabetically."""
        result = nvi.normalize_consequence_subfield("splice_region_variant&missense_variant")
        assert result == "missense_variant&splice_region_variant"

    def test_replaces_pipe_with_ampersand(self):
        """Pipe used as an intra-subfield delimiter is replaced with &."""
        result = nvi.normalize_consequence_subfield("splice_region_variant|missense_variant")
        assert result == "missense_variant&splice_region_variant"

    def test_mixed_delimiters_normalized(self):
        """Mixed & and | delimiters are all replaced with sorted & output."""
        result = nvi.normalize_consequence_subfield("z_term&a_term|m_term")
        assert result == "a_term&m_term&z_term"

    def test_empty_tokens_skipped(self):
        """Leading/trailing delimiters do not produce empty tokens."""
        result = nvi.normalize_consequence_subfield("&missense_variant&")
        assert result == "missense_variant"

    def test_idempotent(self):
        """Applying normalization twice gives the same result."""
        once = nvi.normalize_consequence_subfield("splice_region_variant&missense_variant")
        twice = nvi.normalize_consequence_subfield(once)
        assert once == twice


# ---------------------------------------------------------------------------
# normalize_vep_value
# ---------------------------------------------------------------------------

class TestNormalizeVepValue:

    def test_single_entry_passthrough(self):
        """A single transcript entry is returned normalized but unchanged in order."""
        val = "A|missense_variant|MODERATE|GENE|ENST001|"
        assert nvi.normalize_vep_value(val) == val

    def test_sorts_transcript_entries(self):
        """Comma-separated transcript entries are sorted alphabetically."""
        entry_b = "B|synonymous_variant|LOW|GENE|ENST002|"
        entry_a = "A|missense_variant|MODERATE|GENE|ENST001|"
        result = nvi.normalize_vep_value(f"{entry_b},{entry_a}")
        assert result == f"{entry_a},{entry_b}"

    def test_consequence_subfields_normalized(self):
        """& within a sub-field is sorted even when transcript order is fixed."""
        val = "A|splice_region_variant&missense_variant|MODERATE|ENST001|"
        result = nvi.normalize_vep_value(val)
        assert "missense_variant&splice_region_variant" in result

    def test_order_independent_md5(self):
        """Two values with swapped transcript entries produce the same normalized string."""
        e1 = "A|missense_variant|MODERATE|ENST001"
        e2 = "A|synonymous_variant|LOW|ENST002"
        v1 = nvi.normalize_vep_value(f"{e1},{e2}")
        v2 = nvi.normalize_vep_value(f"{e2},{e1}")
        assert v1 == v2


# ---------------------------------------------------------------------------
# normalize_info — focus on non-VEP fields from real sawfish data
# ---------------------------------------------------------------------------

class TestNormalizeInfo:

    @pytest.mark.parametrize("description,line", SAWFISH_LINES)
    def test_non_vep_info_unchanged(self, description, line):
        """Non-CSQ/ANN INFO fields must be returned byte-for-byte identical."""
        fields = line.split("\t")
        info = fields[7]
        assert nvi.normalize_info(info) == info, (
            f"INFO was modified unexpectedly for {description}"
        )

    def test_pipe_in_custom_field_value_preserved(self):
        """Pipe characters used as value separators in non-VEP INFO keys are not touched."""
        info = "SVTYPE=INS;HM24385_sawfish_found_in_CHROM=sawfish_0_106_0_0|chr1"
        assert nvi.normalize_info(info) == info

    def test_csq_key_is_normalized(self):
        """CSQ key is recognized and its value sorted."""
        info = "SVTYPE=INS;CSQ=B|syn|LOW,A|mis|MOD"
        result = nvi.normalize_info(info)
        # CSQ entries should now be sorted (A before B)
        assert result == "SVTYPE=INS;CSQ=A|mis|MOD,B|syn|LOW"

    def test_ann_key_is_normalized(self):
        """ANN key is recognized and its value sorted."""
        info = "SVTYPE=INS;ANN=B|syn|LOW,A|mis|MOD"
        result = nvi.normalize_info(info)
        assert result == "SVTYPE=INS;ANN=A|mis|MOD,B|syn|LOW"

    def test_unrecognized_info_key_passthrough(self):
        """Unknown INFO keys (e.g. FOUND_IN, HOMSEQ) pass through unchanged."""
        info = "FOUND_IN=sawfish;HOMSEQ=ACCACCCCCC;set=Intersection"
        assert nvi.normalize_info(info) == info


# ---------------------------------------------------------------------------
# normalize_line
# ---------------------------------------------------------------------------

class TestNormalizeLine:

    @pytest.mark.parametrize("description,line", SAWFISH_LINES)
    def test_sawfish_lines_unchanged(self, description, line):
        """Real sawfish lines (no CSQ/ANN) pass through normalize_line unchanged."""
        assert nvi.normalize_line(line) == line, (
            f"Line was unexpectedly modified for {description}"
        )

    def test_fewer_than_8_fields_passthrough(self):
        """Lines with < 8 fields are returned as-is without error."""
        short = "chr1\t100\t.\tA\tT"
        assert nvi.normalize_line(short) == short

    def test_comment_line_not_called_directly(self):
        """normalize_line does not guard against '#' lines; callers must filter."""
        header = "#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO"
        # Should not raise; INFO field here is literal "#CHROM..."  — fine for unit test
        result = nvi.normalize_line(header)
        assert result == header


# ---------------------------------------------------------------------------
# compute_md5 — integration tests using real bgzipped VCFs
# ---------------------------------------------------------------------------

class TestComputeMd5:

    def test_returns_hex_digest(self, tmp_path):
        """compute_md5 returns a 32-character lowercase hex string."""
        vcf = make_bgzipped_vcf(tmp_path, [SAWFISH_LINES[0][1]])
        digest, _ = nvi.compute_md5(str(vcf))
        assert len(digest) == 32
        assert digest == digest.lower()

    def test_lines_hashed_count(self, tmp_path):
        """lines_hashed equals #CHROM line + number of data lines."""
        data_lines = [line for _, line in SAWFISH_LINES]
        vcf = make_bgzipped_vcf(tmp_path, data_lines)
        _, count = nvi.compute_md5(str(vcf))
        assert count == 1 + len(data_lines)  # 1 for #CHROM header

    def test_meta_headers_skipped(self, tmp_path):
        """Adding extra ##meta headers does not change the MD5."""
        data_lines = [line for _, line in SAWFISH_LINES]
        vcf_no_extra = make_bgzipped_vcf(tmp_path / "a", data_lines)
        vcf_extra = make_bgzipped_vcf(
            tmp_path / "b", data_lines,
            extra_headers=["##extra=this_should_be_ignored"]
        )
        digest_a, _ = nvi.compute_md5(str(vcf_no_extra))
        digest_b, _ = nvi.compute_md5(str(vcf_extra))
        assert digest_a == digest_b

    def test_same_content_same_md5(self, tmp_path):
        """Two identical VCFs produce the same MD5."""
        data_lines = [line for _, line in SAWFISH_LINES]
        vcf1 = make_bgzipped_vcf(tmp_path / "x", data_lines)
        vcf2 = make_bgzipped_vcf(tmp_path / "y", data_lines)
        assert nvi.compute_md5(str(vcf1))[0] == nvi.compute_md5(str(vcf2))[0]

    def test_different_content_different_md5(self, tmp_path):
        """VCFs with different data lines produce different MD5s."""
        vcf1 = make_bgzipped_vcf(tmp_path / "p", [SAWFISH_LINES[0][1]])
        vcf2 = make_bgzipped_vcf(tmp_path / "q", [SAWFISH_LINES[1][1]])
        assert nvi.compute_md5(str(vcf1))[0] != nvi.compute_md5(str(vcf2))[0]

    def test_csq_order_independent(self, tmp_path):
        """Swapping VEP transcript order in CSQ produces the same MD5."""
        e1 = "A|missense_variant|MODERATE|ENST001"
        e2 = "A|synonymous_variant|LOW|ENST002"
        base = "chr1\t100\t.\tA\tT\t.\tPASS\tCSQ={csq}\tGT\t0/1"
        line_ab = base.format(csq=f"{e1},{e2}")
        line_ba = base.format(csq=f"{e2},{e1}")
        vcf_ab = make_bgzipped_vcf(tmp_path / "ab", [line_ab])
        vcf_ba = make_bgzipped_vcf(tmp_path / "ba", [line_ba])
        assert nvi.compute_md5(str(vcf_ab))[0] == nvi.compute_md5(str(vcf_ba))[0]

    def test_consequence_order_independent(self, tmp_path):
        """Swapping & consequence order within a sub-field produces the same MD5."""
        base = "chr1\t100\t.\tA\tT\t.\tPASS\tCSQ={csq}\tGT\t0/1"
        line_ms = base.format(csq="A|missense_variant&splice_region_variant|MOD")
        line_sm = base.format(csq="A|splice_region_variant&missense_variant|MOD")
        vcf_ms = make_bgzipped_vcf(tmp_path / "ms", [line_ms])
        vcf_sm = make_bgzipped_vcf(tmp_path / "sm", [line_sm])
        assert nvi.compute_md5(str(vcf_ms))[0] == nvi.compute_md5(str(vcf_sm))[0]

#!/usr/bin/env python3
"""Audit the normative specification and complete A/B acceptance inventory.

This audits repository *structure* only. It never reports Fusion host tests as PASS.
"""
from __future__ import annotations
import hashlib
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SPEC = ROOT / "docs/CartoRig_Especificacao_de_Produto_e_Implementacao_V1.md"
DIGEST = ROOT / "docs/SPECIFICATION.sha256"
TRACE = ROOT / "docs/TRACEABILITY.md"

EXPECTED_IDS = {f"{prefix}{n:02d}" for prefix in "AB" for n in range(1, 21)}
EXPECTED_PRESETS = {
    "MO-CAM-01", "MO-CAM-02", "MO-CAM-03",
    "MO-REG-01", "MO-REG-02", "MO-REG-03",
    "MO-RTE-01", "MO-RTE-02",
    "MO-MRK-01", "MO-MRK-02",
    "MO-LBL-01", "MO-MAP-01",
}

def main() -> int:
    if not all(p.is_file() for p in (SPEC, DIGEST, TRACE)):
        raise ValueError("BLOCKED: missing normative specification, digest or traceability")
    digest_record = DIGEST.read_text(encoding="utf-8").split()
    if len(digest_record) != 2 or digest_record[1] != SPEC.name:
        raise ValueError("Invalid specification digest record")
    actual = hashlib.sha256(SPEC.read_bytes()).hexdigest()
    if actual != digest_record[0]:
        raise ValueError(f"Specification tampered: expected {digest_record[0]}, got {actual}")

    source = SPEC.read_text(encoding="utf-8")
    trace = TRACE.read_text(encoding="utf-8")
    source_cases = re.findall(r"^\|\s*\*\*([AB]\d{2})\*\*\s*\|", source, re.M)
    rows = re.findall(r"^\|\s*([AB]\d{2})\s*\|[^\n]*\|", trace, re.M)
    source_presets = re.findall(r"^\|\s*`(MO-[A-Z]+-\d{2})`\s*\|", source, re.M)

    if len(source_cases) != 40 or set(source_cases) != EXPECTED_IDS:
        raise ValueError("Normative acceptance inventory differs from 40 A/B cases")
    if len(rows) != 40 or set(rows) != EXPECTED_IDS:
        raise ValueError("Traceability must contain exactly 40 unique A/B cases")
    if len(source_presets) != 12 or set(source_presets) != EXPECTED_PRESETS:
        raise ValueError("Normative Motion inventory differs from 12 presets")

    for row in trace.splitlines():
        if re.match(r"^\|\s*[AB]\d{2}\s*\|", row):
            status = row.split("|")[-2].strip()
            if status not in ("NOT RUN", "BLOCKED", "FAIL", "SKIPPED", "PASS"):
                raise ValueError(f"Unrecognized traceability status: {status}")
            if status == "PASS" and ("PENDING" in row or "NOT RUN" in row):
                raise ValueError("PASS row missing implementation, evidence or PR")
    print(f"STRUCTURAL PASS: specification SHA-256 {actual}; 40 cases; 12 presets.")
    print("This is NOT acceptance approval or evidence of Fusion integration.")
    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError) as exc:
        print(f"STRUCTURAL FAIL: {exc}", file=sys.stderr)
        sys.exit(1)

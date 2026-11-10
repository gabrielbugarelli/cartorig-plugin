#!/usr/bin/env python3
"""Fail-closed V1 release gate for SAME installer and real Fusion host evidence.

Synthetic fixtures in unit tests verify this validator only: they are NOT host tests.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys

IDS = {f"{prefix}{n:02d}" for prefix in "AB" for n in range(1, 21)}
SHA256 = re.compile(r"^[0-9a-f]{64}$")
SHA = re.compile(r"^[0-9a-f]{40}$")

def must(value: bool, message: str) -> None:
    if not value:
        raise ValueError("RELEASE BLOCKED: " + message)

def safe_file(root: Path, relative: str) -> Path:
    must(isinstance(relative, str) and bool(relative), "evidence/path missing")
    must(not Path(relative).is_absolute(), "absolute paths forbidden")
    target = (root / relative).resolve()
    must(target.is_relative_to(root.resolve()), "path escapes artifact directory")
    must(target.is_file() and target.stat().st_size > 0, f"missing/empty artifact: {relative}")
    return target

def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def verify(package_root: Path, host_root: Path, expected_sha: str, run_id: str, attempt: str) -> dict:
    manifest_file = safe_file(package_root, "manifest.json")
    report_file = safe_file(host_root, "host-results.json")
    package = json.loads(manifest_file.read_text(encoding="utf-8"))
    report = json.loads(report_file.read_text(encoding="utf-8"))

    must(bool(SHA.fullmatch(expected_sha)), "invalid expected commit SHA")
    must(str(package.get("commit_sha")) == expected_sha, "installer commit mismatch")
    must(str(report.get("commit_sha")) == expected_sha, "host test commit mismatch")
    must(str(package.get("run_id")) == run_id == str(report.get("run_id")), "workflow run mismatch")
    must(str(package.get("run_attempt")) == attempt == str(report.get("run_attempt")), "workflow attempt mismatch")
    must(package.get("version") == "1.0.0" == report.get("version"), "unexpected V1 version")
    must(isinstance(package.get("installer_sha256"), str) and bool(SHA256.fullmatch(package["installer_sha256"])), "missing installer digest")
    must(report.get("installer_sha256") == package["installer_sha256"], "host used different installer")
    must(isinstance(package.get("dataset_manifest_sha256"), str) and bool(SHA256.fullmatch(package["dataset_manifest_sha256"])), "missing dataset manifest digest")
    must(report.get("dataset_manifest_sha256") == package["dataset_manifest_sha256"], "host dataset differs")
    installer_path = safe_file(package_root, package.get("installer_path"))
    must(installer_path.suffix.casefold() == ".exe", "installer must be Windows EXE")
    must(digest(installer_path) == package["installer_sha256"], "installer bytes do not match manifest")

    environment = report.get("environment")
    must(isinstance(environment, dict), "host environment missing")
    must("windows" in str(environment.get("os", "")).lower(), "host must be Windows")
    must(re.search(r"DaVinci Resolve Studio\s+20(?:\.|\b)", str(environment.get("resolve", "")), re.I) is not None, "genuine Resolve Studio 20 environment not recorded")
    for field in ("cpu", "gpu", "ram", "driver", "dataset_version", "resolution"):
        must(bool(environment.get(field)), f"missing real host information: {field}")
    tests = report.get("tests")
    must(isinstance(tests, list), "host test list missing")
    must(len(tests) == 40, f"host must report 40 tests; got {len(tests)}")
    seen = set()
    for item in tests:
        must(isinstance(item, dict), "malformed test result")
        case = item.get("test_id")
        must(case in IDS and case not in seen, f"invalid/duplicate test ID: {case}")
        seen.add(case)
        must(item.get("status") == "PASS", f"{case} is not PASS ({item.get('status')})")
        must(bool(item.get("precondition")), f"{case} missing precondition")
        must(bool(item.get("expected")), f"{case} missing expected result")
        must(bool(item.get("observed")), f"{case} lacks observed result")
        must(isinstance(item.get("steps"), list) and bool(item["steps"]) and all(isinstance(step, str) and step.strip() for step in item["steps"]), f"{case} lacks executable steps")
        must(bool(item.get("responsible")), f"{case} missing responsible tester")
        must(item.get("dataset_version") == environment["dataset_version"], f"{case} dataset version differs")
        must(item.get("build_version") == "1.0.0", f"{case} build version differs")
        must(item.get("defect_id") is None or isinstance(item.get("defect_id"), str), f"{case} malformed defect ID")
        must(item.get("commit_sha") == expected_sha, f"{case} commit differs")
        must(item.get("installer_sha256") == package["installer_sha256"], f"{case} installer differs")
        proofs = item.get("evidence")
        must(isinstance(proofs, list) and bool(proofs), f"{case} lacks evidence")
        must(any(isinstance(p, str) and Path(p).suffix.lower() in (".png", ".jpg", ".jpeg", ".mp4", ".mov", ".drp") for p in proofs), f"{case} lacks capture or project evidence")
        for p in proofs:
            safe_file(host_root, p)
    must(seen == IDS, f"missing host cases: {sorted(IDS - seen)}")
    return {"installer": str(installer_path), "sha256": package["installer_sha256"], "run_id": run_id}

def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--package", required=True, type=Path)
    p.add_argument("--host-evidence", required=True, type=Path)
    p.add_argument("--sha", default=os.getenv("GITHUB_SHA", ""))
    p.add_argument("--run-id", default=os.getenv("GITHUB_RUN_ID", ""))
    p.add_argument("--attempt", default=os.getenv("GITHUB_RUN_ATTEMPT", ""))
    args = p.parse_args()
    approved = verify(args.package, args.host_evidence, args.sha, args.run_id, args.attempt)
    print("RELEASE GATE PASS: " + json.dumps(approved, sort_keys=True))
    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, json.JSONDecodeError) as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)

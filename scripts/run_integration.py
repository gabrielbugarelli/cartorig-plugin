#!/usr/bin/env python3
"""Discover and execute actual non-host component integration tests.

This runner never supplies synthetic product behavior. A missing implementation,
missing tests, or an empty test suite is BLOCKED; normal unittest failures fail CI.
The Windows/Resolve host matrix is independently mandatory for release.
"""
from __future__ import annotations
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "src/CartoRig"
TESTS = ROOT / "tests/integration"

def main() -> int:
    missing = [str(p.relative_to(ROOT)) for p in (SOURCE, TESTS) if not p.is_dir()]
    if missing:
        print("BLOCKED: real integration unavailable; missing " + ", ".join(missing), file=sys.stderr)
        return 1
    cases = list(TESTS.rglob("test_*.py"))
    if not cases:
        print("BLOCKED: no real integration test modules", file=sys.stderr)
        return 1
    loader = unittest.TestLoader()
    suite = loader.discover(str(TESTS), pattern="test_*.py", top_level_dir=str(ROOT))
    if suite.countTestCases() == 0:
        print("BLOCKED: zero discoverable integration tests", file=sys.stderr)
        return 1
    print(f"Running {suite.countTestCases()} actual non-host integration tests.")
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    return 0 if result.wasSuccessful() else 1

if __name__ == "__main__":
    raise SystemExit(main())

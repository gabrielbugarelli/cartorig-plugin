"""Unit tests of the gate, never evidence of Fusion V1 acceptance."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from scripts.release_gate import verify

SHA = "a" * 40
DATASET = "b" * 64

class GateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.package = self.root / "candidate"
        self.host = self.root / "host"
        self.package.mkdir()
        self.host.mkdir()
        self.installer = self.package / "installer.exe"
        self.installer.write_bytes(b"synthetic gate unit-test bytes; NOT a CartoRig installer")
        self.hash = hashlib.sha256(self.installer.read_bytes()).hexdigest()
        self.manifest = {
            "commit_sha": SHA, "run_id": "101", "run_attempt": "1",
            "version": "1.0.0", "installer_path": "installer.exe",
            "installer_sha256": self.hash,
            "dataset_manifest_sha256": DATASET,
        }
        self.report = {
            "commit_sha": SHA, "run_id": "101", "run_attempt": "1",
            "version": "1.0.0", "installer_sha256": self.hash,
            "dataset_manifest_sha256": DATASET,
            "environment": {
                "os": "Windows", "resolve": "DaVinci Resolve Studio 20.0",
                "cpu": "synthetic", "gpu": "synthetic", "ram": "synthetic",
                "driver": "synthetic", "dataset_version": "synthetic",
                "resolution": "1920x1080",
            },
            "tests": [],
        }
        for p in "AB":
            for i in range(1, 21):
                tid = f"{p}{i:02d}"
                proof = f"{tid}.txt"
                (self.host / proof).write_text("synthetic schema validation fixture\n", encoding="utf-8")
                self.report["tests"].append({
                    "test_id": tid, "status": "PASS", "observed": "synthetic verifier fixture",
                    "commit_sha": SHA, "installer_sha256": self.hash, "evidence": [proof]
                })
        self.save()

    def tearDown(self):
        self.tmp.cleanup()

    def save(self):
        (self.package / "manifest.json").write_text(json.dumps(self.manifest), encoding="utf-8")
        (self.host / "host-results.json").write_text(json.dumps(self.report), encoding="utf-8")

    def test_validator_accepts_only_complete_well_formed_fixture(self):
        self.assertEqual(verify(self.package, self.host, SHA, "101", "1")["sha256"], self.hash)

    def test_missing_test_fails(self):
        self.report["tests"].pop()
        self.save()
        with self.assertRaisesRegex(ValueError, "40 tests"):
            verify(self.package, self.host, SHA, "101", "1")

    def test_blocked_case_fails(self):
        self.report["tests"][0]["status"] = "BLOCKED"
        self.save()
        with self.assertRaisesRegex(ValueError, "not PASS"):
            verify(self.package, self.host, SHA, "101", "1")

    def test_installer_swap_fails(self):
        self.installer.write_bytes(b"changed")
        with self.assertRaisesRegex(ValueError, "installer bytes"):
            verify(self.package, self.host, SHA, "101", "1")

    def test_run_attempt_mismatch_fails(self):
        with self.assertRaisesRegex(ValueError, "attempt mismatch"):
            verify(self.package, self.host, SHA, "101", "2")

    def test_missing_evidence_fails(self):
        (self.host / "A01.txt").unlink()
        with self.assertRaisesRegex(ValueError, "missing/empty"):
            verify(self.package, self.host, SHA, "101", "1")

    def test_other_commit_fails(self):
        with self.assertRaisesRegex(ValueError, "commit mismatch"):
            verify(self.package, self.host, "c" * 40, "101", "1")

    def test_incomplete_host_info_fails(self):
        self.report["environment"]["resolve"] = "DaVinci Resolve Free 20"
        self.save()
        with self.assertRaisesRegex(ValueError, "genuine Resolve"):
            verify(self.package, self.host, SHA, "101", "1")

if __name__ == "__main__":
    unittest.main()

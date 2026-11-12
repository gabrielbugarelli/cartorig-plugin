"""Byte-for-byte spec integrity is a mandatory local source gate, not a CI decoration."""
from pathlib import Path
import hashlib
import unittest

ROOT=Path(__file__).resolve().parents[1]
SPEC=ROOT/"docs/CartoRig_Especificacao_de_Produto_e_Implementacao_V1.md"
PIN=ROOT/"docs/SPECIFICATION.sha256"

class NormativeSpecificationIntegrity(unittest.TestCase):
    def test_exact_final_bytes_match_pinned_sha256(self):
        words=PIN.read_text(encoding="utf-8").split()
        self.assertEqual(len(words),2)
        self.assertEqual(words[1],SPEC.name)
        self.assertEqual(
            hashlib.sha256(SPEC.read_bytes()).hexdigest(),words[0],
            "V1 FINAL spec bytes changed during Windows checkout; check .gitattributes")
        self.assertFalse(SPEC.read_bytes().count(b"\\r\\n"),
            "The normative V1 FINAL spec must remain LF-only in all checkouts")

if __name__=="__main__":
    unittest.main()

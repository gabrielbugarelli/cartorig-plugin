from __future__ import annotations

import csv
import json
import os
from pathlib import Path
import unittest


class GeneratedNaturalEarthRuntime(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        data_dir = os.getenv("CARTORIG_DATA_DIR")
        if not data_dir:
            raise unittest.SkipTest("CARTORIG_DATA_DIR is set by the Integration workflow")
        cls.root = Path(data_dir)
        cls.manifest = json.loads((cls.root / "natural-earth-manifest.json").read_text(encoding="utf-8"))
        with (cls.root / "ne_catalog.tsv").open(encoding="utf-8", newline="") as stream:
            cls.rows = list(csv.DictReader(stream, delimiter="\t"))

    def find(self, *, geo_type: str, name: str):
        matches=[r for r in self.rows if r["geo_type"]==geo_type and r["canonical_name"]==name]
        self.assertEqual(len(matches),1,f"expected unique {geo_type} {name}, got {len(matches)}")
        return matches[0]

    def test_required_milestone_a_locations_exist_with_real_provenance(self):
        brazil=self.find(geo_type="Country",name="Brazil")
        argentina=self.find(geo_type="Country",name="Argentina")
        mato=self.find(geo_type="State",name="Mato Grosso")
        self.assertEqual(brazil["scale"],"1:50m")
        self.assertEqual(argentina["scale"],"1:50m")
        self.assertEqual(mato["scale"],"1:10m")
        self.assertTrue((self.root / brazil["geometry_file"]).is_file())
        self.assertTrue((self.root / argentina["geometry_file"]).is_file())
        self.assertTrue((self.root / mato["geometry_file"]).is_file())
        self.assertIn("Brasil",brazil["aliases"].split("|"))

    def test_search_acceptance_locations_and_ambiguity_exist(self):
        sao=[r for r in self.rows if r["canonical_name"]=="São Paulo"]
        self.assertTrue(any(r["geo_type"]=="City" for r in sao))
        rio=[r for r in self.rows if r["canonical_name"]=="Rio de Janeiro"]
        self.assertTrue(any(r["geo_type"]=="City" for r in rio))
        self.assertTrue(any(r["geo_type"]=="State" for r in rio))
        georgia=[r for r in self.rows if r["canonical_name"]=="Georgia"]
        self.assertGreaterEqual(len({r["geo_type"] for r in georgia}),2)

    def test_manifest_pins_exact_source_commit_versions_and_scales(self):
        self.assertEqual(
            self.manifest["source_commit"],
            "f1890d9f152c896d250a77557a5751a93d494776",
        )
        datasets={d["dataset_id"]:d for d in self.manifest["datasets"]}
        self.assertEqual(datasets["natural-earth-land"]["source_version"],"4.1.0")
        self.assertEqual(datasets["natural-earth-admin0-boundaries"]["source_version"],"5.1.0")
        self.assertEqual(datasets["natural-earth-admin0-boundaries"]["scale"],"1:50m")
        self.assertGreater(datasets["natural-earth-admin0-boundaries"]["line_count"],10)
        self.assertTrue((self.root / "ne_50m_admin0_borders.lua").is_file())
        self.assertEqual(datasets["natural-earth-admin0-countries"]["source_version"],"5.1.1")
        self.assertEqual(datasets["natural-earth-admin1-states-provinces"]["source_version"],"5.1.1")
        self.assertEqual(datasets["natural-earth-populated-places"]["source_version"],"5.1.2")
        self.assertEqual(datasets["natural-earth-admin1-states-provinces"]["scale"],"1:10m")
        self.assertEqual(datasets["natural-earth-admin0-countries"]["scale"],"1:50m")
        self.assertGreater(datasets["natural-earth-admin0-countries"]["generated_geometry_count"],100)
        self.assertGreater(datasets["natural-earth-admin1-states-provinces"]["generated_geometry_count"],1000)


if __name__=="__main__":
    unittest.main()

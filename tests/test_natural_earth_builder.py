from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

import shapefile

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "build_natural_earth", ROOT / "tools" / "build_natural_earth.py"
)
assert SPEC and SPEC.loader
builder = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(builder)


def make_polygon(root: Path, stem: str, fields: list[tuple[str, str]], rows: list[tuple[dict, list]]):
    path = root / stem
    path.parent.mkdir(parents=True, exist_ok=True)
    writer = shapefile.Writer(str(path), shapeType=shapefile.POLYGON, encoding="utf-8")
    for name, kind in fields:
        writer.field(name, kind, size=120 if kind == "C" else 20)
    for attrs, rings in rows:
        writer.poly(rings)
        writer.record(*[attrs.get(name, "") for name, _ in fields])
    writer.close()
    path.with_suffix(".prj").write_text(
        'GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563]]]',
        encoding="utf-8",
    )
    path.with_suffix(".cpg").write_text("UTF-8\n", encoding="ascii")


def make_points(root: Path, stem: str, fields: list[tuple[str, str]], rows: list[tuple[dict, tuple]]):
    path = root / stem
    path.parent.mkdir(parents=True, exist_ok=True)
    writer = shapefile.Writer(str(path), shapeType=shapefile.POINT, encoding="utf-8")
    for name, kind in fields:
        writer.field(name, kind, size=120 if kind == "C" else 20)
    for attrs, (lon, lat) in rows:
        writer.point(lon, lat)
        writer.record(*[attrs.get(name, "") for name, _ in fields])
    writer.close()
    path.with_suffix(".prj").write_text(
        'GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563]]]',
        encoding="utf-8",
    )
    path.with_suffix(".cpg").write_text("UTF-8\n", encoding="ascii")


class NaturalEarthBuilderTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name) / "natural-earth"
        self.out = Path(self.temp.name) / "runtime"

        country_fields = [
            ("NE_ID", "C"), ("NAME_EN", "C"), ("NAME", "C"), ("NAME_PT", "C"),
            ("CONTINENT", "C"), ("ADM0_A3", "C")
        ]
        make_polygon(
            self.root,
            builder.DATASETS["countries"]["stem"],
            country_fields,
            [
                (
                    {
                        "NE_ID": "1159125035", "NAME_EN": "Brazil", "NAME": "Brazil",
                        "NAME_PT": "Brasil", "CONTINENT": "South America", "ADM0_A3": "BRA"
                    },
                    [[(-74, -34), (-34, -34), (-34, 5), (-74, 5), (-74, -34)]],
                ),
                (
                    {
                        "NE_ID": "1159320801", "NAME_EN": "Argentina", "NAME": "Argentina",
                        "CONTINENT": "South America", "ADM0_A3": "ARG"
                    },
                    [[(-73, -55), (-53, -55), (-53, -21), (-73, -21), (-73, -55)]],
                ),
            ],
        )

        state_fields = [
            ("ADM1_CODE", "C"), ("NAME_EN", "C"), ("NAME", "C"),
            ("ADMIN", "C"), ("ISO_3166_2", "C")
        ]
        make_polygon(
            self.root,
            builder.DATASETS["states"]["stem"],
            state_fields,
            [
                (
                    {
                        "ADM1_CODE": "BRA-1294", "NAME_EN": "Mato Grosso",
                        "NAME": "Mato Grosso", "ADMIN": "Brazil", "ISO_3166_2": "BR-MT"
                    },
                    [[(-61, -18), (-50, -18), (-50, -7), (-61, -7), (-61, -18)]],
                ),
                (
                    {
                        "ADM1_CODE": "BRA-1296", "NAME_EN": "São Paulo",
                        "NAME": "São Paulo", "ADMIN": "Brazil", "ISO_3166_2": "BR-SP"
                    },
                    [[(-53, -25), (-44, -25), (-44, -19), (-53, -19), (-53, -25)]],
                ),
            ],
        )

        make_polygon(
            self.root,
            builder.LAND_DATASET["stem"],
            [("NAME", "C")],
            [
                (
                    {"NAME": "Land"},
                    [[(-180, -60), (180, -60), (180, 85), (-180, 85), (-180, -60)]],
                )
            ],
        )

        place_fields = [
            ("NE_ID", "C"), ("NAME", "C"), ("NAMEPAR", "C"), ("NAMEASCII", "C"),
            ("ADM0NAME", "C"), ("ADM1NAME", "C")
        ]
        make_points(
            self.root,
            builder.DATASETS["places"]["stem"],
            place_fields,
            [
                (
                    {
                        "NE_ID": "1159151615", "NAME": "São Paulo", "NAMEPAR": "São Paulo",
                        "NAMEASCII": "Sao Paulo", "ADM0NAME": "Brazil", "ADM1NAME": "São Paulo"
                    },
                    (-46.6333, -23.5505),
                )
            ],
        )

        for spec in [builder.LAND_DATASET, *builder.DATASETS.values()]:
            version_file = self.root / f'{spec["stem"]}.VERSION.txt'
            version_file.write_text(spec["version"] + "\n", encoding="utf-8")

    def tearDown(self):
        self.temp.cleanup()

    def test_builds_real_provenance_catalog_and_feature_geometry(self):
        manifest = builder.build(self.root, self.out, "fixture-commit")
        self.assertEqual(manifest["source_commit"], "fixture-commit")
        self.assertEqual(manifest["generated"]["catalog"]["record_count"], 5)

        catalog = (self.out / "ne_catalog.tsv").read_text(encoding="utf-8")
        self.assertIn(
            "Country\tBrazil\tSouth America\t1159125035\tnatural-earth-admin0-countries\t"
            "5.1.1\t1:50m\tPolygon\tregions/natural-earth-admin0-countries/1159125035.lua\t",
            catalog,
        )
        self.assertIn("Brasil", catalog)
        self.assertIn(
            "State\tMato Grosso\tBrazil\tBRA-1294\tnatural-earth-admin1-states-provinces\t"
            "5.1.1\t1:10m\tPolygon",
            catalog,
        )
        self.assertIn("City\tSão Paulo\tSão Paulo, Brazil", catalog)

        brazil = self.out / "regions" / "natural-earth-admin0-countries" / "1159125035.lua"
        mato_grosso = self.out / "regions" / "natural-earth-admin1-states-provinces" / "BRA-1294.lua"
        self.assertTrue(brazil.exists())
        self.assertTrue(mato_grosso.exists())
        self.assertIn('source_id="1159125035"', brazil.read_text(encoding="utf-8"))
        self.assertIn('scale="1:10m"', mato_grosso.read_text(encoding="utf-8"))

        written_manifest = json.loads(
            (self.out / "natural-earth-manifest.json").read_text(encoding="utf-8")
        )
        datasets = {item["dataset_id"]: item for item in written_manifest["datasets"]}
        self.assertEqual(datasets["natural-earth-land"]["source_version"], "4.1.0")
        self.assertEqual(datasets["natural-earth-land"]["ring_count"], 1)
        self.assertTrue((self.out / "ne_50m_land.lua").exists())
        self.assertEqual(datasets["natural-earth-admin0-countries"]["feature_count"], 2)
        self.assertEqual(datasets["natural-earth-admin1-states-provinces"]["feature_count"], 2)
        self.assertEqual(datasets["natural-earth-populated-places"]["feature_count"], 1)
        self.assertTrue(datasets["natural-earth-admin0-countries"]["source_files_sha256"]["ne_50m_admin_0_countries.shp"])

    def test_rejects_source_version_mismatch(self):
        version_file = self.root / f'{builder.DATASETS["states"]["stem"]}.VERSION.txt'
        version_file.write_text("wrong-version\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "expected version 5.1.1"):
            builder.build(self.root, self.out, "fixture-commit")


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Build CartoRig's offline Natural Earth runtime assets.

The end user never runs this script. GitHub Actions executes it from a pinned
Natural Earth source checkout and packages only the generated offline runtime
files.

Milestone A sources:
- Admin 0 countries: Natural Earth 1:50m, v5.1.1.
- Admin 1 states/provinces: Natural Earth 1:10m, v5.1.1, used because the
  official 1:50m Admin 1 layer currently contains only USA/Canada and cannot
  satisfy the required Mato Grosso acceptance scenario.
- Populated Places: Natural Earth 1:50m, v5.1.2.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
from pathlib import Path
from typing import Any, Iterable

try:
    import shapefile  # pyshp
except ImportError as exc:  # pragma: no cover - build precondition
    raise SystemExit("pyshp==2.3.1 is required to build Natural Earth assets") from exc

CATALOG_HEADER = [
    "geo_type",
    "canonical_name",
    "parent_name",
    "source_id",
    "dataset_id",
    "source_version",
    "scale",
    "geometry",
    "geometry_file",
    "aliases",
    "latitude",
    "longitude",
]

SOURCE_REPOSITORY = "https://github.com/nvkelso/natural-earth-vector"
DATASETS = {
    "countries": {
        "stem": "50m_cultural/ne_50m_admin_0_countries",
        "dataset_id": "natural-earth-admin0-countries",
        "version": "5.1.1",
        "scale": "1:50m",
        "geo_type": "Country",
    },
    "states": {
        "stem": "10m_cultural/ne_10m_admin_1_states_provinces",
        "dataset_id": "natural-earth-admin1-states-provinces",
        "version": "5.1.1",
        "scale": "1:10m",
        "geo_type": "State",
    },
    "places": {
        "stem": "50m_cultural/ne_50m_populated_places",
        "dataset_id": "natural-earth-populated-places",
        "version": "5.1.2",
        "scale": "1:50m",
        "geo_type": "City",
    },
}

_SAFE = re.compile(r"[^A-Za-z0-9_.-]+")


def _field_map(record: Any) -> dict[str, Any]:
    raw = record.as_dict() if hasattr(record, "as_dict") else dict(record)
    return {str(key).upper(): value for key, value in raw.items()}


def _text(fields: dict[str, Any], *names: str) -> str:
    for name in names:
        value = fields.get(name.upper())
        if value is None:
            continue
        value = str(value).strip()
        if value and value not in {"-99", "-1"}:
            return value
    return ""


def _number(fields: dict[str, Any], *names: str) -> float | None:
    for name in names:
        value = fields.get(name.upper())
        if value in (None, "", "-99"):
            continue
        try:
            number = float(value)
        except (TypeError, ValueError):
            continue
        if math.isfinite(number):
            return number
    return None


def _aliases(fields: dict[str, Any], canonical: str, extra: Iterable[str] = ()) -> str:
    values: list[str] = []
    seen = {canonical.casefold()}
    candidate_names = [
        "NAME", "NAME_EN", "NAME_LONG", "FORMAL_EN", "NAMEPAR", "NAMEASCII",
        "NAME_PT", "NAME_ES", "NAME_FR", "NAME_DE", "NAME_IT",
        "ABBREV", "POSTAL", "ISO_A2", "ISO_A3", "ADM0_A3", "ADM1_CODE",
    ]
    for candidate in list(extra) + [_text(fields, field) for field in candidate_names]:
        candidate = str(candidate or "").strip()
        key = candidate.casefold()
        if candidate and candidate not in {"-99", "-1"} and key not in seen:
            seen.add(key)
            values.append(candidate.replace("|", "/").replace("\t", " "))
    return "|".join(values)


def _source_id(fields: dict[str, Any], geo_type: str) -> str:
    if geo_type == "Country":
        value = _text(fields, "NE_ID", "ADM0_A3", "SOV_A3")
    elif geo_type == "State":
        value = _text(fields, "ADM1_CODE", "NE_ID", "ISO_3166_2")
    else:
        value = _text(fields, "NE_ID", "WIKIDATAID", "GEONAMEID")
    if not value:
        raise ValueError(f"{geo_type} feature has no stable source identifier")
    return value


def _canonical(fields: dict[str, Any], geo_type: str) -> str:
    if geo_type == "Country":
        value = _text(fields, "NAME_EN", "NAME", "NAME_LONG")
    elif geo_type == "State":
        value = _text(fields, "NAME_EN", "NAME", "GN_NAME")
    else:
        value = _text(fields, "NAMEPAR", "NAME", "NAMEASCII", "NAME_EN")
    if not value:
        raise ValueError(f"{geo_type} feature has no canonical name")
    return value


def _parent(fields: dict[str, Any], geo_type: str) -> str:
    if geo_type == "State":
        return _text(fields, "ADMIN", "ADM0NAME", "SOVEREIGNT")
    if geo_type == "City":
        state = _text(fields, "ADM1NAME")
        country = _text(fields, "ADM0NAME", "SOV0NAME")
        if state and country:
            return f"{state}, {country}"
        return state or country
    return _text(fields, "CONTINENT")


def _safe_id(source_id: str) -> str:
    cleaned = _SAFE.sub("_", source_id).strip("._")
    if not cleaned:
        cleaned = hashlib.sha256(source_id.encode("utf-8")).hexdigest()[:24]
    return cleaned[:120]


def _format_number(value: float) -> str:
    if not math.isfinite(value):
        raise ValueError("non-finite coordinate")
    text = f"{value:.6f}".rstrip("0").rstrip(".")
    return text if text and text != "-0" else "0"


def _rings(shape: Any) -> list[list[tuple[float, float]]]:
    points = shape.points
    if not points:
        return []
    starts = list(shape.parts) + [len(points)]
    rings: list[list[tuple[float, float]]] = []
    for index in range(len(starts) - 1):
        ring = [(float(x), float(y)) for x, y in points[starts[index] : starts[index + 1]]]
        if len(ring) < 4:
            continue
        # Shapefiles commonly repeat the closing point. The Fusion Shape API
        # closes the ring explicitly, so omit the duplicate to reduce runtime size.
        if ring[0] == ring[-1]:
            ring = ring[:-1]
        if len(ring) >= 3:
            rings.append(ring)
    if not rings:
        raise ValueError("polygon feature has no renderable rings")
    return rings


def _write_geometry(
    output_root: Path,
    dataset_id: str,
    source_id: str,
    canonical: str,
    parent: str,
    version: str,
    scale: str,
    shape: Any,
) -> str:
    rings = _rings(shape)
    relative = Path("regions") / dataset_id / f"{_safe_id(source_id)}.lua"
    destination = output_root / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    bbox = [float(value) for value in shape.bbox]
    with destination.open("w", encoding="utf-8", newline="\n") as stream:
        stream.write("-- Generated from pinned Natural Earth source. Do not edit.\n")
        stream.write("return {")
        stream.write(f'source_id={json.dumps(source_id, ensure_ascii=False)},')
        stream.write(f'name={json.dumps(canonical, ensure_ascii=False)},')
        stream.write(f'parent={json.dumps(parent, ensure_ascii=False)},')
        stream.write(f'version={json.dumps(version)},scale={json.dumps(scale)},')
        stream.write("bbox={" + ",".join(_format_number(v) for v in bbox) + "},rings={")
        for ring in rings:
            stream.write("{")
            flattened: list[str] = []
            for lon, lat in ring:
                if not (-180 <= lon <= 180 and -90 <= lat <= 90):
                    raise ValueError(
                        f"{canonical} ({source_id}) contains coordinate outside WGS84 degrees"
                    )
                flattened.extend((_format_number(lon), _format_number(lat)))
            stream.write(",".join(flattened))
            stream.write("},")
        stream.write("}}\n")
    return relative.as_posix()


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _dataset_source_hashes(root: Path, stem: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for suffix in (".shp", ".shx", ".dbf", ".prj", ".cpg", ".VERSION.txt"):
        path = root / f"{stem}{suffix}"
        if path.exists():
            result[path.name] = _sha256(path)
    for required in (".shp", ".shx", ".dbf"):
        if not (root / f"{stem}{required}").exists():
            raise FileNotFoundError(f"required Natural Earth file missing: {stem}{required}")
    return result


def _version_from_source(root: Path, stem: str, expected: str) -> str:
    path = root / f"{stem}.VERSION.txt"
    if not path.exists():
        raise FileNotFoundError(f"Natural Earth version file missing: {path}")
    actual = path.read_text(encoding="utf-8").strip()
    if actual != expected:
        raise ValueError(f"{stem} expected version {expected}, got {actual}")
    return actual


def _reader(root: Path, stem: str) -> shapefile.Reader:
    return shapefile.Reader(str(root / f"{stem}.shp"), encoding="utf-8")


def build(source_root: Path, output_root: Path, source_commit: str) -> dict[str, Any]:
    output_root.mkdir(parents=True, exist_ok=True)
    catalog_rows: list[list[str]] = []
    manifest_datasets: list[dict[str, Any]] = []

    for key, spec in DATASETS.items():
        stem = spec["stem"]
        version = _version_from_source(source_root, stem, spec["version"])
        reader = _reader(source_root, stem)
        count = 0
        for shape_record in reader.iterShapeRecords():
            fields = _field_map(shape_record.record)
            geo_type = spec["geo_type"]
            source_id = _source_id(fields, geo_type)
            canonical = _canonical(fields, geo_type)
            parent = _parent(fields, geo_type)
            aliases = _aliases(
                fields,
                canonical,
                extra=("Brasil",) if geo_type == "Country" and canonical == "Brazil" else (),
            )
            geometry_file = ""
            latitude = ""
            longitude = ""
            geometry = "Point" if geo_type == "City" else "Polygon"
            if geo_type == "City":
                if not shape_record.shape.points:
                    raise ValueError(f"city {canonical} has no point")
                lon, lat = map(float, shape_record.shape.points[0])
                if not (-180 <= lon <= 180 and -90 <= lat <= 90):
                    raise ValueError(f"city {canonical} has invalid coordinate")
                latitude, longitude = _format_number(lat), _format_number(lon)
            else:
                geometry_file = _write_geometry(
                    output_root,
                    spec["dataset_id"],
                    source_id,
                    canonical,
                    parent,
                    version,
                    spec["scale"],
                    shape_record.shape,
                )

            catalog_rows.append(
                [
                    geo_type,
                    canonical,
                    parent,
                    source_id,
                    spec["dataset_id"],
                    version,
                    spec["scale"],
                    geometry,
                    geometry_file,
                    aliases,
                    latitude,
                    longitude,
                ]
            )
            count += 1

        manifest_datasets.append(
            {
                "dataset_id": spec["dataset_id"],
                "natural_earth_theme": Path(stem).name,
                "source_version": version,
                "scale": spec["scale"],
                "feature_type": spec["geo_type"],
                "feature_count": count,
                "source_files_sha256": _dataset_source_hashes(source_root, stem),
            }
        )

    catalog_rows.sort(key=lambda row: (row[0], row[1].casefold(), row[2].casefold(), row[3]))
    catalog_path = output_root / "ne_catalog.tsv"
    with catalog_path.open("w", encoding="utf-8", newline="\n") as stream:
        stream.write("\t".join(CATALOG_HEADER) + "\n")
        for row in catalog_rows:
            if any("\t" in value or "\n" in value or "\r" in value for value in row):
                raise ValueError("catalog value contains unsupported TSV control character")
            stream.write("\t".join(row) + "\n")

    manifest: dict[str, Any] = {
        "manifest_schema": 1,
        "source": "Natural Earth",
        "source_repository": SOURCE_REPOSITORY,
        "source_commit": source_commit,
        "license": "public domain",
        "datasets": manifest_datasets,
        "generated": {
            "catalog": {
                "path": "ne_catalog.tsv",
                "sha256": _sha256(catalog_path),
                "record_count": len(catalog_rows),
            }
        },
    }

    for dataset in manifest_datasets:
        dataset_dir = output_root / "regions" / dataset["dataset_id"]
        generated_files = sorted(dataset_dir.glob("*.lua")) if dataset_dir.exists() else []
        dataset["generated_geometry_count"] = len(generated_files)
        digest = hashlib.sha256()
        for path in generated_files:
            digest.update(path.name.encode("utf-8"))
            digest.update(bytes.fromhex(_sha256(path)))
        dataset["generated_geometry_set_sha256"] = digest.hexdigest() if generated_files else None

    manifest_path = output_root / "natural-earth-manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, sort_keys=True, indent=2) + "\n",
        encoding="utf-8",
    )
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--source-commit", required=True)
    args = parser.parse_args()
    manifest = build(args.source_root.resolve(), args.output.resolve(), args.source_commit)
    print(
        "Natural Earth runtime built:",
        manifest["generated"]["catalog"]["record_count"],
        "catalog records;",
        ", ".join(
            f'{d["dataset_id"]}={d["feature_count"]}' for d in manifest["datasets"]
        ),
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

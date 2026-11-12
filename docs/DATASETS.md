# CartoRig — offline Natural Earth data inventory

CartoRig builds its installed geography from one pinned checkout of
`nvkelso/natural-earth-vector`:

`f1890d9f152c896d250a77557a5751a93d494776`

The build runs in the CartoRig installer build with `tools/build_natural_earth.py`. End users
never install Python, GIS tools or source shapefiles.

## Bundled Milestone A datasets

| Runtime purpose | Natural Earth source theme | Source version | Scale |
| --- | --- | ---: | ---: |
| WorldMap land | `50m_physical/ne_50m_land` | 4.1.0 | 1:50m |
| WorldMap Admin 0 borders | `50m_cultural/ne_50m_admin_0_boundary_lines_land` | 5.1.0 | 1:50m |
| Country polygons | `50m_cultural/ne_50m_admin_0_countries` | 5.1.1 | 1:50m |
| State/Province polygons | `10m_cultural/ne_10m_admin_1_states_provinces` | 5.1.1 | 1:10m |
| Searchable populated places | `50m_cultural/ne_50m_populated_places` | 5.1.2 | 1:50m |

Natural Earth's 1:50m Admin 1 v5.1.1 layer currently covers USA and Canada
rather than the Brazil subdivisions required by the CartoRig acceptance flow.
CartoRig therefore uses Natural Earth's 1:10m Admin 1 layer for State/Province.
That is an explicit per-object source scale: a Mato Grosso node persists
`1:10m`; it is never relabeled as 1:50m.

## Installed representation

- `data/ne_50m_land.lua`: generated land rings consumed by WorldMap.
- `data/ne_50m_admin0_borders.lua`: generated Admin 0 land boundary lines consumed by WorldMap.
- `data/ne_catalog.tsv`: canonical names, aliases, type, hierarchy, stable
  source ID, dataset/version/scale, geometry availability and point coordinates.
- `data/regions/<dataset>/<source-id>.lua`: one generated polygon geometry file
  per Country/State feature, loaded by that Region node.
- `data/natural-earth-manifest.json`: source commit, source file hashes,
  versions, scales, coverage, feature counts and generated set hashes.

The Region node persists `dataset_id`, `source_id`, `source_version`,
`scale`, `geometry_file`, parent and draw order. A catalog entry and its
geometry file must agree before the Fusion graph is mutated.

## Search behavior

The index normalizes case and diacritics at query time and retains canonical
Unicode names. Aliases such as `Brasil/Brazil` and ASCII variants such as
`Sao Paulo/São Paulo` are indexed locally. Homonyms retain type and hierarchy,
so Country/State/City results are not collapsed.

No address geocoder, road network, online API or invented municipal polygon is
part of this data package.

## Licensing

Natural Earth data is public domain. CartoRig credits “Made with Natural Earth.”
See `THIRD_PARTY_NOTICES` and https://www.naturalearthdata.com/about/terms-of-use/.

Host Viewer/Inspector/render and save/reopen remain subject to the Resolve Studio
20 test gate; generating or installing these files alone is not acceptance.

# CartoRig — offline data inventory, partial Marco A

- Dataset: Natural Earth 1:50m Land polygons.
- Original GeoJSON: `geojson/ne_50m_land.geojson`.
- Source: `nvkelso/natural-earth-vector` at commit `ca96624a56bd078437bca8184e78163e5039ad19` (2022-06-02).
- Exact source URL: https://github.com/nvkelso/natural-earth-vector/blob/ca96624a56bd078437bca8184e78163e5039ad19/geojson/ne_50m_land.geojson
- Runtime representation: `data/ne_50m_land.lua`. Git blob SHA-1 `5b3ea7e3acf76928b29d083ba2208495ae9d4b58`.
- Geometry: 1,420 GeoJSON features, 1,422 rings, 60,669 vertex pairs. Each original numeric coordinate is preserved; no fabricated geography, no synthetic polygons, no online API.
- CRS: WGS84 angular lon/lat, GeoJSON CRS84; projection used by CartoRig is equirectangular 2D.
- License: public domain, attribution voluntary; CartoRig credits "Made with Natural Earth." See `THIRD_PARTY_NOTICES`.
- The installer bundles this file locally and verifies its exact SHA-256 against the checked-in file in GitHub Actions.
- **Unimplemented**: full Natural Earth Admin 0/1, populated places, border lines and the corresponding index. The Land file is not a substitute. WorldMap/Region full features are NOT DONE.
- End-user rendering and validation with Resolve Studio 20 is still pending.

Source terms: https://www.naturalearthdata.com/about/terms-of-use/

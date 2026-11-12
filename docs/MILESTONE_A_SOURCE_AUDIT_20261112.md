# CartoRig 0.7.0 — Milestone A source audit and implementation (2026-11-12)

Branch: `feat/milestone-a-regions`. This document records the source changes for
steps 1–4 of Milestone A. It does **not** certify Windows/Resolve host behavior or
close the milestone.

## 1 — Audit of the existing code

Inspected `tools/build_natural_earth.py`, offline catalog, NodeFactory,
WorldMap/Region/Camera/Scene Fuses, structural fixtures, existing test contracts,
distribution manifest and product specification. Confirmed real physical
WorldMap/Region/Camera/Scene Fuse source and structured scene integration code.
Identified these source-level issues and applied the changes below:

- Polygon rings had no serialized exterior/hole distinction.
- Region Fill/Stroke were fixed local defaults and did not inherit WorldMap
  palette until explicitly overridden.
- Camera lacked a native static Reset Pose action.
- WorldMap lacked a scoped style-reset action and explicit RGBA allocation.
- Generated data needed stricter provenance, schema and source ID validation.
- Runtime builder tests did not cover disjoint islands with holes or source-ID
  collisions as regressions of the actual geographic contracts.

No changes were made to the Scene selection model, `cartorig-dev` launcher,
GitHub Actions installer-only policy or the stable release gate.

## 2 — Natural Earth offline dataset improvements

- `tools/build_natural_earth.py` groups rings into polygons, normalizes exterior
  and hole winding, and serializes `ring_roles` with `topology_schema=2`.
  This applies to Land and each Country/State geometry.
- Source fields, feature types, duplicate source identifiers and the checkout's
  pinned Git SHA are validated before final packaging.
- The local index automatically includes diacritic-free name aliases, keeping
  canonical Unicode and actual source/dataset scale.
- Generated runtime integration tests check catalog and asset SHA-256 hashes,
  aggregate geometry-set hashes, required locations and polygon schema.
- NodeFactory rejects missing geometry topology before altering any Fusion
  graph, and the Region Fuse validates source/version/scale against the node.
- Natural Earth Admin 0 remains 1:50m; required Admin 1 Brazil subdivisions
  use the real 1:10m dataset and preserve that information.

## 3 — WorldMap, Region and camera rendering

- WorldMap explicitly allocates RGBA output channels and initializes a fully
  transparent background with zero RGB to avoid hidden color.
- WorldMap rejects unsupported Land topology and splits boundary line
  segments at antimeridian crossings rather than drawing a line across the
  entire world. This does not by itself complete polygon antimeridian clipping.
- Region uses real versioned feature geometries and rejects cached geometry
  whose source/version/scale differs from the selected node.
- Exteriors and holes now retain normalized opposite winding as source data.
  The actual Fusion ShapeFill fill-rule and Viewer/MediaOut result remain
  host-verification requirements.
- Existing shared camera transform and node graph were retained; the camera
  now rejects NaN values and includes native Reset Pose.

## 4 — Native Inspector controls

- Region Control has live WorldMap Land and Border color inheritance, with
  independent editable Fill/Stroke overrides. Editing a Region color disables
  inheritance on that channel without affecting any other Region.
- Region Control implements a scoped Reset Object Style; WorldMap Control
  implements Reset WorldMap Style, and Camera Control implements Reset Pose.
- Existing Color, Stroke Width, Fill/Stroke Opacity, overall Opacity, Visibility,
  Camera latitude/longitude/Zoom/Bearing, and read-only source information
  remain accessible through their own Fuses.
- Motion remains an intentionally nonfunctional placeholder for Milestone D;
  the presence of a page does not imply the presets are implemented.
- Button and color-change callbacks disable initial notifications, avoiding an unintended reset of saved camera/style state when a Fuse is initialized.
- Full Camera `Focus Target`, `Fit to Location`, `Fit to Objects` and geometric
  editor workflows have not been validated or completed in this source pass.
  Do not describe Camera Control as specification-complete.

## Source regression evidence and limits

- Locally executed an isolated PyShp 2.3.1 test for an outer polygon,
  contained hole, disjoint island, winding normalization and rejection of a
  degenerate ring.
- Inspected current GitHub branch files and passed 29 cross-file static contract
  checks over the builder, Fuses, NodeFactory and tests.
- Added/updated source tests in `tests/test_natural_earth_builder.py`,
  `tests/test_fuse_contracts.py`, `tests/lua/test_node_factory.lua`, and
  `tests/integration/test_natural_earth_runtime.py`.
- Full local `scripts/run_local_tests.py --phase source/full` was **not
  executed** during this source-edit pass: the repository checkout and pinned
  Natural Earth inputs were unavailable in the execution container, and its
  GitHub network endpoint could not be resolved.
- A real DaVinci Resolve Studio 20 host was not available. No Viewer, MediaOut,
  Installer, save/reopen or native Inspector PASS is asserted here.
- The mandatory host cases remain `NOT RUN` until an exact build on a
  licensed Windows host is verified. Antimeridian polygon clipping and
  reliable rendering of nested holes are explicit acceptance risks.

## Resolve Studio observed rendering failure and correction (2026-11-12)

A genuine Windows/Resolve user session confirmed that Create Scene rendered the
offline WorldMap, but adding Brazil, Argentina and Mato Grosso caused the
Region chain to fail. The Console reported:

`CartoRigRegion.fuse:150: REGION_INHERIT_FAILED: unable to inspect managed WorldMap`

followed by dependent Camera/Scene/MediaOut input failures. Root cause:
`CartoRigRegion.Process` attempted to enumerate and query other Fusion Tools
from the render thread. The graph's physical sequence itself was connected.

The corrected Region Fuse has six hidden numeric inputs
`WorldLandR/G/B` and `WorldBorderR/G/B` evaluated via normal
`Input:GetValue(req)`. On region creation, NodeFactory installs and verifies
native Fusion expressions such as `CR_WorldMap_Main.LandR` before connecting
the Region to the render chain. The renderer no longer invokes
`Comp:GetToolList` or cross-tool `GetInput`.

Existing 0.7.0 compositions can use the explicit Scene UI button
**Repair WorldMap Color Links (Existing Regions)**. This operation performs
a transactional, idempotent binding of missing palette expressions while
preserving unrelated links and custom Region controls.

The user-observed failure is established; the corrected palette expression
implementation and repair workflow still require a fresh Windows installer
and real Resolve render/Inspector/save/reopen evidence. Do not mark A04/A05
PASS merely because the source and installer build are valid.

## Next gate

In an environment with a full checkout and pinned Natural Earth source, run
the entire internal source and full-data test phases; fix any failing tests.
Then validate the real Fuse/Inspector and render behavior in Studio 20 and
record evidence. GitHub Actions is reserved **only** for Windows installer
packaging after local review, not for running product tests.

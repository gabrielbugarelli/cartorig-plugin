# CartoRig 1.0 — technical execution plan

## Normative input and invariants

Source of truth: `CartoRig_Especificacao_de_Produto_e_Implementacao_V1.md`, exact SHA-256 recorded in `SPECIFICATION.sha256`. The specification alone defines V1 product behavior. Do not infer City polygons, silent route anchors, selectable Scene rows, unofficial camera controls, or unimplemented presets.

- Scene UI Manager owns CRUD and search; clicking its object rows never selects the Fusion node or changes Inspector.
- Fusion Node Editor is the only normal node selection surface.
- Control and Motion belong to the selected real physical node's native Inspector.
- Shared real Camera provides all geographic transform; no geoanchor drift.
- Natural Earth 1:50m is locally installed and versioned; there are no fabricated geodata.
- Every authored object has immutable UUID, separate node and independent animation.
- The 12 Motion presets use actual Fusion-editable channels and preserved temporal state.
- Untrusted or foreign Fusion nodes are never silently mutated.
- Installation GUI, offline render, save/reopen, alpha and 40 host acceptance cases are mandatory.

## Milestones (complete vertical slices)

### A — Core

1. Validate the exact supported Resolve Studio 20 Fusion scripting/SDK interface on a legitimately licensed Windows host; document real exposed APIs and limitations.
2. Implement local Natural Earth datasets, versioned indexes and search with aliases, hierarchy, geometry availability, canonical identifiers and checksums.
3. Implement native scene identity/state persistence, Scene UI Manager lifecycle/CRUD transactions, and real physical `Scene`, `WorldMap`, `Camera`, `Country` and `State` nodes.
4. Connect via managed compositing graph; show correct node Inspector `Control`/`Motion` grouping after direct Node Editor selection; render reproducibly with Scene closed.
5. Tests: A01–A05, A15, A16, A19 and B01–B03, B06, B18 plus shared contracts. Gate requires real host evidence.

### B — Geography and references

1. Add physical Continent and Route nodes with WGS84 geodesic and pre-camera quadratic Curved algorithms, adaptive sampling, antimeridian clipping, length-based Trim/Reveal and true polygons.
2. Create Route from existing objects with mandatory explicit anchors and UUID links; implement Marker linkage, dependency inspection, freeze/cancel and camera-target freezing.
3. Implement transaction-safe reorder, duplicate/rename/delete, copy-of-composition UUID remap, Undo/rollback and protection of external nodes.
4. Tests: A06, A13, A14, A18; B05, B07–B11, B16, B19, B20.

### C — Appearance and objects

1. Add physical Marker and Label nodes, Unicode text/font fallback and screen-space offsets; independent per-node Control parameters.
2. Complete WorldMap/Region/Route/Marker/Label styles, Shadow/Glow, override/reset semantics, per-frame cache invalidation and RGBA compositing across HD/QHD/4K.
3. Tests: A07, A11, A17, B04, B17 and cross-type render/persistence assertions.

### D — Motion and distribution

1. Implement exactly 12 presets by their normative MO- IDs with actual Fusion channels, FPS/frame treatment, native spline compatibility and random-frame evaluation.
2. Enforce conflicts, idempotent Update, manual `Customized`, protective Remove and independent static styles; Fly To must preserve geoanchors.
3. Produce reproducible GUI installer/uninstaller through GitHub Actions only, bundling checked Natural Earth assets, version/manifest, docs and complete licenses.
4. Execute full A01–A20/B01–B20 host matrix including snapshots, render comparisons and load tests (25 Regions / 10 Routes / 20 Markers / 10 Labels).
5. Release only after CI + integration + Windows package validation + host matrix all PASS on the exact installer SHA-256.

## Vertical completion rule

A slice is not DONE until Scene (if applicable) → node → Inspector → actual renderer → state persistence → error path → automated/host tests is supported and its evidence is tied to a commit/build. A UI-only, fake-data, or isolated renderer exercise cannot mark a V1 requirement complete.

## Critical blockers at foundation stage

- No CartoRig implementation source exists in the original repository.
- No proven Windows + licensed Resolve Studio 20 self-hosted runner is registered/authorized for protected host testing.
- No Natural Earth datasets have been legally inventoried, downloaded, verified, or bundled.
- No installer has been generated, and no A/B host test has been run.
- GitHub `main` is unprotected; protection/rulesets must be configured using the free repository settings, with required CI checks once their names exist.

Do not silently alter these product contracts to resolve a blocker. The existing MIT LICENSE remains intact.

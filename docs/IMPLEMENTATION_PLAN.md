# CartoRig 1.0 — implementation plan (FINAL normative contract)

Normative source: [CartoRig V1 FINAL](CartoRig_Especificacao_de_Produto_e_Implementacao_V1.md).
Pinned SHA-256: `af25a7816b0d4cb616f81d30f1c2c77b4c663f783c9f8dc41d96e0b2936427c9`.
All product acceptance refers to this exact file, not a prior timeline-insertion variant.

## Fundamental product invariants

- Scene is a UI Manager structural window; it never edits style or selects a Fusion node.
- **Create Scene** operates once on the currently active Fusion composition. It must
  never create a new timeline clip or target a different composition.
- **Open Scene** reconstructs that composition's managed scene without any mutation.
- The source graph contains real Scene, WorldMap and Camera nodes, and each Country
  and State added becomes a real independent Region tool.
- Persist UUIDs in Fusion node/comp data, never treat visible names as identity.
- Offline Natural Earth source/version/scale must be checked and persisted.
- Inspector Control and Motion use native Fusion UI; rendering works with Scene closed.
- Existing third-party nodes and image paths cannot be overwritten silently.
- GitHub Actions is used exclusively to package a Windows installer using free
  GitHub resources. All automated tests run outside Actions.

## A — Core (current implementation gate)

1. Bind Scene to the live Fusion composition using the documented
   `Resolve.Fusion().CurrentComp` API. Verify a stable host handle and fail closed
   if the composition changes while the Scene window is open.
2. Implement `Create Scene` / `Open Scene` and static Scene identity/rename on
   that composition. No timeline insertion, no duplicate structural nodes.
3. Validate one WorldMap, one Camera and one Scene, with connected MediaOut and
   safe handling of occupied/foreign outputs. Report rollback failures.
4. Search the offline catalog and insert Brazil, Argentina and Mato Grosso as
   physical Country/State Region nodes, keyed by persistent UUIDs. Geometries
   must be independent, topo-valid, correctly ordered and render without a
   Scene window.
5. Make WorldMap and Region Fill/Stroke/Opacity/Visibility live in the native
   Inspector. Verify per-object overrides, live inheritance, alpha and Reset.
6. Implement the required static Camera controls (Center/Zoom/Bearing,
   Focus Target, Fit to Location/Objects, Reset Pose) without implicit keyframes.
7. Preserve all node/source/UUID state and render after Save/Reopen. Add tests
   for adversarial host API return values, cloned UUIDs and missing files.
8. Execute the full source/Lua/geodata gate outside Actions; publish exact
   command, results, hashes and any `SKIPPED` cases.
9. Build installer by GitHub Actions only after the source gate. Resolve host
   acceptance must then demonstrate A01–A05, A15, A16, A19 and applicable
   B01–B03, B06, B18, B19 on that exact installer hash.

**Status: NOT COMPLETE.** Source/UI integration is changing to the FINAL
active-composition model; no licensed host acceptance has been demonstrated
for this new architecture. Never mark A complete on an installer-only success.

## B — Geography and references

Implement Continent, Route, explicit WGS84 anchors, geodesic and curved paths,
dependency inspection, Freeze/Cancel, duplication, safe reorder/delete, and
UUID remapping for cloned compositions.

## C — Appearance and objects

Add physical Marker and Label, shadow/glow, Unicode font fallback, complete
per-type style controls, consistent alpha and HD/QHD/4K render verification.

## D — Motion and distribution

Implement exactly the twelve MO presets as native editable Fusion channels,
with non-destructive update/removal, Customized state, spline support, and
per-frame deterministic evaluation. Re-run A01–A20/B01–B20 on the exact final
installer and source commit. Publish versioned license notices and docs.

## Acceptance and rollback discipline

A stage is DONE only with source tests, fixture/full-data tests, host Viewer and
Inspector evidence, render and Save/Reopen on the same candidate. Regressions
block the stage. The Resolve Studio host cannot be replaced with mocks, static
checks, GitHub Actions packaging, or claims based on code inspection.

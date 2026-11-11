# CartoRig

**CartoRig 1.0 is under development. There is no installable release yet.**

CartoRig is a free, open-source MIT-licensed 2D cartographic compositing extension targeting **DaVinci Resolve Studio 20 / Fusion on Windows**. The user-facing product is in English and operates offline. The normative product and acceptance contract is [the complete V1.0 specification](docs/CartoRig_Especificacao_de_Produto_e_Implementacao_V1.md).

## Product contract

CartoRig Scene is a UI Manager window exclusively for creating and structurally managing cartographic objects. A row selected in Scene must **not** select a Fusion node or open the Inspector. Users choose the actual node directly in Fusion's Node Editor. Its native Inspector exposes **Control** for properties and **Motion** for compatible animation presets. Native Spline/Keyframes refine animations.

The nine required physical authoring nodes are Scene, WorldMap, Camera, Continent, Country, State, Route, Marker and Label. Every one must be an independently identifiable real Fusion node; no virtual substitutions are accepted. CartoRig connects the composition automatically, maintains one geographically shared camera, and uses versioned local Natural Earth 1:50m datasets. Motion must provide all 12 specified editable presets. Output must work through Fusion Viewer/MediaOut/Deliver and survive save/reopen with Scene closed.

## Current implementation state

This branch now includes the **first functional implementation candidate for Scene, WorldMap and Camera**, as three separately registered physical Fusion Fuses. The single `cartorig-dev` Utility script opens Scene from any Resolve page, without an existing Fusion Composition. Every Create Scene uses the Resolve Timeline API to insert a fresh Fusion Composition clip with independent UUIDs and WorldMap → Camera → Scene → the actual MediaOut. The reviewed transaction snapshots video/audio/subtitle items, track locks, timeline markers, page, playhead and video In/Out marks, appends after their global end, and fails closed if Resolve moves existing editorial state. Scene automatically lists CartoRig clips and has no Open Scene button. WorldMap paints authentic locally bundled Natural Earth **1:50m Land** geometry with editable Land/Ocean appearance; Camera exposes Center Latitude/Longitude, Zoom and Bearing in its own native Inspector. These are coded and verified in non-host tests, **not yet validated in Resolve Studio 20**. Missing in this partial milestone: borders, Natural Earth Admin 0/Admin 1 and place search datasets, Country/State author nodes, complete Motion, full render/persistence/Inspector validation. The 40 A/B cases remain NOT RUN, and the stable release gate stays closed. Future versions continue updating the same single `Workspace → Scripts → cartorig-dev` Utility entry.

- [Single-entry cartorig-dev Windows preview, upgrade and editor test](docs/CARTORIG_PREVIEW_TEST.md)
- [Engineering plan](docs/IMPLEMENTATION_PLAN.md)
- [40-test traceability](docs/TRACEABILITY.md)
- [CI, release and zero-cost policy](docs/CI_AND_RELEASE.md)
- [Licensing and third-party notices](THIRD_PARTY_NOTICES)
- [Pinned specification digest](docs/SPECIFICATION.sha256)

## Required end-user workflow (upon implementation)

1. From Resolve Edit or Fusion, use **Workspace → Scripts → cartorig-dev → Create Scene**. CartoRig inserts a Fusion Composition clip automatically and connects the output.
2. In Scene, add Country **Brazil** (and other geographic objects). Close Scene.
3. Click `CR_Country_Brazil_001` directly in Fusion's Node Editor.
4. Edit **Control → Fill Color** for only that Country.
5. Use Scene to add Argentina and a Route, explicitly confirm both anchors, then select the Route node in Node Editor; adjust **Control** and apply **Motion → Draw Path**.
6. Edit channels using Fusion Spline/Keyframes, compose with MediaOut and render with Deliver.

These are mandatory workflows, **not current functional instructions**.

## License

Own code: MIT — see [LICENSE](LICENSE). Third-party data and code retain their own licenses and notices. There are currently no bundled third-party resources.

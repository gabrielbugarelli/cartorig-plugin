# CartoRig

**CartoRig 1.0 is under development. There is no installable release yet.**

CartoRig is a free, open-source MIT-licensed 2D cartographic compositing extension targeting **DaVinci Resolve Studio 20 / Fusion on Windows**. The user-facing product is in English and operates offline. The normative product and acceptance contract is [the complete V1.0 specification](docs/CartoRig_Especificacao_de_Produto_e_Implementacao_V1.md).

## Product contract

CartoRig Scene is a UI Manager window exclusively for creating and structurally managing cartographic objects. A row selected in Scene must **not** select a Fusion node or open the Inspector. Users choose the actual node directly in Fusion's Node Editor. Its native Inspector exposes **Control** for properties and **Motion** for compatible animation presets. Native Spline/Keyframes refine animations.

The nine required physical authoring nodes are Scene, WorldMap, Camera, Continent, Country, State, Route, Marker and Label. Every one must be an independently identifiable real Fusion node; no virtual substitutions are accepted. CartoRig connects the composition automatically, maintains one geographically shared camera, and uses versioned local Natural Earth 1:50m datasets. Motion must provide all 12 specified editable presets. Output must work through Fusion Viewer/MediaOut/Deliver and survive save/reopen with Scene closed.

## Current implementation state

This branch contains the normative specification, CI/release-control groundwork and initial **tested Lua domain/geographic modules** (identity, offline search index reader and equirectangular camera math). A **separate read-only Windows host diagnostic** can be installed using the Actions-generated GUI package; it is not the CartoRig product or a render test. **No physical CartoRig Fusion nodes, Natural Earth package, map renderer, integrated Scene window or host-tested product features have been delivered.** Do not treat this repository as an installable V1 plugin. The release gate is intentionally closed until the actual implementation and all 40 A/B host tests pass on the exact candidate build.

- [Read-only Windows host probe (not an editor plugin)](docs/HOST_PROBE.md)
- [Milestone A native Fusion graph integration diagnostic 0.2 (not V1)](docs/NATIVE_INTEGRATION_TEST.md)
- [Engineering plan](docs/IMPLEMENTATION_PLAN.md)
- [40-test traceability](docs/TRACEABILITY.md)
- [CI, release and zero-cost policy](docs/CI_AND_RELEASE.md)
- [Licensing and third-party notices](THIRD_PARTY_NOTICES)
- [Pinned specification digest](docs/SPECIFICATION.sha256)

## Required end-user workflow (upon implementation)

1. Open Fusion, launch **CartoRig → Scene → Create Scene**.
2. In Scene, add Country **Brazil** (and other geographic objects). Close Scene.
3. Click `CR_Country_Brazil_001` directly in Fusion's Node Editor.
4. Edit **Control → Fill Color** for only that Country.
5. Use Scene to add Argentina and a Route, explicitly confirm both anchors, then select the Route node in Node Editor; adjust **Control** and apply **Motion → Draw Path**.
6. Edit channels using Fusion Spline/Keyframes, compose with MediaOut and render with Deliver.

These are mandatory workflows, **not current functional instructions**.

## License

Own code: MIT — see [LICENSE](LICENSE). Third-party data and code retain their own licenses and notices. There are currently no bundled third-party resources.

# CartoRig

**CartoRig 1.0 is under development. There is no installable release yet.**

CartoRig is a free, open-source MIT-licensed 2D cartographic compositing extension targeting **DaVinci Resolve Studio 20 / Fusion on Windows**. The user-facing product is in English and operates offline. The normative product and acceptance contract is [the complete V1.0 specification](docs/CartoRig_Especificacao_de_Produto_e_Implementacao_V1.md).

## Product contract

CartoRig Scene is a UI Manager window exclusively for creating and structurally managing cartographic objects. A row selected in Scene must **not** select a Fusion node or open the Inspector. Users choose the actual node directly in Fusion's Node Editor. Its native Inspector exposes **Control** for properties and **Motion** for compatible animation presets. Native Spline/Keyframes refine animations.

The nine required physical authoring nodes are Scene, WorldMap, Camera, Continent, Country, State, Route, Marker and Label. Every one must be an independently identifiable real Fusion node; no virtual substitutions are accepted. CartoRig connects the composition automatically, maintains one geographically shared camera, and uses versioned local Natural Earth 1:50m datasets. Motion must provide all 12 specified editable presets. Output must work through Fusion Viewer/MediaOut/Deliver and survive save/reopen with Scene closed.

## Current implementation state

This repository currently contains only the normative specification, engineering plan, acceptance inventory and CI/release-control groundwork. **No Fusion nodes, installer, Natural Earth package, or host-tested functionality have been delivered.** Do not use this repository as an installable plugin. The release gate is intentionally closed until the actual implementation and all 40 A/B host tests pass on the exact candidate build.

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

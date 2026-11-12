# CartoRig

**CartoRig 1.0 is under development. There is no installable release yet.**

CartoRig is a free, open-source MIT-licensed 2D cartographic compositing extension targeting **DaVinci Resolve Studio 20 / Fusion on Windows**. The user-facing product is in English and operates offline. The normative product and acceptance contract is [the complete V1.0 specification](docs/CartoRig_Especificacao_de_Produto_e_Implementacao_V1.md).

## Product contract

CartoRig Scene is a UI Manager window exclusively for creating and structurally managing cartographic objects. A row selected in Scene must **not** select a Fusion node or open the Inspector. Users choose the actual node directly in Fusion's Node Editor. Its native Inspector exposes **Control** for properties and **Motion** for compatible animation presets. Native Spline/Keyframes refine animations.

The nine required physical authoring nodes are Scene, WorldMap, Camera, Continent, Country, State, Route, Marker and Label. Every one must be an independently identifiable real Fusion node; no virtual substitutions are accepted. CartoRig connects the composition automatically, maintains one geographically shared camera, and uses versioned local Natural Earth 1:50m datasets. Motion must provide all 12 specified editable presets. Output must work through Fusion Viewer/MediaOut/Deliver and survive save/reopen with Scene closed.

## Current implementation state

The current **0.7.0 Milestone A candidate** implements the complete non-host vertical slice for Scene, WorldMap, Camera, Country and State. The single `cartorig-dev` Utility script opens Scene without a prepared Fusion Composition; each Create Scene inserts an independent Fusion Composition and builds WorldMap → Regions → Camera → Scene → the composition's existing MediaOut. Scene is strictly structural: it can search the installed offline catalog, choose a target Scene, add Country/State nodes and rename their display names by UUID without selecting a Fusion node. Direct node selection in Fusion remains the only editing surface for Control/Motion.

WorldMap renders pinned Natural Earth 1:50m Land and Admin 0 boundary lines. Country uses pinned Natural Earth Admin 0 1:50m polygons; State uses Natural Earth Admin 1 1:10m where the required Brazil subdivisions are absent from the official 1:50m Admin 1 layer, with the actual scale persisted per object. Search indexes pinned Populated Places 1:50m and preserves aliases, Unicode names, type and hierarchy. Country/State are independent physical `CartoRigRegion` Fuses with their own Fill, Stroke, opacity and visibility controls, persisted dataset/source/version/scale/geometry metadata and deterministic draw order before the shared Camera. Scene exposes read-only identity, managed links and dataset diagnostics.

All source/unit/integration tests are executed locally in the development environment. GitHub Actions is reserved exclusively for the manual Windows installer build. **Resolve Studio 20 Viewer/Inspector/render/save-reopen validation is still NOT RUN**, so no A/B case is claimed PASS and the stable V1 release gate remains closed.

- [Single-entry cartorig-dev Windows preview, upgrade and editor test](docs/CARTORIG_PREVIEW_TEST.md)
- [Blackmagic Resolve/Fusion API contracts used by CartoRig](docs/BLACKMAGIC_API_CONTRACTS.md)
- [Engineering plan](docs/IMPLEMENTATION_PLAN.md)
- [40-test traceability](docs/TRACEABILITY.md)
- [CI, release and zero-cost policy](docs/CI_AND_RELEASE.md)
- [Licensing and third-party notices](THIRD_PARTY_NOTICES)
- [Milestone A source audit, fixes and pending host evidence](docs/MILESTONE_A_SOURCE_AUDIT_20261112.md)
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

Own code: MIT — see [LICENSE](LICENSE). The development installer builds its offline runtime from one pinned Natural Earth source checkout (public domain): Land, Admin 0 boundaries/countries, Admin 1 States/Provinces and Populated Places. Exact versions, scales, source commit and redistribution notice are recorded in [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES) and [docs/DATASETS.md](docs/DATASETS.md).

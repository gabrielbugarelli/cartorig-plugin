# CartoRig

**CartoRig 1.0 is under development. There is no installable release yet.**

CartoRig is a free, open-source MIT-licensed 2D cartographic compositing extension targeting **DaVinci Resolve Studio 20 / Fusion on Windows**. The user-facing product is in English and operates offline. The normative product and acceptance contract is [the complete V1.0 specification](docs/CartoRig_Especificacao_de_Produto_e_Implementacao_V1.md).

## Product contract

CartoRig Scene is a UI Manager window exclusively for creating and structurally managing cartographic objects. A row selected in Scene must **not** select a Fusion node or open the Inspector. Users choose the actual node directly in Fusion's Node Editor. Its native Inspector exposes **Control** for properties and **Motion** for compatible animation presets. Native Spline/Keyframes refine animations.

The nine required physical authoring nodes are Scene, WorldMap, Camera, Continent, Country, State, Route, Marker and Label. Every one must be an independently identifiable real Fusion node; no virtual substitutions are accepted. CartoRig connects the composition automatically, maintains one geographically shared camera, and uses versioned local Natural Earth 1:50m datasets. Motion must provide all 12 specified editable presets. Output must work through Fusion Viewer/MediaOut/Deliver and survive save/reopen with Scene closed.

## Current implementation state

**Milestone A is under repair and NOT ACCEPTED.** The single normative V1
product contract is [the exact FINAL specification](docs/CartoRig_Especificacao_de_Produto_e_Implementacao_V1.md),
pinned by [SHA-256](docs/SPECIFICATION.sha256).

The current development branch introduces an active-Fusion-composition Scene
service: **Create Scene** must initialize the current composition once, and
**Open Scene** must read the current Scene without adding nodes. Unlike older
0.7.0 previews, no timeline item is to be inserted implicitly. Scene UI actions
must refuse to mutate another active composition.

The foundation retains physical WorldMap, Camera, Scene, Country and State
Fuses, an offline Natural Earth catalog, source/version metadata, native
Inspector pages and transactional graph construction. The new UI and host
integration have **not yet passed** full Lua/Python source tests or validation
in a licensed Resolve Studio 20 host. In particular, live Region palette
inheritance, camera Focus/Fit, polygon antimeridian clipping and project
save/reopen remain acceptance risks.

**Do not interpret a GitHub Actions Success as feature acceptance.** GitHub
Actions exclusively builds Windows installer artifacts; functional tests are
run separately in a development environment and the licensed host.

- [Current Fusion composition test protocol](docs/CARTORIG_PREVIEW_TEST.md)
- [Host/API contracts](docs/BLACKMAGIC_API_CONTRACTS.md)
- [Engineering plan](docs/IMPLEMENTATION_PLAN.md)
- [40-case traceability](docs/TRACEABILITY.md)
- [CI and free GitHub resource policy](docs/CI_AND_RELEASE.md)
- [Licensing and third-party notices](THIRD_PARTY_NOTICES)

## Required end-user workflow (Milestone A target)

1. Open the desired Fusion composition on Resolve's **Fusion** page.
2. Use **Workspace → Scripts → cartorig-dev** to open Scene.
3. Select **Create Scene** only if this composition does not yet contain a
   CartoRig Scene. It creates WorldMap, Camera and Scene nodes and connects
   the composition's output; it does **not** insert a timeline clip.
4. For a composition already containing CartoRig, select **Open Scene**. This
   reconstructs the structural object list without creating new nodes.
5. Search the offline catalog and add Country Brazil, Country Argentina and
   State Mato Grosso to the currently bound Scene.
6. Close Scene, select each physical Region node in the Fusion Node Editor,
   and adjust its **Control** properties in the native Inspector.
7. Save, close and reopen the Resolve project, then render with Scene closed.
   Repeat Open Scene to verify the persisted structural list.

**Status:** implementation target, not yet a verified end-to-end host PASS.

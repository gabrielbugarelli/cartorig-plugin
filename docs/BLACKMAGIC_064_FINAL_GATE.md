# CartoRig 0.6.4 — Blackmagic API contract final gate

This candidate replaces the 0.6.3 host-failed Resolve/Fusion integration layer.

## Contract basis

- Resolve scripting contracts follow the Blackmagic Developer scripting README
  shipped with Resolve. A public mirror is used only for cloud review; the target
  installation's Help → Documentation → Developer copy remains authoritative.
- Fusion Composition/Operator contracts follow Blackmagic's Fusion Scripting Guide.
- Structural Fuse code was reviewed against Blackmagic's Fuse SDK.
- Resolve Studio 20.3.1 host observation `__flags` is binding metadata, not a
  documented list element. Only `CartoRig.blackmagic_api` recognizes it.

## Required automated gates on one commit

- CI PASS.
- Integration Lua 5.1 PASS.
- Windows build/migration/uninstall PASS.
- Windows artifact manifest, SHA256SUMS and installed build-info identify that same commit.

## Mandatory regression coverage

- Exact historical 0.6.3 package from commit
  `86bc10e8f7dd2b7f3d85f79184a8e937edca6099` is reproduced before upgrade.
- Its historical TimelineService still contains the raw `pairs(items)` /
  `pairs(clips)` regression and does not contain the new contract modules.
- 0.6.4 normalizes `GetItemListInTrack()` as a strict documented sequence.
- `GetMarkers()`, `GetMarkInOut()` and Fusion `GetToolList()` use distinct
  dictionary/table adapters rather than the list adapter.
- Lua-binding `__flags` is represented in tests at every observed collection
  boundary. Other contract-violating public keys fail closed.
- Resolve object methods and `bmd` module functions preserve colon-call vs
  dot-call semantics.
- Fusion graph connections verify the connected Output's owning Tool through
  `GetConnectedOutput():GetTool()`.
- NodeFactory explicitly rolls back graph/data mutations; `EndUndo(false)` is
  never treated as an automatic rollback mechanism.
- Object UUID generation is host-independent and does not call undocumented
  `bmd.createuuid` or alter Lua's global `math.random` state.
- Installer packages and preflights `blackmagic_api.lua` and
  `fusion_contract.lua`; support diagnostics report both.

## Host gate

Passing these automated gates does not approve Resolve behavior. The exact 0.6.4
artifact must then be installed and exercised in Resolve Studio 20. The 40
A01–A20/B01–B20 acceptance cases remain NOT RUN unless their complete normative
observations are separately executed and recorded.

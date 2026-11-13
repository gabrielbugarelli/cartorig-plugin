# CartoRig 0.7.0 — host Create Scene AddTool rejection

## Evidence from licensed Resolve Studio 20

Build commit: `4a8070f454ddcb9b67e4b454a1d8df0e96fd0e56`  
UTC: `2026-11-13T20:47:22Z`  
Action: `Create Scene`  
Status: `BLOCKED/FAILED`

Actual editor report:

```text
SCENE_CREATE_FAILED: node_factory.lua:271:
NODE_CREATE_FAILED: FUSION_ADD_TOOL_FAILED: Fuse.CartoRigWorldMap: nil;
transaction rolled back
```

This proves `Composition:AddTool("Fuse.CartoRigWorldMap", x, y)`
returned `nil` without an exception, before the WorldMap node was
successfully created. **It does not prove why the host returned nil**.
Possible conditions include an unavailable Fuse registration, an unsupported
signature in the active Fusion composition, or a non-editable host context.
The previously approved local suite did not cover a nil-returning real host.

## Corrective changes

- The Fusion API layer now attempts the previously observed
  `AddTool(id,x,y)` first and, only if the first attempt demonstrably produced
  **no** new Tool, retries the documented
  `AddTool(id,false,x,y)` overload.
- Before/after Tool inventories are compared, accounting for Fusion proxy
  wrappers that may change Lua identity while retaining the same Tool name.
  A nil return with exactly one newly added Tool is recovered and type-checked;
  multiple ambiguous new Tools stop the operation without a second insertion.
- The Scene rollback checks for **all** unexpected Tools remaining after
  failure, not only returned/recorded Tools, and reports
  `ROLLBACK_INCOMPLETE` if any remain.
- If both overloads refuse to create WorldMap, the Scene report includes
  read-only `Fusion:GetRegAttrs` results for all four CartoRig Fuse names.
  A registry lookup that returns nil is recorded without falsely claiming
  that the cause is known.

## Local regressions (not licensed-host acceptance)

`tests/lua/test_fusion_contract.lua` exercises:

1. successful legacy three-argument AddTool;
2. successful explicit four-argument fallback;
3. nil return after creating one Tool, without duplicate insertion;
4. both overloads returning nil;
5. ambiguous multi-Tool side effects;
6. changing Lua proxy wrappers for existing Tools.

`tests/lua/test_scene_service.lua` verifies the read-only registry
diagnostic. `tests/lua/test_node_factory.lua` verifies that ambiguous
untracked side effects cannot be reported as a successful rollback.

Local source/full-data gate must be executed outside GitHub Actions. Windows
GitHub Actions remains build-only using free resources. The resulting build
is a **candidate**, not a claim that the original Resolve issue was fixed.

## Required host evidence

After installing the new exact candidate and reopening Resolve, open a
disposable Fusion composition and run `Create Scene`. If it fails, supply
the newly generated **Save Report** output, including the Fuse registry
summary and any Fusion Console error. If it succeeds, verify native WorldMap,
Camera, Scene, connected MediaOut, Brazil → Argentina → Mato Grosso, Viewer,
Inspector, and Save/Reopen. Host acceptance is `NOT RUN` until observed.

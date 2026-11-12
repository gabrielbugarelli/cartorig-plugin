# CartoRig 0.7.0 — Milestone A host-validation candidate

**Windows · DaVinci Resolve Studio 20 · development build, not V1 release.**

This test plan follows the exact pinned **V1 FINAL** specification.
`Create Scene` operates only on the active Fusion composition.
`Open Scene` is explicit and read-only. Neither command inserts a new
timeline clip.

## Build and source gate

- GitHub Actions is exclusively the **build-only** Windows installer packager;
  free GitHub resources only. Actions does not execute source tests.
- Download the candidate artifact containing `cartorig-dev-0.7.0-win64.exe`,
  `SHA256SUMS.txt`, `manifest.json` and the local-test source snapshot.
- The source/full-data regression gate is run in a separate development
  environment with `CARTORIG_DATA_DIR=build/cartorig-data`.
- A green source gate or a green installer build **does not** mark Resolve
  Studio host tests as PASS.

## Install / active composition

1. Close Resolve, install the reviewed build and reopen Resolve.
2. Use a disposable project and prepare a Fusion composition in the
   appropriate Fusion workflow. Switch to the **Fusion** page and make the
   intended composition current. The plugin will not create a timeline clip.
3. Open **Workspace → Scripts → cartorig-dev**.
4. Press **Create Scene** once. Verify the active composition has physical
   `CR_WorldMap_Main`, `CR_Camera_Main`, `CR_Scene_Main`
   connected to MediaOut, and the map appears in Viewer.
5. Click **Create Scene** a second time: it must refuse without duplicating
   the graph or changing the UUID.
6. Click **Open Scene**: the existing structural list must be reconstructed
   with no new or deleted Tool.

## Countries and states

1. Search for **Brazil** and add Country.
2. Search for **Argentina** and add Country.
3. Search for **Mato Grosso** and add State/Province.
4. Verify three physical Region nodes are connected in the correct order,
   all have distinct object UUIDs and valid source metadata.
5. Render while Scene is closed. Check the Fusion Console for errors.
6. Select each node **directly in the Node Editor**. In native Inspector
   Control, change Fill Color, Stroke, Opacity, Visibility and independent
   style overrides. Brazil's edits must not mutate Argentina, State or
   WorldMap. Test inherited WorldMap Land and Border color channels.

## Context isolation and persistence

1. Open a second Fusion composition. If it has no Scene, pressing **Open
   Scene** must fail safely.
2. With the original Scene window still bound to the first composition,
   switch the active composition and attempt Add Country: the action must
   refuse and must not touch either graph.
3. Open Scene for the second composition; create a Scene there and add a
   Country. Confirm the first scene was not modified.
4. Rename the Scene and the Brazil display name, without changing UUIDs
   or physical node selection.
5. Save, close and reopen Resolve. With the Scene window closed, verify
   the nodes, geometry, styles, camera, links and render are intact.
6. Reopen Scene and confirm the structural list from persistent node data.

## Known pending Milestone A issues

- The Camera Inspector currently has Center Lat/Lon, Zoom, Bearing and
  Reset Pose. Full static Focus Target, Fit to Location/Objects and
  pose reference workflows still need implementation/host approval.
- Correct handling of clipped polygon antimeridian boundaries and holes
  remains unproven in the licensed host.
- The active-comp handle contract and Region native palette expressions
  require actual host evidence, including Save/Reopen.
- Any problem above is a **blocking A gate**, not an optional feature.

## Failure reports

Use the Scene **Save Report** action after each failure, including exact
build commit and the first Fusion Console error. Attach report and
screenshot. Do not manually rearrange or delete managed nodes as a
workaround. Failure in any required A flow means the Marco A is **NOT DONE**.

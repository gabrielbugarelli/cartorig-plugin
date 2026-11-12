# cartorig-dev 0.7.0 — Milestone A editor validation

**Windows · DaVinci Resolve Studio 20 · development build, not V1 release.**

The only Scripts entry is **Workspace → Scripts → cartorig-dev**. It is installed in the Utility scope and does not require a manually prepared Fusion Composition, Python, SDK, terminal or network access on the editor machine.

## Build and verification policy

All source, Lua, Python, integration, Natural Earth fixture, repository and installer-policy tests are executed in the development environment **before** an installer build is requested.

GitHub Actions is used only to compile/package the final Windows installer from committed source and the pinned Natural Earth source commit. A green build is not a product test and is not Resolve acceptance.

Resolve Studio host results remain `NOT RUN` until observed with the exact installer SHA-256.

## Install

1. Close DaVinci Resolve.
2. Download the manually built artifact for the candidate commit.
3. Extract and run **`cartorig-dev-0.7.0-win64.exe`**.
4. Restart Resolve and open a disposable project/timeline.
5. Stay on the **Edit** page. Do **not** create a Fusion Composition manually.
6. Open **Workspace → Scripts → cartorig-dev**.

## Milestone A host exercise

### A01 — Scene lifecycle

1. Click **Create Scene** five times.
2. Expect five independent Fusion Composition timeline clips.
3. Each composition must contain real `CR_WorldMap_Main`, `CR_Camera_Main` and `CR_Scene_Main` nodes connected automatically to that composition's existing MediaOut.
4. No manual Fusion clip creation or MediaOut wiring is permitted.

### A02/A16 — offline geography

In Scene search and add:

- **Brazil** / alias **Brasil** as Country;
- **Argentina** as Country;
- **Mato Grosso** as State/Province.

Search also:

- **São Paulo** and **Sao Paulo**;
- **Rio de Janeiro**;
- **Georgia**.

Results must remain typed/hierarchical and work with internet disabled. Country polygons come from Natural Earth Admin 0 1:50m. Required Brazil State polygons use Natural Earth Admin 1 1:10m and must report that real scale; CartoRig must never relabel them as 1:50m.

### A03 — Scene is structural only

1. In the Scene window select the Brazil object in **Structural object**.
2. Rename its display name, for example to **Brazil Highlight**.
3. The Scene action must not select a Fusion node, change the active Inspector or alter Brazil's physical node name/UUID.
4. The physical node remains `CR_Country_Brazil_001`; only the display metadata changes.

### A04/A05 — native Inspector and independent rendering

1. Close Scene.
2. Open the corresponding Fusion Composition.
3. Click `CR_Country_Brazil_001` directly in the Node Editor.
4. Its Inspector must expose **Control** and **Motion** pages. In Control, change Fill Color/Opacity and Stroke settings.
5. Verify only Brazil changes.
6. Select Mato Grosso directly and change its Fill/Stroke.
7. Verify Mato Grosso changes independently while Brazil, Argentina and WorldMap retain their values.
8. Select Camera and change Center Latitude/Longitude, Zoom and Bearing. All geographic layers must move together without changing their source identity.

Scene Control must show read-only scene UUID/title/schema, the managed WorldMap → Regions → Camera → Scene → MediaOut chain and installed Natural Earth diagnostics.

### Persistence

1. Save the project.
2. Close Resolve.
3. Reopen the project with the Scene window closed.
4. Verify Scene/WorldMap/Camera/Country/State nodes, UUIDs, source metadata, Fill/Stroke values, camera settings and render are preserved.
5. Reopen cartorig-dev and verify the structural list reconstructs from the existing composition.

## Data expected in 0.7.0

The installer contains an offline runtime generated from Natural Earth commit:

`f1890d9f152c896d250a77557a5751a93d494776`

It includes:

- Natural Earth 1:50m Land v4.1.0;
- Admin 0 boundary lines 1:50m v5.1.0;
- Admin 0 countries 1:50m v5.1.1;
- Admin 1 States/Provinces 1:10m v5.1.1;
- Populated Places 1:50m v5.1.2;
- per-feature Region geometry files;
- catalog and source/hash manifest.

No end-user geodata preparation or download is required.

## Failure evidence

Use **Save Report** after the exercise even if it succeeds. The report identifies the installed version and exact build commit.

If the script/menu/runtime appears incomplete, run the read-only `verificar-cartorig-dev.cmd` included with the artifact and provide its report. Do not manually repair the Fusion graph as a workaround.

## Acceptance limit

Local automated tests prove only source/data/domain/transaction contracts. The manual installer build proves only packaging. Neither proves Viewer, Inspector, render, menu enumeration or save/reopen in licensed Resolve Studio 20.

A01–A20/B01–B20 stay `NOT RUN` until actual host evidence is reviewed.

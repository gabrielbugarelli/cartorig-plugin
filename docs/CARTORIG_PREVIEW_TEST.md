# CartoRig — Windows development preview 0.5

**Only one Scripts menu entry is installed: `Workspace → Scripts → Comp → cartorig-dev`.** All future preview upgrades use the same entry, installer identity and Windows Installed Apps entry. This is a development diagnostic, **not** the stable CartoRig V1 plugin.

## Install or update

1. Close DaVinci Resolve Studio 20.
2. In the [GitHub Actions Windows preview build](https://github.com/gabrielbugarelli/cartorig-plugin/actions/workflows/cartorig-preview-windows.yml), open a **successful run** associated with the intended commit. Download the **cartorig-preview-...** artifact ZIP; extract the ZIP.
3. Run `cartorig-dev-0.5-win64.exe` and complete the Windows installer wizard. No terminal, Python, SDK, compiler, geodata or manual file copying is required.
4. Restart Resolve. Only **cartorig-dev** should appear under `Workspace → Scripts → Comp`.
5. If `CartoRig Host Probe` or `CartoRig Native Integration Probe` were previously installed by our 0.1/0.2 installers, the 0.5 installer calls **their own uninstallers** to remove the old scripts and obsolete Installed Apps registrations. It does not remove scripts, projects or folders belonging to other software.
6. Subsequent CartoRig preview installations replace the existing CartoRig installation in place. If an unmanaged script already exists at `Comp/cartorig-dev.lua`, installation stops rather than overwriting it.

## Run a controlled test

1. Create a **disposable project** and open a Fusion Composition, then choose **Workspace → Scripts → Comp → CartoRig**.
2. Click **Check Compatibility**. This only reads the Fusion environment and node count; it does not change the composition.
3. Tick **I confirm this is a disposable test project** and click **Create Test Nodes**. The test attempts to create five separately identifiable Fusion tools (`CRTEST_Source`, `CRTEST_Backdrop`, `CRTEST_Transform`, `CRTEST_Composite`, `CRTEST_Output`) connected **only to one another**.
4. **The composition can already contain other nodes.** The test preserves them without reconnecting, renaming, removing, selecting or editing them. Name collisions with the five reserved `CRTEST_` names and a previous CartoRig test graph are reported explicitly; repeated clicks will not create duplicates.
5. Check whether all five test tools appear in the Node Editor. Select `CRTEST_Composite` and send it to the Viewer; verify output and the native Inspector parameters when selecting `CRTEST_Transform`.
6. Save the **disposable project**, close it, reopen it, open CartoRig again, and select **Verify Test Nodes**. This checks that five tools retained their persistent CartoRig test identifiers; project save/reopen and Viewer appearance still require **your manual confirmation**.
7. Click **Save Report**, then send the generated `CartoRig-Test-*.txt` from your Windows temporary directory, together with a screenshot of the Node Editor if an unexpected result occurred.

Do not run experimental node creation on important project files. The diagnostic does not promise to undo nodes that have already been saved. Its failure recovery attempts to remove **only the nodes it created during that invocation**.

## Uninstall

Open **Windows → Installed Apps → cartorig-dev (Development Preview) → Uninstall**. The uninstaller removes only the `cartorig-dev.lua` entry and its own local runtime/docs; it leaves external scripts, Fusion projects and Resolve untouched.

## Verification boundaries

This version does **not** implement real CartoRig Scene/WorldMap/Camera nodes, Natural Earth maps, native Inspector Control/Motion for authorial nodes, render, or the acceptance matrix. A/B tests remain **40 NOT RUN** until the real Studio 20 acceptance workflow executes. CI validates tests of reusable Lua modules and this Windows installation/update/removal package; it cannot validate Fusion running on the editor's computer. There is no stable release.

## Failure report from 0.3 and regression protection

The editor's 2026-11-10T23:55:18Z report on Resolve 20.3.1.6 showed `AddTool failed: Background`. Unlike the earlier 0.2 failure, graph preflight completed and the actual API call returned no tool handle. The previous implementation called `comp:AddTool(id, false, x, y)`; version 0.4 tries the documented `comp:AddTool(id, x, y)` form first and only tries the explicit-defaults overload when the graph was unchanged. Errors now identify both attempts and detect a graph that changed without a usable handle. **This does not prove creation until it is re-run in Resolve.**

The installation tests now include migration from historical versions 0.1, 0.2 **and 0.3** to the single `cartorig-dev.lua` menu entry. No other Scripts entry is installed. Future developer previews update that same entry.

## Marco A — first Scene / WorldMap / Camera functional test (0.5)

This is an **implementation candidate**, not an approved V1. After installing the Windows GUI package and restarting Resolve Studio 20:

1. Open **a disposable project**, add a Fusion Composition and go to the Fusion page. Other unrelated nodes are preserved; the existing MediaOut is used only if its image input is empty.
2. Choose **Workspace → Scripts → Comp → cartorig-dev**. This is the **only** installed Scripts menu entry.
3. Enter a title and click **Create Scene**. The UI Manager should show three objects with different UUIDs. The Node Editor should contain physical `CR_WorldMap_Main`, `CR_Camera_Main` and `CR_Scene_Main`. The graph should be automatically connected to an available MediaOut; no manual wiring is required.
4. Close the Scene window and select **CR_WorldMap_Main directly in the Fusion Node Editor**. Check the Control and Motion pages in its native Inspector. Change Land Fill Color and Ocean Fill Color; the Viewer should update the offline Natural Earth 1:50m world land/ocean.
5. Select **CR_Camera_Main directly in Node Editor**, use its Control to adjust Zoom, Center Latitude/Longitude and Bearing, and verify whether the Viewer responds without moving geodata anchors.
6. Select **CR_Scene_Main directly** and confirm it has no visual style or motion editing. Confirm selecting Scene rows did **not** select Fusion nodes.
7. Try Create Scene a second time; it must refuse with `SCENE_EXISTS` without adding a second set. Open Scene should only reconstruct the object list.
8. Save, close, reopen the **disposable** project. Re-open `cartorig-dev` and choose **Open Scene**, then verify the three nodes, values, connections, land image and MediaOut/Viewer. Close the window and render a test clip from Deliver if possible.
9. Click **Save Report** and send the resulting `cartorig-dev-Test-*.txt`, plus screenshots of the graph and Viewer (whether it renders or shows an error). Report the precise Studio version.

**Do not use this preview on production projects.** The native Fuse output and Save/Reopen behavior have not been tested yet in the real Resolve host. Failure must be reported as such, not silently corrected or labelled PASS. The early map implementation does not yet render borders or country/state layers; these remain explicit feature gaps rather than fake shapes.

This installer bundles Natural Earth 1:50m Land and Fuse modules; the editor does not need Python, GIS datasets or developer tools. The free GitHub Actions Windows pipeline builds and tests installation/update/uninstallation only. It cannot validate the Fuse render without Resolve Studio 20.

Version 0.5 automatically upgrades prior managed `cartorig-dev` installs; future developer previews continue to use the same `cartorig-dev` menu item.

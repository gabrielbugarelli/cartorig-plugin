# CartoRig — Windows development build 0.5.1

**This is a development preview for DaVinci Resolve Studio 20, not the stable V1 release.** The only entry installed in Workspace → Scripts → Comp is named `cartorig-dev`.

## Installation

1. Close DaVinci Resolve Studio 20.
2. Download the artifact `cartorig-dev-<commit>` from the successful **cartorig-dev Windows** GitHub Actions run, extract it, and run **`cartorig-dev-0.5.1-win64.exe`**. Do not use the older 0.5 installer.
3. Finish the graphical installation, then restart Resolve and open its **Fusion** page. Under **Workspace → Scripts → Comp**, select **cartorig-dev**. No Python, compiler, SDK, CMake or manual data installation is necessary.

The installer updates the existing development entry in place without running the previous 0.4/0.5 developer uninstaller. It preserves the former `cartorig-dev.lua` until the new entrypoint has been staged and activated. Legacy auxiliary diagnostic entries are migrated by their own uninstallers. Unmanaged scripts in the Fusion Scripts directory are not deleted.

The launcher is placed in the per-user Resolve directory:

`%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Comp\cartorig-dev.lua`

The underlying UI implementation is separate, at:

`%LOCALAPPDATA%\CartoRig\App\lua\cartorig_scene_ui.lua`

The installer writes `%LOCALAPPDATA%\CartoRig\App\install-location.txt`, recording the exact locations. If the UI fails on invocation, the launcher writes `%LOCALAPPDATA%\CartoRig\App\last-error.txt`. These files can be sent to the developer when diagnosing an issue; they do not contain the contents of editing projects.

## Editor test (disposable project only)

1. Open a disposable Fusion Composition, select `cartorig-dev` from the Scripts menu and click **Create Scene**.
2. Look for three individual nodes: `CR_WorldMap_Main`, `CR_Camera_Main` and `CR_Scene_Main`, automatically connected to an unused/new MediaOut.
3. Close the Scene window. Click `CR_WorldMap_Main` directly in the Fusion Node Editor and check the Inspector's Control page and the local Natural Earth 1:50m world land/ocean output in Viewer.
4. Select `CR_Camera_Main` directly and try zoom and center coordinates. Do not interpret Scene rows as Fusion node selection.
5. Save, close and reopen the disposable project, then reopen `cartorig-dev` and choose **Open Scene**. Check graph connectivity, parameter persistence and render.
6. Use **Save Report** and send `cartorig-dev-Test-*.txt` from the Windows temporary folder. Also report Viewer/Inspector errors and provide screenshots when relevant.

**If cartorig-dev is absent from the Scripts menu:** do not install multiple diagnostics or modify shared Fusion directories. First check whether `install-location.txt` and the exact `cartorig-dev.lua` path above exist. Send the installation record, plus `last-error.txt` if generated. The installer only verifies installation to the documented path; enumeration by your licensed Resolve Studio 20 requires a real-host test and is **not** proven by the free Windows runner.

## Removing the preview

Windows Settings → Installed apps → **cartorig-dev (Development Preview)** → Uninstall. It removes the dedicated entry and installed runtime/Fuses/dataset without deleting projects or unrelated scripts.

## Verification status

GitHub Actions checks script syntax, source tests, installer file hashes, migration from prior releases, repeated upgrade and clean install/uninstall using the standard free Windows runner. These **do not verify the Fusion menu, Fuse render or Inspector in licensed Resolve**. Scene/WorldMap/Camera render and persist tests remain NOT RUN until tested in that host. The A01–A20/B01–B20 product acceptance matrix remains 40 NOT RUN. No stable release has been published.

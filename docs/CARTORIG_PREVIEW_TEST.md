# cartorig-dev 0.6.1 — Editor installation and Scene workflow

**Windows · DaVinci Resolve Studio 20 · development build, not V1 release.**

The only scripts entry is **Workspace → Scripts → cartorig-dev**. It is installed in the **Utility** scope so it can open from any Resolve page. No additional technical diagnostics are installed in the Scripts menu.

## Install / upgrade

1. Close DaVinci Resolve.
2. From the **cartorig-dev Scene Timeline Windows** GitHub Actions run for the chosen commit, download the successful artifact named `cartorig-dev-timeline-<commit>`.
3. Extract the ZIP and double-click **`cartorig-dev-0.6.1-win64.exe`**. No additional dependencies, Python, SDK, manual data install or commands are required.
4. Restart Resolve and open an existing test project. **Do not manually add Fusion Composition to the timeline.**
5. Open **Workspace → Scripts → cartorig-dev** on the Edit page. The Scene window will appear without an active Fusion Composition.

Upgrading from 0.5.2 installs the new Utility launcher before retiring the previous Comp launcher. The older file is retained as a non-script backup at `Comp\cartorig-dev.lua.migrated-060` until the next uninstall. After installation, exactly one active `cartorig-dev.lua` should exist under `Scripts\Utility`.

## First Studio 20 acceptance exercise

1. Use a **disposable project/timeline**.
2. Click **Create Scene** five times in the same CartoRig window, changing the title if desired.
3. The expected result is **five distinct Fusion Composition clips on the timeline**, each with its own UUID and real nodes `CR_WorldMap_Main`, `CR_Camera_Main`, `CR_Scene_Main`, automatically connected to **that composition's MediaOut**. You should not need to add any clip or manually connect any output.
4. Close the window and select a CartoRig clip, then inspect the Fusion Node Editor. In WorldMap, adjust Land Fill Color and verify the Viewer/MediaOut output. Change the Camera's center and zoom directly in its Inspector.
5. Save, close and reopen the project. Verify that the five clips still exist, remain independent and render. Opening cartorig-dev again must show the scene list automatically; there is **no Open Scene button**.
6. Test while keeping unrelated editorial clips in the timeline. The CartoRig insertion must append safely and **must not overwrite or move** existing clips.
7. Use **Save Report** and send the TXT from `%TEMP%` with screenshots if errors occur.

If Resolve refuses to create the first empty timeline, refuses to seek safely to the append boundary, cannot return the inserted Fusion Composition or rejects the default MediaOut connection, **the command fails explicitly**. These exact host capabilities have not yet been verified with this new workflow. Do not edit your main project to experiment.

## Verify the Resolve API context fix

Version 0.6.1 validates every API receiver before accessing methods, and it rejects a numerical global `resolve`. When the host supplies a numerical global, the launcher reacquires a valid Resolve API object with `bmd.scriptapp("Resolve")`. If neither exposes `GetProjectManager`, the command reports the actual value types without crashing.

The regression suite tests numeric and malformed API handles, real C-proxy lookup exceptions, initialization without a project, nil video-track lists, and five independent Scene creations. These Lua/Python tests are **not** a substitute for running Resolve Studio 20 itself.

If `Create Scene` is blocked, use **Save Report** and send the generated TXT. It will contain the specific API method and observed return type. Do not manually add a Fusion Composition or connect MediaOut as a workaround.

## Support and uninstall

The ZIP includes a read-only **`verificar-cartorig-dev.cmd`** diagnostic. Running it creates a report in `%TEMP%` without modifying project files. If the menu entry is present but the UI does not open, inspect `%LOCALAPPDATA%\CartoRig\App\last-error.txt`.

Windows Installed Apps → **cartorig-dev (Development Preview)** → Uninstall. It removes only the managed scripts, Fuses, assets and their temporary staging files, not Resolve projects or unrelated scripts.

## Verification limits

GitHub Actions tests Lua/Python logic, five-composition lifecycle through explicitly marked mocks, Windows installation/upgrade/uninstall and source integrity on **free public standard runners**. The runner cannot validate UI menu enumeration, timeline insertion or the Fuses in an actual licensed Resolve Studio 20. Full A01–A20/B01–B20 acceptance remains **40 NOT RUN** until host test evidence is reviewed.

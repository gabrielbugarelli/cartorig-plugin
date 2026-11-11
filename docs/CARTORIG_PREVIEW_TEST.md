# cartorig-dev 0.5.2 — Windows development preview

**This is an engineering preview, not the CartoRig V1 stable release.** The installer places exactly one new Fusion Scripts entry: `Workspace → Scripts → Comp → cartorig-dev`. Existing, unidentified third-party scripts are never deleted.

## Installation or repair

1. Close DaVinci Resolve Studio 20 completely.
2. Download the artifact ZIP from the **successful** GitHub Actions run named **cartorig-dev Windows**, associated with the exact intended commit. Extract the ZIP.
3. Double-click `cartorig-dev-0.5.2-win64.exe` from the same Windows account that normally opens Resolve. The installer needs no system Python, external datasets, compiler, SDK or third-party services.
4. Restart DaVinci Resolve Studio 20, go to the Fusion page with a Fusion Composition open, then choose **Workspace → Scripts → Comp → cartorig-dev**.

### What this version changes

- The `cartorig-dev.lua` launcher has a permanent per-user path: `%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Comp\cartorig-dev.lua`.
- The installer recovers a launcher left in `.backup` after an interrupted update, clears an obsolete `.pending` file, stages the new launcher before promoting it, and tries to restore the previous launcher on activation failure. It does **not** execute a previous CartoRig developer uninstaller before updating.
- The UI is a separate file, `%LOCALAPPDATA%\CartoRig\App\lua\cartorig_scene_ui.lua`, while the single menu launcher is a short script. Top-level early exits due to missing Fusion APIs or modules now explicitly report failure rather than silently terminating.
- Previous diagnostic files (`CartoRig Host Probe.lua`, `CartoRig Native Integration Probe.lua`, `CartoRig.lua`, `CartoRigProbe\native_probe.lua`) are deleted **only when their entire SHA-256 matches a known, pinned historical source** (LF or CRLF). Unknown or modified files are preserved; their existence does not block installing `cartorig-dev`.
- A Windows cleanup report is written to `%LOCALAPPDATA%\CartoRig\App\legacy-cleanup.txt`; `install-location.txt` records the actual launcher and UI paths.
- The user-facing menu name remains exactly **cartorig-dev**. No extra diagnostic script appears in Resolve.

## First test in the editor

1. Open a disposable project with a Fusion Composition and choose `Workspace → Scripts → Comp → cartorig-dev`.
2. Confirm the Scene UI opens. Click **Create Scene**, then inspect the physical Scene, WorldMap and Camera nodes in the Node Editor.
3. Choose WorldMap or Camera directly in the Node Editor and check the Inspector and Viewer.
4. Save/close/reopen the disposable project and choose **Open Scene**. Share the TXT from **Save Report** and any Fusion errors.

If the menu entry is still missing, execute **`verificar-cartorig-dev.cmd`** from the diagnostic files bundled in the same Actions artifact. Run it in the **same Windows account** as Resolve, not as a different administrator. It will write `%TEMP%\cartorig-dev-install-check.txt`. Send that file for inspection. It only reads directories and does not touch any Resolve project.

If the entry is listed but does not open, send `%LOCALAPPDATA%\CartoRig\App\last-error.txt` and `install-location.txt`. The launcher now reports both Lua exceptions and early `return` failures.

## Automated checks and limits

GitHub Actions uses standard **free Windows runners** and only free build-time tools. It tests package compilation, SHA-256 file integrity, migration from prior versions 0.1–0.5.1, interrupted update recovery, stale backups, complete legacy source-only cleanup, preservation of unknown scripts, clean installation, repeated updates and uninstallation. Lua and Python tests cover launcher status reporting and installer source invariants.

These checks **do not prove** enumeration in the Resolve Studio 20 Scripts menu or native Fuse rendering; those require an editor's host run. The 40 mandatory A01–A20/B01–B20 V1 acceptance cases remain NOT RUN. No release can be approved.

## Uninstallation

Windows → Installed Apps → **cartorig-dev (Development Preview)** → Uninstall. It removes its dedicated launcher, UI, Fuses and bundled data, never shared Resolve script directories, other scripts or editing projects. Unknown legacy files preserved during installation remain available and are reported rather than silently removed.

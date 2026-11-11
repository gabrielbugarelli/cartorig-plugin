# cartorig-dev 0.6.4 — Editor installation and Scene workflow

**Windows · DaVinci Resolve Studio 20 · development build, not V1 release.**

The only scripts entry is **Workspace → Scripts → cartorig-dev**. It is installed in the **Utility** scope so it can open from any Resolve page. No additional technical diagnostics are installed in the Scripts menu.

## Install / upgrade

1. Close DaVinci Resolve.
2. From the **cartorig-dev Scene Timeline Windows** GitHub Actions run for the chosen commit, download the successful artifact named `cartorig-dev-timeline-<commit>`.
3. Extract the ZIP and double-click **`cartorig-dev-0.6.4-win64.exe`**. No additional dependencies, Python, SDK, manual data install or commands are required.
4. Restart Resolve and open an existing test project. **Do not manually add Fusion Composition to the timeline.**
5. Open **Workspace → Scripts → cartorig-dev** on the Edit page. The Scene window will appear without an active Fusion Composition.

Upgrading from a recognized 0.5.1/0.5.2 Comp launcher verifies its normalized SHA-256, activates the new Utility launcher first, retires the legacy entry, and removes the temporary migration backup only after the new entry is active. Unknown or modified same-name scripts are preserved and the upgrade is blocked. After installation, exactly one active managed `cartorig-dev.lua` should exist under `Scripts\Utility`.

## First Studio 20 acceptance exercise

1. Use a **disposable project/timeline**.
2. Click **Create Scene** five times in the same CartoRig window, changing the title if desired.
3. The expected result is **five distinct Fusion Composition clips on the timeline**, each with its own UUID and real nodes `CR_WorldMap_Main`, `CR_Camera_Main`, `CR_Scene_Main`, automatically connected to **that composition's MediaOut**. You should not need to add any clip or manually connect any output.
4. Close the window and select a CartoRig clip, then inspect the Fusion Node Editor. In WorldMap, adjust Land Fill Color and verify the Viewer/MediaOut output. Change the Camera's center and zoom directly in its Inspector.
5. Save, close and reopen the project. Verify that the five clips still exist, remain independent and render. Opening cartorig-dev again must show the scene list automatically; there is **no Open Scene button**.
6. Test while keeping unrelated editorial clips in the timeline. The CartoRig insertion must append safely and **must not overwrite or move** existing clips.
7. Use **Save Report** after the test. The TXT records the installed version and exact GitHub Actions commit; send that report with screenshots if errors occur.

If Resolve refuses to create the first empty timeline, refuses to seek safely to the append boundary, cannot return the inserted Fusion Composition or rejects the default MediaOut connection, **the command fails explicitly**. These exact host capabilities have not yet been verified with this new workflow. Do not edit your main project to experiment.

## Verify the Resolve API context fix

Version 0.6.4 validates every API receiver before accessing methods, and it rejects a numerical global `resolve`. When the host supplies a numerical global, the launcher reacquires a valid Resolve API object with `bmd.scriptapp("Resolve")`. If neither exposes `GetProjectManager`, the command reports the actual value types without crashing.

The regression suite tests numeric and malformed API handles, real C-proxy lookup exceptions, initialization without a project, nil video-track lists, and five independent Scene creations. These Lua/Python tests are **not** a substitute for running Resolve Studio 20 itself.

If `Create Scene` is blocked, use **Save Report** and send the generated TXT. It will contain the specific API method and observed return type. Do not manually add a Fusion Composition or connect MediaOut as a workaround.

## Blackmagic API contract refactor and 0.6.3 host regression

The previous 0.6.3 candidate was executed in Resolve Studio 20.3.1 and **failed** before Scene insertion. The Lua binding returned the documented `GetItemListInTrack()` list with an internal `__flags` table member. The 0.6.3 implementation iterated the whole table with `pairs()`, treated that numeric metadata value as a TimelineItem and attempted `GetUniqueId()` on it.

0.6.4 does not special-case that symptom in TimelineService. Resolve collection shapes are centralized in `CartoRig.blackmagic_api`:

- documented `[items...]` returns are normalized as strict 1-based sequences;
- `GetMarkers()` is normalized as a numeric-key dictionary;
- `GetMarkInOut()` is normalized as the documented `video`/`audio` dictionary;
- Fusion `GetToolList()` is treated as a table of Tool handles, without assuming numeric indices;
- the observed binding member `__flags` is removed only inside this boundary; any other key that violates the documented collection shape fails closed.

The Lua regression fixtures deliberately include `__flags` on item lists, marker dictionaries, marker information and In/Out dictionaries. A non-metadata unexpected key must still block before any timeline insertion. See `docs/BLACKMAGIC_API_CONTRACTS.md`.

## Resolve TimelineItem position compatibility

Version 0.6.4 calls `TimelineItem.GetStart(false)` and `GetEnd(false)` explicitly. The Resolve scripting API documents the `subframe_precision` argument; the 0.6.1 implementation omitted it and could receive non-numeric/nil positions in the Lua binding, causing `TRACK_POSITION_INVALID` before scene insertion. The regression suite now uses mocks that deliberately return nil unless `false` is supplied.

If a position still cannot be read, CartoRig reports the item name, value and Lua type returned by both methods instead of the generic 0.6.1 message.

## Reviewed 0.6.4 Blackmagic-contract timeline transaction

Version 0.6.4 is a safety rewrite of Scene insertion, not merely another error-message patch.

Before insertion CartoRig snapshots all existing **video, audio and subtitle** TimelineItems by their Resolve UUIDs, start/end frames, track location and lock state. Timeline markers are also snapshotted. The append boundary is the greatest end among clips and markers, so a Scene is not inserted before editorial audio, subtitles or markers that extend beyond the last video clip.

CartoRig temporarily clears only the video In/Out range because Resolve can use it while creating a Fusion Composition. The original video marks are restored before the composition is authored. The original page and playhead are captured for rollback.

After Resolve inserts the Fusion Composition, CartoRig verifies:

- the new item has a real `GetUniqueId()`;
- it landed on a pre-existing video track rather than silently creating or changing another track;
- it starts exactly at the validated append boundary;
- every pre-existing video/audio/subtitle item remains on the same track and frame range;
- track counts and lock states are unchanged;
- timeline markers are unchanged.

If any verification fails, CartoRig deletes only the newly inserted clip, removes only empty tracks that were created during the failed transaction, restores track locks, video In/Out marks, playhead and page, and validates the restored timeline. A timeline created solely for a failed command is deleted through the MediaPool API. If external material was moved and cannot be restored safely, the command reports **ROLLBACK_INCOMPLETE** instead of claiming success.

Timeline-created Scenes require the actual MediaOut supplied by the new Fusion Composition. The NodeFactory is called with `disallow_new_mediaout=true`; it will not manufacture a second MediaOut as a fallback.

These checks are exercised by Lua/Python tests, including simulated ripple across audio/subtitle tracks, locked targets, markers after the last clip, auto-created tracks, missing UUIDs, NodeFactory failures, and five Scene creations. They remain mocks and **do not replace the Resolve Studio 20 host test**.

## Support and uninstall

The ZIP includes a read-only **`verificar-cartorig-dev.cmd`** diagnostic. Running it creates a report in `%TEMP%` without modifying project files. If the menu entry is present but the UI does not open, inspect `%LOCALAPPDATA%\CartoRig\App\last-error.txt`.

Windows Installed Apps → **cartorig-dev (Development Preview)** → Uninstall. Resolve must be closed. Files in Resolve's shared Scripts/Fuses directories are removed only when their normalized SHA-256 matches a known CartoRig-managed version; modified or replacement files are preserved. Private CartoRig runtime files are removed. Resolve projects and unrelated scripts are never targeted.

## Verification limits

GitHub Actions tests Lua/Python logic, five-composition lifecycle through explicitly marked mocks, Windows installation/upgrade/uninstall and source integrity on **free public standard runners**. The runner cannot validate UI menu enumeration, timeline insertion or the Fuses in an actual licensed Resolve Studio 20. Full A01–A20/B01–B20 acceptance remains **40 NOT RUN** until host test evidence is reviewed.

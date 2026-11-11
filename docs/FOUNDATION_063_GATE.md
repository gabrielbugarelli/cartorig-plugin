# CartoRig 0.6.3 — foundation candidate gate

This branch is the frozen candidate for the automatic Scene foundation.

It does **not** mark CartoRig V1 or Milestone A complete. The 40 acceptance cases A01–A20/B01–B20 remain NOT RUN until the required licensed Resolve Studio 20 host executions exist.

The candidate is eligible for editor installation only when the exact same commit has all of these GitHub Actions results:

- CI: PASS.
- Integration: PASS.
- cartorig-dev Scene Timeline Windows: PASS and an installer artifact whose manifest identifies the same commit.

Foundation scope frozen here:

- one Workspace → Scripts → cartorig-dev Utility entry;
- Create Scene can start from Edit without a manually prepared Fusion Composition;
- one independent Fusion Composition TimelineItem per command;
- actual Scene, WorldMap and Camera Fusion nodes wired to the composition's existing MediaOut;
- fail-closed timeline transaction protecting existing video/audio/subtitle clips, track counts/names/enabled/lock state, markers and In/Out ranges;
- verified rollback of created clip/timeline/tracks and Fusion graph resources;
- persisted Scene UUID/title/schema/dataset source and per-node UUID/display metadata;
- native Fusion UUID preference with validated fallback;
- Natural Earth 1:50m Land structural validation before graph mutation;
- installer/upgrade/uninstall ownership verification for shared Resolve scripts/Fuses;
- Resolve-closed installer/uninstaller preflight;
- exact build commit stored in the installed runtime and included in Scene diagnostic reports.

The first real-host editor test after a green package is still required. A mock, standard Windows runner or this document does not approve host behavior.

# CartoRig Milestone A — Native Fusion Integration Test 0.2

**Diagnostic only. This installer does not install CartoRig 1.0, a geographic renderer, authorial nodes, Natural Earth data, or Inspector Control/Motion pages.** It must not be used as V1 acceptance evidence.

## GUI installation and test

1. Download the ZIP artifact from a passing GitHub Actions run named **Milestone A Native Integration Windows** for the exact commit. Extract it and run `CartoRig-NativeIntegration-0.2-win64.exe`. The package includes SHA-256 and a manifest.
2. Close and reopen **DaVinci Resolve Studio 20**.
3. Create a **NEW disposable project and Fusion Composition** with no tools except the default MediaOut. Never run this test in an editing project.
4. Open **Workspace → Scripts → Comp → CartoRig Native Integration Probe**.
5. Confirm the disposable composition and click **Create Native Test Graph**. It creates five physical nodes named `CRTEST_Source`, `CRTEST_Backdrop`, `CRTEST_Transform`, `CRTEST_Composite`, `CRTEST_Output`. Every link goes between new test tools only. It does not modify the default MediaOut or external objects.
6. Inspect the five nodes in the native Node Editor and select `CRTEST_Composite` for Viewer (keyboard 1 or 2). Confirm the diagnostic solid-colour output appears and that clicking `CRTEST_Transform` shows its native Inspector controls.
7. Save the disposable project, **close the project and reopen it**, run the diagnostic again and click **Verify Persisted Nodes**. Check that all five test nodes and their connections remain present.
8. Click **Save Report** and send the TXT saved to Windows `%TEMP%`, plus screenshots if possible. The script cannot tell whether the project was genuinely closed/reopened; confirm that part yourself.

If a test fails or any node is missing, do not try it in a production composition. Send the recorded error. The generated nodes remain in the disposable project; discard that project or use Fusion Undo immediately after creation. The diagnostic does not automatically remove saved project nodes.

## GUI uninstallation

Open Windows **Installed Apps → CartoRig Native Integration Probe 0.2 → Uninstall**. The uninstaller removes only the diagnostic script, its Lua module and the diagnostic's own documents and registry entry. It does not uninstall Resolve, the previous Host Probe 0.1 or any existing projects. It needs no system Python, SDK, CMake or GIS datasets.

## Evidence boundaries

This exercise probes actual `AddTool`, `SetAttrs`, `ConnectInput`, `SetData/GetData`, `StartUndo/EndUndo`, and physical tools in Fusion. Only direct testing on the user's host can validate actual execution. Unit tests use an explicit mock only to validate defensive logic and **never** approve the host acceptance matrix A01–B20.

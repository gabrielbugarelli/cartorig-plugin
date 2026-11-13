# Blackmagic API contracts used by CartoRig

This document is a development gate for CartoRig's Resolve/Fusion integration.
It is not a replacement for Blackmagic documentation.

## Sources and precedence

1. **Authoritative Resolve scripting reference shipped by Blackmagic Design**:
   `C:\ProgramData\Blackmagic Design\DaVinci Resolve\Support\Developer\Scripting\README.txt`
   on Windows. Blackmagic's own release documentation directs developers to
   **Help → Documentation → Developer** for detailed scripting documentation.
2. **Blackmagic Fusion Scripting Guide and Reference Manual** for Composition/
   Operator contracts that are not described in the Resolve scripting README.
3. **Observed Resolve Studio 20.3.1 host evidence**. Observations may clarify
   binding details that the documentation does not specify, but they never
   override a documented contract.
4. Tests and mocks. Mocks must model (1) plus known binding observations from (3);
   they are never authority for host behavior.

A public mirror of the Blackmagic README snapshot dated 18 Aug 2025 (Resolve
20.2) is used during cloud review because GitHub Actions does not contain a
licensed Resolve installation. Before any release claim, the README shipped
with the target Resolve Studio 20 installation remains authoritative.

## Native Fuse Input temporal contract

Blackmagic's **Fusion Fuse SDK** distinguishes two signatures that must not be
interchanged:

- `Input:GetValue(request)` requires the **Request object** supplied to
  `Process(req)`.
- `Input:GetSource(number frame)` reads a control's **Parameter** at a
  numeric frame, including the `time` argument to `NotifyChanged(inp,param,time)`.
- `Input:SetSource(Parameter, number frame)` changes the value at the specified
  frame; if that input is already animated, it affects the appropriate
  keyframe. A static camera action does not add a preset or animator itself,
  but it must not promise to preserve an existing animated channel unchanged.

`CartoRigCamera.fuse` uses `GetSource(time)` for Focus/Fit buttons and
`GetValue(req)` only in the render function. The local regression test
`tests/lua/test_camera_fuse.lua` rejects a numeric event frame being passed
to `GetValue`. Real Resolve Studio 20 acceptance remains mandatory.

## Collection shapes

| API | Blackmagic contract | CartoRig handling |
| --- | --- | --- |
| `Timeline.GetItemListInTrack(type,index)` | `[items...]` list | Strict 1-based sequence via `blackmagic_api.sequence`. |
| `Timeline.GetMarkers()` | `{markers...}` dictionary keyed by frameId | Numeric-key dictionary via `blackmagic_api.numeric_dict`. |
| `Timeline.GetMarkInOut()` | `{mark}`; keys `video` / `audio` omitted when unset | Closed named dictionary via `blackmagic_api.named_dict`. |
| `Composition.GetToolList(...)` | table of Tool handles | Table values via `blackmagic_api.table_values`; no numeric-index assumption. |

### Lua binding metadata

Resolve Studio 20.3.1 host evidence shows an internal `__flags` member can be
present in Lua tables returned by the binding, including the value returned by
`GetItemListInTrack()`. `__flags` is **not** a documented list/dictionary
element.

Only the central API boundary recognizes `__flags` as binding metadata. Any
other public key that violates the documented collection shape fails closed.
Application code must never special-case `__flags`.

## Resolve contracts used by Create Scene

| Object | Method | Documented contract used |
| --- | --- | --- |
| Resolve | `Fusion()` | Returns Fusion object. |
| Resolve | `GetProjectManager()` | Returns ProjectManager. |
| Resolve | `OpenPage(pageName)` | Bool; page is one of media/cut/edit/fusion/color/fairlight/deliver. |
| Resolve | `GetCurrentPage()` | Current page string or None. |
| ProjectManager | `GetCurrentProject()` | Current Project. |
| Project | `GetMediaPool()` | MediaPool. |
| Project | `GetTimelineCount()` | int. |
| Project | `GetCurrentTimeline()` | current Timeline. |
| Project | `SetCurrentTimeline(timeline)` | Bool. |
| MediaPool | `CreateEmptyTimeline(name)` | Timeline. |
| MediaPool | `DeleteTimelines([timeline])` | Bool. |
| Timeline | `GetStartFrame()` | int. |
| Timeline | `GetStartTimecode()` | string. |
| Timeline | `GetTrackCount(trackType)` | int; type video/audio/subtitle. |
| Timeline | `AddTrack(trackType,...)` | Bool. |
| Timeline | `DeleteTrack(trackType,index)` | Bool. |
| Timeline | `GetTrackName/SetTrackName` | string / Bool. |
| Timeline | `GetIsTrackEnabled/SetTrackEnable` | Bool / Bool. |
| Timeline | `GetIsTrackLocked/SetTrackLock` | Bool / Bool. |
| Timeline | `GetItemListInTrack` | list of TimelineItems. |
| Timeline | `GetMarkers()` | marker dictionary. |
| Timeline | `GetMarkInOut/SetMarkInOut/ClearMarkInOut` | mark dictionary / Bool / Bool. |
| Timeline | `GetCurrentTimecode/SetCurrentTimecode` | string / Bool on Cut, Edit, Color, Fairlight, Deliver. |
| Timeline | `InsertFusionCompositionIntoTimeline()` | returns TimelineItem. No placement/track/duration parameters are documented. |
| Timeline | `DeleteClips([items], ripple)` | Bool; ripple defaults false. |
| TimelineItem | `GetUniqueId()` | unique string ID. |
| TimelineItem | `GetStart(false)/GetEnd(false)` | integer frame positions when subframe precision is false. |
| TimelineItem | `GetFusionCompCount()` | int. |
| TimelineItem | `GetFusionCompByIndex(index)` | Fusion composition; 1-based index. |
| TimelineItem | `GetName/SetName` | string / Bool. |

## Deliberately unassumed Resolve behavior

The Blackmagic reference documents `InsertFusionCompositionIntoTimeline()`
without arguments. It does **not** document a destination track parameter,
duration parameter, or placement algorithm.

CartoRig therefore does not encode those as assumptions:

1. Snapshot protected editorial state.
2. Enter Edit page before using `SetCurrentTimecode`, as required by the
   documented page support.
3. Seek to the calculated append boundary.
4. Temporarily clear only an existing video In/Out range and restore it.
5. Call `InsertFusionCompositionIntoTimeline()` with no invented arguments.
6. Read the returned TimelineItem's UUID/start/end.
7. Re-scan documented track lists and locate that UUID.
8. Verify destination, frame position and preservation of every pre-existing
   clip/track/marker/mark state.
9. Roll back and report failure if any postcondition differs.

If host behavior changes, this path must fail closed rather than infer a new
placement rule.

## Fusion contracts used by NodeFactory

| Object | Method | Contract |
| --- | --- | --- |
| Composition | `GetToolList([selected][,regid])` | table of Tool handles. |
| Composition | `StartUndo(name)` | starts one undo event. |
| Composition | `EndUndo(keep)` | closes event; `false` discards the undo event, it does **not** replace explicit rollback. |
| Composition | `AddTool(...)` | returns Tool. Coordinate overload is verified from host return and tool attributes. |
| Operator | `ConnectInput(input,target)` | connect/disconnect; target may be Operator/Output/nil. |
| Operator | `Delete()` | removes Tool from composition. |

The official historical Fusion manual and current Resolve host differ in
overload details around `AddTool`. CartoRig's three-argument Lua form
`AddTool(id,x,y)` is retained because it was directly verified in Resolve
Studio 20 host probing. The returned object and RegID are always verified;
failure is never inferred as success.

## Fuse SDK audit for the structural nodes

The structural Fuses were reviewed against Blackmagic's **Fusion SDK — Fuse
Plugin Guide and Reference** (June 2023).

- `Create()`, `self:AddControlPage`, `self:AddInput` and
  `self:AddOutput` follow the documented Fuse UI/input pattern.
- `Input:GetValue(req)` and `Output:Set(req,image)` follow the documented
  Process examples.
- Camera uses `Image:Transform(nil, taglist)`, including center offsets,
  pivot, size, angle and the documented `"Black"` edge mode.
- WorldMap uses `ImageChannel`, `FillStyle`, `ChannelStyle`,
  `ShapeFill` and `PutToImage("CM_Merge", ...)` as documented by the Fuse
  SDK.
- Scene is a pass-through image Tool using the documented GetValue/Set pattern.

This audit does **not** convert Viewer/render behavior into PASS. The actual
Fuses still require Resolve Studio 20 host render, Inspector and save/reopen
evidence.

## Host-independent object identity

`bmd.createuuid` is visible in some Fusion environments but was not found in
the Blackmagic documentation used for this audit. CartoRig 0.6.4 therefore
does not depend on it. Object identity is generated by a local UUID-v4-shaped
generator whose PRNG state is private to `domain.lua`; it neither reseeds nor
consumes Lua's process-global `math.random` state. Domain tests validate UUID
format, collision-free generation for the test volume and absence of global RNG
side effects.

## Numeric marker positions

The Resolve scripting reference describes marker `frameId` and `duration`
as numeric values and does not state that either must be an integer. CartoRig
therefore preserves finite numeric marker offsets/durations exactly in the
snapshot. Only the protected append boundary is rounded upward to the next
whole timeline frame when needed; the marker itself is never rewritten.

## Connection readback

Blackmagic documents `PlainInput.GetConnectedOutput()` as returning the connected
`Output`, and `Link.GetTool()` as returning the Tool that owns an Input/Output.
CartoRig therefore verifies structural graph connections by resolving the connected
Output back to its owning Tool and comparing that Tool object with the requested
upstream Tool. A non-nil connection to the wrong Tool is a failure, not success.

## Intentional raw-API surfaces

Two source areas intentionally do not route every call through the product API
boundary:

- **UIManager widget operations** (`AddWindow`, `GetItems`, `Show`,
  `RunLoop`, `ExitLoop`) follow Blackmagic's documented UIManager/UIDispatcher
  workflow directly. Resolve/Fusion handle acquisition and `bmd` dot-call
  semantics still go through `blackmagic_api.lua`.
- **`native_probe.lua` and historical host probes** deliberately call the host
  API directly because their purpose is to measure which raw host calls work.
  Their observations may justify a later contract update, but probe behavior is
  never used as a substitute for the product boundary.

## Review rule for future API use

A new Resolve/Fusion API dependency is not accepted until all four are present:

1. a row or note in this document identifying the Blackmagic contract;
2. implementation through the appropriate API boundary module;
3. a Lua 5.1 regression covering return shape, failure and relevant binding
   metadata;
4. host evidence when behavior needed by CartoRig is not specified by the
   Blackmagic documentation.

CI or mocks can validate the contract adapter and CartoRig logic. They cannot
turn a licensed Resolve host test into PASS.

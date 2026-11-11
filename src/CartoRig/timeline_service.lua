-- CartoRig | one Scene == one independent Fusion Composition TimelineItem.
-- Resolve timeline edits are fail-closed: snapshot all tracks, append after the
-- global end, verify the new item, and rollback only resources created here.
local factory=require("CartoRig.node_factory")
local M={}

local TRACK_TYPES={"video","audio","subtitle"}

local function lookup(o,name)
  local kind=type(o)
  if kind~="userdata" and kind~="table" then
    return nil,"API_INVALID_RECEIVER: "..tostring(name).." needs an object, got "..kind
  end
  local ok,fn=pcall(function() return o[name] end)
  if not ok then return nil,"API_LOOKUP_FAILED: "..tostring(name)..": "..tostring(fn) end
  if type(fn)~="function" then
    return nil,"API_METHOD_UNAVAILABLE: "..tostring(name).." on "..kind.." (member type "..type(fn)..")"
  end
  return fn
end
local function method(o,name) return lookup(o,name)~=nil end
local function call(o,name,...)
  local fn,err=lookup(o,name)
  if not fn then return nil,err end
  local ok,value=pcall(fn,o,...)
  if not ok then return nil,"API_CALL_FAILED: "..name..": "..tostring(value) end
  return value
end
local function strict(o,name,...)
  local value,err=call(o,name,...)
  if value==nil or value==false then return nil,err or "API_REJECTED: "..name end
  return value
end
local function require_handle(value,returned_by,required_method)
  local _,err=lookup(value,required_method)
  if err then
    return nil,"API_INVALID_HANDLE: "..tostring(returned_by).." returned "..type(value)..
      "; expected object implementing "..required_method.."; "..tostring(err)
  end
  return value
end

local function frame_base(fps)
  local n=tonumber(fps)
  if not n or n<1 or n>120 then return nil end
  return math.floor(n+0.5),n
end
local function parse_tc(tc,nominal)
  if type(tc)~="string" then return nil end
  local h,m,s,sep,f=tc:match("^(%d%d):(%d%d):(%d%d)([:;])(%d%d)$")
  h,m,s,f=tonumber(h),tonumber(m),tonumber(s),tonumber(f)
  if not h or not m or not s or not f or h>=24 or m>=60 or s>=60 or f>=nominal then return nil end
  local total=((h*60+m)*60+s)*nominal+f
  if sep==";" then
    if nominal~=30 and nominal~=60 then return nil end
    local drop=nominal==30 and 2 or 4
    if m%10~=0 and s==0 and f<drop then return nil end
    local minutes=60*h+m
    total=total-drop*(minutes-math.floor(minutes/10))
  end
  return total,sep
end
local function emit_tc(frame,nominal,sep)
  if frame<0 then return nil end
  local nominal_frames=frame
  if sep==";" then
    local drop=nominal==30 and 2 or (nominal==60 and 4 or nil)
    if not drop then return nil end
    local per10=nominal*600-9*drop
    local perMinute=nominal*60-drop
    local whole=math.floor(frame/per10)
    local rest=frame%per10
    nominal_frames=frame+drop*9*whole+drop*math.max(0,math.floor((rest-drop)/perMinute))
  end
  nominal_frames=nominal_frames%(nominal*3600*24)
  local h=math.floor(nominal_frames/(nominal*3600))
  local m=math.floor(nominal_frames/(nominal*60))%60
  local s=math.floor(nominal_frames/nominal)%60
  local f=nominal_frames%nominal
  return string.format("%02d:%02d:%02d%s%02d",h,m,s,sep,f)
end
function M.timecode_add(tc,frames,fps)
  local nominal=frame_base(fps)
  if not nominal or type(frames)~="number" or frames~=math.floor(frames) then
    return nil,"TIMEBASE_UNSUPPORTED: invalid timeline frame rate or frame offset"
  end
  local origin,sep=parse_tc(tc,nominal)
  if not origin then return nil,"TIMECODE_UNSUPPORTED: cannot safely seek from "..tostring(tc) end
  local value=emit_tc(origin+frames,nominal,sep)
  if not value then return nil,"TIMECODE_UNSUPPORTED: cannot encode target frame" end
  return value
end
local function equivalent_tc(a,b,fps)
  local nominal=frame_base(fps)
  if not nominal then return false end
  local af=parse_tc(a,nominal)
  local bf=parse_tc(b,nominal)
  return af~=nil and bf~=nil and af==bf
end

local function item_bounds(item,context)
  local valid,invalid=require_handle(item,context or "TimelineItem","GetStart")
  if not valid then return nil,nil,invalid end
  local start,startErr=call(item,"GetStart",false)
  local finish,endErr=call(item,"GetEnd",false)
  if type(start)~="number" or type(finish)~="number" then
    local name=call(item,"GetName")
    return nil,nil,"TRACK_POSITION_INVALID: "..tostring(context or "TimelineItem")..
      " name="..tostring(name)..
      " GetStart(false)="..tostring(start).." ["..type(start).."]"..
      " GetEnd(false)="..tostring(finish).." ["..type(finish).."]"..
      (startErr and (" start_error="..tostring(startErr)) or "")..
      (endErr and (" end_error="..tostring(endErr)) or "")
  end
  if finish<start then
    return nil,nil,"TRACK_POSITION_INVALID: "..tostring(context or "TimelineItem")..
      " end before start ("..tostring(start).." > "..tostring(finish)..")"
  end
  return start,finish
end
local function item_id(item,context)
  local value,err=call(item,"GetUniqueId")
  if type(value)~="string" or value=="" then
    return nil,"ITEM_ID_INVALID: "..tostring(context).." GetUniqueId returned "..type(value)..
      " "..tostring(value)..(err and ("; "..tostring(err)) or "")
  end
  return value
end
local function item_track(item,context)
  local location,err=call(item,"GetTrackTypeAndIndex")
  if type(location)~="table" or type(location[1])~="string" or type(location[2])~="number" then
    return nil,nil,"TRACK_LOCATION_INVALID: "..tostring(context).." returned "..type(location)..
      " "..tostring(location)..(err and ("; "..tostring(err)) or "")
  end
  return location[1],location[2]
end

local function scalar_signature(value)
  local kind=type(value)
  if kind=="nil" or kind=="boolean" or kind=="number" or kind=="string" then
    return kind..":"..tostring(value)
  end
  return nil,"MARKER_VALUE_INVALID: unsupported marker field type "..kind
end
local function marker_signature(info)
  if type(info)~="table" then return nil,"MARKER_INVALID: marker info is "..type(info) end
  local keys={}
  for key,_ in pairs(info) do keys[#keys+1]=key end
  table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
  local parts={}
  for _,key in ipairs(keys) do
    local value,err=scalar_signature(info[key])
    if not value then return nil,err end
    parts[#parts+1]=type(key)..":"..tostring(key).."="..value
  end
  return table.concat(parts,"|")
end
local function snapshot_markers(timeline,start_frame)
  local markers,err=call(timeline,"GetMarkers")
  if markers==nil and err then return nil,nil,"MARKER_READ_FAILED: "..tostring(err) end
  if markers==nil then markers={} end
  if type(markers)~="table" then return nil,nil,"MARKER_READ_INVALID: GetMarkers returned "..type(markers) end
  local snapshot,maxend={},nil
  for frameId,info in pairs(markers) do
    if type(frameId)~="number" or frameId<0 or frameId~=math.floor(frameId) then
      return nil,nil,"MARKER_POSITION_INVALID: expected non-negative integer offset, got "..tostring(frameId)
    end
    local signature,sigErr=marker_signature(info)
    if not signature then return nil,nil,sigErr end
    local duration=type(info.duration)=="number" and info.duration or 1
    if duration<1 then duration=1 end
    if duration~=math.floor(duration) then
      return nil,nil,"MARKER_DURATION_INVALID: marker "..tostring(frameId).." duration "..tostring(duration)
    end
    snapshot[frameId]=signature
    maxend=math.max(maxend or start_frame,start_frame+frameId+duration)
  end
  return snapshot,maxend
end

local function snapshot_timeline(timeline)
  local timelineStart,startErr=call(timeline,"GetStartFrame")
  if type(timelineStart)~="number" or timelineStart~=math.floor(timelineStart) then
    return nil,"TIMELINE_START_INVALID: "..tostring(startErr or timelineStart)
  end
  local markers,markerEnd,markerErr=snapshot_markers(timeline,timelineStart)
  if not markers then return nil,markerErr end
  local state={items={},counts={},locks={},markers=markers,maxend=markerEnd,timeline_start=timelineStart}
  for _,trackType in ipairs(TRACK_TYPES) do
    local count,err=call(timeline,"GetTrackCount",trackType)
    if type(count)~="number" or count<0 or count~=math.floor(count) then
      return nil,"TRACK_COUNT_INVALID: "..trackType.." returned "..type(count).." "..tostring(count)..
        (err and ("; "..tostring(err)) or "")
    end
    state.counts[trackType]=count
    state.locks[trackType]={}
    for track=1,count do
      local locked,lockErr=call(timeline,"GetIsTrackLocked",trackType,track)
      if type(locked)~="boolean" then
        return nil,"TRACK_LOCK_STATE_INVALID: "..trackType.." "..track.." returned "..type(locked)..
          " "..tostring(locked)..(lockErr and ("; "..tostring(lockErr)) or "")
      end
      state.locks[trackType][track]=locked
      local items,listErr=call(timeline,"GetItemListInTrack",trackType,track)
      if items==nil and listErr then return nil,"TRACK_READ_FAILED: "..tostring(listErr) end
      if items==nil then items={} end
      if type(items)~="table" then
        return nil,"TRACK_READ_INVALID: "..trackType.." "..track.." returned "..type(items)
      end
      for index,item in pairs(items) do
        local id,idErr=item_id(item,trackType.." "..track.." item "..tostring(index))
        if not id then return nil,idErr end
        if state.items[id] then return nil,"TRACK_ID_COLLISION: duplicate TimelineItem UUID "..id end
        local start,finish,posErr=item_bounds(item,trackType.." "..track.." item "..id)
        if not start then return nil,posErr end
        state.items[id]={track_type=trackType,track_index=track,start=start,finish=finish}
        state.maxend=math.max(state.maxend or finish,finish)
      end
    end
  end
  return state
end
local function compare_timeline(timeline,before,allowed_new_id)
  local after,err=snapshot_timeline(timeline)
  if not after then return nil,err end
  for _,trackType in ipairs(TRACK_TYPES) do
    if after.counts[trackType]~=before.counts[trackType] then
      return nil,"EXTERNAL_TIMELINE_CHANGED: "..trackType.." track count changed from "..
        tostring(before.counts[trackType]).." to "..tostring(after.counts[trackType])
    end
    for track=1,before.counts[trackType] do
      if after.locks[trackType][track]~=before.locks[trackType][track] then
        return nil,"EXTERNAL_TIMELINE_CHANGED: lock state changed on "..trackType.." "..track
      end
    end
  end
  for frameId,oldSignature in pairs(before.markers or {}) do
    if after.markers[frameId]~=oldSignature then
      return nil,"EXTERNAL_TIMELINE_CHANGED: timeline marker changed or vanished at offset "..tostring(frameId)
    end
  end
  for frameId,_ in pairs(after.markers or {}) do
    if not (before.markers or {})[frameId] then
      return nil,"EXTERNAL_TIMELINE_CHANGED: unexpected timeline marker at offset "..tostring(frameId)
    end
  end
  for id,old in pairs(before.items) do
    local now=after.items[id]
    if not now then return nil,"EXTERNAL_TIMELINE_CHANGED: existing item vanished: "..id end
    if now.track_type~=old.track_type or now.track_index~=old.track_index or
       now.start~=old.start or now.finish~=old.finish then
      return nil,"EXTERNAL_TIMELINE_CHANGED: existing item moved: "..id
    end
  end
  for id,_ in pairs(after.items) do
    if not before.items[id] and id~=allowed_new_id then
      return nil,"EXTERNAL_TIMELINE_CHANGED: unexpected new item: "..id
    end
  end
  return after
end

local function project_context(resolve)
  local _,rerr=require_handle(resolve,"Resolve context","GetProjectManager")
  if rerr then return nil,"RESOLVE_CONTEXT_INVALID: "..rerr end
  local manager,err=strict(resolve,"GetProjectManager")
  if not manager then return nil,"PROJECT_MANAGER_UNAVAILABLE: "..tostring(err) end
  manager,err=require_handle(manager,"GetProjectManager","GetCurrentProject")
  if not manager then return nil,err end
  local project,perr=strict(manager,"GetCurrentProject")
  if not project then return nil,"NO_PROJECT: open a Resolve project ("..tostring(perr)..")" end
  project,perr=require_handle(project,"GetCurrentProject","GetCurrentTimeline")
  if not project then return nil,perr end
  return {project=project}
end
local function ensure_timeline(ctx)
  local timeline,err=call(ctx.project,"GetCurrentTimeline")
  if err then return nil,"TIMELINE_ACCESS_FAILED: "..tostring(err) end
  if timeline~=nil and timeline~=false then
    local checked,invalid=require_handle(timeline,"GetCurrentTimeline","GetTrackCount")
    if not checked then return nil,invalid end
    ctx.timeline=timeline
    return timeline
  end
  local mediaPool,merr=strict(ctx.project,"GetMediaPool")
  if not mediaPool then return nil,"NO_MEDIA_POOL: "..tostring(merr) end
  mediaPool,merr=require_handle(mediaPool,"GetMediaPool","CreateEmptyTimeline")
  if not mediaPool then return nil,merr end
  ctx.media_pool=mediaPool
  local count=call(ctx.project,"GetTimelineCount")
  local name="CartoRig Scenes"..(type(count)=="number" and count>0 and (" "..tostring(count+1)) or "")
  local created,cerr=strict(ctx.media_pool,"CreateEmptyTimeline",name)
  if not created then return nil,"TIMELINE_CREATE_FAILED: "..tostring(cerr) end
  created,cerr=require_handle(created,"CreateEmptyTimeline","GetTrackCount")
  if not created then return nil,cerr end
  local selected,serr=call(ctx.project,"SetCurrentTimeline",created)
  if selected~=true then
    pcall(function() ctx.media_pool:DeleteTimelines({created}) end)
    return nil,"TIMELINE_SELECT_FAILED: "..tostring(serr)
  end
  ctx.timeline=created
  ctx.created_timeline=true
  return created
end
local function ensure_video_track(ctx)
  local count,err=call(ctx.timeline,"GetTrackCount","video")
  if type(count)~="number" then return nil,"TRACK_COUNT_INVALID: video: "..tostring(err) end
  if count>0 then return true end
  local added,aerr=call(ctx.timeline,"AddTrack","video")
  if added~=true then return nil,"VIDEO_TRACK_REQUIRED: Resolve refused AddTrack(video): "..tostring(aerr) end
  local after=call(ctx.timeline,"GetTrackCount","video")
  if after~=1 then return nil,"VIDEO_TRACK_REQUIRED: expected one video track after AddTrack, got "..tostring(after) end
  ctx.added_video_track=1
  return true
end

local function save_marks(timeline)
  local marks,err=call(timeline,"GetMarkInOut")
  if marks==nil and err then return nil,"MARK_STATE_UNAVAILABLE: "..tostring(err) end
  if marks~=nil and type(marks)~="table" then
    return nil,"MARK_STATE_INVALID: GetMarkInOut returned "..type(marks)
  end
  return marks or {}
end
local function restore_video_marks(timeline,marks)
  local cleared,clearErr=call(timeline,"ClearMarkInOut","video")
  if cleared~=true then return nil,"MARK_RESTORE_FAILED: ClearMarkInOut(video): "..tostring(clearErr) end
  local video=marks and marks.video
  if type(video)=="table" and type(video["in"])=="number" and type(video["out"])=="number" then
    local restored,restoreErr=call(timeline,"SetMarkInOut",video["in"],video["out"],"video")
    if restored~=true then return nil,"MARK_RESTORE_FAILED: SetMarkInOut(video): "..tostring(restoreErr) end
  end
  return true
end
local function clear_video_marks(timeline)
  local cleared,err=call(timeline,"ClearMarkInOut","video")
  if cleared~=true then return nil,"MARK_CLEAR_FAILED: "..tostring(err) end
  return true
end

local function rollback_context(ctx,item)
  local problems={}
  if item and ctx.timeline then
    local removed,err=call(ctx.timeline,"DeleteClips",{item},false)
    if removed~=true then problems[#problems+1]="new clip not removed: "..tostring(err) end
  end
  if ctx.added_video_track and ctx.timeline and not ctx.created_timeline then
    local items=call(ctx.timeline,"GetItemListInTrack","video",ctx.added_video_track)
    if items==nil or (type(items)=="table" and next(items)==nil) then
      local removed,err=call(ctx.timeline,"DeleteTrack","video",ctx.added_video_track)
      if removed~=true then problems[#problems+1]="added video track not removed: "..tostring(err) end
    else
      problems[#problems+1]="added video track retained because it is not empty"
    end
  end
  -- Existing timelines must be restored before any verification. A timeline
  -- created solely for this failed command is deleted instead of being edited.
  if not ctx.created_timeline and ctx.timeline and ctx.original_marks then
    local ok,err=restore_video_marks(ctx.timeline,ctx.original_marks)
    if not ok then problems[#problems+1]=err end
  end
  if not ctx.created_timeline and ctx.timeline and type(ctx.original_timecode)=="string" then
    local editOk,editErr=call(ctx.resolve,"OpenPage","edit")
    if editOk~=true then
      problems[#problems+1]="cannot enter Edit page to restore playhead: "..tostring(editErr)
    else
      local ok,err=call(ctx.timeline,"SetCurrentTimecode",ctx.original_timecode)
      if ok~=true then problems[#problems+1]="playhead not restored: "..tostring(err) end
    end
  end
  if not ctx.created_timeline and ctx.timeline and ctx.rollback_baseline then
    local restored,err=compare_timeline(ctx.timeline,ctx.rollback_baseline,nil)
    if not restored then problems[#problems+1]="external timeline not restored: "..tostring(err) end
  end
  if ctx.created_timeline and ctx.media_pool and ctx.timeline then
    local deleted,err=call(ctx.media_pool,"DeleteTimelines",{ctx.timeline})
    if deleted~=true then problems[#problems+1]="created timeline not deleted: "..tostring(err) end
  end
  if ctx.resolve and type(ctx.original_page)=="string" then
    local ok,err=call(ctx.resolve,"OpenPage",ctx.original_page)
    if ok~=true then problems[#problems+1]="page not restored: "..tostring(err) end
  end
  return #problems==0,table.concat(problems,"; ")
end
local function fail(ctx,item,reason)
  local ok,details=rollback_context(ctx or {},item)
  if ok then return nil,reason.."; transaction rolled back" end
  return nil,reason.."; ROLLBACK_INCOMPLETE: "..details
end

local function access_comp(item)
  local valid,invalid=require_handle(item,"TimelineItem","GetFusionCompCount")
  if not valid then return nil,invalid end
  local n,err=call(item,"GetFusionCompCount")
  if type(n)~="number" or n<1 then
    return nil,"FUSION_COMP_MISSING: inserted item has no Fusion composition; "..tostring(err)
  end
  local comp,cerr=call(item,"GetFusionCompByIndex",1)
  if not comp then return nil,"FUSION_COMP_MISSING: cannot open Fusion comp by index 1; "..tostring(cerr) end
  local checked,invalidComp=require_handle(comp,"GetFusionCompByIndex","GetToolList")
  if not checked then return nil,invalidComp end
  return comp
end

function M.create(resolve,title,opts)
  opts=opts or {}
  if type(title)~="string" or title:match("^%s*$") then return nil,"INVALID_TITLE: Scene title is required" end
  local base,err=project_context(resolve)
  if not base then return nil,err end
  local ctx={resolve=resolve,project=base.project}
  local originalPage,pageErr=call(resolve,"GetCurrentPage")
  if type(originalPage)~="string" then
    return nil,"PAGE_STATE_UNAVAILABLE: cannot capture editor page before transaction: "..tostring(pageErr or originalPage)
  end
  ctx.original_page=originalPage
  local timeline,terr=ensure_timeline(ctx)
  if not timeline then return fail(ctx,nil,terr) end
  -- Snapshot before CartoRig adds a missing video track. This is the state a
  -- failed transaction must restore exactly.
  local rollbackBaseline,snapErr=snapshot_timeline(timeline)
  if not rollbackBaseline then return fail(ctx,nil,snapErr) end
  ctx.rollback_baseline=rollbackBaseline
  local okTrack,trackErr=ensure_video_track(ctx)
  if not okTrack then return fail(ctx,nil,trackErr) end
  -- Working baseline includes any video track that a successful Scene needs.
  local before,workErr=snapshot_timeline(timeline)
  if not before then return fail(ctx,nil,workErr) end
  ctx.baseline=before
  local start=before.timeline_start
  local fps=call(timeline,"GetSetting","timelineFrameRate")
  local starttc=call(timeline,"GetStartTimecode")
  if type(start)~="number" or not frame_base(fps) or type(starttc)~="string" then
    return fail(ctx,nil,"TIMELINE_GEOMETRY_UNAVAILABLE: start/fps/timecode unavailable")
  end
  local target=before.maxend or start
  if target<start then target=start end
  local targettc,tcErr=M.timecode_add(starttc,target-start,fps)
  if not targettc then return fail(ctx,nil,tcErr) end
  if not method(resolve,"OpenPage") then return fail(ctx,nil,"RESOLVE_PAGE_API_UNAVAILABLE") end
  local switched,swErr=call(resolve,"OpenPage","edit")
  if switched~=true then return fail(ctx,nil,"EDIT_PAGE_UNAVAILABLE: "..tostring(swErr)) end
  ctx.original_timecode=call(timeline,"GetCurrentTimecode")
  if type(ctx.original_timecode)~="string" then
    return fail(ctx,nil,"TIMELINE_PLAYHEAD_UNAVAILABLE: no readable Edit-page timecode")
  end
  local marks,markErr=save_marks(timeline)
  if not marks then return fail(ctx,nil,markErr) end
  ctx.original_marks=marks
  local cleared,clearErr=clear_video_marks(timeline)
  if not cleared then return fail(ctx,nil,clearErr) end
  local seek,seekErr=call(timeline,"SetCurrentTimecode",targettc)
  if seek~=true then return fail(ctx,nil,"TIMELINE_SEEK_FAILED: "..tostring(seekErr)) end
  local actual=call(timeline,"GetCurrentTimecode")
  if not equivalent_tc(actual,targettc,fps) then
    return fail(ctx,nil,"TIMELINE_SEEK_UNVERIFIED: target "..targettc.." got "..tostring(actual))
  end
  local item,insertErr=call(timeline,"InsertFusionCompositionIntoTimeline")
  if not item then
    return fail(ctx,nil,"FUSION_INSERT_FAILED: Resolve rejected insertion (destination video track may be locked/unavailable): "..tostring(insertErr))
  end
  local itemId,idErr=item_id(item,"new Fusion Composition")
  if not itemId then return fail(ctx,item,idErr) end
  if before.items[itemId] then return fail(ctx,item,"FUSION_INSERT_ID_COLLISION: "..itemId) end
  local trackType,trackIndex,locErr=item_track(item,"new Fusion Composition")
  if not trackType then return fail(ctx,item,locErr) end
  if trackType~="video" or trackIndex<1 or trackIndex>before.counts.video then
    return fail(ctx,item,"FUSION_INSERT_WRONG_TRACK: landed on "..tostring(trackType).." "..tostring(trackIndex))
  end
  local at,finish,posErr=item_bounds(item,"new Fusion Composition")
  if not at then return fail(ctx,item,posErr) end
  if at~=target or finish<=at then
    return fail(ctx,item,"FUSION_INSERT_POSITION_INVALID: expected start "..tostring(target)..
      ", got "..tostring(at).."-"..tostring(finish))
  end
  local after,preserveErr=compare_timeline(timeline,before,itemId)
  if not after then return fail(ctx,item,preserveErr) end
  local restored,restoreErr=restore_video_marks(timeline,ctx.original_marks)
  if not restored then return fail(ctx,item,restoreErr) end
  ctx.original_marks=nil
  local opened,openErr=call(resolve,"OpenPage","fusion")
  if opened~=true then return fail(ctx,item,"FUSION_PAGE_UNAVAILABLE: "..tostring(openErr)) end
  local comp,compErr=access_comp(item)
  if not comp then return fail(ctx,item,compErr) end
  local inspect,inspectErr=factory.inspect(comp)
  if not inspect then return fail(ctx,item,"NEW_COMP_INVALID: "..tostring(inspectErr)) end
  if inspect.has_scene then return fail(ctx,item,"NEW_COMP_ALREADY_HAS_SCENE") end
  local result,nodeErr=factory.create_scene(comp,title,{disallow_new_mediaout=true,localappdata=opts.localappdata})
  if not result then return fail(ctx,item,nodeErr) end
  if method(item,"SetName") then pcall(item.SetName,item,"CartoRig - "..title) end
  -- Insertion already happened at the desired playhead. Do not call
  -- SetCurrentTimecode while Fusion is active; Resolve documents it for Edit-like pages.
  return {
    scene_id=result.scene_id,objects=result.objects,timeline_item=item,composition=comp,
    start_frame=at,end_frame=finish,track_index=trackIndex,new_timeline=ctx.created_timeline==true,
    fusion_page_opened=true,
    message="Scene created in its own Fusion Composition; host Viewer and save/reopen require verification"
  }
end

function M.list_scenes(resolve)
  local base,err=project_context(resolve)
  if not base then return nil,err end
  local timeline,terr=call(base.project,"GetCurrentTimeline")
  if terr then return nil,"TIMELINE_ACCESS_FAILED: "..tostring(terr) end
  if timeline==nil or timeline==false then return {},nil end
  timeline,terr=require_handle(timeline,"GetCurrentTimeline","GetTrackCount")
  if not timeline then return nil,terr end
  local total,tErr=call(timeline,"GetTrackCount","video")
  if type(total)~="number" or total<0 or total~=math.floor(total) then
    return nil,"TRACK_ACCESS_FAILED: expected video count, got "..type(total).." ("..tostring(tErr or total)..")"
  end
  local results,warnings={},{}
  for track=1,total do
    local clips,clipErr=call(timeline,"GetItemListInTrack","video",track)
    if clips==nil and clipErr then return nil,"TRACK_LIST_FAILED: V"..track..": "..tostring(clipErr) end
    if clips==nil then clips={} end
    if type(clips)~="table" then return nil,"TRACK_LIST_INVALID: V"..track.." returned "..type(clips) end
    for _,item in pairs(clips) do
      local itemHandle,itemHandleErr=require_handle(item,"GetItemListInTrack","GetFusionCompCount")
      if not itemHandle then return nil,itemHandleErr end
      local count,numErr=call(item,"GetFusionCompCount")
      if type(count)=="number" and count>=1 then
        local comp,cerr=call(item,"GetFusionCompByIndex",1)
        if comp then
          local compHandle,compHandleErr=require_handle(comp,"GetFusionCompByIndex","GetToolList")
          if not compHandle then return nil,compHandleErr end
          local state,inspectErr=factory.inspect(comp)
          if state and state.has_scene then
            local sceneStart,_,positionError=item_bounds(item,"scene list V"..track)
            if sceneStart then
              results[#results+1]={scene_id=state.scene_id,name=call(item,"GetName") or "CartoRig Scene",
                track=track,start_frame=sceneStart,objects=state.objects}
            else
              warnings[#warnings+1]=positionError
            end
          elseif inspectErr then
            warnings[#warnings+1]="Skipped Fusion composition: "..tostring(inspectErr)
          end
        elseif cerr then
          warnings[#warnings+1]="Cannot inspect Fusion composition: "..tostring(cerr)
        end
      elseif numErr then
        warnings[#warnings+1]="Cannot read Fusion comp count: "..tostring(numErr)
      end
    end
  end
  table.sort(results,function(a,b)
    if a.start_frame~=b.start_frame then return a.start_frame<b.start_frame end
    return a.track<b.track
  end)
  return results,#warnings>0 and table.concat(warnings," | ") or nil
end

function M.current_scene(resolve)
  local base,err=project_context(resolve)
  if not base then return nil,err end
  local timeline,terr=call(base.project,"GetCurrentTimeline")
  if not timeline then return nil,"NO_TIMELINE: "..tostring(terr) end
  timeline,terr=require_handle(timeline,"GetCurrentTimeline","GetCurrentVideoItem")
  if not timeline then return nil,terr end
  local item,itemErr=call(timeline,"GetCurrentVideoItem")
  if not item then return nil,"NO_ACTIVE_CLIP: "..tostring(itemErr) end
  local comp,compErr=access_comp(item)
  if not comp then return nil,compErr end
  local scene,inspectErr=factory.inspect(comp)
  if not scene then return nil,inspectErr end
  if not scene.has_scene then return nil,"ACTIVE_CLIP_IS_NOT_CARTORIG" end
  return {composition=comp,objects=scene.objects,scene_id=scene.scene_id,timeline_item=item}
end
return M

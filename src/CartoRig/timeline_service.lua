-- CartoRig: one Scene == one independent Fusion Composition TimelineItem.
-- The Resolve timeline API owns clip creation; NodeFactory only edits the NEW comp.
-- No pre-existing timeline clip, foreign node or media is deliberately modified.
local factory=require("CartoRig.node_factory")
local M={}
-- Resolve API proxies are userdata (sometimes tables). An exposed global or
-- an API return can also be nil/false/0; Lua considers 0 truthy. Never index
-- an unchecked value or assume a lookup through a proxy cannot throw.
local function lookup(o,name)
  local kind=type(o)
  if kind~="userdata" and kind~="table" then
    return nil,"API_INVALID_RECEIVER: "..tostring(name).." needs an object, got "..kind
  end
  local ok,fn=pcall(function() return o[name] end)
  if not ok then
    return nil,"API_LOOKUP_FAILED: "..tostring(name)..": "..tostring(fn)
  end
  if type(fn)~="function" then
    return nil,"API_METHOD_UNAVAILABLE: "..tostring(name).." on "..kind..
      " (member type "..type(fn)..")"
  end
  return fn
end
local function method(o,name)
  return lookup(o,name)~=nil
end
local function call(o,name,...)
  local fn,err=lookup(o,name)
  if not fn then return nil,err end
  local ok,value=pcall(fn,o,...)
  if not ok then return nil,"API_CALL_FAILED: "..name..": "..tostring(value) end
  return value
end
local function strict(o,name,...)
  local val,err=call(o,name,...)
  if val==nil or val==false then return nil,err or "API_REJECTED: "..name end
  return val
end
local function require_handle(value,returned_by,required_method)
  local fn,err=lookup(value,required_method)
  if not fn then
    return nil,"API_INVALID_HANDLE: "..tostring(returned_by).." returned "..type(value)..
      "; expected object implementing "..required_method.."; "..tostring(err)
  end
  return value
end

-- Positioning inserts at the END of the timeline instead of overwriting
-- editorial clips at the current playhead. SMPTE non-drop and drop frames.
local function frame_base(fps)
  local n=tonumber(fps)
  if not n or n<1 or n>120 then return nil end
  return math.floor(n+0.5),n
end
local function parse_tc(tc,nominal)
  if type(tc)~="string" then return nil end
  local h,m,s,sep,f=tc:match("^(%d%d):(%d%d):(%d%d)([:;])(%d%d)$")
  h,m,s,f=tonumber(h),tonumber(m),tonumber(s),tonumber(f)
  if not h or not m or not s or not f or m>=60 or s>=60 or f>=nominal then return nil end
  if h>=24 then return nil end
  local total=((h*60+m)*60+s)*nominal+f
  if sep==";" then
    if nominal~=30 and nominal~=60 then return nil end
    local skip=nominal==30 and 2 or 4
    if m%10~=0 and s==0 and f<skip then return nil end
    local minutes=60*h+m
    total=total-skip*(minutes-math.floor(minutes/10))
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
    local extra=drop*9*whole+drop*math.max(0,math.floor((rest-drop)/perMinute))
    nominal_frames=frame+extra
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

local function project_and_timeline(resolve)
  local _,rerr=require_handle(resolve,"Resolve context","GetProjectManager")
  if rerr then return nil,nil,nil,"RESOLVE_CONTEXT_INVALID: "..rerr end
  local manager,err=strict(resolve,"GetProjectManager")
  if not manager then return nil,nil,nil,"PROJECT_MANAGER_UNAVAILABLE: "..tostring(err) end
  manager,err=require_handle(manager,"GetProjectManager","GetCurrentProject")
  if not manager then return nil,nil,nil,err end
  local project,perr=strict(manager,"GetCurrentProject")
  if not project then return nil,nil,nil,"NO_PROJECT: open a Resolve project ("..tostring(perr)..")" end
  project,perr=require_handle(project,"GetCurrentProject","GetCurrentTimeline")
  if not project then return nil,nil,nil,perr end
  local timeline,terr=call(project,"GetCurrentTimeline")
  if terr then return nil,nil,nil,"TIMELINE_ACCESS_FAILED: "..tostring(terr) end
  if timeline==false or timeline==0 then
    return nil,nil,nil,"TIMELINE_INVALID: GetCurrentTimeline returned "..type(timeline).." value "..tostring(timeline)
  end
  local made=false
  if timeline==nil then
    local pool,perr2=strict(project,"GetMediaPool")
    if not pool then return nil,nil,nil,"NO_MEDIA_POOL: "..tostring(perr2) end
    pool,perr2=require_handle(pool,"GetMediaPool","CreateEmptyTimeline")
    if not pool then return nil,nil,nil,perr2 end
    local name="CartoRig Scenes"
    local count=call(project,"GetTimelineCount")
    if type(count)=="number" and count>0 then name=name.." "..tostring(count+1) end
    local created,cerr=strict(pool,"CreateEmptyTimeline",name)
    if not created then
      return nil,nil,nil,"TIMELINE_CREATE_FAILED: "..tostring(cerr)
    end
    timeline,cerr=require_handle(created,"CreateEmptyTimeline","GetTrackCount")
    if not timeline then return nil,nil,nil,cerr end
    local selected,serr=call(project,"SetCurrentTimeline",timeline)
    if selected==false or selected==nil then
      return nil,nil,nil,"TIMELINE_SELECT_FAILED: new timeline exists but is not current. "..tostring(serr)
    end
    made=true
  else
    local checked,invalid=require_handle(timeline,"GetCurrentTimeline","GetTrackCount")
    if not checked then return nil,nil,nil,invalid end
  end
  return project,timeline,made
end
local function track_snapshot(timeline)
  local tracks,err=call(timeline,"GetTrackCount","video")
  if type(tracks)~="number" then
    return nil,"TRACK_ACCESS_FAILED: "..tostring(err)
  end
  -- A newly created empty timeline may contain no video track.
  if tracks==0 then
    local added=call(timeline,"AddTrack","video")
    if added~=true then return nil,"VIDEO_TRACK_REQUIRED: Resolve refused to create first video track" end
    tracks=call(timeline,"GetTrackCount","video")
    if type(tracks)~="number" or tracks<1 then return nil,"VIDEO_TRACK_REQUIRED: missing after AddTrack" end
  end
  local before,maxend={},nil
  for track=1,tracks do
    local items,ie=call(timeline,"GetItemListInTrack","video",track)
    if type(items)~="table" then return nil,"TRACK_READ_FAILED: "..tostring(ie) end
    for _,item in pairs(items) do
      local start=call(item,"GetStart")
      local finish=call(item,"GetEnd")
      if type(start)~="number" or type(finish)~="number" or finish<start then
        return nil,"TRACK_POSITION_INVALID: cannot safely append"
      end
      local identity=call(item,"GetUniqueId")
      local id=type(identity)=="string" and identity or tostring(item)
      if before[id] then return nil,"TRACK_ID_COLLISION: refuse unsafe insertion" end
      before[id]={start=start,finish=finish}
      maxend=math.max(maxend or finish,finish)
    end
  end
  return {items=before,count=tracks,maxend=maxend}
end
local function verify_preserved(timeline,baseline)
  local present,err=track_snapshot(timeline)
  if not present then return nil,err end
  for id,old in pairs(baseline.items) do
    local now=present.items[id]
    if not now or now.start~=old.start or now.finish~=old.finish then
      return nil,"EXTERNAL_TIMELINE_CHANGED: existing editorial clip changed position or vanished"
    end
  end
  return true
end
local function access_comp(item)
  local valid,invalid=require_handle(item,"TimelineItem","GetFusionCompCount")
  if not valid then return nil,invalid end
  local n,err=call(item,"GetFusionCompCount")
  if type(n)~="number" or n<1 then
    return nil,"FUSION_COMP_MISSING: inserted item has no Fusion composition; "..tostring(err)
  end
  local comp,cerr=call(item,"GetFusionCompByIndex",1)
  if not comp then
    return nil,"FUSION_COMP_MISSING: cannot open Fusion comp by index 1; "..tostring(cerr)
  end
  local checked,invalid=require_handle(comp,"GetFusionCompByIndex","GetToolList")
  if not checked then return nil,invalid end
  return comp
end
local function cleanup_only_new(timeline,item)
  local removed,err=call(timeline,"DeleteClips",{item},false)
  return removed==true,removed==true and nil or ("NEW_CLIP_RETAINED: cannot safely remove inserted item; "..tostring(err))
end
local function result_error(timeline,item,reason)
  if not item then return nil,reason end
  local removed,report=cleanup_only_new(timeline,item)
  return nil,reason..(removed and "; newly inserted clip removed" or "; "..tostring(report))
end

function M.create(resolve,title,opts)
  opts=opts or {}
  if type(title)~="string" or title:match("^%s*$") then return nil,"INVALID_TITLE: Scene title is required" end
  local project,timeline,created,err=project_and_timeline(resolve)
  if not project then return nil,err end
  local previous,serr=track_snapshot(timeline)
  if not previous then return nil,serr end
  local start=call(timeline,"GetStartFrame")
  local ending=call(timeline,"GetEndFrame")
  local starttc=call(timeline,"GetStartTimecode")
  local fps=call(timeline,"GetSetting","timelineFrameRate")
  if type(start)~="number" or type(ending)~="number" or ending<start then
    return nil,"TIMELINE_GEOMETRY_UNAVAILABLE: no reliable frame positions"
  end
  local target=math.max(start,ending,previous.maxend or start)
  local targettc,te=M.timecode_add(starttc,target-start,fps)
  if not targettc then return nil,te end
  if not method(resolve,"OpenPage") then return nil,"RESOLVE_PAGE_API_UNAVAILABLE" end
  -- SetCurrentTimecode is documented for Edit/Color/etc; not for the Fusion page.
  local page=call(resolve,"GetCurrentPage")
  local switched=call(resolve,"OpenPage","edit")
  if switched~=true then return nil,"EDIT_PAGE_UNAVAILABLE: cannot position playhead safely" end
  -- GetCurrentTimecode is not guaranteed on the Fusion page. Read it only
  -- after switching to Edit, including on the 2nd/3rd/... Create Scene click.
  local currenttc=call(timeline,"GetCurrentTimecode")
  if type(currenttc)~="string" then
    return nil,"TIMELINE_PLAYHEAD_UNAVAILABLE: no readable Edit-page timecode"
  end
  local seek=call(timeline,"SetCurrentTimecode",targettc)
  if seek~=true then
    if type(page)=="string" then pcall(resolve.OpenPage,resolve,page) end
    return nil,"TIMELINE_SEEK_FAILED: cannot append safely at "..targettc
  end
  local actual=call(timeline,"GetCurrentTimecode")
  if actual~=targettc then
    return nil,"TIMELINE_SEEK_UNVERIFIED: target "..targettc.." got "..tostring(actual)
  end
  local item,insertErr=call(timeline,"InsertFusionCompositionIntoTimeline")
  if not item then return nil,"FUSION_INSERT_FAILED: "..tostring(insertErr) end
  local at=call(item,"GetStart")
  local finish=call(item,"GetEnd")
  if type(at)~="number" or type(finish)~="number" or at<target or finish<=at then
    return result_error(timeline,item,"FUSION_INSERT_POSITION_INVALID: insertion outside append boundary")
  end
  local retained,why=verify_preserved(timeline,previous)
  if not retained then return result_error(timeline,item,why) end
  -- Materialize the inserted Fusion Composition in the host BEFORE inspecting
  -- MediaOut. Resolve may create its default MediaOut only on Fusion page entry;
  -- authoring beforehand could create a second, unconnected output.
  local opened=call(resolve,"OpenPage","fusion")
  if opened~=true then
    return result_error(timeline,item,"FUSION_PAGE_UNAVAILABLE: cannot initialize default MediaOut")
  end
  local comp,cerr=access_comp(item)
  if not comp then return result_error(timeline,item,cerr) end
  local inspect,ie=factory.inspect(comp)
  if not inspect then return result_error(timeline,item,"NEW_COMP_INVALID: "..tostring(ie)) end
  if inspect.has_scene then return result_error(timeline,item,"NEW_COMP_ALREADY_HAS_SCENE") end
  -- Protect the canonical MediaOut of a newly created empty Fusion composition.
  local result,nerr=factory.create_scene(comp,title,{require_existing_mediaout=opts.require_existing_mediaout~=false,
    localappdata=opts.localappdata})
  if not result then return result_error(timeline,item,nerr) end
  -- A human-readable clip name, if supported, is optional. UUID is in comp metadata.
  if method(item,"SetName") then pcall(item.SetName,item,"CartoRig - "..title) end
  -- Keep playhead within newly created item so the editor sees the result in Fusion.
  local scene_tc=M.timecode_add(starttc,at-start,fps)
  if scene_tc then pcall(timeline.SetCurrentTimecode,timeline,scene_tc) end
  return {
    scene_id=result.scene_id,
    objects=result.objects,
    timeline_item=item,
    composition=comp,
    start_frame=at,
    end_frame=finish,
    new_timeline=created,
    fusion_page_opened=true,
    message="Scene created in its own Fusion Composition; host Viewer and save/reopen require verification",
  }
end
function M.list_scenes(resolve)
  local valid,invalid=require_handle(resolve,"Resolve context","GetProjectManager")
  if not valid then return nil,"RESOLVE_CONTEXT_INVALID: "..invalid end
  local manager,err=strict(resolve,"GetProjectManager")
  if not manager then return nil,"PROJECT_MANAGER_UNAVAILABLE: "..tostring(err) end
  manager,err=require_handle(manager,"GetProjectManager","GetCurrentProject")
  if not manager then return nil,err end
  local project,perr=call(manager,"GetCurrentProject")
  if perr then return nil,"PROJECT_ACCESS_FAILED: "..tostring(perr) end
  if project==nil or project==false then return {},nil end
  project,perr=require_handle(project,"GetCurrentProject","GetCurrentTimeline")
  if not project then return nil,perr end
  local timeline,terr=call(project,"GetCurrentTimeline")
  if terr then return nil,"TIMELINE_ACCESS_FAILED: "..tostring(terr) end
  if timeline==nil then return {},nil end
  if timeline==false then return nil,"TIMELINE_UNAVAILABLE: "..tostring(terr) end
  timeline,terr=require_handle(timeline,"GetCurrentTimeline","GetTrackCount")
  if not timeline then return nil,terr end
  local total,tErr=call(timeline,"GetTrackCount","video")
  if type(total)~="number" or total<0 or total~=math.floor(total) then
    return nil,"TRACK_ACCESS_FAILED: expected count, got "..type(total).." ("..tostring(tErr or total)..")"
  end
  local results={}
  for track=1,total do
    local clips,cliperr=call(timeline,"GetItemListInTrack","video",track)
    if clips==nil and cliperr then
      return nil,"TRACK_LIST_FAILED: V"..track..": "..tostring(cliperr)
    elseif clips==nil then
      -- Some Resolve versions return nil for an empty track; this is not an error.
      clips={}
    elseif type(clips)~="table" then
      return nil,"TRACK_LIST_INVALID: GetItemListInTrack V"..track.." returned "..type(clips)..
        " ("..tostring(cliperr or clips)..")"
    end
    for _,item in pairs(clips) do
      local handle,herr=require_handle(item,"GetItemListInTrack","GetFusionCompCount")
      if not handle then return nil,herr end
      local number,numerr=call(item,"GetFusionCompCount")
      if type(number)~="number" then
        return nil,"FUSION_COUNT_INVALID: GetFusionCompCount returned "..type(number)..
          " ("..tostring(numerr or number)..")"
      end
      if number>=1 then
        local comp,cerr=call(item,"GetFusionCompByIndex",1)
        if comp==nil or comp==false then
          return nil,"FUSION_COMP_UNAVAILABLE: "..tostring(cerr)
        end
        local checked,invalid_comp=require_handle(comp,"GetFusionCompByIndex","GetToolList")
        if not checked then return nil,invalid_comp end
        local state,inspecterr=factory.inspect(comp)
        if not state then
          return nil,"SCENE_INSPECTION_FAILED: "..tostring(inspecterr)
        end
        if state.has_scene then
          results[#results+1]={
            scene_id=state.scene_id,
            name=call(item,"GetName") or "CartoRig Scene",
            track=track,
            start_frame=call(item,"GetStart") or 0,
            objects=state.objects
          }
        end
      end
    end
  end
  table.sort(results,function(a,b)
    if a.start_frame~=b.start_frame then return a.start_frame<b.start_frame end
    return a.track<b.track
  end)
  return results
end

function M.current_scene(resolve)
  local valid,invalid=require_handle(resolve,"Resolve context","GetProjectManager")
  if not valid then return nil,"RESOLVE_CONTEXT_INVALID: "..invalid end
  local manager,err=call(resolve,"GetProjectManager")
  if not manager then return nil,"PROJECT_MANAGER_UNAVAILABLE: "..tostring(err) end
  manager,err=require_handle(manager,"GetProjectManager","GetCurrentProject")
  if not manager then return nil,err end
  local project,perr=call(manager,"GetCurrentProject")
  if not project then return nil,"NO_PROJECT: "..tostring(perr) end
  project,perr=require_handle(project,"GetCurrentProject","GetCurrentTimeline")
  if not project then return nil,perr end
  local timeline,terr=call(project,"GetCurrentTimeline")
  if not timeline then return nil,"NO_TIMELINE: "..tostring(terr) end
  timeline,terr=require_handle(timeline,"GetCurrentTimeline","GetCurrentVideoItem")
  if not timeline then return nil,terr end
  local item,ierr=call(timeline,"GetCurrentVideoItem")
  if not item then return nil,"NO_ACTIVE_CLIP: "..tostring(ierr) end
  local comp,cerr=access_comp(item)
  if not comp then return nil,cerr end
  local scene,inspecterr=factory.inspect(comp)
  if not scene then return nil,inspecterr end
  if not scene.has_scene then return nil,"ACTIVE_CLIP_IS_NOT_CARTORIG" end
  return {composition=comp,objects=scene.objects,scene_id=scene.scene_id,timeline_item=item}
end
return M

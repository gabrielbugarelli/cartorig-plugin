-- Resolve Timeline API fakes. These tests model failure semantics but are NEVER
-- licensed DaVinci Resolve host acceptance.
local prior=package.loaded["CartoRig.node_factory"]
local seq=0
local mockFactory={}
function mockFactory.inspect(comp)
  if comp.corrupt then return nil,"FAKE_CORRUPT_EXTERNAL_COMP" end
  return {scene_id=comp.sid,objects=comp.objects or {},has_scene=comp.sid~=nil}
end
function mockFactory.create_scene(comp,title,opts)
  assert(opts and opts.disallow_new_mediaout==true,
    "timeline-created Scenes must refuse a replacement MediaOut")
  if comp.sid then return nil,"SCENE_EXISTS" end
  if comp.fail then return nil,"FAKE_FUSE_FAILURE" end
  seq=seq+1
  comp.sid=string.format("scene-%d",seq)
  comp.objects={{name="CR_Scene_Main"},{name="CR_WorldMap_Main"},{name="CR_Camera_Main"}}
  return {scene_id=comp.sid,objects=comp.objects}
end
package.loaded["CartoRig.node_factory"]=mockFactory
package.loaded["CartoRig.timeline_service"]=nil
local svc=require("CartoRig.timeline_service")

local function make_item(id,start_frame,end_frame,track_type,track_index,comp)
  local item={
    identity=id,start=start_frame,finish=end_frame,
    track_type=track_type,track_index=track_index,comp=comp
  }
  function item:GetStart(subframe_precision)
    assert(subframe_precision==false,"GetStart must receive explicit false")
    return self.start
  end
  function item:GetEnd(subframe_precision)
    assert(subframe_precision==false,"GetEnd must receive explicit false")
    return self.finish
  end
  function item:GetUniqueId()
    if self.bad_id then return nil end
    return self.identity
  end
  function item:GetTrackTypeAndIndex() return {self.track_type,self.track_index} end
  function item:GetFusionCompCount()
    if self.missing then return 0 end
    return self.comp and 1 or 0
  end
  function item:GetFusionCompByIndex(index) return self.comp end
  function item:SetName(name) self.name=name;return true end
  function item:GetName() return self.name or self.identity end
  return item
end

local function fake(start_with_timeline)
  local clock=86400
  local timeline={
    tracks={video={},audio={},subtitle={}},
    seek=clock,created=0,deletes=0,deleted_tracks=0,
    destination_track=1,marks={
      video={["in"]=4,["out"]=8},
      audio={["in"]=2,["out"]=9}
    },
    timeline_markers={},default_duration=120
  }
  local function to_tc(n)
    local f=n%24;local s=math.floor(n/24)%60
    local m=math.floor(n/(24*60))%60;local h=math.floor(n/(24*3600))%24
    return string.format("%02d:%02d:%02d:%02d",h,m,s,f)
  end
  local function from_tc(tc)
    local h,m,s,f=tc:match("^(%d%d):(%d%d):(%d%d):(%d%d)$")
    if not h then return nil end
    return (((tonumber(h)*60+tonumber(m))*60+tonumber(s))*24+tonumber(f))
  end
  local function ensure_track(kind,index)
    while #timeline.tracks[kind]<index do
      timeline.tracks[kind][#timeline.tracks[kind]+1]={
        items={},locked=false,enabled=true,name=kind:sub(1,1):upper()..tostring(#timeline.tracks[kind]+1)
      }
    end
    return timeline.tracks[kind][index]
  end
  function timeline:GetTrackCount(kind) return #self.tracks[kind] end
  function timeline:AddTrack(kind)
    ensure_track(kind,#self.tracks[kind]+1)
    return true
  end
  function timeline:DeleteTrack(kind,index)
    local track=self.tracks[kind][index]
    if not track or #track.items>0 then return false end
    table.remove(self.tracks[kind],index)
    self.deleted_tracks=self.deleted_tracks+1
    return true
  end
  function timeline:GetIsTrackLocked(kind,index)
    local track=self.tracks[kind][index]
    return track and track.locked or false
  end
  function timeline:SetTrackLock(kind,index,locked)
    local track=self.tracks[kind][index]
    if not track then return false end
    track.locked=locked
    return true
  end
  function timeline:GetIsTrackEnabled(kind,index)
    local track=self.tracks[kind][index]
    return track and track.enabled or false
  end
  function timeline:SetTrackEnable(kind,index,enabled)
    local track=self.tracks[kind][index]
    if not track then return false end
    track.enabled=enabled
    return true
  end
  function timeline:GetTrackName(kind,index)
    local track=self.tracks[kind][index]
    return track and track.name or nil
  end
  function timeline:SetTrackName(kind,index,name)
    local track=self.tracks[kind][index]
    if not track then return false end
    track.name=name
    return true
  end
  function timeline:GetItemListInTrack(kind,index)
    local track=self.tracks[kind][index]
    if not track or #track.items==0 then return nil end
    return track.items
  end
  function timeline:GetStartFrame() return clock end
  function timeline:GetStartTimecode() return "01:00:00:00" end
  function timeline:GetSetting(key) return key=="timelineFrameRate" and "24" or nil end
  function timeline:GetCurrentTimecode()
    if self.host and self.host.page=="fusion" then return nil end
    return to_tc(self.seek)
  end
  function timeline:SetCurrentTimecode(tc)
    if self.host and self.host.page=="fusion" then return false end
    local frame=from_tc(tc)
    if not frame then return false end
    self.seek=frame
    return true
  end
  function timeline:GetMarkers()
    local out={}
    for frameId,info in pairs(self.timeline_markers) do
      local copy={}
      for key,value in pairs(info) do copy[key]=value end
      out[frameId]=copy
    end
    return out
  end
  function timeline:GetMarkInOut()
    local out={}
    if self.marks.video then
      out.video={["in"]=self.marks.video["in"],["out"]=self.marks.video["out"]}
    end
    if self.marks.audio then
      out.audio={["in"]=self.marks.audio["in"],["out"]=self.marks.audio["out"]}
    end
    return out
  end
  function timeline:ClearMarkInOut(kind)
    if self.fail_mark_clear then return false end
    if self.fail_clear_missing and kind~="all" and self.marks[kind]==nil then return false end
    if kind=="all" then self.marks={} else self.marks[kind]=nil end
    return true
  end
  function timeline:SetMarkInOut(mark_in,mark_out,kind)
    if self.fail_mark_restore then return false end
    self.marks[kind or "all"]={["in"]=mark_in,["out"]=mark_out}
    return true
  end
  function timeline:InsertFusionCompositionIntoTimeline()
    self.created=self.created+1
    if self.failinsert then return nil end
    local destination=self.destination_track
    if self.auto_extra_track then
      ensure_track("video",#self.tracks.video+1)
      destination=#self.tracks.video
    end
    local track=self.tracks.video[destination]
    if not track or track.locked then return nil end
    local duration=self.default_duration
    if self.marks.video then
      duration=self.marks.video["out"]-self.marks.video["in"]+1
    end
    -- Model Resolve's ripple-style insertion. Correct code places at the global
    -- end, therefore no existing item should satisfy start >= seek.
    for _,kind in ipairs({"video","audio","subtitle"}) do
      for _,tr in ipairs(self.tracks[kind]) do
        for _,existing in ipairs(tr.items) do
          if existing.start>=self.seek or self.force_global_shift then
            existing.start=existing.start+duration
            existing.finish=existing.finish+duration
          end
        end
      end
    end
    local movedMarkers={}
    for frameId,info in pairs(self.timeline_markers) do
      local absolute=clock+frameId
      local newFrame=frameId
      if absolute>=self.seek or self.force_global_shift then newFrame=frameId+duration end
      movedMarkers[newFrame]=info
    end
    self.timeline_markers=movedMarkers
    local comp={}
    function comp:GetToolList() return {} end
    if self.failfuse then comp.fail=true end
    if self.corrupt_new_comp then comp.corrupt=true end
    local item=make_item("clip-"..self.created,self.seek,self.seek+duration,
      self.wrong_track_type or "video",self.wrong_track_index or destination,comp)
    if self.missingcomp then item.missing=true end
    track.items[#track.items+1]=item
    if self.mutate_existing_lock and self.tracks.video[1] then
      self.tracks.video[1].locked=not self.tracks.video[1].locked
    end
    if self.mutate_existing_enabled and self.tracks.video[1] then
      self.tracks.video[1].enabled=not self.tracks.video[1].enabled
    end
    if self.mutate_existing_name and self.tracks.video[1] then
      self.tracks.video[1].name="Changed by insertion"
    end
    self.last=item
    return item
  end
  function timeline:DeleteClips(items,ripple)
    assert(ripple==false)
    self.deletes=self.deletes+1
    local target=items[1]
    for _,kind in ipairs({"video","audio","subtitle"}) do
      for _,track in ipairs(self.tracks[kind]) do
        for i,item in ipairs(track.items) do
          if item==target then table.remove(track.items,i);return true end
        end
      end
    end
    return false
  end
  function timeline:GetCurrentVideoItem()
    for _,track in ipairs(self.tracks.video) do
      for _,item in ipairs(track.items) do
        if self.seek>=item.start and self.seek<item.finish then return item end
      end
    end
  end

  local project={timeline=start_with_timeline and timeline or nil,deleted_timeline=false}
  local mediaPool={}
  function mediaPool:CreateEmptyTimeline(name)
    project.createdName=name
    return timeline
  end
  function mediaPool:DeleteTimelines(items)
    if items[1]~=timeline or project.fail_delete_timeline then return false end
    project.deleted_timeline=true
    if project.timeline==timeline then project.timeline=nil end
    return true
  end
  function project:GetCurrentTimeline() return self.timeline end
  function project:SetCurrentTimeline(tl)
    if self.fail_select then return false end
    self.timeline=tl;return true
  end
  function project:GetMediaPool() return mediaPool end
  function project:GetTimelineCount() return self.timeline and 1 or 0 end
  local manager={GetCurrentProject=function() return project end}
  local resolve={page="edit",switches={}}
  function resolve:GetProjectManager() return manager end
  function resolve:GetCurrentPage() return self.page end
  function resolve:OpenPage(page)
    self.page=page
    self.switches[#self.switches+1]=page
    return true
  end
  timeline.host=resolve
  timeline.ensure_track=ensure_track
  return resolve,project,timeline
end

local function add_item(timeline,kind,track,start_frame,end_frame,id,comp)
  local tr=timeline.ensure_track(kind,track)
  local item=make_item(id,start_frame,end_frame,kind,track,comp)
  tr.items[#tr.items+1]=item
  return item
end

assert(svc.timecode_add("01:00:00:00",120,24)=="01:00:05:00")
assert(svc.timecode_add("00:00:59;29",1,29.97)=="00:01:00;02")
assert(svc.timecode_add("00:09:59;29",1,29.97)=="00:10:00;00")
assert(svc.timecode_add("00:09:59;29",1,"29.97 DF")=="00:10:00;00")
assert(svc.timecode_add("01:00:00:00",24,"24 NDF")=="01:00:01:00")
assert(svc.timecode_add("00:00:00;00",1,25)==nil)

-- Five clicks from a project with no current timeline.
local resolve,project,timeline=fake(false)
local ids,comps,items={},{},{}
for n=1,5 do
  local result,err=svc.create(resolve,"CartoRig Map "..n)
  assert(result,err)
  assert(result.start_frame==86400+(n-1)*120)
  assert(result.end_frame==86400+n*120)
  assert(result.track_index==1 and result.fusion_page_opened)
  assert(not ids[result.scene_id]);ids[result.scene_id]=true
  assert(not comps[result.composition]);comps[result.composition]=true
  assert(not items[result.timeline_item]);items[result.timeline_item]=true
  assert(timeline.marks.video and timeline.marks.video["in"]==4 and timeline.marks.video["out"]==8,
    "video marks must be restored after each insertion")
  assert(timeline.marks.audio and timeline.marks.audio["in"]==2 and timeline.marks.audio["out"]==9,
    "audio marks must remain byte-for-byte equivalent after each insertion")
end
assert(timeline.created==5 and project.createdName=="CartoRig Scenes")
assert(#assert(svc.list_scenes(resolve))==5)
assert(resolve.page=="fusion")
assert(svc.current_scene(resolve).scene_id==timeline.last.comp.sid)

-- Append target must be the global end across video, audio and subtitle tracks.
local r2,p2,t2=fake(true)
add_item(t2,"video",1,86400,86500,"video-editorial")
local audio=add_item(t2,"audio",1,86420,87000,"audio-editorial")
local subtitle=add_item(t2,"subtitle",1,86900,87100,"subtitle-editorial")
-- Timeline markers are offsets from timeline start. This marker ends after all clips.
t2.timeline_markers[900]={color="Blue",name="Editorial Marker",note="keep",duration=20,customData="external"}
local beforeMarker=t2.timeline_markers[900]
local beforeSeek=t2.seek
local appended,appendErr=svc.create(r2,"After all media")
assert(appended,appendErr)
assert(appended.start_frame==87320,"must append after subtitle/audio and marker global end")
assert(t2.timeline_markers[900] and t2.timeline_markers[900].name=="Editorial Marker",
  "timeline marker must remain at the same offset")
assert(audio.start==86420 and audio.finish==87000)
assert(subtitle.start==86900 and subtitle.finish==87100)
assert(t2.marks.video and t2.marks.video["in"]==4 and t2.marks.video["out"]==8)
assert(t2.marks.audio and t2.marks.audio["in"]==2 and t2.marks.audio["out"]==9)

-- The explicit subframe argument is mandatory for 0.6.1 regression coverage.
local strictItem=add_item(t2,"video",1,90000,90120,"strict-position")
local oldStart,oldEnd=strictItem.GetStart,strictItem.GetEnd
function strictItem:GetStart(flag) if flag~=false then return nil end return oldStart(self,false) end
function strictItem:GetEnd(flag) if flag~=false then return nil end return oldEnd(self,false) end
local strictCreated,strictError=svc.create(r2,"Explicit subframe flag")
assert(strictCreated,strictError)
assert(strictCreated.start_frame==90120)

-- Empty In/Out state must not call ClearMarkInOut(video). Some host builds can
-- reject clearing a range that does not exist.
local r2b,p2b,t2b=fake(true)
t2b:AddTrack("video")
t2b.marks={}
t2b.fail_clear_missing=true
local emptyMarks,emptyMarksErr=svc.create(r2b,"No marks")
assert(emptyMarks,emptyMarksErr)
assert(next(t2b.marks)==nil,"empty In/Out state must remain empty after Scene creation")

-- Locked destination track: no clip, no page/playhead/marks side effects.
local r3,p3,t3=fake(true)
t3:AddTrack("video")
t3.tracks.video[1].locked=true
r3.page="color";t3.seek=86555
local oldTc=t3:GetCurrentTimecode()
local lockedResult,lockedErr=svc.create(r3,"Locked")
assert(lockedResult==nil and lockedErr:find("FUSION_INSERT_FAILED",1,true))
assert(#t3.tracks.video[1].items==0)
assert(r3.page=="color" and t3:GetCurrentTimecode()==oldTc)
assert(t3.marks.video and t3.marks.video["in"]==4)

-- NodeFactory failure removes only the new item and restores editor state.
local r4,p4,t4=fake(true)
t4:AddTrack("video")
local keep=add_item(t4,"video",1,86400,86500,"keep-me")
r4.page="color";t4.seek=86425;t4.failfuse=true
local failed,failedErr=svc.create(r4,"Broken")
assert(failed==nil and failedErr:find("FAKE_FUSE_FAILURE",1,true))
assert(#t4.tracks.video[1].items==1 and t4.tracks.video[1].items[1]==keep)
assert(keep.start==86400 and keep.finish==86500)
assert(r4.page=="color" and t4.seek==86425 and t4.deletes==1)

-- If service adds the first video track and insertion fails, rollback deletes it.
local r5,p5,t5=fake(true)
add_item(t5,"audio",1,86400,86500,"audio-only")
t5.failinsert=true
local noClip,noClipErr=svc.create(r5,"No insert")
assert(noClip==nil and noClipErr:find("FUSION_INSERT_FAILED",1,true))
assert(t5:GetTrackCount("video")==0 and t5.deleted_tracks==1)
assert(#t5.tracks.audio[1].items==1)

-- A newly created timeline that cannot be selected is still owned by the
-- transaction and must be deleted before returning failure.
local r5b,p5b,t5b=fake(false)
p5b.fail_select=true
r5b.page="color"
local selectFailed,selectErr=svc.create(r5b,"Cannot select")
assert(selectFailed==nil and selectErr:find("TIMELINE_SELECT_FAILED",1,true))
assert(p5b.deleted_timeline==true and p5b.timeline==nil)
assert(r5b.page=="color")

-- If even that created timeline cannot be deleted, report rollback incomplete.
local r5c,p5c,t5c=fake(false)
p5c.fail_select=true
p5c.fail_delete_timeline=true
local deleteFailed,deleteErr=svc.create(r5c,"Cannot delete")
assert(deleteFailed==nil and deleteErr:find("ROLLBACK_INCOMPLETE",1,true))

-- A timeline created only for a failed command is removed.
local r6,p6,t6=fake(false)
t6.failinsert=true
local noTimeline,noTimelineErr=svc.create(r6,"Rollback timeline")
assert(noTimeline==nil and noTimelineErr:find("FUSION_INSERT_FAILED",1,true))
assert(p6.timeline==nil and p6.deleted_timeline==true)

-- UUID is mandatory; tostring(proxy) is no longer an identity fallback.
local r7,p7,t7=fake(true)
local bad=add_item(t7,"video",1,86400,86500,"bad-id")
bad.bad_id=true
local badResult,badErr=svc.create(r7,"Bad identity")
assert(badResult==nil and type(badErr)=="string" and badErr:find("ITEM_ID_INVALID",1,true),
  "Expected ITEM_ID_INVALID, got result="..tostring(badResult).." err="..tostring(badErr))
assert(t7.created==0)

-- Wrong destination track/type is rejected and the new item removed.
local r8,p8,t8=fake(true)
t8:AddTrack("video")
t8.wrong_track_type="audio"
local wrong,wrongErr=svc.create(r8,"Wrong target")
assert(wrong==nil and wrongErr:find("FUSION_INSERT_WRONG_TRACK",1,true))
assert(#t8.tracks.video[1].items==0 and t8.deletes==1)

-- If Resolve creates an extra destination track, reject the insertion and remove
-- the now-empty auto-created track during rollback.
local r9a,p9a,t9a=fake(true)
t9a:AddTrack("video")
t9a.auto_extra_track=true
local extraTrack,extraTrackErr=svc.create(r9a,"Auto extra track")
assert(extraTrack==nil and extraTrackErr:find("FUSION_INSERT_WRONG_TRACK",1,true))
assert(t9a:GetTrackCount("video")==1 and t9a.deleted_tracks==1)

-- If an insertion unexpectedly mutates a pre-existing track lock, rollback
-- restores the lock instead of leaving editor state changed.
local r9b,p9b,t9b=fake(true)
t9b:AddTrack("video")
t9b.mutate_existing_lock=true
local lockResult,lockErr=svc.create(r9b,"Lock mutation")
assert(lockResult==nil and lockErr:find("EXTERNAL_TIMELINE_CHANGED",1,true))
assert(t9b.tracks.video[1].locked==false,"rollback must restore original lock state")

-- Enabled state and track name are editorial state too; unexpected changes are
-- rejected and restored just like track locks.
local r9c,p9c,t9c=fake(true)
t9c:AddTrack("video")
t9c.tracks.video[1].name="Editorial V1"
t9c.mutate_existing_enabled=true
t9c.mutate_existing_name=true
local metaResult,metaErr=svc.create(r9c,"Track metadata mutation")
assert(metaResult==nil and metaErr:find("EXTERNAL_TIMELINE_CHANGED",1,true))
assert(t9c.tracks.video[1].enabled==true)
assert(t9c.tracks.video[1].name=="Editorial V1")

-- If Resolve unexpectedly moves pre-existing media, report incomplete rollback
-- instead of claiming safety.
local r9,p9,t9=fake(true)
t9:AddTrack("video")
local moved=add_item(t9,"video",1,86400,86500,"must-not-move")
t9.timeline_markers[300]={color="Red",name="Must not move",note="",duration=1,customData="marker"}
t9.force_global_shift=true
local unsafe,unsafeErr=svc.create(r9,"Unsafe ripple")
assert(unsafe==nil and unsafeErr:find("EXTERNAL_TIMELINE_CHANGED",1,true))
assert(unsafeErr:find("ROLLBACK_INCOMPLETE",1,true))
assert(moved.start~=86400,"fixture must actually simulate unexpected ripple")

-- list_scenes skips a corrupt foreign Fusion comp instead of aborting all scenes.
local r10,p10,t10=fake(true)
t10:AddTrack("video")
local externalComp={corrupt=true}
function externalComp:GetToolList() return {} end
add_item(t10,"video",1,86400,86500,"external-fusion",externalComp)
local okScene=assert(svc.create(r10,"Healthy Scene"))
local scenes,warnings=svc.list_scenes(r10)
assert(scenes and #scenes==1)
assert(type(warnings)=="string" and warnings:find("FAKE_CORRUPT_EXTERNAL_COMP",1,true))

package.loaded["CartoRig.node_factory"]=prior
package.loaded["CartoRig.timeline_service"]=nil
print("timeline_service: PASS (5 Scenes, all-track append, marks/locks, UUIDs, rollback, ripple detection; mock NOT Resolve)")

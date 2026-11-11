-- Mocks for Resolve Timeline API, NEVER Studio-host acceptance.
-- Five clicks must create five different TimelineItems with different compositions.
local prior=package.loaded["CartoRig.node_factory"]
local seq=0
local mockFactory={}
function mockFactory.inspect(comp)
  return {scene_id=comp.sid,objects=comp.objects or {},has_scene=comp.sid~=nil}
end
function mockFactory.create_scene(comp,title,opts)
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
local function fake(start_with_timeline)
  local clock=86400
  local timecode="01:00:00:00"
  local timeline={clips={},tracks=0,seek=clock,created=0,deletes=0}
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
  function timeline:GetTrackCount(which) return self.tracks end
  function timeline:AddTrack(which) self.tracks=1;return true end
  function timeline:GetItemListInTrack(which,index) return self.clips end
  function timeline:GetStartFrame() return clock end
  function timeline:GetEndFrame()
    local finish=clock
    for _,clip in ipairs(self.clips) do finish=math.max(finish,clip.finish) end
    return finish
  end
  function timeline:GetStartTimecode() return timecode end
  function timeline:GetSetting(key) return "24" end
  function timeline:GetCurrentTimecode()
    -- The real Resolve API does not promise this method on the Fusion page.
    if self.host and self.host.page=="fusion" then return nil end
    return to_tc(self.seek)
  end
  function timeline:SetCurrentTimecode(tc)
    local frame=from_tc(tc)
    if not frame then return false end
    self.seek=frame
    return true
  end
  function timeline:InsertFusionCompositionIntoTimeline()
    self.created=self.created+1
    if self.failinsert then return nil end
    local comp={}
    local item={start=self.seek,finish=self.seek+120,identity="clip-"..self.created,comp=comp}
    function item:GetStart() return self.start end
    function item:GetEnd() return self.finish end
    function item:GetUniqueId() return self.identity end
    function item:GetFusionCompCount() return self.missing and 0 or 1 end
    function item:GetFusionCompByIndex(index) return self.comp end
    function item:SetName(name) self.name=name;return true end
    function item:GetName() return self.name end
    function comp:GetToolList() return {} end
    self.clips[#self.clips+1]=item
    self.last=item
    if self.failfuse then comp.fail=true end
    if self.missingcomp then item.missing=true end
    return item
  end
  function timeline:DeleteClips(items,ripple)
    assert(ripple==false)
    self.deletes=self.deletes+1
    local target=items[1]
    for i,clip in ipairs(self.clips) do
      if clip==target then table.remove(self.clips,i);return true end
    end
    return false
  end
  function timeline:GetCurrentVideoItem()
    for _,item in ipairs(self.clips) do
      if self.seek>=item.start and self.seek<item.finish then return item end
    end
  end
  local project={timeline=start_with_timeline and timeline or nil}
  function project:GetCurrentTimeline() return self.timeline end
  function project:SetCurrentTimeline(tl) self.timeline=tl;return true end
  function project:GetMediaPool()
    return {CreateEmptyTimeline=function(_,name) self.createdName=name;return timeline end}
  end
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
  return resolve,project,timeline
end
-- SMPTE positions are deterministic, including drop frame.
assert(svc.timecode_add("01:00:00:00",120,24)=="01:00:05:00")
assert(svc.timecode_add("00:00:59;29",1,29.97)=="00:01:00;02")
assert(svc.timecode_add("00:09:59;29",1,29.97)=="00:10:00;00")
assert(svc.timecode_add("00:00:00;00",1,25)==nil)
local resolve,project,timeline=fake(false)
local ids,comps,items={},{},{}
for n=1,5 do
  local result,err=svc.create(resolve,"CartoRig Map "..n)
  assert(result,err)
  assert(result.start_frame==86400+(n-1)*120)
  assert(result.end_frame==86400+n*120)
  assert(result.fusion_page_opened)
  assert(result.composition==result.timeline_item.comp)
  assert(not ids[result.scene_id])
  ids[result.scene_id]=true
  assert(not comps[result.composition])
  comps[result.composition]=true
  assert(not items[result.timeline_item])
  items[result.timeline_item]=true
end
assert(#timeline.clips==5 and timeline.created==5 and project.createdName=="CartoRig Scenes")
assert(#assert(svc.list_scenes(resolve))==5)
assert(resolve.page=="fusion")
assert(svc.current_scene(resolve).scene_id==timeline.last.comp.sid)
-- Existing media in a project must stay byte-equivalent and at same frames.
local second,pr,tl=fake(true)
tl:AddTrack("video")
local foreign={start=86400,finish=86500,identity="editorialClip",comp={}}
function foreign:GetStart() return self.start end
function foreign:GetEnd() return self.finish end
function foreign:GetUniqueId() return self.identity end
function foreign:GetFusionCompCount() return 0 end
tl.clips[1]=foreign
local added,why=svc.create(second,"New independent Scene")
assert(added,why)
assert(added.start_frame==86500)
assert(foreign.start==86400 and foreign.finish==86500 and tl.clips[1]==foreign)
-- Creation failure only removes the NEW inserted clip, never unrelated footage.
tl.failfuse=true
local attempt,reason=svc.create(second,"Broken Scene")
assert(attempt==nil and reason:find("FAKE_FUSE_FAILURE",1,true))
assert(tl.deletes==1 and #tl.clips==2 and tl.clips[1]==foreign)
-- If Resolve does not expose a Fusion comp, refuse and clean new timeline clip.
local third,pr3,tl3=fake(true)
tl3.missingcomp=true
assert(svc.create(third,"No Composition")==nil)
assert(#tl3.clips==0 and tl3.deletes==1)
-- A failed Resolve insertion must not create any author nodes.
local fourth,pr4,tl4=fake(true)
tl4.failinsert=true
assert(svc.create(fourth,"No Insert")==nil and #tl4.clips==0)
package.loaded["CartoRig.node_factory"]=prior
package.loaded["CartoRig.timeline_service"]=nil
print("timeline_service: PASS (5 distinct timeline clips/comps/IDs, safe append, foreign media, rollback; mock NOT Resolve)")

-- Regression: the actual 0.6.0 failure occurred when the host supplied
-- a number where CartoRig expected a Resolve API handle.
-- These are Lua 5.1 source tests, not licensed Studio 20 host acceptance.
local original_factory=package.loaded["CartoRig.node_factory"]
local original_service=package.loaded["CartoRig.timeline_service"]
package.loaded["CartoRig.node_factory"]={
  inspect=function(comp) return {has_scene=false,objects={}} end,
  create_scene=function() error("Unexpected author-node mutation during invalid-context test") end
}
package.loaded["CartoRig.timeline_service"]=nil
local svc=require("CartoRig.timeline_service")
local function rejected(operation,contains)
  local ok,result,message=pcall(operation)
  assert(ok,"API invocation must never throw for malformed host handles: "..tostring(result))
  assert(result==nil,"Malformed API handle cannot be treated as success")
  assert(type(message)=="string" and message:find(contains,1,true),
    "Expected informative diagnostic containing "..contains..", got "..tostring(message))
end
local fakeResolve=function(manager)
  local resolve={page="edit"}
  function resolve:GetProjectManager() return manager end
  function resolve:GetCurrentPage() return self.page end
  function resolve:OpenPage(page) self.page=page;return true end
  return resolve
end
local fakeManager=function(project)
  return {GetCurrentProject=function() return project end}
end
local calls=0
local function fakeProject(timeline)
  return {GetCurrentTimeline=function()
    calls=calls+1
    return timeline
  end}
end

for _,value in ipairs({0,17,true,"resolve",function() end}) do
  rejected(function() return svc.create(value,"Scene") end,"RESOLVE_CONTEXT_INVALID")
  rejected(function() return svc.list_scenes(value) end,"RESOLVE_CONTEXT_INVALID")
  rejected(function() return svc.current_scene(value) end,"RESOLVE_CONTEXT_INVALID")
end

local managerIsNumber=fakeResolve(7)
rejected(function() return svc.create(managerIsNumber,"Scene") end,
  "GetProjectManager returned number")
rejected(function() return svc.list_scenes(managerIsNumber) end,
  "GetProjectManager returned number")
local projectIsNumber=fakeResolve(fakeManager(12))
rejected(function() return svc.create(projectIsNumber,"Scene") end,
  "GetCurrentProject returned number")
rejected(function() return svc.list_scenes(projectIsNumber) end,
  "GetCurrentProject returned number")
local timelineIsNumber=fakeResolve(fakeManager(fakeProject(23)))
rejected(function() return svc.create(timelineIsNumber,"Scene") end,
  "GetCurrentTimeline returned number")
rejected(function() return svc.list_scenes(timelineIsNumber) end,
  "GetCurrentTimeline returned number")

local selected=false
local noTimeline={
  GetCurrentTimeline=function() return nil end,
  GetMediaPool=function() return {CreateEmptyTimeline=function() return 64 end} end,
  GetTimelineCount=function() return 0 end,
  SetCurrentTimeline=function() selected=true; return true end
}
rejected(function() return svc.create(fakeResolve(fakeManager(noTimeline)),"Scene") end,
  "CreateEmptyTimeline returned number")
assert(not selected,"Invalid Timeline must never be passed to SetCurrentTimeline")

local badTrack={
  GetTrackCount=function() return 1 end,
  GetItemListInTrack=function() return {[1]=99} end
}
rejected(function() return svc.list_scenes(fakeResolve(fakeManager(fakeProject(badTrack)))) end,
  "GetItemListInTrack returned number")

local badCompItem={
  GetFusionCompCount=function() return 1 end,
  GetFusionCompByIndex=function() return 314 end
}
local badCompTimeline={
  GetTrackCount=function() return 1 end,
  GetItemListInTrack=function() return {badCompItem} end
}
rejected(function() return svc.list_scenes(fakeResolve(fakeManager(fakeProject(badCompTimeline)))) end,
  "GetFusionCompByIndex returned number")

local throwing=setmetatable({},{
  __index=function() error("synthetic proxy method lookup failure") end
})
rejected(function() return svc.list_scenes(throwing) end,
  "API_LOOKUP_FAILED")

-- Reproduce the global Resolve numeric value from the captured error:
-- 0 is truthy in Lua. Scene UI must fall back to bmd.scriptapp("Resolve")
-- rather than opening a window with the integer.
local original_bmd,original_resolve,original_fusion,original_fu=
  rawget(_G,"bmd"),rawget(_G,"resolve"),rawget(_G,"fusion"),rawget(_G,"fu")
local original_print=print
local scene_chunk=assert(loadfile("host/cartorig-dev-scene.lua"))
local capture,scriptapp_calls={},0
print=function(msg) capture[#capture+1]=tostring(msg) end
_G.fusion=nil
_G.fu=nil
_G.resolve=0
_G.bmd={
  scriptapp=function(which)
    scriptapp_calls=scriptapp_calls+1
    assert(which=="Resolve")
    return {GetProjectManager=function() return {} end}
  end
}
local ok,status,reason=pcall(scene_chunk)
assert(ok and status==false and reason:find("UI_UNAVAILABLE",1,true),
  "Numeric global resolve must be discarded and real Resolve object selected")
assert(scriptapp_calls==1,"Must acquire real Resolve via bmd.scriptapp after numeric global")
_G.resolve=7
_G.bmd={scriptapp=function() return 0 end}
local ok2,status2,reason2=pcall(scene_chunk)
assert(ok2 and status2==false and reason2:find("RESOLVE_CONTEXT_INVALID",1,true))
assert(reason2:find("returned number",1,true))
_G.bmd=original_bmd
_G.resolve=original_resolve
_G.fusion=original_fusion
_G.fu=original_fu
print=original_print
package.loaded["CartoRig.node_factory"]=original_factory
package.loaded["CartoRig.timeline_service"]=original_service
print("resolve_api_handles: PASS (numeric globals and API returns, bad proxies, safe startup; host NOT RUN)")

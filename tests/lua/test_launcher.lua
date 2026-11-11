-- Launcher unit tests only; no DaVinci Resolve host is simulated or approved.
local original_getenv=os.getenv
local original_dofile=dofile
local original_ioopen=io.open
local original_remove=os.remove
local original_print=print
local calls,lines,deleted={},{},{}
local report=nil
local base="X:\\user\\AppData\\Local"
os.getenv=function(key)
  if key=="LOCALAPPDATA" then return base end
  return original_getenv(key)
end
io.open=function(path,mode)
  if path==base.."\\CartoRig\\App\\last-error.txt" and mode=="wb" then
    return {write=function(_,...) report=table.concat({...}) end,close=function() end}
  end
  return original_ioopen(path,mode)
end
os.remove=function(path) deleted[#deleted+1]=path end
print=function(message) lines[#lines+1]=tostring(message) end
local run=assert(loadfile("host/cartorig-dev-launcher.lua"))
local function check(ok,status,detail)
  local success,a,b=pcall(run)
  assert(success,"launcher crashed: "..tostring(a))
  assert(a==status, "unexpected status: "..tostring(a))
  if detail then assert(tostring(b):find(detail,1,true)) end
end
dofile=function(path)
  calls[#calls+1]=path
  return true,"Session closed"
end
check(true,true)
assert(#calls==1)
assert(calls[1]==base.."\\CartoRig\\App\\lua\\cartorig_scene_ui.lua")
assert(#deleted==1 and deleted[1]==base.."\\CartoRig\\App\\last-error.txt")
assert(not report)
dofile=function() return false,"Fusion UI Manager unavailable" end
check(true,false,"Fusion UI Manager unavailable")
assert(report and report:find("Fusion UI Manager unavailable",1,true))
report=nil
dofile=function() return nil end
check(true,false,"UI exited without opening normally")
assert(report and report:find("UI exited without opening normally",1,true))
report=nil
dofile=function() error("synthetic UI exception") end
check(true,false,"synthetic UI exception")
assert(report and report:find("synthetic UI exception",1,true))
base=nil
check(true,false,"LOCALAPPDATA environment")
assert(#lines>=4)
-- The actual UI top-level early return now explicitly reports a failure.
local old_fu=_G.fu
local old_fusion=_G.fusion
local old_bmd=_G.bmd
_G.fu=nil;_G.fusion=nil;_G.bmd=nil
local scene=assert(loadfile("host/cartorig-dev-scene.lua"))
local ok,status,message=pcall(scene)
assert(ok and status==false and message:find("RESOLVE_UNAVAILABLE",1,true))
_G.fu=old_fu;_G.fusion=old_fusion;_G.bmd=old_bmd
os.getenv=original_getenv;dofile=original_dofile;io.open=original_ioopen
os.remove=original_remove;print=original_print
print("launcher: PASS (successful UI, false, nil, exception, missing env, UI early return; host NOT RUN)")

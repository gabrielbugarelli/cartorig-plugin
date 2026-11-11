-- Unit test of the single menu launcher. No Resolve/Fusion host is simulated or approved.
local env=os.getenv
local old_dofile=dofile
local old_open=io.open
local calls={}
os.getenv=function(name)
  if name=="LOCALAPPDATA" then return "X:\\user\\AppData\\Local" end
  return env(name)
end
dofile=function(path)
  calls[#calls+1]=path
  return true
end
local launcher=assert(loadfile("host/cartorig-dev-launcher.lua"))
launcher()
assert(#calls==1)
assert(calls[1]=="X:\\user\\AppData\\Local\\CartoRig\\App\\lua\\cartorig_scene_ui.lua")
-- If the UI raises an error, the launcher must not crash the host.
local messages={}
local original_print=print
print=function(message) messages[#messages+1]=tostring(message) end
local report
dofile=function() error("synthetic UI startup error") end
io.open=function(path,mode)
  if path:find("last%-error%.txt") then
    return {write=function(_,message) report=message end,close=function() end}
  end
  return old_open(path,mode)
end
assert(pcall(launcher))
assert(type(report)=="string" and report:find("synthetic UI startup error",1,true))
assert(report:find("cartorig_scene_ui.lua",1,true))
assert(#messages>0)
-- An unavailable app folder is a safe explicit blocker.
os.getenv=function(name)
  if name=="LOCALAPPDATA" then return nil end
  return env(name)
end
assert(pcall(launcher))
assert(#messages>=2)
io.open=old_open;os.getenv=env;dofile=old_dofile;print=original_print
print("launcher: PASS (startup path, failure logging and fail-safe unit checks; NOT host menu)")

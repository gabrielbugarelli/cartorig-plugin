-- Single stable Workspace > Scripts > Utility launcher for cartorig-dev.
-- Loads the UI from the managed app directory and explicitly reports all failures,
-- including the UI returning early without raising an exception.
local base=os.getenv("LOCALAPPDATA")
local function startup_failure(message)
  local detail="cartorig-dev STARTUP FAILED: "..tostring(message)
  print(detail)
  if base and base~="" then
    local path=base.."\\CartoRig\\App\\last-error.txt"
    local stream=io.open(path,"wb")
    if stream then
      stream:write(detail,"\n")
      stream:close()
    else
      print("cartorig-dev: could not write startup report to "..path)
    end
  end
  return false,detail
end
if not base or base=="" then
  return startup_failure("LOCALAPPDATA environment variable is unavailable")
end
local ui=base.."\\CartoRig\\App\\lua\\cartorig_scene_ui.lua"
local ok,status,detail=pcall(dofile,ui)
if not ok then
  return startup_failure("UI Lua exception: "..tostring(status).."; path: "..ui)
end
if status~=true then
  -- A top-level 'print(...);return' was previously interpreted as success.
  return startup_failure("UI exited without opening normally: "..tostring(detail or status).."; path: "..ui)
end
-- Do not keep a stale failure report after a successful UI session.
pcall(os.remove,base.."\\CartoRig\\App\\last-error.txt")
return true

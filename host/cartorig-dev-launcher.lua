-- Stable cartorig-dev Scripts menu launcher. This is the ONLY Fusion menu entry.
-- UI and engine live outside scanned Scripts, so upgrades cannot duplicate menu items.
local base=os.getenv("LOCALAPPDATA")
if not base or base=="" then
  print("cartorig-dev ERROR: LOCALAPPDATA is unavailable")
  return
end
local ui=base.."\\CartoRig\\App\\lua\\cartorig_scene_ui.lua"
local ok,reason=pcall(dofile,ui)
if not ok then
  local report="cartorig-dev STARTUP FAILED: "..tostring(reason).."\n"..
    "UI path: "..ui.."\n"..
    "Do not run Create Scene until this installation has been repaired.\n"
  print(report)
  local handle=io.open(base.."\\CartoRig\\App\\last-error.txt","wb")
  if handle then handle:write(report);handle:close() end
end

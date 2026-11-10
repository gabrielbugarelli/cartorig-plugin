-- CartoRig Milestone A: read-only native Fusion host capability probe.
-- This is NOT a map/node/renderer implementation or a V1 acceptance test.
-- No tools, properties, projects, graphs or assets are written or deleted.
local app = rawget(_G, "fusion") or rawget(_G, "fu")
local bmd_api = rawget(_G, "bmd")
if not app or not bmd_api then
  print("CartoRig Host Probe BLOCKED: run from a Fusion composition in DaVinci Resolve Studio 20.")
  return
end

local ui = app.UIManager
if type(ui) == "function" then
  local ok, value = pcall(function() return app:UIManager() end)
  if ok then ui = value end
end
if not ui or not bmd_api.UIDispatcher then
  print("CartoRig Host Probe BLOCKED: the host did not expose UI Manager/UIDispatcher.")
  return
end

local function attempt(fn)
  local ok, result = pcall(fn)
  if not ok then return "ERROR: " .. tostring(result) end
  if result == nil then return "UNAVAILABLE" end
  return tostring(result)
end

local function make_report()
  local lines = {
    "CartoRig Milestone A | Host Capability Probe 0.1",
    "This is a read-only diagnostic, NOT V1 acceptance evidence.",
    "UTC: " .. os.date("!%Y-%m-%dT%H:%M:%SZ"),
    "Operating system: Windows (installer target; not independently verified by this script)",
    "Fusion object: " .. (app and "AVAILABLE" or "MISSING"),
    "UI Manager window: AVAILABLE",
    "UIDispatcher: AVAILABLE"
  }
  local res = rawget(_G, "resolve")
  if not res and bmd_api.scriptapp then
    local ok, value = pcall(function() return bmd_api.scriptapp("Resolve") end)
    if ok then res = value end
  end
  lines[#lines+1] = "Resolve version: " .. (res and attempt(function()
    return res:GetVersionString()
  end) or "UNAVAILABLE")
  local active = rawget(_G, "comp")
  if not active then
    local ok, value = pcall(function() return app:GetCurrentComp() end)
    if ok then active = value end
  end
  lines[#lines+1] = "Fusion composition context: " .. (active and "AVAILABLE" or "MISSING")
  if active then
    lines[#lines+1] = "Tool graph available: " .. attempt(function()
      local tools = active:GetToolList(false)
      local count = 0
      for _, _ in pairs(tools) do count = count + 1 end
      return count .. " native tools currently in composition"
    end)
    lines[#lines+1] = "Comp:SetData / GetData callable: " .. attempt(function()
      return type(active.SetData) .. " / " .. type(active.GetData)
    end)
    lines[#lines+1] = "Comp:AddTool callable: " .. attempt(function()
      return type(active.AddTool)
    end)
    lines[#lines+1] = "Comp:StartUndo / EndUndo callable: " .. attempt(function()
      return type(active.StartUndo) .. " / " .. type(active.EndUndo)
    end)
  else
    lines[#lines+1] = "Open a disposable Fusion composition and run again."
  end
  lines[#lines+1] = "No node was created, changed, selected, connected or deleted."
  lines[#lines+1] = "No Fusion-native rendering, Inspector or persistence test performed."
  return table.concat(lines, "\n")
end

local disp = bmd_api.UIDispatcher(ui)
local window = disp:AddWindow({
  ID = "CartoRigHostProbeWindow",
  WindowTitle = "CartoRig - Studio 20 Host Probe (Milestone A)",
  Geometry = {200, 200, 720, 500}
}, ui:VGroup{
  ui:Label{
    ID = "Banner",
    Text = "Host capability diagnostics only. Product features are not installed.",
    WordWrap = true
  },
  ui:TextEdit{ID = "Report", ReadOnly = true, Weight = 1},
  ui:Label{ID = "SaveStatus", Text = "Run a read-only capability probe.", WordWrap = true},
  ui:HGroup{
    ui:Button{ID = "RunProbe", Text = "Run Diagnostics"},
    ui:Button{ID = "SaveReport", Text = "Save Report"},
    ui:Button{ID = "CloseProbe", Text = "Close"}
  }
})
if not window then
  print("CartoRig Host Probe BLOCKED: UIManager returned no window.")
  return
end
local items = window:GetItems()
local report = make_report()
items.Report.PlainText = report

function window.On.RunProbe.Clicked(ev)
  report = make_report()
  items.Report.PlainText = report
  items.SaveStatus.Text = "Diagnostic complete. No project changes."
end

function window.On.SaveReport.Clicked(ev)
  local temp = os.getenv("TEMP") or os.getenv("TMP")
  if not temp or temp == "" then
    items.SaveStatus.Text = "ERROR: Windows TEMP directory missing."
    return
  end
  local path = temp .. "\\CartoRig-HostProbe-" .. os.date("!%Y%m%d-%H%M%S") .. ".txt"
  local f, err = io.open(path, "wb")
  if not f then
    items.SaveStatus.Text = "ERROR: " .. tostring(err)
    return
  end
  f:write(report, "\r\n")
  f:close()
  items.SaveStatus.Text = "Saved diagnostic report in Windows TEMP. Copy path: " .. path
end

function window.On.CloseProbe.Clicked(ev)
  disp:ExitLoop()
end
function window.On.CartoRigHostProbeWindow.Close(ev)
  disp:ExitLoop()
end

window:Show()
disp:RunLoop()
window:Hide()

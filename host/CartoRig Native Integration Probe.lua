-- GUI for a real native graph diagnostic in a disposable composition ONLY.
-- This script is not CartoRig Scene, a real map engine, or a V1 feature.
local app=rawget(_G,"fusion") or rawget(_G,"fu")
local bmd=rawget(_G,"bmd")
if not app or not bmd then
 print("BLOCKED: No Fusion/UIManager environment");return
end
local root=os.getenv("APPDATA")
if not root then print("BLOCKED: Missing Windows APPDATA");return end
local library=root.."\\Blackmagic Design\\DaVinci Resolve\\Support\\Fusion\\Scripts\\Comp\\CartoRigProbe\\native_probe.lua"
local loaded,service=pcall(dofile,library)
if not loaded or type(service)~="table" then
 print("BLOCKED: CartoRig native diagnostic module unavailable: "..tostring(service));return
end
local ui=app.UIManager
if type(ui)=="function" then
 local ok,value=pcall(function() return app:UIManager() end)
 if ok then ui=value end
end
if not ui or not bmd.UIDispatcher then print("BLOCKED: UIManager/UIDispatcher unavailable");return end
local dispatch=bmd.UIDispatcher(ui)
local window=dispatch:AddWindow({
 ID="CartoRigNativeProbeWindow",WindowTitle="CartoRig Native API Test 0.2 (diagnostic)",
 Geometry={200,180,780,510}
},ui:VGroup{
 ui:Label{Text="DIAGNOSTIC ONLY — Not CartoRig V1 or a map editor.",WordWrap=true},
 ui:Label{Text="Use a NEW disposable Fusion Composition with no nodes other than default MediaOut. The test creates 5 native nodes and connects only those new nodes.",WordWrap=true},
 ui:CheckBox{ID="Scratch",Text="I confirm this is a disposable test composition"},
 ui:TextEdit{ID="Report",ReadOnly=true,Weight=1},
 ui:Label{ID="Status",Text="No nodes have been added.",WordWrap=true},
 ui:HGroup{
  ui:Button{ID="Create",Text="Create Native Test Graph"},
  ui:Button{ID="Verify",Text="Verify Persisted Nodes"},
  ui:Button{ID="Save",Text="Save Report"},
  ui:Button{ID="Close",Text="Close"}
 }
})
if not window then print("BLOCKED: UI window could not be created");return end
local items=window:GetItems()
local report=""
local function current_comp()
 local c=rawget(_G,"comp")
 if c then return c end
 local ok,value=pcall(function() return app:GetCurrentComp() end)
 if ok then return value end
 return nil
end
local function version()
 local r=rawget(_G,"resolve")
 if not r and bmd.scriptapp then
  local ok,v=pcall(function() return bmd.scriptapp("Resolve") end)
  if ok then r=v end
 end
 if not r then return "UNAVAILABLE" end
 local ok,v=pcall(function() return r:GetVersionString() end)
 return ok and tostring(v) or ("ERROR: "..tostring(v))
end
local function show(action,result,err)
 local lines={
  "CartoRig Milestone A | Native Graph Test 0.2",
  "Only native diagnostic nodes; no cartographic features installed.",
  "UTC: "..os.date("!%Y-%m-%dT%H:%M:%SZ"),
  "Resolve reported version: "..version(),
  "Operation: "..action,
  "Result: "..(result and "NATIVE_API_READBACK" or "BLOCKED/FAILED"),
 }
 if err then lines[#lines+1]="Error: "..tostring(err) end
 if result then
  for k,v in pairs(result) do lines[#lines+1]=tostring(k)..": "..tostring(v) end
 end
 lines[#lines+1]="A01-B20 product acceptance: 40 NOT RUN"
 lines[#lines+1]="Native Inspector Control/Motion: NOT RUN; Natural Earth map: NOT RUN"
 lines[#lines+1]="Save/reopen validity requires human confirmation after closing/reopening project."
 report=table.concat(lines,"\n").."\n"
 items.Report.PlainText=report
 items.Status.Text=result and "Operation completed; read report." or ("BLOCKED/FAILED: "..tostring(err))
end
show("Startup",nil,"No action requested")
function window.On.Create.Clicked(ev)
 if not items.Scratch.Checked then
  show("Create",nil,"Confirm disposable composition before modifying the graph");return
 end
 local ok,result,err=pcall(service.create,current_comp(),true)
 if ok then show("Create",result,err)
 else show("Create",nil,"Native API error: "..tostring(result)) end
end
function window.On.Verify.Clicked(ev)
 local ok,result,err=pcall(service.verify,current_comp())
 if ok then show("Verify",result,err)
 else show("Verify",nil,"Native API error: "..tostring(result)) end
end
function window.On.Save.Clicked(ev)
 local temp=os.getenv("TEMP") or os.getenv("TMP")
 if not temp then items.Status.Text="ERROR: Windows TEMP missing";return end
 local path=temp.."\\CartoRig-NativeIntegration-"..os.date("!%Y%m%d-%H%M%S")..".txt"
 local file,err=io.open(path,"wb")
 if not file then items.Status.Text="ERROR: "..tostring(err);return end
 file:write(report);file:close()
 items.Status.Text="Saved report: "..path
end
function window.On.Close.Clicked(ev) dispatch:ExitLoop() end
function window.On.CartoRigNativeProbeWindow.Close(ev) dispatch:ExitLoop() end
window:Show()
dispatch:RunLoop()
window:Hide()

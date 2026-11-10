-- CartoRig | single user-facing Scripts > Comp entry.
-- Milestone A preview: compatibility readback and guarded, disposable graph tests.
-- Neither mode is evidence of the 40 mandatory CartoRig V1 acceptance tests.
local fusion_app=rawget(_G,"fusion") or rawget(_G,"fu")
local bmd_api=rawget(_G,"bmd")
if not fusion_app or not bmd_api then
 print("CartoRig BLOCKED: Fusion application or UI API not available")
 return
end
local storage=os.getenv("LOCALAPPDATA")
if not storage or storage=="" then
 print("CartoRig BLOCKED: LOCALAPPDATA unavailable")
 return
end
local test_file=storage.."\\CartoRig\\App\\graph_test.lua"
local loaded,graph=pcall(dofile,test_file)
if not loaded or type(graph)~="table" then
 print("CartoRig BLOCKED: installed test module missing or invalid: "..tostring(graph))
 return
end
local ui=fusion_app.UIManager
if type(ui)=="function" then
 local ok,value=pcall(function() return fusion_app:UIManager() end)
 if ok then ui=value end
end
if not ui or not bmd_api.UIDispatcher then
 print("CartoRig BLOCKED: Fusion UI Manager is not available")
 return
end
local disp=bmd_api.UIDispatcher(ui)
local window=disp:AddWindow({
 ID="CartoRigWindow",WindowTitle="CartoRig",Geometry={220,180,740,510}
},ui:VGroup{
 ui:Label{Text="CartoRig V1 — Development preview",WordWrap=true},
 ui:Label{Text="Compatibility and test graph checks only. Map creation and rendering are not implemented.",WordWrap=true},
 ui:CheckBox{ID="Scratch",Text="I confirm this is a disposable test project"},
 ui:TextEdit{ID="Report",ReadOnly=true,Weight=1},
 ui:Label{ID="Status",Text="Check compatibility before creating test nodes.",WordWrap=true},
 ui:HGroup{
  ui:Button{ID="Compatibility",Text="Check Compatibility"},
  ui:Button{ID="Create",Text="Create Test Nodes"},
  ui:Button{ID="Verify",Text="Verify Test Nodes"}
 },
 ui:HGroup{
  ui:Button{ID="Save",Text="Save Report"},
  ui:Button{ID="Close",Text="Close"}
 }
})
if not window then print("CartoRig BLOCKED: could not create UI window");return end
local items=window:GetItems()
local report=""
local function comp()
 local current=rawget(_G,"comp")
 if current then return current end
 local ok,value=pcall(function() return fusion_app:GetCurrentComp() end)
 if ok then return value end
 return nil
end
local function version()
 local resolve_app=rawget(_G,"resolve")
 if not resolve_app and bmd_api.scriptapp then
  local ok,val=pcall(function() return bmd_api.scriptapp("Resolve") end)
  if ok then resolve_app=val end
 end
 if not resolve_app then return "UNAVAILABLE" end
 local ok,val=pcall(function() return resolve_app:GetVersionString() end)
 return ok and tostring(val) or ("ERROR: "..tostring(val))
end
local function begin(action,success,error,result)
 local lines={
  "CartoRig | Milestone A development preview",
  "UTC: "..os.date("!%Y-%m-%dT%H:%M:%SZ"),
  "Resolve reported version: "..version(),
  "Action: "..action,
  "Result: "..(success and "CHECK COMPLETED" or "BLOCKED/FAILED")
 }
 if error then lines[#lines+1]="Error: "..tostring(error) end
 if result then
  local keys={}
  for k in pairs(result) do keys[#keys+1]=k end
  table.sort(keys)
  for _,k in ipairs(keys) do lines[#lines+1]=tostring(k)..": "..tostring(result[k]) end
 end
 lines[#lines+1]="CartoRig product acceptance A01-B20: 40 NOT RUN"
 lines[#lines+1]="Node Editor appearance/Viewer/Inspector: inspect manually"
 lines[#lines+1]="Project save/reopen: only the editor can attest this occurred"
 report=table.concat(lines,"\n").."\n"
 items.Report.PlainText=report
 items.Status.Text=success and "Check complete. Save the report if needed." or ("BLOCKED/FAILED: "..tostring(error))
end
local function compatibility()
 local current=comp()
 if not current then return nil,"Fusion composition unavailable" end
 local results={fusion="AVAILABLE",ui_manager="AVAILABLE",dispatcher="AVAILABLE"}
 local ok,tools=pcall(function() return current:GetToolList(false) end)
 if not ok or type(tools)~="table" then
  return nil,"Cannot inspect current composition tool list"
 end
 local count=0
 for _ in pairs(tools) do count=count+1 end
 results.existing_tool_count=count
 for _,name in ipairs({"AddTool","StartUndo","EndUndo","SetData","GetData"}) do
  results[name]=(type(current[name])=="function") and "AVAILABLE" or "MISSING"
 end
 return results
end
begin("Startup",true,nil,{message="No project changes have been made"})
function window.On.Compatibility.Clicked(ev)
 local ok,val,err=pcall(compatibility)
 if ok then begin("Compatibility",val~=nil,err,val)
 else begin("Compatibility",false,"API call failed: "..tostring(val)) end
end
function window.On.Create.Clicked(ev)
 if items.Scratch.Checked~=true then
  begin("Create Test Nodes",false,"Confirm that this is a disposable test project")
  return
 end
 local ok,val,err=pcall(graph.create,comp(),true)
 if ok then begin("Create Test Nodes",val~=nil,err,val)
 else begin("Create Test Nodes",false,"Fusion API error: "..tostring(val)) end
end
function window.On.Verify.Clicked(ev)
 local ok,val,err=pcall(graph.verify,comp())
 if ok then begin("Verify Test Nodes",val~=nil,err,val)
 else begin("Verify Test Nodes",false,"Fusion API error: "..tostring(val)) end
end
function window.On.Save.Clicked(ev)
 local path_base=os.getenv("TEMP") or os.getenv("TMP")
 if not path_base or path_base=="" then
  items.Status.Text="ERROR: Windows TEMP unavailable";return
 end
 local path=path_base.."\\CartoRig-Test-"..os.date("!%Y%m%d-%H%M%S")..".txt"
 local f,err=io.open(path,"wb")
 if not f then items.Status.Text="ERROR: "..tostring(err);return end
 f:write(report);f:close()
 items.Status.Text="Report saved: "..path
end
function window.On.Close.Clicked(ev) disp:ExitLoop() end
function window.On.CartoRigWindow.Close(ev) disp:ExitLoop() end
window:Show()
disp:RunLoop()
window:Hide()

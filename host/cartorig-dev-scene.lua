-- CartoRig developer entry (SINGLE Scripts menu item).
-- Scene is the structural UI Manager; editing controls belong to real Fusion nodes.
local app=rawget(_G,"fusion") or rawget(_G,"fu")
local bmd=rawget(_G,"bmd")
if not app or not bmd or not bmd.UIDispatcher then
 local reason="CartoRig BLOCKED: Fusion/UIManager is unavailable"
 print(reason);return false,reason
end
local localapp=os.getenv("LOCALAPPDATA")
if not localapp or localapp=="" then
 local reason="CartoRig BLOCKED: LOCALAPPDATA missing"
 print(reason);return false,reason
end
package.path=localapp.."\\CartoRig\\App\\lua\\?.lua;"..
 localapp.."\\CartoRig\\App\\lua\\?\\init.lua;"..package.path
local loaded,factory=pcall(require,"CartoRig.node_factory")
if not loaded then
 local reason="CartoRig BLOCKED: Scene/NodeFactory module not installed: "..tostring(factory)
 print(reason);return false,reason
end
local diagnostic_ok,diagnostic=pcall(dofile,localapp.."\\CartoRig\\App\\graph_test.lua")
local ui=app.UIManager
if type(ui)=="function" then
 local ok,value=pcall(function() return app:UIManager() end)
 if ok then ui=value end
end
if not ui then
 local reason="CartoRig BLOCKED: UIManager unavailable"
 print(reason);return false,reason
end
local disp=bmd.UIDispatcher(ui)
if not disp then
 local reason="CartoRig BLOCKED: UIDispatcher could not be constructed"
 print(reason);return false,reason
end
local function current_comp()
 local ok,value=pcall(function() return app:GetCurrentComp() end)
 if ok and value then return value end
 return rawget(_G,"comp")
end
local bound_comp=current_comp()
if not bound_comp then
 local reason="CartoRig BLOCKED: open Fusion Composition first"
 print(reason);return false,reason
end
local window=disp:AddWindow({
 ID="CartoRigDevWindow",WindowTitle="cartorig-dev",Geometry={200,140,770,610}
},ui:VGroup{
 ui:Label{Text="Scene — CartoRig V1 development",WordWrap=true},
 ui:Label{Text="Scene is structural only. Select a real CartoRig node in Fusion's Node Editor to edit its Inspector.",WordWrap=true},
 ui:HGroup{
  ui:Label{Text="Scene title"},
  ui:LineEdit{ID="SceneTitle",Text="Map Scene",Weight=1},
  ui:Button{ID="CreateScene",Text="Create Scene"},
  ui:Button{ID="OpenScene",Text="Open Scene"},
 },
 ui:TextEdit{ID="SceneList",ReadOnly=true,Weight=1},
 ui:Label{ID="Status",Text="No structural changes have been made.",WordWrap=true},
 ui:Label{Text="Developer diagnostics (not the CartoRig product)",WordWrap=true},
 ui:CheckBox{ID="Scratch",Text="I confirm this is a disposable test project"},
 ui:HGroup{
  ui:Button{ID="Compatibility",Text="Check Compatibility"},
  ui:Button{ID="CreateTest",Text="Create Test Nodes"},
  ui:Button{ID="VerifyTest",Text="Verify Test Nodes"},
 },
 ui:HGroup{
  ui:Button{ID="SaveReport",Text="Save Report"},
  ui:Button{ID="Close",Text="Close"}
 }
})
if not window then
 local reason="CartoRig BLOCKED: Scene UI did not initialize"
 print(reason);return false,reason
end
local items=window:GetItems()
local report=""
local function comp_guard()
 local now=current_comp()
 if not now or tostring(now)~=tostring(bound_comp) then
  return nil,"WRONG_COMPOSITION: active Fusion composition changed; close/reopen Scene"
 end
 return now
end
local function write(action,result,err)
 local lines={
  "cartorig-dev | Scene / Milestone A",
  "UTC: "..os.date("!%Y-%m-%dT%H:%M:%SZ"),
  "Action: "..action,
  "Result: "..(result and "COMMAND_COMPLETED" or "BLOCKED/FAILED"),
 }
 if err then lines[#lines+1]="Error: "..tostring(err) end
 if result then
  local keys={}
  for key in pairs(result) do keys[#keys+1]=key end
  table.sort(keys)
  for _,key in ipairs(keys) do
    if type(result[key])~="table" then
      lines[#lines+1]=tostring(key)..": "..tostring(result[key])
    end
  end
 end
 lines[#lines+1]="Studio 20 Viewer / Inspector and save-reopen: VERIFY MANUALLY"
 lines[#lines+1]="V1 acceptance A01-B20: 40 NOT RUN"
 report=table.concat(lines,"\n").."\n"
 items.Status.Text=(result and "Operation completed. Inspector requires direct Node Editor selection." or
   "BLOCKED/FAILED: "..tostring(err))
end
local function show_state(state)
 local lines={}
 if not state or not state.has_scene then
  lines[1]="No CartoRig scene is stored in this composition."
 else
  lines[#lines+1]="Scene ID: "..tostring(state.scene_id)
  lines[#lines+1]="Objects (structural listing only; no Fusion selection):"
  for _,object in ipairs(state.objects) do
   lines[#lines+1]="  "..object.name.." ("..object.type..") | "..object.id
  end
 end
 items.SceneList.PlainText=table.concat(lines,"\n")
end
local function guarded(action,method)
 local comp,err=comp_guard()
 if not comp then write(action,nil,err);return end
 local ok,result,message=pcall(method,comp)
 if not ok then write(action,nil,"FUSION_API_ERROR: "..tostring(result))
 else write(action,result,message) end
end
function window.On.CreateScene.Clicked(ev)
 guarded("Create Scene",function(comp)
  local title=items.SceneTitle.Text or "Map Scene"
  local created,err=factory.create_scene(comp,title)
  if not created then return nil,err end
  local state=assert(factory.inspect(comp))
  show_state(state)
  return {scene_id=created.scene_id,physical_author_nodes=created.created_author_nodes,
    output_connected=created.output_connected,source="Natural Earth 1:50m Land",
    message="Select CR_Camera_Main or CR_WorldMap_Main in Fusion to edit Control."}
 end)
end
function window.On.OpenScene.Clicked(ev)
 guarded("Open Scene",function(comp)
  local state,err=factory.inspect(comp)
  if not state then return nil,err end
  show_state(state)
  if not state.has_scene then return nil,"NO_SCENE: use Create Scene" end
  return {scene_id=state.scene_id,object_count=#state.objects,
    note="Reading Scene does not select or alter Fusion tools"}
 end)
end
function window.On.Compatibility.Clicked(ev)
 guarded("Compatibility",function(comp)
  local list=comp:GetToolList(false)
  local count=0
  for _ in pairs(list) do count=count+1 end
  return {existing_native_tool_count=count,
   fuse_scene="CartoRigScene",fuse_worldmap="CartoRigWorldMap",
   fuse_camera="CartoRigCamera",note="Registration checked when Create Scene is executed"}
 end)
end
function window.On.CreateTest.Clicked(ev)
 if not items.Scratch.Checked then
  write("Create Test Nodes",nil,"Disposable test project confirmation required");return
 end
 if not diagnostic_ok or not diagnostic then
  write("Create Test Nodes",nil,"Developer diagnostic module unavailable");return
 end
 guarded("Create Test Nodes",function(comp) return diagnostic.create(comp,true) end)
end
function window.On.VerifyTest.Clicked(ev)
 if not diagnostic_ok or not diagnostic then
  write("Verify Test Nodes",nil,"Developer diagnostic module unavailable");return
 end
 guarded("Verify Test Nodes",function(comp) return diagnostic.verify(comp) end)
end
function window.On.SaveReport.Clicked(ev)
 local temp=os.getenv("TEMP") or os.getenv("TMP")
 if not temp then items.Status.Text="ERROR: TEMP not available";return end
 local filepath=temp.."\\cartorig-dev-Test-"..os.date("!%Y%m%d-%H%M%S")..".txt"
 local stream,err=io.open(filepath,"wb")
 if not stream then items.Status.Text="ERROR: "..tostring(err);return end
 stream:write(report);stream:close()
 items.Status.Text="Report saved: "..filepath
end
function window.On.Close.Clicked(ev) disp:ExitLoop() end
function window.On.CartoRigDevWindow.Close(ev) disp:ExitLoop() end
local initial,err=factory.inspect(bound_comp)
if initial then show_state(initial)
else items.SceneList.PlainText="STATE ERROR: "..tostring(err) end
window:Show()
disp:RunLoop()
window:Hide()
return true,"Scene window closed normally"

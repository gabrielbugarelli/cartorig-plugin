-- cartorig-dev: Scene UI Manager only. One Create Scene = one timeline Fusion clip.
-- No prior Fusion Composition or manual wiring; scene listing is automatic.
-- The host can expose a global named "resolve" whose value is a number.
-- In Lua, 0 is truthy: never accept globals solely by their truthiness.
local function api_member(o,key)
  local kind=type(o)
  if kind~="table" and kind~="userdata" then return nil end
  local ok,v=pcall(function() return o[key] end)
  if ok then return v end
end
local function api_method(o,name)
  return type(api_member(o,name))=="function"
end
local bmd=rawget(_G,"bmd")
local supplied_resolve=rawget(_G,"resolve")
local resolve=api_method(supplied_resolve,"GetProjectManager") and supplied_resolve or nil
local fallback_type="not attempted"
if not resolve and api_method(bmd,"scriptapp") then
  local ok,result=pcall(function() return bmd.scriptapp("Resolve") end)
  fallback_type=ok and type(result) or "exception"
  if ok and api_method(result,"GetProjectManager") then
    resolve=result
  end
end
if not resolve then
  local err="RESOLVE_CONTEXT_INVALID: global resolve type "..type(supplied_resolve)..
    "; bmd.scriptapp('Resolve') returned "..fallback_type..
    ". Resolve scripting handle unavailable."
  print(err);return false,err
end
local fusion=rawget(_G,"fusion")
if not api_member(fusion,"UIManager") then fusion=rawget(_G,"fu") end
if not api_member(fusion,"UIManager") and api_method(resolve,"Fusion") then
  local ok,result=pcall(function() return resolve:Fusion() end)
  if ok and api_member(result,"UIManager") then fusion=result end
end
if not api_method(bmd,"UIDispatcher") or not api_member(fusion,"UIManager") then
  local err="UI_UNAVAILABLE: Resolve Fusion UIManager or UIDispatcher is missing"
  print(err);return false,err
end
local localapp=os.getenv("LOCALAPPDATA")
if not localapp or localapp=="" then
  local err="LOCALAPPDATA_UNAVAILABLE: runtime folder missing"
  print(err);return false,err
end
package.path=localapp.."\\CartoRig\\App\\lua\\?.lua;"..
  localapp.."\\CartoRig\\App\\lua\\?\\init.lua;"..package.path
local ok,service=pcall(require,"CartoRig.timeline_service")
if not ok or type(service)~="table" then
  local err="TIMELINE_SERVICE_MISSING: "..tostring(service)
  print(err);return false,err
end
local ui=api_member(fusion,"UIManager")
if type(ui)=="function" then
  local worked,result=pcall(function() return fusion:UIManager() end)
  if worked then ui=result end
end
if type(ui)~="table" and type(ui)~="userdata" then
  local err="UI_MANAGER_UNAVAILABLE: expected UIManager object; got "..type(ui)
  print(err);return false,err
end
local okd,disp=pcall(function() return bmd.UIDispatcher(ui) end)
if not okd or not disp then
  local err="DISPATCHER_FAILED: cannot start Scene UI"
  print(err);return false,err
end
local window=disp:AddWindow({
  ID="CartoRigDevSceneWindow", WindowTitle="cartorig-dev",
  Geometry={220,120,810,630}
},ui:VGroup{
  ui:Label{Text="CartoRig — Scene",WordWrap=true},
  ui:Label{Text="Create Scene adds an independent Fusion Composition to the timeline. Open the scene node directly in Fusion to edit its Inspector.",WordWrap=true},
  ui:HGroup{
    ui:Label{Text="Scene name"},
    ui:LineEdit{ID="SceneTitle",Text="Map Scene",Weight=1},
    ui:Button{ID="CreateScene",Text="Create Scene"}
  },
  ui:Label{Text="Scenes in the active timeline (structural list only)",WordWrap=true},
  ui:TextEdit{ID="SceneList",ReadOnly=true,Weight=1},
  ui:Label{ID="Status",Text="No scene has been created in this session.",WordWrap=true},
  ui:HGroup{
    ui:Button{ID="SaveReport",Text="Save Report"},
    ui:Button{ID="Close",Text="Close"}
  }
})
if not window then
  local err="SCENE_WINDOW_FAILED: UIManager did not create a Scene window"
  print(err);return false,err
end
local items=window:GetItems()
local report=""
local function record(action,success,details)
  local text=tostring(details or "")
  report=table.concat({
    "cartorig-dev | Timeline Scene service",
    "UTC: "..os.date("!%Y-%m-%dT%H:%M:%SZ"),
    "Action: "..tostring(action),
    "Status: "..(success and "COMMAND_COMPLETED" or "BLOCKED/FAILED"),
    "Details: "..text,
    "Fusion host Viewer/Inspector and Save/Reopen: requires editor confirmation",
    "V1 acceptance A01-B20: 40 NOT RUN"
  },"\n").."\n"
  items.Status.Text=(success and "Scene created. " or "Scene not created. ")..text
end
local function refresh()
  local ok2,scenes,err=pcall(service.list_scenes,resolve)
  if not ok2 or not scenes then
    items.SceneList.PlainText="Timeline scene listing unavailable: "..tostring(err or scenes)
    return
  end
  if #scenes==0 then
    items.SceneList.PlainText=(err and ("No readable CartoRig scenes. Warning: "..tostring(err))
      or "No CartoRig scenes in the active timeline.")
    return
  end
  local lines={}
  if err then lines[#lines+1]="Warning: "..tostring(err) end
  for n,scene in ipairs(scenes) do
    lines[#lines+1]=string.format("%d. %s  |  Track V%d  |  Frame %s",
      n,tostring(scene.name),scene.track,tostring(scene.start_frame))
    lines[#lines+1]="   Scene UUID: "..tostring(scene.scene_id)
    lines[#lines+1]="   Objects: "..tostring(#scene.objects)
  end
  items.SceneList.PlainText=table.concat(lines,"\n")
end
function window.On.CreateScene.Clicked(ev)
  local title=items.SceneTitle.Text
  if type(title)~="string" or title:match("^%s*$") then
    record("Create Scene",false,"A scene name is required")
    return
  end
  -- No comp argument and no selected-Fusion-tool assumption: timeline service
  -- creates a fresh TimelineItem and passes its comp to the NodeFactory.
  local ok2,value,err=pcall(service.create,resolve,title)
  if not ok2 then
    record("Create Scene",false,"Resolve API failure: "..tostring(value))
    return
  end
  if not value then
    record("Create Scene",false,tostring(err))
    refresh()
    return
  end
  record("Create Scene",true,"Scene "..tostring(value.scene_id)..
    ", individual Fusion Composition frames "..tostring(value.start_frame)..
    "–"..tostring(value.end_frame).."; Fusion page opened: "..tostring(value.fusion_page_opened))
  refresh()
end
function window.On.SaveReport.Clicked(ev)
  local temp=os.getenv("TEMP") or os.getenv("TMP")
  if not temp then items.Status.Text="Cannot locate Windows TEMP";return end
  local dest=temp.."\\cartorig-dev-Scene-"..os.date("!%Y%m%d-%H%M%S")..".txt"
  local file,err=io.open(dest,"wb")
  if not file then items.Status.Text="Cannot save report: "..tostring(err);return end
  file:write(report);file:close()
  items.Status.Text="Report saved: "..dest
end
function window.On.Close.Clicked(ev) disp:ExitLoop() end
function window.On.CartoRigDevSceneWindow.Close(ev) disp:ExitLoop() end
refresh()
window:Show()
disp:RunLoop()
window:Hide()
return true,"Scene window closed normally"

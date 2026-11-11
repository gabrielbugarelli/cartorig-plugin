-- cartorig-dev: Scene UI Manager only. One Create Scene = one timeline Fusion clip.
-- No prior Fusion Composition or manual wiring; scene listing is automatic.
-- Resolve/Fusion handles are validated through the same Blackmagic API boundary
-- used by TimelineService. Do not accept globals solely by Lua truthiness.
local localapp=os.getenv("LOCALAPPDATA")
if localapp and localapp~="" then
  package.path=localapp.."\\CartoRig\\App\\lua\\?.lua;"..
    localapp.."\\CartoRig\\App\\lua\\?\\init.lua;"..package.path
end
local api_ok,api=pcall(require,"CartoRig.blackmagic_api")
if not api_ok or type(api)~="table" then
  local err="BLACKMAGIC_API_BOUNDARY_MISSING: "..tostring(api)
  print(err);return false,err
end

local bmd=rawget(_G,"bmd")
local supplied_resolve=rawget(_G,"resolve")
local resolve=nil
local _,globalResolveErr=api.method(supplied_resolve,"GetProjectManager")
if not globalResolveErr then resolve=supplied_resolve end

local fallback_type="not attempted"
local fallback_error=nil
if not resolve then
  local _,scriptappErr=api.method(bmd,"scriptapp")
  if not scriptappErr then
    local result,callErr=api.call_function(bmd,"scriptapp","Resolve")
    fallback_type=type(result)
    fallback_error=callErr
    local _,resultErr=api.method(result,"GetProjectManager")
    if not resultErr then resolve=result end
  else
    fallback_error=scriptappErr
  end
end
if not resolve then
  local err="RESOLVE_CONTEXT_INVALID: global resolve type "..type(supplied_resolve)..
    "; bmd.scriptapp('Resolve') returned "..fallback_type..
    (fallback_error and ("; "..tostring(fallback_error)) or "")..
    ". Resolve scripting handle unavailable."
  print(err);return false,err
end

local fusion=rawget(_G,"fusion")
local uiValue=api.get(fusion,"UIManager","fusion.UIManager")
if uiValue==nil then
  fusion=rawget(_G,"fu")
  uiValue=api.get(fusion,"UIManager","fu.UIManager")
end
if uiValue==nil then
  local _,fusionMethodErr=api.method(resolve,"Fusion")
  if not fusionMethodErr then
    local result,callErr=api.call(resolve,"Fusion")
    if result then
      local candidate=api.get(result,"UIManager","Resolve.Fusion.UIManager")
      if candidate~=nil then
        fusion=result
        uiValue=candidate
      elseif callErr then
        fallback_error=callErr
      end
    end
  end
end

local _,dispatcherErr=api.method(bmd,"UIDispatcher")
if dispatcherErr or uiValue==nil then
  local err="UI_UNAVAILABLE: Resolve Fusion UIManager or UIDispatcher is missing"
  print(err);return false,err
end

if not localapp or localapp=="" then
  local err="LOCALAPPDATA_UNAVAILABLE: runtime folder missing"
  print(err);return false,err
end

local ok,service=pcall(require,"CartoRig.timeline_service")
if not ok or type(service)~="table" then
  local err="TIMELINE_SERVICE_MISSING: "..tostring(service)
  print(err);return false,err
end
local ui=uiValue
if type(ui)=="function" then
  local result,uiErr=api.call(fusion,"UIManager")
  if not result then
    local err="UI_MANAGER_UNAVAILABLE: "..tostring(uiErr)
    print(err);return false,err
  end
  ui=result
end
if type(ui)~="table" and type(ui)~="userdata" then
  local err="UI_MANAGER_UNAVAILABLE: expected UIManager object; got "..type(ui)
  print(err);return false,err
end
local disp,dispErr=api.call_function(bmd,"UIDispatcher",ui)
if not disp then
  local err="DISPATCHER_FAILED: "..tostring(dispErr or "cannot start Scene UI")
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
local function read_build_info()
  local info={version="unknown",commit="unknown"}
  local stream=io.open(localapp.."\\CartoRig\\App\\build-info.txt","rb")
  if not stream then return info end
  for line in stream:lines() do
    local key,value=line:match("^([%w_]+)=(.+)$")
    if key and value then info[key]=value end
  end
  stream:close()
  return info
end
local function record(action,success,details)
  local text=tostring(details or "")
  local build=read_build_info()
  report=table.concat({
    "cartorig-dev | Timeline Scene service",
    "Version: "..tostring(build.version),
    "Build commit: "..tostring(build.commit),
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
  local detail="Scene "..tostring(value.scene_id)..
    ", individual Fusion Composition frames "..tostring(value.start_frame)..
    "–"..tostring(value.end_frame).."; Fusion page opened: "..tostring(value.fusion_page_opened)
  if type(value.warnings)=="table" and #value.warnings>0 then
    detail=detail.."; warnings: "..table.concat(value.warnings," | ")
  end
  record("Create Scene",true,detail)
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

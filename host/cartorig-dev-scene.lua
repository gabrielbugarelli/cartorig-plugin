-- cartorig-dev: Scene UI Manager only. Create Scene targets the current Fusion composition.
-- An active Fusion composition is required; Scene never inserts timeline clips.
-- Resolve/Fusion handles are validated through the same Blackmagic API boundary
-- used by the native SceneService. Do not accept globals solely by Lua truthiness.
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

local ok,service=pcall(require,"CartoRig.scene_service")
if not ok or type(service)~="table" then
  local err="SCENE_SERVICE_MISSING: "..tostring(service)
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
-- The Scene window is bound to one active Fusion composition at a time.
-- Selecting a row never selects a node or changes the native Inspector.
local window=disp:AddWindow({
  ID="CartoRigDevSceneWindow",WindowTitle="CartoRig — Scene",
  Geometry={220,120,820,650}
},ui:VGroup{
  ui:Label{Text="CartoRig — Scene",WordWrap=true},
  ui:Label{Text="Create Scene acts on the CURRENT Fusion composition. Open Scene reads an existing one. Edit properties by selecting nodes in Fusion.",WordWrap=true},
  ui:HGroup{
    ui:LineEdit{ID="SceneTitle",Text="Map Scene",Weight=1},
    ui:Button{ID="CreateScene",Text="Create Scene"},
    ui:Button{ID="OpenScene",Text="Open Scene"},
  },
  ui:HGroup{
    ui:Label{ID="ActiveContext",Text="Active Fusion composition: not verified",Weight=1},
  },
  ui:HGroup{
    ui:LineEdit{ID="RenameSceneName",PlaceholderText="New Scene title",Weight=1},
    ui:Button{ID="RenameScene",Text="Rename Scene"},
  },
  ui:Label{Text="Offline geography (search does not modify the composition)"},
  ui:HGroup{
    ui:LineEdit{ID="SearchLocation",PlaceholderText="Brazil, Argentina, Mato Grosso...",Weight=1},
    ui:ComboBox{ID="GeoType"},
    ui:Button{ID="Search",Text="Search"},
  },
  ui:ComboBox{ID="SearchResults",Weight=1},
  ui:HGroup{
    ui:Button{ID="AddCountry",Text="Add Country",Enabled=false},
    ui:Button{ID="AddState",Text="Add State/Province",Enabled=false},
  },
  ui:Label{Text="CartoRig objects (structural list; no Inspector selection)"},
  ui:ComboBox{ID="ObjectContext",Weight=1},
  ui:HGroup{
    ui:LineEdit{ID="RenameObjectName",PlaceholderText="New object display name",Weight=1},
    ui:Button{ID="RenameObject",Text="Rename Object",Enabled=false},
  },
  ui:Button{ID="RepairPalette",Text="Repair WorldMap Color Links (legacy scenes)"},
  ui:TextEdit{ID="SceneList",ReadOnly=true,Weight=1},
  ui:Label{ID="Status",Text="Scene has not modified the active composition.",WordWrap=true},
  ui:HGroup{
    ui:Button{ID="SaveReport",Text="Save Report"},
    ui:Button{ID="Close",Text="Close"},
  }
})
if not window then
  local err="SCENE_WINDOW_FAILED: UIManager did not create the window"
  print(err);return false,err
end

local items=window:GetItems()
local current=nil
local results={}
local objects={}
local report=""
items.GeoType:AddItem("All")
items.GeoType:AddItem("Continent")
items.GeoType:AddItem("Country")
items.GeoType:AddItem("State/Province")
items.GeoType:AddItem("City")
items.GeoType.CurrentIndex=0

local function build_info()
  local info={version="unknown",commit="unknown"}
  local file=io.open(localapp.."\\CartoRig\\App\\build-info.txt","rb")
  if not file then return info end
  for line in file:lines() do
    local k,v=line:match("^([%w_]+)=(.+)$")
    if k and v then info[k]=v end
  end
  file:close()
  return info
end

local function record(action,ok,detail)
  local info=build_info()
  detail=tostring(detail or "")
  report=table.concat({
    "cartorig-dev | Current Fusion Composition Scene service",
    "Version: "..tostring(info.version),
    "Build commit: "..tostring(info.commit),
    "UTC: "..os.date("!%Y-%m-%dT%H:%M:%SZ"),
    "Action: "..tostring(action),
    "Status: "..(ok and "COMMAND_COMPLETED" or "BLOCKED/FAILED"),
    "Details: "..detail,
    "Fusion Viewer / Inspector / Save-Reopen acceptance: requires editor evidence",
    "V1 A01-B20: NOT RUN until verified in licensed host",
  },"\\n").."\\n"
  items.Status.Text=(ok and "Completed. " or "Blocked. ")..detail
end

local function selected_result()
  local i=tonumber(items.SearchResults.CurrentIndex)
  return i and i>=0 and results[i+1] or nil
end

local function selected_object()
  local i=tonumber(items.ObjectContext.CurrentIndex)
  return i and i>=0 and objects[i+1] or nil
end

local function update_buttons()
  local row=selected_result()
  items.AddCountry.Enabled=current~=nil and current.has_scene and
    row~=nil and row.geo_type=="Country"
  items.AddState.Enabled=current~=nil and current.has_scene and
    row~=nil and row.geo_type=="State"
  local obj=selected_object()
  items.RenameObject.Enabled=current~=nil and current.has_scene and
    obj~=nil and (obj.type=="Country" or obj.type=="State")
  items.RenameScene.Enabled=current~=nil and current.has_scene
end

local function draw_scene(preferred_id)
  items.ObjectContext:Clear()
  objects={}
  if not current then
    items.ActiveContext.Text="Fusion context not bound. Open the Fusion page, then relaunch Scene."
    items.SceneList.PlainText="No active Fusion composition was verified."
    update_buttons()
    return
  end
  items.ActiveContext.Text="Bound Fusion composition | "..
    (current.has_scene and ("Scene "..tostring(current.scene_id)) or "No CartoRig Scene")
  if not current.has_scene then
    items.SceneList.PlainText="No CartoRig Scene. Create Scene to initialize the active composition."
    update_buttons()
    return
  end
  local lines={
    "Scene: "..tostring(current.title),
    "Scene UUID: "..tostring(current.scene_id),
    "Structural graph: WorldMap → Regions → Camera → Scene → MediaOut",
  }
  local sorted={}
  for _,obj in ipairs(current.objects or {}) do sorted[#sorted+1]=obj end
  table.sort(sorted,function(a,b)
    if (a.draw_order or -1)~=(b.draw_order or -1) then
      return (a.draw_order or -1)<(b.draw_order or -1)
    end
    return tostring(a.name)<tostring(b.name)
  end)
  local preferred_index=1
  for _,obj in ipairs(sorted) do
    objects[#objects+1]=obj
    items.ObjectContext:AddItem(tostring(obj.type).." — "..
      tostring(obj.display_name or obj.name).." | "..tostring(obj.name))
    if preferred_id and obj.id==preferred_id then
      preferred_index=#objects
    end
    lines[#lines+1]=tostring(obj.type).." | "..tostring(obj.name)..
      " | UUID "..tostring(obj.id)
  end
  if #objects>0 then items.ObjectContext.CurrentIndex=preferred_index-1 end
  items.SceneList.PlainText=table.concat(lines,"\\n")
  items.RenameSceneName.Text=tostring(current.title or "")
  update_buttons()
end

local function read_active_without_rebinding()
  if not current then return nil,"SCENE_CONTEXT_UNBOUND" end
  local active,err=service.inspect_active(resolve)
  if not active then return nil,err end
  if active.composition~=current.composition or active.scene_id~=current.scene_id then
    return nil,"SCENE_CONTEXT_CHANGED: use Open Scene on the new active composition"
  end
  return active
end

local function recheck(preferred_id)
  local active,err=read_active_without_rebinding()
  if active then current=active;draw_scene(preferred_id) end
  return active,err
end

local function initial_binding()
  local ok2,active,err=pcall(service.inspect_active,resolve)
  if ok2 and active then
    current=active
    draw_scene()
  else
    current=nil
    draw_scene()
    items.Status.Text="Scene not bound: "..tostring(err or active)
  end
end

function window.On.OpenScene.Clicked(ev)
  local ok2,active,err=pcall(service.open_scene,resolve)
  if not ok2 then record("Open Scene",false,active);return end
  if not active then record("Open Scene",false,err);return end
  current=active
  draw_scene()
  record("Open Scene",true,"Read-only reconstruction of Scene "..tostring(active.scene_id))
end

function window.On.CreateScene.Clicked(ev)
  local title=items.SceneTitle.Text
  local ok2,created,err=pcall(service.create_scene,resolve,title,current)
  if not ok2 then record("Create Scene",false,created);return end
  if not created then record("Create Scene",false,err);return end
  current=created
  draw_scene()
  record("Create Scene",true,"Created nodes in current composition: "..tostring(created.scene_id))
end

function window.On.RenameScene.Clicked(ev)
  local active,contextErr=read_active_without_rebinding()
  if not active then record("Rename Scene",false,contextErr);return end
  local ok2,renamed,err=pcall(service.rename_scene,resolve,current,items.RenameSceneName.Text)
  if not ok2 then record("Rename Scene",false,renamed);return end
  if not renamed then record("Rename Scene",false,err);return end
  recheck()
  record("Rename Scene",true,"Title updated; Scene UUID preserved: "..tostring(renamed.scene_id))
end

local function search()
  local types={"All","Continent","Country","State","City"}
  local which=types[(tonumber(items.GeoType.CurrentIndex) or 0)+1] or "All"
  local ok2,rows,err=pcall(service.search_locations,items.SearchLocation.Text or "",which)
  items.SearchResults:Clear()
  results={}
  if not ok2 or not rows then
    record("Search",false,err or rows)
    update_buttons()
    return
  end
  results=rows
  for _,row in ipairs(rows) do
    local parent=(row.parent_name and row.parent_name~="") and (" — "..row.parent_name) or ""
    items.SearchResults:AddItem(tostring(row.canonical_name).." — "..tostring(row.geo_type)..
      parent.." | "..tostring(row.geometry).." | "..tostring(row.scale))
  end
  if #rows>0 then items.SearchResults.CurrentIndex=0 end
  update_buttons()
  items.Status.Text=tostring(#rows).." offline result(s). Search made no graph changes."
end

function window.On.Search.Clicked(ev) search() end
function window.On.SearchLocation.ReturnPressed(ev) search() end
function window.On.SearchResults.CurrentIndexChanged(ev) update_buttons() end

local function add_selected(kind)
  local row=selected_result()
  if not row or row.geo_type~=kind then
    record("Add "..kind,false,"Select an offline "..kind.." geometry")
    return
  end
  local active,contextErr=read_active_without_rebinding()
  if not active or not active.has_scene then
    record("Add "..kind,false,contextErr or "NO_SCENE")
    return
  end
  local ok2,result,err=pcall(service.add_region,resolve,current,row.dataset_id,row.source_id)
  if not ok2 then record("Add "..kind,false,result);return end
  if not result then record("Add "..kind,false,err);return end
  recheck(result.object_id)
  record("Add "..kind,true,"Created "..tostring(result.node_name)..
    " | UUID "..tostring(result.object_id))
end
function window.On.AddCountry.Clicked(ev) add_selected("Country") end
function window.On.AddState.Clicked(ev) add_selected("State") end
function window.On.ObjectContext.CurrentIndexChanged(ev)
  local obj=selected_object()
  items.RenameObjectName.Text=obj and tostring(obj.display_name or obj.name) or ""
  update_buttons()
end

function window.On.RenameObject.Clicked(ev)
  local obj=selected_object()
  if not obj or (obj.type~="Country" and obj.type~="State") then
    record("Rename Object",false,"Select a Country or State row")
    return
  end
  local active,contextErr=read_active_without_rebinding()
  if not active then record("Rename Object",false,contextErr);return end
  local ok2,result,err=pcall(service.rename_object,resolve,current,obj.id,items.RenameObjectName.Text)
  if not ok2 then record("Rename Object",false,result);return end
  if not result then record("Rename Object",false,err);return end
  recheck(obj.id)
  record("Rename Object",true,"Display name changed, UUID and node name preserved")
end

function window.On.RepairPalette.Clicked(ev)
  local active,contextErr=read_active_without_rebinding()
  if not active then record("Repair Palette",false,contextErr);return end
  local ok2,result,err=pcall(service.repair_palette,resolve,current)
  if not ok2 then record("Repair Palette",false,result);return end
  if not result then record("Repair Palette",false,err);return end
  recheck()
  record("Repair Palette",true,tostring(result.expressions_repaired).." color links repaired")
end

function window.On.SaveReport.Clicked(ev)
  local temp=os.getenv("TEMP") or os.getenv("TMP")
  if not temp then items.Status.Text="Windows TEMP directory unavailable";return end
  local dest=temp.."\\cartorig-dev-Scene-"..os.date("!%Y%m%d-%H%M%S")..".txt"
  local f,err=io.open(dest,"wb")
  if not f then items.Status.Text="Report failure: "..tostring(err);return end
  f:write(report);f:close()
  items.Status.Text="Report saved: "..dest
end
function window.On.Close.Clicked(ev) disp:ExitLoop() end
function window.On.CartoRigDevSceneWindow.Close(ev) disp:ExitLoop() end
initial_binding()
window:Show()
disp:RunLoop()
window:Hide()
return true,"Scene window closed normally"

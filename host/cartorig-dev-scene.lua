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
  ui:Label{Text="Create Scene adds an independent Fusion Composition to the timeline. Select CartoRig nodes directly in Fusion to edit their Inspector.",WordWrap=true},
  ui:HGroup{
    ui:Label{Text="Scene name"},
    ui:LineEdit{ID="SceneTitle",Text="Map Scene",Weight=1},
    ui:Button{ID="CreateScene",Text="Create Scene"}
  },
  ui:HGroup{
    ui:Label{Text="Structural target"},
    ui:ComboBox{ID="SceneContext",Weight=1},
  },
  ui:Label{Text="Search installed offline geography",WordWrap=true},
  ui:HGroup{
    ui:LineEdit{ID="SearchLocation",PlaceholderText="Brazil, Mato Grosso, São Paulo...",Weight=1},
    ui:ComboBox{ID="GeoType"},
    ui:Button{ID="Search",Text="Search"}
  },
  ui:ComboBox{ID="SearchResults",Weight=1},
  ui:HGroup{
    ui:Button{ID="AddCountry",Text="Add Country",Enabled=false},
    ui:Button{ID="AddState",Text="Add State/Province",Enabled=false},
  },
  ui:Label{Text="Objects in selected Scene (structural list only)",WordWrap=true},
  ui:HGroup{
    ui:Label{Text="Structural object"},
    ui:ComboBox{ID="ObjectContext",Weight=1},
  },
  ui:HGroup{
    ui:LineEdit{ID="RenameObjectName",PlaceholderText="New display name",Weight=1},
    ui:Button{ID="RenameObject",Text="Rename",Enabled=false},
  },
  ui:TextEdit{ID="SceneList",ReadOnly=true,Weight=1},
  ui:Label{ID="Status",Text="No structural operation has run in this session.",WordWrap=true},
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
local sceneContexts={}
local searchResults={}
local objectContexts={}

items.GeoType:AddItem("All")
items.GeoType:AddItem("Country")
items.GeoType:AddItem("State/Province")
items.GeoType:AddItem("City")
items.GeoType.CurrentIndex=0

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
  items.Status.Text=(success and "Completed. " or "Blocked/failed. ")..text
end

local function selected_scene()
  local index=tonumber(items.SceneContext.CurrentIndex)
  if not index or index<0 then return nil end
  return sceneContexts[index+1]
end

local function selected_result()
  local index=tonumber(items.SearchResults.CurrentIndex)
  if not index or index<0 then return nil end
  return searchResults[index+1]
end

local function selected_object()
  local index=tonumber(items.ObjectContext.CurrentIndex)
  if not index or index<0 then return nil end
  return objectContexts[index+1]
end

local function update_rename_controls()
  local obj=selected_object()
  local supported=obj and (obj.type=="Country" or obj.type=="State")
  items.RenameObject.Enabled=supported==true
  if obj then
    items.RenameObjectName.Text=tostring(obj.display_name or obj.name or "")
  else
    items.RenameObjectName.Text=""
  end
end

local function update_add_buttons()
  local result=selected_result()
  items.AddCountry.Enabled=result~=nil and result.geo_type=="Country"
  items.AddState.Enabled=result~=nil and result.geo_type=="State"
end

local function render_selected_scene(preferredObjectId)
  local scene=selected_scene()
  items.ObjectContext:Clear()
  objectContexts={}
  if not scene then
    items.SceneList.PlainText="No CartoRig Scene selected."
    update_rename_controls()
    return
  end
  local lines={
    tostring(scene.name),
    "Scene UUID: "..tostring(scene.scene_id),
    "Track V"..tostring(scene.track).." | Frame "..tostring(scene.start_frame),
  }
  table.sort(scene.objects,function(a,b)
    local ao=a.draw_order or -1
    local bo=b.draw_order or -1
    if ao~=bo then return ao<bo end
    return tostring(a.name)<tostring(b.name)
  end)
  local selectedIndex=1
  for n,obj in ipairs(scene.objects) do
    objectContexts[#objectContexts+1]=obj
    items.ObjectContext:AddItem(tostring(obj.type).." — "..
      tostring(obj.display_name or obj.name).." | "..tostring(obj.name))
    if preferredObjectId and obj.id==preferredObjectId then selectedIndex=n end
    local detail="• "..tostring(obj.type).." | "..tostring(obj.name)..
      " | "..tostring(obj.id)
    if obj.source then
      detail=detail.." | "..tostring(obj.source.scale).." | "..tostring(obj.source.source_id)
    end
    lines[#lines+1]=detail
  end
  if #objectContexts>0 then items.ObjectContext.CurrentIndex=selectedIndex-1 end
  items.SceneList.PlainText=table.concat(lines,"\n")
  update_rename_controls()
end

local function refresh(preferredSceneId,preferredObjectId)
  local previous=preferredSceneId
  if not previous then
    local selected=selected_scene()
    previous=selected and selected.scene_id or nil
  end
  local ok2,scenes,err=pcall(service.list_scenes,resolve)
  items.SceneContext:Clear()
  sceneContexts={}
  if not ok2 or not scenes then
    items.SceneList.PlainText="Timeline scene listing unavailable: "..tostring(err or scenes)
    items.Status.Text="Scene context unavailable."
    return
  end
  sceneContexts=scenes
  local selectedIndex=1
  for n,scene in ipairs(scenes) do
    items.SceneContext:AddItem(string.format("%s | V%d @ %s",
      tostring(scene.name),scene.track,tostring(scene.start_frame)))
    if previous and scene.scene_id==previous then selectedIndex=n end
  end
  if #scenes==0 then
    items.SceneList.PlainText=(err and ("No readable CartoRig scenes. Warning: "..tostring(err))
      or "No CartoRig scenes in the active timeline.")
    return
  end
  items.SceneContext.CurrentIndex=selectedIndex-1
  render_selected_scene(preferredObjectId)
  if err then items.Status.Text="Scene list warning: "..tostring(err) end
end

local function perform_search()
  local filterByIndex={"All","Country","State","City"}
  local filter=filterByIndex[(tonumber(items.GeoType.CurrentIndex) or 0)+1] or "All"
  local query=items.SearchLocation.Text or ""
  local ok2,results,err=pcall(service.search_locations,query,filter)
  items.SearchResults:Clear()
  searchResults={}
  if not ok2 or not results then
    items.Status.Text="Search failed: "..tostring(err or results)
    update_add_buttons()
    return
  end
  searchResults=results
  for _,result in ipairs(results) do
    local parent=result.parent_name~="" and (" — "..result.parent_name) or ""
    items.SearchResults:AddItem(
      tostring(result.canonical_name).." — "..tostring(result.geo_type)..parent..
      " | "..tostring(result.geometry)..
      " | "..tostring(result.dataset_id).." v"..tostring(result.source_version)..
      " | "..tostring(result.scale)
    )
  end
  if #results==0 then
    items.Status.Text="Location not found in installed offline data"
  else
    items.SearchResults.CurrentIndex=0
    items.Status.Text=tostring(#results).." offline result(s). Search does not modify the Scene."
  end
  update_add_buttons()
end

local function add_selected(expectedType)
  local scene=selected_scene()
  if not scene then record("Add "..expectedType,false,"Choose a structural Scene target");return end
  local result=selected_result()
  if not result then record("Add "..expectedType,false,"Choose a search result");return end
  if result.geo_type~=expectedType then
    record("Add "..expectedType,false,"Selected result is "..tostring(result.geo_type))
    return
  end
  local ok2,value,err=pcall(service.add_region,resolve,scene.scene_id,result.dataset_id,result.source_id)
  if not ok2 then
    record("Add "..expectedType,false,"Resolve/Fusion API failure: "..tostring(value))
    return
  end
  if not value then
    record("Add "..expectedType,false,tostring(err))
    refresh(scene.scene_id)
    return
  end
  record("Add "..expectedType,true,"Node created: "..tostring(value.node_name)..
    " | source "..tostring(value.source.source_id).." | "..tostring(value.source.scale))
  refresh(scene.scene_id)
end

function window.On.SceneContext.CurrentIndexChanged(ev)
  render_selected_scene()
end
function window.On.ObjectContext.CurrentIndexChanged(ev)
  update_rename_controls()
end
function window.On.SearchResults.CurrentIndexChanged(ev)
  update_add_buttons()
end
function window.On.Search.Clicked(ev)
  perform_search()
end
function window.On.SearchLocation.ReturnPressed(ev)
  perform_search()
end
function window.On.AddCountry.Clicked(ev)
  add_selected("Country")
end
function window.On.AddState.Clicked(ev)
  add_selected("State")
end

function window.On.RenameObject.Clicked(ev)
  local scene=selected_scene()
  local obj=selected_object()
  if not scene then record("Rename",false,"Choose a structural Scene target");return end
  if not obj then record("Rename",false,"Choose a structural object");return end
  if obj.type~="Country" and obj.type~="State" then
    record("Rename",false,"Milestone A renames Country/State objects only")
    return
  end
  local newName=items.RenameObjectName.Text
  if type(newName)~="string" or newName:match("^%s*$") then
    record("Rename",false,"Enter a display name")
    return
  end
  local ok2,value,err=pcall(service.rename_object,resolve,scene.scene_id,obj.id,newName)
  if not ok2 then
    record("Rename",false,"Resolve/Fusion API failure: "..tostring(value))
    return
  end
  if not value then
    record("Rename",false,tostring(err))
    refresh(scene.scene_id,obj.id)
    return
  end
  record("Rename",true,"Display name changed to "..tostring(value.display_name)..
    "; UUID and physical node name preserved: "..tostring(value.node_name))
  refresh(scene.scene_id,obj.id)
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
  refresh(value.scene_id)
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

-- Full Scene UI controller regression with an injected numeric global resolve.
-- The UI callback must use the object returned from bmd.scriptapp("Resolve").
-- All Resolve/Fusion calls below are mocks; this is not a Studio host test.
local prior={
  resolve=rawget(_G,"resolve"),bmd=rawget(_G,"bmd"),
  fusion=rawget(_G,"fusion"),fu=rawget(_G,"fu"),
  getenv=os.getenv,packagepath=package.path,
  service=package.loaded["CartoRig.timeline_service"]
}
local realResolve={GetProjectManager=function() return {} end}
local calls,created,buttons,history=0,{}, {},{}
local selectedToolCalls=0
function realResolve:SetActiveTool() selectedToolCalls=selectedToolCalls+1 end

local ui={}
local function make_component(_,properties) return properties end
for _,name in ipairs({"VGroup","HGroup","Label","LineEdit","TextEdit","Button"}) do
  ui[name]=function(self,properties)
    assert(type(properties)=="table")
    if name=="Button" then buttons[#buttons+1]=properties.Text end
    return properties
  end
end
ui.ComboBox=function(self,properties)
  assert(type(properties)=="table")
  properties._items={}
  properties.CurrentIndex=properties.CurrentIndex or -1
  function properties:AddItem(value)
    self._items[#self._items+1]=value
    if self.CurrentIndex<0 then self.CurrentIndex=0 end
  end
  function properties:Clear()
    self._items={}
    self.CurrentIndex=-1
  end
  return properties
end

local items={
  SceneTitle={Text="Map Scene"},
  SceneContext=ui:ComboBox{ID="SceneContext"},
  SearchLocation={Text="Brasil"},
  GeoType=ui:ComboBox{ID="GeoType"},
  SearchResults=ui:ComboBox{ID="SearchResults"},
  AddCountry={Enabled=false},
  AddState={Enabled=false},
  ObjectContext=ui:ComboBox{ID="ObjectContext"},
  RenameObjectName={Text=""},
  RenameObject={Enabled=false},
  SceneList={PlainText=""},
  Status={Text=""}
}

local service={}
function service.create(received,title)
  assert(received==realResolve,"Scene callback passed numeric or wrong Resolve object")
  assert(title=="Map Scene")
  local count=#created+1
  local result={
    scene_id="test-scene-"..count,
    title=title,start_frame=count*120,
    end_frame=count*120+119,
    fusion_page_opened=true,
    objects={
      {id="scene-node-"..count,type="Scene",name="CR_Scene_Main"},
      {id="map-node-"..count,type="WorldMap",name="CR_WorldMap_Main",draw_order=0},
      {id="camera-node-"..count,type="Camera",name="CR_Camera_Main",draw_order=-1},
    }
  }
  created[#created+1]=result
  return result
end
function service.list_scenes(received)
  assert(received==realResolve)
  local scenes={}
  for n,scene in ipairs(created) do
    scenes[#scenes+1]={
      scene_id=scene.scene_id,track=1,start_frame=scene.start_frame,
      name="Scene "..n,objects=scene.objects
    }
  end
  history[#history+1]=#scenes
  return scenes
end
function service.search_locations(query,filter)
  assert(query=="Brasil")
  assert(filter=="Country")
  return {{
    geo_type="Country",canonical_name="Brazil",parent_name="South America",
    source_id="br-source",dataset_id="natural-earth-admin0-countries",
    source_version="5.1.1",geometry="Polygon",scale="1:50m"
  }}
end
function service.add_region(received,scene_id,dataset_id,source_id)
  assert(received==realResolve)
  assert(scene_id=="test-scene-1","structural target must come from SceneContext")
  assert(dataset_id=="natural-earth-admin0-countries")
  assert(source_id=="br-source")
  local object={
    id="country-br-1",type="Country",name="CR_Country_Brazil_001",
    display_name="Brazil",draw_order=20001,
    source={source_id="br-source",scale="1:50m"}
  }
  created[1].objects[#created[1].objects+1]=object
  return {
    scene_id=scene_id,object_id=object.id,object_type="Country",
    node_name=object.name,display_name="Brazil",source=object.source
  }
end
function service.rename_object(received,scene_id,object_id,new_name)
  assert(received==realResolve)
  assert(scene_id=="test-scene-1")
  assert(object_id=="country-br-1")
  assert(new_name=="Brazil Highlight")
  local object=created[1].objects[4]
  assert(object.id=="country-br-1" and object.name=="CR_Country_Brazil_001")
  object.display_name=new_name
  return {
    scene_id=scene_id,object_id=object.id,object_type=object.type,
    node_name=object.name,display_name=new_name
  }
end
package.loaded["CartoRig.timeline_service"]=service

local dispatcher={window=nil}
function dispatcher:AddWindow(options,layout)
  assert(options.ID=="CartoRigDevSceneWindow")
  assert(layout~=nil)
  local window={On={
    CreateScene={},SceneContext={},ObjectContext={},SearchResults={},Search={},SearchLocation={},
    AddCountry={},AddState={},RenameObject={},SaveReport={},Close={},CartoRigDevSceneWindow={}
  }}
  function window:GetItems() return items end
  function window:Show() self.visible=true end
  function window:Hide() self.visible=false end
  self.window=window
  return window
end
function dispatcher:RunLoop()
  assert(self.window and self.window.visible)
  assert(type(self.window.On.CreateScene.Clicked)=="function")
  assert(type(self.window.On.Search.Clicked)=="function")
  assert(type(self.window.On.AddCountry.Clicked)=="function")
  for n=1,5 do self.window.On.CreateScene.Clicked({}) end

  -- Deliberately choose the first Scene although the fifth is the last created.
  items.SceneContext.CurrentIndex=0
  self.window.On.SceneContext.CurrentIndexChanged({})
  -- Country is index 1 after All.
  items.GeoType.CurrentIndex=1
  self.window.On.Search.Clicked({})
  assert(items.AddCountry.Enabled==true and items.AddState.Enabled==false)
  assert(items.SearchResults._items[1]:find("natural-earth-admin0-countries v5.1.1",1,true),
    "Search result must expose dataset/version provenance")
  self.window.On.AddCountry.Clicked({})

  -- A03: choose Brazil only in the structural object selector, then Rename.
  local countryIndex=nil
  for index,label in ipairs(items.ObjectContext._items) do
    if label:find("Country — Brazil",1,true) then countryIndex=index-1;break end
  end
  assert(countryIndex~=nil,"Country must be present in structural object selector")
  items.ObjectContext.CurrentIndex=countryIndex
  self.window.On.ObjectContext.CurrentIndexChanged({})
  assert(items.RenameObject.Enabled==true)
  assert(items.RenameObjectName.Text=="Brazil")
  items.RenameObjectName.Text="Brazil Highlight"
  self.window.On.RenameObject.Clicked({})
end
function dispatcher:ExitLoop() end

local bmd={
  scriptapp=function(application)
    assert(application=="Resolve")
    calls=calls+1
    return realResolve
  end,
  UIDispatcher=function(manager)
    assert(manager==ui)
    return dispatcher
  end
}
_G.resolve=0
_G.bmd=bmd
_G.fusion={UIManager=ui}
_G.fu=nil
os.getenv=function(key)
  if key=="LOCALAPPDATA" then return "C:\\Users\\Test\\AppData\\Local" end
  return prior.getenv(key)
end

local ok,status,reason=pcall(assert(loadfile("host/cartorig-dev-scene.lua")))
assert(ok,"Scene UI must not crash when raw Resolve global is numeric: "..tostring(status))
assert(status==true,"Scene UI should finish normally: "..tostring(reason))
assert(calls==1,"Scene UI failed to recover the Resolve object exactly once")
assert(#created==5,"Five Create Scene clicks should invoke the timeline service five times")
assert(#history>=8 and history[1]==0,
  "Scene list must refresh initially, after Create Scene, Add Country and Rename")
assert(#created[1].objects==4 and created[1].objects[4].name=="CR_Country_Brazil_001",
  "Country must be added to selected structural Scene")
assert(created[1].objects[4].id=="country-br-1" and
       created[1].objects[4].display_name=="Brazil Highlight",
  "Rename must preserve UUID/node name and update display name only")
for n=2,5 do
  assert(#created[n].objects==3,"search/add must not mutate a different Scene")
end
assert(items.SceneList.PlainText:find("CR_Country_Brazil_001",1,true),
  "Selected Scene object list must display created Country")
assert(items.Status.Text:find("Display name changed to Brazil Highlight",1,true))
assert(items.Status.Text:find("CR_Country_Brazil_001",1,true))
assert(selectedToolCalls==0,"Scene structural UI must never select a Fusion node")
assert(dispatcher.window.visible==false)
assert(#buttons==7,"Expected Create/Search/Add Country/Add State/Rename/Save Report/Close")
for _,button in ipairs(buttons) do assert(button~="Open Scene") end

_G.resolve=prior.resolve
_G.bmd=prior.bmd
_G.fusion=prior.fusion
_G.fu=prior.fu
os.getenv=prior.getenv
package.path=prior.packagepath
package.loaded["CartoRig.timeline_service"]=prior.service
print("scene_ui_dispatch: PASS (5 Scenes + offline search + structural Country add/rename; host NOT RUN)")

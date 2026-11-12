-- Scene V1 FINAL controller test: NO timeline insertion, explicit Open Scene,
-- no automatic Fusion selection, and fail-closed composition switching.
-- Lua fakes are not a substitute for Resolve Studio host acceptance.
local prior={
  resolve=rawget(_G,"resolve"),bmd=rawget(_G,"bmd"),
  fusion=rawget(_G,"fusion"),fu=rawget(_G,"fu"),
  getenv=os.getenv,packagepath=package.path,
  service=package.loaded["CartoRig.scene_service"]
}
local realResolve={GetProjectManager=function() return {} end}
local selected=0
function realResolve:SetActiveTool() selected=selected+1 end
local compA,compB={},{ }
local active=compA
local a={composition=compA,has_scene=false,scene_id=nil,objects={}}
local b={composition=compB,has_scene=true,scene_id="scene-B",title="Second Scene",
 objects={{id="b-scene",type="Scene",name="CR_Scene_Main"},
          {id="b-world",type="WorldMap",name="CR_WorldMap_Main"},
          {id="b-camera",type="Camera",name="CR_Camera_Main"}}}
local created=0
local addA,addB=0,0
local blocked=0
local ui={}
for _,kind in ipairs({"VGroup","HGroup","Label","LineEdit","TextEdit","Button"}) do
  ui[kind]=function(_,attrs) return attrs end
end
ui.ComboBox=function(_,attrs)
  attrs._items={}
  attrs.CurrentIndex=attrs.CurrentIndex or -1
  function attrs:AddItem(value)
    self._items[#self._items+1]=value
    if self.CurrentIndex<0 then self.CurrentIndex=0 end
  end
  function attrs:Clear() self._items={};self.CurrentIndex=-1 end
  return attrs
end
local items={
  SceneTitle={Text="Map Scene"},ActiveContext={Text=""},
  RenameSceneName={Text=""},RenameScene={Enabled=false},
  SearchLocation={Text="Brazil"},GeoType=ui:ComboBox{ID="GeoType"},
  SearchResults=ui:ComboBox{ID="SearchResults"},
  AddCountry={Enabled=false},AddState={Enabled=false},
  ObjectContext=ui:ComboBox{ID="ObjectContext"},
  RenameObjectName={Text=""},RenameObject={Enabled=false},
  SceneList={PlainText=""},Status={Text=""}
}
local mock={}
function mock.inspect_active(received)
  assert(received==realResolve)
  return active==compA and a or b
end
function mock.open_scene(received)
  local state=mock.inspect_active(received)
  assert(state.has_scene)
  return state
end
function mock.create_scene(received,title,binding)
  assert(received==realResolve and binding==a)
  assert(active==compA and title=="Map Scene")
  if a.has_scene then return nil,"SCENE_EXISTS: use Open Scene" end
  created=created+1
  a.has_scene=true
  a.scene_id="scene-A"
  a.title=title
  a.objects={
    {id="a-scene",type="Scene",name="CR_Scene_Main"},
    {id="a-world",type="WorldMap",name="CR_WorldMap_Main"},
    {id="a-camera",type="Camera",name="CR_Camera_Main"}
  }
  return a
end
function mock.rename_scene(received,binding,title)
  assert(received==realResolve and binding==a and title=="Brazil Map")
  a.title=title
  return {scene_id=a.scene_id,title=title}
end
function mock.search_locations(query,filter)
  assert(query=="Brazil" and filter=="Country")
  return {{
    geo_type="Country",canonical_name="Brazil",parent_name="South America",
    source_id="br-source",dataset_id="natural-earth-admin0-countries",
    source_version="5.1.1",geometry="Polygon",scale="1:50m"
  }}
end
function mock.add_region(received,binding,dataset_id,source_id)
  assert(received==realResolve and binding.composition==active)
  assert(dataset_id=="natural-earth-admin0-countries" and source_id=="br-source")
  local object={
    id=active==compA and "a-br" or "b-br",type="Country",
    name="CR_Country_Brazil_001",display_name="Brazil",draw_order=20001,
  }
  binding.objects[#binding.objects+1]=object
  if active==compA then addA=addA+1 else addB=addB+1 end
  return {object_id=object.id,node_name=object.name}
end
function mock.rename_object(received,binding,object_id,title)
  assert(received==realResolve and binding==a)
  assert(object_id=="a-br" and title=="Brazil Highlight")
  a.objects[4].display_name=title
  return {object_id=object_id,node_name=a.objects[4].name}
end
function mock.repair_palette(received,binding)
  assert(received==realResolve and binding==b)
  return {regions=1,expressions_repaired=0}
end
package.loaded["CartoRig.scene_service"]=mock

local dispatcher={}
function dispatcher:AddWindow(options,layout)
  assert(options.ID=="CartoRigDevSceneWindow" and layout)
  local window={On={}}
  for _,event in ipairs({
    "CreateScene","OpenScene","RenameScene","Search","SearchLocation",
    "SearchResults","AddCountry","AddState","ObjectContext","RenameObject",
    "RepairPalette","SaveReport","Close","CartoRigDevSceneWindow"
  }) do window.On[event]={} end
  function window:GetItems() return items end
  function window:Show() self.visible=true end
  function window:Hide() self.visible=false end
  self.window=window
  return window
end
function dispatcher:RunLoop()
  local w=self.window
  assert(w and w.visible)
  assert(items.SceneList.PlainText:find("No CartoRig Scene",1,true))
  w.On.CreateScene.Clicked({})
  assert(created==1 and a.has_scene)
  w.On.CreateScene.Clicked({})
  assert(created==1 and items.Status.Text:find("SCENE_EXISTS",1,true)~=nil,
    "second Create Scene must be blocked by the service")
  w.On.OpenScene.Clicked({})
  assert(a.scene_id=="scene-A")
  items.RenameSceneName.Text="Brazil Map"
  w.On.RenameScene.Clicked({})
  assert(a.title=="Brazil Map")
  items.GeoType.CurrentIndex=2 -- All, Continent, Country
  w.On.Search.Clicked({})
  assert(items.AddCountry.Enabled and not items.AddState.Enabled)
  w.On.AddCountry.Clicked({})
  assert(addA==1 and addB==0)
  local country=4
  items.ObjectContext.CurrentIndex=country-1
  w.On.ObjectContext.CurrentIndexChanged({})
  items.RenameObjectName.Text="Brazil Highlight"
  w.On.RenameObject.Clicked({})
  assert(a.objects[4].display_name=="Brazil Highlight")
  active=compB
  w.On.AddCountry.Clicked({})
  assert(addA==1 and addB==0,"composition changes must block mutations")
  assert(items.Status.Text:find("SCENE_CONTEXT_CHANGED",1,true),
    "context switch must tell editor how to rebind")
  w.On.OpenScene.Clicked({})
  assert(items.ActiveContext.Text:find("scene-B",1,true))
  w.On.AddCountry.Clicked({})
  assert(addA==1 and addB==1)
  w.On.RepairPalette.Clicked({})
end
function dispatcher:ExitLoop() end

local bmd={
  scriptapp=function(name) assert(name=="Resolve");return realResolve end,
  UIDispatcher=function(manager) assert(manager==ui);return dispatcher end,
}
_G.resolve=0
_G.bmd=bmd
_G.fusion={UIManager=ui}
_G.fu=nil
os.getenv=function(name)
  if name=="LOCALAPPDATA" then return "C:\\Users\\Test\\AppData\\Local" end
  return prior.getenv(name)
end
local ok,result=pcall(dofile,"host/cartorig-dev-scene.lua")
assert(ok and result==true,"Scene UI dispatch failed: "..tostring(result))
assert(selected==0,"Scene UI must never select Fusion nodes")
assert(created==1 and addA==1 and addB==1,
  "Scene UI must mutate only its explicitly bound active composition")

_G.resolve=prior.resolve
_G.bmd=prior.bmd
_G.fusion=prior.fusion
_G.fu=prior.fu
os.getenv=prior.getenv
package.path=prior.packagepath
package.loaded["CartoRig.scene_service"]=prior.service
print("PASS Scene UI active-comp binding / Create/Open/CRUD isolation")

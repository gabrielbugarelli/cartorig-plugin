-- V1 FINAL active-Fusion-composition service tests (pure Lua host doubles).
-- No timeline clip insertion is permitted by this service.
local saved={
  factory=package.loaded["CartoRig.node_factory"],
  catalog=package.loaded["CartoRig.catalog"],
  service=package.loaded["CartoRig.scene_service"],
}
local a,b={},{ }
local function state(comp)
  return comp.state or {has_scene=false,scene_id=nil,title=nil,objects={}}
end
local mutations={create=0,add=0,rename=0,repair=0}
local fakeFactory={}
function fakeFactory.inspect(comp)
  return state(comp)
end
function fakeFactory.create_scene(comp,title,opts)
  if comp.state and comp.state.has_scene then return nil,"SCENE_EXISTS" end
  mutations.create=mutations.create+1
  local sid="scene-"..tostring(mutations.create)
  comp.state={has_scene=true,scene_id=sid,title=title,objects={
    {id=sid.."-scene",type="Scene",name="CR_Scene_Main"},
    {id=sid.."-world",type="WorldMap",name="CR_WorldMap_Main"},
    {id=sid.."-camera",type="Camera",name="CR_Camera_Main"},
  }}
  return {scene_id=sid}
end
function fakeFactory.add_region(comp,feature,opts)
  mutations.add=mutations.add+1
  local id=comp.state.scene_id.."-region-"..mutations.add
  local obj={id=id,type=feature.geo_type,name="CR_Country_Brazil_001"}
  comp.state.objects[#comp.state.objects+1]=obj
  return {object_id=id,node_name=obj.name,source={source_id=feature.source_id}}
end
function fakeFactory.rename_object(comp,object_id,new_name)
  mutations.rename=mutations.rename+1
  return {object_id=object_id,display_name=new_name}
end
function fakeFactory.rename_scene(comp,title)
  mutations.rename=mutations.rename+1
  comp.state.title=title
  return {scene_id=comp.state.scene_id,title=title}
end
function fakeFactory.repair_region_palette(comp)
  mutations.repair=mutations.repair+1
  return {regions=1,expressions_repaired=6}
end
local fakeCatalog={}
function fakeCatalog.open(path) return {path=path} end
function fakeCatalog.search(index,q,t,limit)
  assert(limit==50)
  return {{geo_type="Country",source_id="br",dataset_id="admin0"}}
end
function fakeCatalog.find(index,dataset_id,source_id)
  if dataset_id~="admin0" or source_id~="br" then return nil,"NOT_FOUND" end
  return {geo_type="Country",source_id="br",dataset_id="admin0"}
end
package.loaded["CartoRig.node_factory"]=fakeFactory
package.loaded["CartoRig.catalog"]=fakeCatalog
package.loaded["CartoRig.scene_service"]=nil
local service=require("CartoRig.scene_service")
local page="edit"
local fusion={CurrentComp=a}
local resolve={
  GetCurrentPage=function() return page end,
  Fusion=function() return fusion end,
}
local failed,err=service.inspect_active(resolve)
assert(failed==nil and err:find("FUSION_PAGE_REQUIRED",1,true))
assert(mutations.create==0,"Fusion page required before mutation")
page="fusion"
local initial=assert(service.inspect_active(resolve))
assert(initial.composition==a and not initial.has_scene)
local invalid,invalidErr=service.create_scene(resolve,"",initial)
assert(invalid==nil and invalidErr:find("INVALID_TITLE",1,true))
local created=assert(service.create_scene(resolve,"Map Scene",initial,{}))
assert(created.scene_id=="scene-1" and created.has_scene)
assert(mutations.create==1)
local dup,dupErr=service.create_scene(resolve,"Another",created)
assert(dup==nil and dupErr:find("SCENE_EXISTS",1,true))
assert(mutations.create==1)
local reopened=assert(service.open_scene(resolve))
assert(reopened.scene_id==created.scene_id and mutations.create==1)
local catalogResults=assert(service.search_locations("Brazil","Country",{localappdata="T:"}))
assert(#catalogResults==1)
local first=assert(service.add_region(resolve,reopened,"admin0","br",{localappdata="T:"}))
assert(first.object_id=="scene-1-region-1" and mutations.add==1)
local secondBinding=assert(service.open_scene(resolve))
assert(service.rename_object(resolve,secondBinding,first.object_id,"Brazil Highlight"))
assert(mutations.rename==1)
assert(service.rename_scene(resolve,secondBinding,"Renamed Scene"))
assert(a.state.title=="Renamed Scene")

-- Switching Fusion compositions cannot redirect operations from a previously
-- opened Scene, even if the copied composition has an identical Scene UUID.
fusion.CurrentComp=b
b.state={has_scene=true,scene_id=a.state.scene_id,title="Copied Scene",objects=a.state.objects}
local blocked,contextErr=service.add_region(resolve,secondBinding,"admin0","br",{localappdata="T:"})
assert(blocked==nil and contextErr:find("SCENE_CONTEXT_CHANGED",1,true))
assert(mutations.add==1)
local boundB=assert(service.open_scene(resolve))
assert(boundB.composition==b)
assert(service.add_region(resolve,boundB,"admin0","br",{localappdata="T:"}))
assert(mutations.add==2)
assert(service.repair_palette(resolve,boundB).expressions_repaired==6)
assert(mutations.repair==1)

-- GET method fallback when CurrentComp property is unavailable.
fusion.CurrentComp=nil
fusion.GetCurrentComp=function() return b end
assert(service.inspect_active(resolve).composition==b)
print("PASS SceneService current-comp/Create/Open/CRUD/context isolation")
package.loaded["CartoRig.node_factory"]=saved.factory
package.loaded["CartoRig.catalog"]=saved.catalog
package.loaded["CartoRig.scene_service"]=saved.service

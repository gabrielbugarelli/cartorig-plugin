-- Isolated unit fakes: verifies safety and domain logic, NOT Fusion host acceptance.
local factory=require("CartoRig.node_factory")
local domain=require("CartoRig.domain")
local dataPath="tests/fixtures/local-data-test\\CartoRig\\App\\data\\ne_50m_land.lua"
local f=assert(io.open(dataPath,"wb"))
f:write("local t={}\nfor i=1,1422 do t[i]={0,0,1,0,1,1,0,1} end\nreturn t\n")
f:close()
local borderPath=ROOT.."\\CartoRig\\App\\data\\ne_50m_admin0_borders.lua"
local borderFile=assert(io.open(borderPath,"wb"))
borderFile:write("return {{0,0,1,1,2,1}}\n")
borderFile:close()
local function fake()
 local comp={tools={},data={},added={},deleted=0,undo=0,undo_keeps={}}
 function comp:GetToolList()
  local out={__flags=1048576}
  for i,tool in ipairs(self.tools) do out["Tool"..i]=tool end
  return out
 end
 function comp:GetData(key) return self.data[key] end
 function comp:SetData(key,v) self.data[key]=v end
 function comp:StartUndo() self.undo=self.undo+1 end
 function comp:EndUndo(keep)
  self.undo=self.undo-1
  self.undo_keeps[#self.undo_keeps+1]=keep
  if self.fail_end_undo and keep==true then error("synthetic EndUndo failure") end
 end
 function comp:AddTool(regid,x,y)
  if type(x)~="number" or type(y)~="number" then error("AddTool 3-arg expected") end
  if self.fail==regid then return nil end
  local tool={regid=regid,name=regid..tostring(#self.tools+1),data={},links={},inputs={},inside=comp}
  function tool:GetAttrs() return {TOOLS_RegID=self.regid,TOOLS_Name=self.name} end
  function tool:SetAttrs(dict) if dict.TOOLS_Name then self.name=dict.TOOLS_Name end end
  function tool:SetData(k,v) self.data[k]=v end
  function tool:GetData(k) return self.data[k] end
  function tool:SetInput(k,v) self.inputs[k]=v end
  function tool:GetInput(k) return self.inputs[k] end
  function tool:FindInput(port)
   local parent=self
   return {GetConnectedOutput=function()
    local source=parent.links[port]
    if not source then return nil end
    return {GetTool=function() return source end}
   end}
  end
  function tool:ConnectInput(port,other)
   if comp.fail_link==port and comp.fail_link_regid==self.regid then
    if comp.fail_link_once then
     comp.fail_link=nil;comp.fail_link_regid=nil;comp.fail_link_once=nil
    end
    return false
   end
   if comp.fail_link==port and not comp.fail_link_regid and self.regid=="MediaOut" then return false end
   self.links[port]=other
   return true
  end
  function tool:Delete()
   if comp.fail_delete_for==self.regid then return false end
   for i,v in ipairs(comp.tools) do
    if v==self then table.remove(comp.tools,i);break end
   end
   comp.deleted=comp.deleted+1
   return true
  end
  self.tools[#self.tools+1]=tool
  self.added[#self.added+1]=tool
  return tool
 end
 local media=comp:AddTool("MediaOut",0,0)
 return comp,media
end
local corruptPath="tests/fixtures/corrupt-data-test\\CartoRig\\App\\data\\ne_50m_land.lua"
local corruptFile=assert(io.open(corruptPath,"wb"))
corruptFile:write("return {{0,0,999,0,1,1,0,1}}\n")
corruptFile:close()
local corruptComp,corruptMedia=fake()
local corruptResult,corruptReason=factory.create_scene(corruptComp,"Corrupt data",{localappdata="tests/fixtures/corrupt-data-test"})
assert(corruptResult==nil and corruptReason:match("DATA_INCOMPATIBLE"))
assert(#corruptComp.tools==1 and corruptComp.tools[1]==corruptMedia,
 "invalid Natural Earth data must block before graph mutation")
os.remove(corruptPath)

local throwingComp=setmetatable({},{
 __index=function() error("synthetic Fusion proxy lookup failure") end
})
local inspectOk,inspectResult,inspectReason=pcall(factory.inspect,throwingComp)
assert(inspectOk and inspectResult==nil and tostring(inspectReason):match("NO_COMPOSITION"),
 "Fusion proxy lookup failure must become a diagnostic, not escape as Lua exception; pcall="..
 tostring(inspectOk).." result="..tostring(inspectResult).." reason="..tostring(inspectReason))

local ROOT="tests/fixtures/local-data-test"
local broken,bmedia=fake()
assert(factory.create_scene(broken,"X",{localappdata="nonexistent"})==nil)
assert(#broken.tools==1 and not broken.data["CartoRig.V1.SceneId"])
local comp,media=fake()
local foreign=comp:AddTool("Blur",6,5)
assert(factory.inspect(comp).has_scene==false)
local made=assert(factory.create_scene(comp,"Brazil Map",{localappdata=ROOT}))
assert(made.created_author_nodes==3 and made.output_connected)
assert(#comp.tools==5 and comp.undo==0)
assert(comp.tools[1]==media and comp.tools[2]==foreign)
assert(media.links.Input~=nil and media.links.Input:GetAttrs().TOOLS_Name=="CR_Scene_Main")
local camera,world
for _,node in pairs(comp.tools) do
 if node.name=="CR_Camera_Main" then camera=node end
 if node.name=="CR_WorldMap_Main" then world=node end
end
assert(camera and world and camera.links.Input==world)
local persisted=assert(factory.inspect(comp))
assert(persisted.has_scene and persisted.title=="Brazil Map")
assert(#persisted.objects==3)
local sceneDisplay
for _,o in ipairs(persisted.objects) do
 if o.type=="Scene" then sceneDisplay=o.display_name end
end
assert(sceneDisplay=="Brazil Map","Scene display name must persist independently of timeline clip name")
comp:SetData("CartoRig.V1.Title",nil)
local legacyReadable=assert(factory.inspect(comp))
assert(legacyReadable.has_scene and legacyReadable.legacy_title_missing==true and legacyReadable.title==nil,
 "pre-0.6.3 Scene without persisted title must remain readable")
comp:SetData("CartoRig.V1.Title","Brazil Map")
assert(assert(factory.inspect(comp)).legacy_title_missing==false)
-- Region creation must use the same real-provenance transaction as the product.
local countryGeometryRel="regions/ne_admin0/ne-id-country-br.lua"
local countryGeometryPath=ROOT.."\\CartoRig\\App\\data\\"..countryGeometryRel:gsub("/","\\")
local countryGeometry=assert(io.open(countryGeometryPath,"wb"))
countryGeometry:write('return {source_id="ne-id-country-br",version="fixture-v1",scale="1:50m",rings={{-74,-34,-34,-34,-34,5,-74,5}}}\n')
countryGeometry:close()
local stateGeometryRel="regions/ne_admin1/ne-id-state-mt.lua"
local stateGeometryPath=ROOT.."\\CartoRig\\App\\data\\"..stateGeometryRel:gsub("/","\\")
local stateGeometry=assert(io.open(stateGeometryPath,"wb"))
stateGeometry:write('return {source_id="ne-id-state-mt",version="fixture-v1",scale="1:10m",rings={{-61,-18,-50,-18,-50,-7,-61,-7}}}\n')
stateGeometry:close()

local brazilFeature={
 geo_type="Country",source_type="Country",canonical_name="Brazil",
 parent_name="South America",geometry_available=true,geometry="Polygon",
 source_id="ne-id-country-br",dataset_id="ne_admin0",source_version="fixture-v1",
 scale="1:50m",geometry_file=countryGeometryRel
}
local matoFeature={
 geo_type="State",source_type="State",canonical_name="Mato Grosso",
 parent_name="Brazil",geometry_available=true,geometry="Polygon",
 source_id="ne-id-state-mt",dataset_id="ne_admin1",source_version="fixture-v1",
 scale="1:10m",geometry_file=stateGeometryRel
}
local country1=assert(factory.add_region(comp,brazilFeature,{localappdata=ROOT}))
local country2=assert(factory.add_region(comp,brazilFeature,{localappdata=ROOT}))
local state1=assert(factory.add_region(comp,matoFeature,{localappdata=ROOT}))
assert(country1.node_name=="CR_Country_Brazil_001")
assert(country2.node_name=="CR_Country_Brazil_002")
assert(state1.node_name=="CR_State_MatoGrosso_001")
assert(country1.object_id~=country2.object_id and country2.object_id~=state1.object_id)
assert(country1.source.scale=="1:50m" and state1.source.scale=="1:10m")

local expanded=assert(factory.inspect(comp))
assert(expanded.has_scene and #expanded.objects==6,
 "Country/Country/State must coexist with the three structural nodes")
local countryNodes={}
local stateNode=nil
for _,tool in ipairs(comp.tools) do
 if tool:GetData("CartoRig.V1.ObjectType")=="Country" then countryNodes[#countryNodes+1]=tool end
 if tool:GetData("CartoRig.V1.ObjectType")=="State" then stateNode=tool end
end
assert(#countryNodes==2 and stateNode)
local currentCameraSource=camera.links.Input
assert(currentCameraSource==stateNode,"newest Region must feed Camera")
assert(stateNode.links.Background~=nil and stateNode.links.Background:GetData("CartoRig.V1.ObjectType")=="Country")
assert(stateNode:GetData("CartoRig.V1.GeometryFile")==stateGeometryRel)
assert(stateNode:GetData("CartoRig.V1.SourceScale")=="1:10m")
assert(stateNode:GetInput("IdentityInfo"):find("State — Mato Grosso",1,true))
assert(stateNode:GetInput("GeographyInfo"):find("Natural Earth 1:10m",1,true))
assert(stateNode:GetInput("GeographyInfo"):find("Source ID: ne-id-state-mt",1,true))

local originalCountry2Id=countryNodes[2]:GetData("CartoRig.V1.ObjectId")
countryNodes[2]:SetData("CartoRig.V1.ObjectId",countryNodes[1]:GetData("CartoRig.V1.ObjectId"))
local duplicateId,duplicateIdErr=factory.inspect(comp)
assert(duplicateId==nil and duplicateIdErr:match("duplicated object UUID"))
countryNodes[2]:SetData("CartoRig.V1.ObjectId",originalCountry2Id)
local originalCountry2Name=countryNodes[2].name
countryNodes[2]:SetAttrs({TOOLS_Name=countryNodes[1].name})
local duplicateName,duplicateNameErr=factory.inspect(comp)
assert(duplicateName==nil and duplicateNameErr:match("duplicated CartoRig node name"))
countryNodes[2]:SetAttrs({TOOLS_Name=originalCountry2Name})
assert(#assert(factory.inspect(comp)).objects==6)

-- Catalog/geometry mismatch must fail before graph mutation.
local mismatched={}
for k,v in pairs(brazilFeature) do mismatched[k]=v end
mismatched.source_version="wrong-version"
local beforeMismatch=#comp.tools
local mismatchResult,mismatchErr=factory.add_region(comp,mismatched,{localappdata=ROOT})
assert(mismatchResult==nil and mismatchErr:match("DATA_INCOMPATIBLE"))
assert(#comp.tools==beforeMismatch)

-- Class ordering is independent of click order: State added before Country must
-- still render after Country and before the shared Camera.
local orderedComp,orderedMedia=fake()
local orderedScene=assert(factory.create_scene(orderedComp,"Order test",{localappdata=ROOT}))
local orderedState=assert(factory.add_region(orderedComp,matoFeature,{localappdata=ROOT}))
local orderedCountry=assert(factory.add_region(orderedComp,brazilFeature,{localappdata=ROOT}))
local orderedCamera,orderedWorld,orderedStateTool,orderedCountryTool
for _,tool in ipairs(orderedComp.tools) do
 local typ=tool:GetData("CartoRig.V1.ObjectType")
 if typ=="Camera" then orderedCamera=tool
 elseif typ=="WorldMap" then orderedWorld=tool
 elseif typ=="State" then orderedStateTool=tool
 elseif typ=="Country" then orderedCountryTool=tool end
end
assert(orderedCamera and orderedWorld and orderedStateTool and orderedCountryTool)
assert(orderedCountryTool.links.Background==orderedWorld)
assert(orderedStateTool.links.Background==orderedCountryTool)
assert(orderedCamera.links.Input==orderedStateTool,
 "managed render chain must remain WorldMap -> Country -> State -> Camera")

-- Failure while wiring the new Region to its successor must restore the old
-- managed chain and remove the new node.
local rollbackComp,rollbackMedia=fake()
assert(factory.create_scene(rollbackComp,"Region rollback",{localappdata=ROOT}))
local rollbackCamera
local rollbackWorld
for _,tool in ipairs(rollbackComp.tools) do
 local typ=tool:GetData("CartoRig.V1.ObjectType")
 if typ=="Camera" then rollbackCamera=tool end
 if typ=="WorldMap" then rollbackWorld=tool end
end
rollbackComp.fail_link="Input"
rollbackComp.fail_link_regid="Fuse.CartoRigCamera"
rollbackComp.fail_link_once=true
local regionFailure,regionFailureErr=factory.add_region(rollbackComp,brazilFeature,{localappdata=ROOT})
assert(regionFailure==nil and regionFailureErr:match("REGION_CREATE_FAILED"))
assert(not regionFailureErr:match("ROLLBACK_INCOMPLETE"),regionFailureErr)
assert(rollbackCamera.links.Input==rollbackWorld,
 "failed Region transaction must restore Camera -> WorldMap")
local rolledBackState=assert(factory.inspect(rollbackComp))
assert(#rolledBackState.objects==3,"failed Region transaction must not leave an author node")

local sid=made.scene_id
assert(sid==comp:GetData("CartoRig.V1.SceneId"))
assert(factory.create_scene(comp,"Do not duplicate",{localappdata=ROOT})==nil)
assert(#comp.tools==8)
local rejected,rm=fake()
rejected.fail_link="Input"
local result2,reason2=factory.create_scene(rejected,"Connection failure",{localappdata=ROOT})
assert(not result2 and type(reason2)=="string" and reason2:match("SCENE_CREATE_FAILED"),
 "Expected transactional failure, got result="..tostring(result2).." / "..tostring(reason2))
assert(#rejected.tools==1 and rm.links.Input==nil)
assert(rejected:GetData("CartoRig.V1.SceneId")==nil)
local incomplete,im=fake()
incomplete.fail_link="Input"
incomplete.fail_delete_for="Fuse.CartoRigCamera"
local incompleteResult,incompleteReason=factory.create_scene(incomplete,"Incomplete rollback",{localappdata=ROOT})
assert(incompleteResult==nil and incompleteReason:match("ROLLBACK_INCOMPLETE"))
local leakedCamera=false
for _,tool in pairs(incomplete.tools) do
 if tool.regid=="Fuse.CartoRigCamera" then leakedCamera=true end
end
assert(leakedCamera,"fixture must actually leave a created tool behind")

local failed,c=fake()
failed.fail="Fuse.CartoRigCamera"
local result,error=factory.create_scene(failed,"Failure",{localappdata=ROOT})
assert(not result and error:match("SCENE_CREATE_FAILED"))
assert(#failed.tools==1 and failed.deleted==1)
assert(c.links.Input==nil)
assert(failed:GetData("CartoRig.V1.SceneId")==nil and failed.undo==0)
local undo_failed,undo_media=fake()
undo_failed.fail_end_undo=true
local undoResult,undoReason=factory.create_scene(undo_failed,"Undo failure",{localappdata=ROOT})
assert(undoResult==nil and undoReason:match("UNDO_ERROR"))
assert(#undo_failed.tools==1 and undo_failed.tools[1]==undo_media,
 "Undo-finalization failure must remove all CartoRig nodes")
assert(undo_media.links.Input==nil)
assert(undo_failed:GetData("CartoRig.V1.SceneId")==nil)
assert(undo_failed:GetData("CartoRig.V1.Title")==nil)
assert(undo_failed.undo_keeps[#undo_failed.undo_keeps]==false,
 "failed transaction must close/discard its Undo record with EndUndo(false)")

local busy,foreign_media=fake()
local external=busy:AddTool("Loader",9,9)
foreign_media:ConnectInput("Input",external)
local from_new,reason=factory.create_scene(busy,"Avoid touching external",{localappdata=ROOT})
assert(from_new==nil and reason:match("MEDIAOUT_ALREADY_CONNECTED"))
assert(#busy.tools==2 and foreign_media.links.Input==external)
local no_new,d=fake()
d:Delete()
local noOutput,outputReason=factory.create_scene(no_new,"No managed output",
 {localappdata=ROOT,disallow_new_mediaout=true})
assert(noOutput==nil and outputReason:match("MEDIAOUT_UNAVAILABLE"))
assert(#no_new.tools==0,
 "disallow_new_mediaout must fail before creating any author node or replacement MediaOut")
os.remove(countryGeometryPath)
os.remove(stateGeometryPath)
os.remove(borderPath)
os.remove(dataPath)
print("node_factory: PASS (mocked host only; creation, isolation, UUIDs, rollback, output links)")

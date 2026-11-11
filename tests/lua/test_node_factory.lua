-- Isolated unit fakes: verifies safety and domain logic, NOT Fusion host acceptance.
local factory=require("CartoRig.node_factory")
local domain=require("CartoRig.domain")
local dataPath="tests/fixtures/local-data-test\\CartoRig\\App\\data\\ne_50m_land.lua"
local f=assert(io.open(dataPath,"wb"))
f:write(string.rep("x",510000));f:close()
local function fake()
 local comp={tools={},data={},added={},deleted=0,undo=0,undo_keeps={}}
 function comp:GetToolList() return self.tools end
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
  local tool={regid=regid,name=regid..tostring(#self.tools+1),data={},links={},inside=comp}
  function tool:GetAttrs() return {TOOLS_RegID=self.regid,TOOLS_Name=self.name} end
  function tool:SetAttrs(dict) if dict.TOOLS_Name then self.name=dict.TOOLS_Name end end
  function tool:SetData(k,v) self.data[k]=v end
  function tool:GetData(k) return self.data[k] end
  function tool:FindInput(port)
   local parent=self
   return {GetConnectedOutput=function() return parent.links[port] end}
  end
  function tool:ConnectInput(port,other)
   if comp.fail_link==port and self.regid=="MediaOut" then return false end
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
-- Additional authoring nodes must not invalidate the three singleton structural
-- nodes. Multiple Countries/States/Markers/etc. are expected by the product.
local countries={}
for n=1,2 do
 local country=comp:AddTool("Fuse.CartoRigCountry",10+n,4)
 country:SetAttrs({TOOLS_Name="CR_Country_Test_"..n})
 country:SetData("CartoRig.V1.Owned",true)
 country:SetData("CartoRig.V1.ObjectId",domain.uuid())
 country:SetData("CartoRig.V1.ObjectType","Country")
 country:SetData("CartoRig.V1.SceneId",made.scene_id)
 country:SetData("CartoRig.V1.SchemaVersion","1.0.0")
 countries[n]=country
end
local expanded=assert(factory.inspect(comp))
assert(expanded.has_scene and #expanded.objects==5,
 "Two extra Country nodes must coexist with the structural Scene/WorldMap/Camera")
local originalCountry2Id=countries[2]:GetData("CartoRig.V1.ObjectId")
countries[2]:SetData("CartoRig.V1.ObjectId",countries[1]:GetData("CartoRig.V1.ObjectId"))
local duplicateId,duplicateIdErr=factory.inspect(comp)
assert(duplicateId==nil and duplicateIdErr:match("duplicated object UUID"))
countries[2]:SetData("CartoRig.V1.ObjectId",originalCountry2Id)
countries[2]:SetAttrs({TOOLS_Name="CR_Country_Test_1"})
local duplicateName,duplicateNameErr=factory.inspect(comp)
assert(duplicateName==nil and duplicateNameErr:match("duplicated CartoRig node name"))
countries[2]:SetAttrs({TOOLS_Name="CR_Country_Test_2"})
assert(#assert(factory.inspect(comp)).objects==5)
local sid=made.scene_id
assert(sid==comp:GetData("CartoRig.V1.SceneId"))
assert(factory.create_scene(comp,"Do not duplicate",{localappdata=ROOT})==nil)
assert(#comp.tools==7)
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
os.remove(dataPath)
print("node_factory: PASS (mocked host only; creation, isolation, UUIDs, rollback, output links)")

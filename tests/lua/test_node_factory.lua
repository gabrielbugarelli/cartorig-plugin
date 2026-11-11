-- Isolated unit fakes: verifies safety and domain logic, NOT Fusion host acceptance.
local factory=require("CartoRig.node_factory")
local dataPath="tests/fixtures/local-data-test\\CartoRig\\App\\data\\ne_50m_land.lua"
local f=assert(io.open(dataPath,"wb"))
f:write(string.rep("x",510000));f:close()
local function fake()
 local comp={tools={},data={},added={},deleted=0,undo=0}
 function comp:GetToolList() return self.tools end
 function comp:GetData(key) return self.data[key] end
 function comp:SetData(key,v) self.data[key]=v end
 function comp:StartUndo() self.undo=self.undo+1 end
 function comp:EndUndo() self.undo=self.undo-1 end
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
   for i,v in ipairs(comp.tools) do
    if v==self then table.remove(comp.tools,i);break end
   end
   comp.deleted=comp.deleted+1
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
assert(factory.inspect(comp).has_scene)
assert(#factory.inspect(comp).objects==3)
local sid=made.scene_id
assert(sid==comp:GetData("CartoRig.V1.SceneId"))
assert(factory.create_scene(comp,"Do not duplicate",{localappdata=ROOT})==nil)
assert(#comp.tools==5)
local rejected,rm=fake()
rejected.fail_link="Input"
local result2,reason2=factory.create_scene(rejected,"Connection failure",{localappdata=ROOT})
assert(not result2 and type(reason2)=="string" and reason2:match("SCENE_CREATE_FAILED"),
 "Expected transactional failure, got result="..tostring(result2).." / "..tostring(reason2))
assert(#rejected.tools==1 and rm.links.Input==nil)
assert(rejected:GetData("CartoRig.V1.SceneId")==nil)
local failed,c=fake()
failed.fail="Fuse.CartoRigCamera"
local result,error=factory.create_scene(failed,"Failure",{localappdata=ROOT})
assert(not result and error:match("SCENE_CREATE_FAILED"))
assert(#failed.tools==1 and failed.deleted==1)
assert(c.links.Input==nil)
assert(failed:GetData("CartoRig.V1.SceneId")==nil and failed.undo==0)
local busy,foreign_media=fake()
local external=busy:AddTool("Loader",9,9)
foreign_media:ConnectInput("Input",external)
local from_new,reason=factory.create_scene(busy,"Avoid touching external",{localappdata=ROOT})
assert(from_new==nil and reason:match("MEDIAOUT_ALREADY_CONNECTED"))
assert(#busy.tools==2 and foreign_media.links.Input==external)
local no_new,d=fake()
d:ConnectInput("Input",no_new:AddTool("Loader",3,3))
assert(factory.create_scene(no_new,"No managed output",{localappdata=ROOT,disallow_new_mediaout=true})==nil)
assert(#no_new.tools==2)
os.remove(dataPath)
print("node_factory: PASS (mocked host only; creation, isolation, UUIDs, rollback, output links)")

local fusion=require("CartoRig.fusion_contract")

local comp={tools={},undo=0}
function comp:GetToolList()
  return {Background1=self.tools[1],MediaOut1=self.tools[2],__flags=1048576}
end
function comp:AddTool(regid,x,y)
  assert(type(regid)=="string" and type(x)=="number" and type(y)=="number")
  local tool={regid=regid,name=regid,data={},links={},inputs={}}
  function tool:GetAttrs() return {TOOLS_RegID=self.regid,TOOLS_Name=self.name,__flags=1} end
  function tool:SetAttrs(values) if values.TOOLS_Name then self.name=values.TOOLS_Name end end
  function tool:GetData(key) return self.data[key] end
  function tool:SetData(key,value) self.data[key]=value end
  function tool:SetInput(key,value,time)
    self.inputs[key..":"..tostring(time or "undefined")]=value
    return nil
  end
  function tool:GetInput(key,time)
    return self.inputs[key..":"..tostring(time or "undefined")]
  end
  function tool:FindInput(name)
    local owner=self
    return {GetConnectedOutput=function()
      local source=owner.links[name]
      if not source then return nil end
      return {GetTool=function() return source end}
    end}
  end
  function tool:ConnectInput(name,target) self.links[name]=target;return true end
  function tool:Delete() self.deleted=true;return nil end -- documented Delete may be void
  self.tools[#self.tools+1]=tool
  return tool
end
function comp:StartUndo(name) self.undo=self.undo+1 end
function comp:EndUndo(keep) self.undo=self.undo-1;self.last_keep=keep end

local background=assert(fusion.add_tool(comp,"Background",0,0))
local media=assert(fusion.add_tool(comp,"MediaOut",1,0))
local tools=assert(fusion.tool_list(comp))
assert(#tools==2,"GetToolList binding metadata must not become a Tool")

local attrs=assert(fusion.attrs(background,"Background"))
assert(attrs.TOOLS_RegID=="Background")

assert(fusion.set_attrs(background,{TOOLS_Name="BG"},"Background"))
assert(assert(fusion.attrs(background,"Background")).TOOLS_Name=="BG")
assert(fusion.set_data(background,"CartoRig.Test","value","test metadata"))
assert(fusion.get_data(background,"CartoRig.Test")=="value")
assert(fusion.set_input(background,"IdentityInfo","Country — Brazil","Identity"))
assert(fusion.get_input(background,"IdentityInfo")=="Country — Brazil")

assert(fusion.connect(media,"Input",background))
local input=assert(fusion.find_input(media,"Input"))
local connected=assert(fusion.connected_output(input))
assert(fusion.output_tool(connected)==background)
assert(fusion.connect(media,"Input",nil))
assert(fusion.connected_output(input)==nil)

local decoy=assert(fusion.add_tool(comp,"Background",2,0))
local originalConnect=media.ConnectInput
function media:ConnectInput(name,target)
  self.links[name]=target and decoy or nil
  return true
end
local wrong,wrongErr=fusion.connect(media,"Input",background)
assert(wrong==nil and wrongErr:find("FUSION_CONNECT_WRONG_SOURCE",1,true))
media.ConnectInput=originalConnect
assert(fusion.connect(media,"Input",nil))

assert(fusion.start_undo(comp,"test"))
assert(comp.undo==1)
assert(fusion.end_undo(comp,false))
assert(comp.undo==0 and comp.last_keep==false)

assert(fusion.delete_tool(background))
assert(background.deleted==true)

-- Resolve may accept the explicit default-settings AddTool overload only.
local explicit={tools={},calls=0}
function explicit:GetToolList()
  local out={__flags=1}
  for i,t in ipairs(self.tools) do out["Tool"..i]=t end
  return out
end
function explicit:AddTool(id,defaultSettings,x,y)
  self.calls=self.calls+1
  if type(defaultSettings)~="boolean" or defaultSettings~=false or
     type(x)~="number" or type(y)~="number" then return nil end
  local node={GetAttrs=function() return {TOOLS_RegID=id} end}
  self.tools[#self.tools+1]=node
  return node
end
local typed=assert(fusion.add_tool(explicit,"Fuse.CartoRigWorldMap",-6,2))
assert(typed==explicit.tools[1] and explicit.calls==2 and #explicit.tools==1,
  "must safely retry explicit AddTool defaults exactly once")

-- A nil proxy return may still have created one tool. Adopt and track it;
-- never retry and create a second node for that side effect.
local silent={tools={},calls=0,GetToolList=explicit.GetToolList}
function silent:AddTool(id,x,y)
  self.calls=self.calls+1
  self.tools[#self.tools+1]={GetAttrs=function() return {TOOLS_RegID=id} end}
  return nil
end
local adopted=assert(fusion.add_tool(silent,"Fuse.CartoRigWorldMap",0,0))
assert(adopted==silent.tools[1] and #silent.tools==1 and silent.calls==1)

local refused={tools={},calls=0,GetToolList=explicit.GetToolList}
function refused:AddTool(id,...)
  self.calls=self.calls+1
  return nil
end
local rejected,rejectErr=fusion.add_tool(refused,"Fuse.CartoRigWorldMap",0,0)
assert(rejected==nil and rejectErr:find("FUSION_ADD_TOOL_FAILED",1,true)
  and rejectErr:find("AddTool(id,false,x,y)",1,true)
  and refused.calls==2 and #refused.tools==0)

-- A misleading nil response that created multiple nodes cannot be retried.
local ambiguous={tools={},calls=0,GetToolList=explicit.GetToolList}
function ambiguous:AddTool(id,x,y)
  self.calls=self.calls+1
  for _=1,2 do
    self.tools[#self.tools+1]={GetAttrs=function() return {TOOLS_RegID=id} end}
  end
  return nil
end
local bad,badErr=fusion.add_tool(ambiguous,"Fuse.CartoRigWorldMap",0,0)
assert(bad==nil and badErr:find("FUSION_ADD_TOOL_AMBIGUOUS_SIDE_EFFECTS",1,true)
  and ambiguous.calls==1 and #ambiguous.tools==2)

local throwing=setmetatable({},{
  __index=function() error("proxy lookup exploded") end
})
local list,listErr=fusion.tool_list(throwing)
assert(list==nil and type(listErr)=="string" and listErr:find("API_LOOKUP_FAILED",1,true))

print("fusion_contract: PASS (documented tool table, connect/delete/undo + proxy safety)")

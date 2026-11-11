local fusion=require("CartoRig.fusion_contract")

local comp={tools={},undo=0}
function comp:GetToolList()
  return {Background1=self.tools[1],MediaOut1=self.tools[2],__flags=1048576}
end
function comp:AddTool(regid,x,y)
  assert(type(regid)=="string" and type(x)=="number" and type(y)=="number")
  local tool={regid=regid,name=regid,data={},links={}}
  function tool:GetAttrs() return {TOOLS_RegID=self.regid,TOOLS_Name=self.name,__flags=1} end
  function tool:SetAttrs(values) if values.TOOLS_Name then self.name=values.TOOLS_Name end end
  function tool:GetData(key) return self.data[key] end
  function tool:SetData(key,value) self.data[key]=value end
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

local throwing=setmetatable({},{
  __index=function() error("proxy lookup exploded") end
})
local list,listErr=fusion.tool_list(throwing)
assert(list==nil and type(listErr)=="string" and listErr:find("API_LOOKUP_FAILED",1,true))

print("fusion_contract: PASS (documented tool table, connect/delete/undo + proxy safety)")

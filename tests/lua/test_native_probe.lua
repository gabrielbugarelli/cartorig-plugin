-- Explicit mock/unit test. NOT proof of host behaviour or CartoRig A/B.
local m=require("CartoRig.native_probe")
local function fake(with_external)
 local c={items={},meta={},adds=0,links=0,deletes=0,undo=0}
 function c:GetToolList() return self.items end
 function c:GetData(key) return self.meta[key] end
 function c:SetData(key,val) self.meta[key]=val end
 function c:StartUndo() self.undo=self.undo+1 end
 function c:EndUndo() self.undo=self.undo-1 end
 function c:AddTool(regid)
  self.adds=self.adds+1
  local t={id=regid,meta={}}
  function t:GetAttrs() return {TOOLS_RegID=self.id} end
  function t:GetData(key) return self.meta[key] end
  function t:SetData(key,val) self.meta[key]=val end
  function t:SetAttrs() return true end
  function t:SetInput() return true end
  function t:ConnectInput() c.links=c.links+1;return true end
  function t:Delete()
   for i,v in ipairs(c.items) do if v==self then table.remove(c.items,i);break end end
   c.deletes=c.deletes+1
  end
  c.items[#c.items+1]=t
  return t
 end
 if with_external then c:AddTool("Transform");c.adds=0 end
 return c
end
local e=fake(true)
local external=e.items[1]
local beforeMeta=external.meta
assert(m.preflight(e).external_nodes_preserved==1)
local existing=assert(m.create(e,true))
assert(existing.existing_nodes_preserved==1 and e.adds==5)
assert(e.items[1]==external and external.meta==beforeMeta and external.id=="Transform")
assert(m.verify(e).nodes_with_native_metadata==5)
local collision=fake()
local other=collision:AddTool("Background")
other:GetAttrs=function(self) return {TOOLS_RegID=self.id,TOOLS_Name="CRTEST_Source"} end
collision.adds=0
assert(m.preflight(collision)==nil)
assert(m.create(collision,true)==nil and collision.adds==0)
local c=fake()
assert(m.create(c,false)==nil and c.adds==0)
local r=assert(m.create(c,true))
assert(r.test_nodes_created==5 and c.adds==5 and c.links==4 and c.undo==0)
assert(m.create(c,true)==nil)
assert(m.verify(c).nodes_with_native_metadata==5)
local reopened=fake()
reopened.items=c.items;reopened.meta=c.meta
assert(m.verify(reopened).nodes_with_native_metadata==5)
c.items[1]:SetData("CartoRig.MilestoneA.NativeProbe.Kind","Output")
assert(m.verify(c)==nil)
local z=fake()
assert(m.verify(z)==nil)
local broken=fake()
local add=broken.AddTool
function broken:AddTool(...) if self.adds==2 then error("native failure injected") end return add(self,...) end
local result,msg=m.create(broken,true)
assert(result==nil and msg:match("FAILED"))
assert(#broken.items==0 and broken.deletes==2 and broken.undo==0)
print("graph_test: PASS (isolated logic tests; Fusion host NOT RUN)")

-- Milestone A native Fusion API experiment. NOT a CartoRig product node.
-- The only mutation path requires explicit consent and a disposable comp.
local M={}
local NS="CartoRig.MilestoneA.NativeProbe"
local ID=NS..".Id"
local KIND=NS..".Kind"
local COMP=NS..".CompositionProbeId"
local SPEC={
 {kind="Source",regid="Background",name="CRTEST_Source",x=-6,y=2},
 {kind="Backdrop",regid="Background",name="CRTEST_Backdrop",x=-6,y=4},
 {kind="Transform",regid="Transform",name="CRTEST_Transform",x=-4,y=2},
 {kind="Composite",regid="Merge",name="CRTEST_Composite",x=-2,y=2},
 {kind="Output",regid="MediaOut",name="CRTEST_Output",x=0,y=2},
}
local function tools(comp)
 if not comp or type(comp.GetToolList)~="function" then
  return nil,"BLOCKED: no active Fusion composition or graph access"
 end
 local ok, result=pcall(function() return comp:GetToolList(false) end)
 if not ok or type(result)~="table" then
  return nil,"BLOCKED: cannot inspect native tool graph"
 end
 return result
end
local function attr(tool,key)
 local ok,result=pcall(function() return tool:GetAttrs() end)
 return ok and type(result)=="table" and result[key] or nil
end
local function data(tool,key)
 local ok,result=pcall(function() return tool:GetData(key) end)
 if ok then return result end
 return nil
end
function M.preflight(comp)
 local list,err=tools(comp)
 if not list then return nil,err end
 for _,method in ipairs({"AddTool","StartUndo","EndUndo","SetData","GetData"}) do
  if type(comp[method])~="function" then
   return nil,"BLOCKED: missing native method "..method
  end
 end
 local ok,existing=pcall(function() return comp:GetData(COMP) end)
 if not ok then return nil,"BLOCKED: composition metadata cannot be read" end
 if existing~=nil then return nil,"BLOCKED: this comp already has a native probe" end
 for _,tool in pairs(list) do
  if data(tool,ID)~=nil then return nil,"BLOCKED: previous probe found" end
  if attr(tool,"TOOLS_RegID")~="MediaOut" then
   return nil,"BLOCKED: use NEW disposable Fusion Composition without editorial nodes"
  end
 end
 return true
end
function M.create(comp,confirmed)
 if confirmed~=true then return nil,"BLOCKED: disposable composition confirmation required" end
 local valid,err=M.preflight(comp)
 if not valid then return nil,err end
 local created,nodes={},{}
 local id="probe-"..os.date("!%Y%m%dT%H%M%SZ").."-"..tostring(math.random(100000,999999))
 local begun,msg=pcall(function() comp:StartUndo("CartoRig - native integration diagnostic") end)
 if not begun then return nil,"BLOCKED: StartUndo: "..tostring(msg) end
 local ok,why=pcall(function()
  for _,s in ipairs(SPEC) do
   local tool=comp:AddTool(s.regid,false,s.x,s.y)
   if not tool then error("AddTool failed: "..s.regid) end
   created[#created+1]=tool
   nodes[s.kind]=tool
   if tool:SetAttrs({TOOLS_Name=s.name})==false then error("Rename failed: "..s.kind) end
   if attr(tool,"TOOLS_RegID")~=s.regid then error("Unexpected physical node: "..s.kind) end
   tool:SetData(ID,id)
   tool:SetData(KIND,s.kind)
   if data(tool,ID)~=id or data(tool,KIND)~=s.kind then
    error("Native node metadata not persistent in memory: "..s.kind)
   end
  end
  if nodes.Source:SetInput("TopLeftRed",0.8)==false or
     nodes.Source:SetInput("TopLeftAlpha",0.8)==false then
   error("Background native controls unavailable")
  end
  local connections={
   {nodes.Transform,"Input",nodes.Source},
   {nodes.Composite,"Background",nodes.Backdrop},
   {nodes.Composite,"Foreground",nodes.Transform},
   {nodes.Output,"Input",nodes.Composite},
  }
  for _,c in ipairs(connections) do
   if c[1]:ConnectInput(c[2],c[3])~=true then
    error("Native ConnectInput failed: "..c[2])
   end
  end
  comp:SetData(COMP,id)
  if comp:GetData(COMP)~=id then error("Comp:SetData/GetData round-trip failed") end
 end)
 if not ok then
  local problems={}
  for i=#created,1,-1 do
   local deleted,de=pcall(function() created[i]:Delete() end)
   if not deleted then problems[#problems+1]=tostring(de) end
  end
  pcall(function() comp:SetData(COMP,nil) end)
  pcall(function() comp:EndUndo(true) end)
  return nil,"FAILED: "..tostring(why)..
   (#problems>0 and "; cleanup incomplete: "..table.concat(problems,", ") or "; new nodes cleaned")
 end
 local ended,e=pcall(function() comp:EndUndo(true) end)
 if not ended then
  return nil,"BLOCKED: EndUndo error: "..tostring(e).."; discard disposable comp"
 end
 return {native_nodes_created=5,native_links_created=4,probe_id=id,
  node_metadata_roundtrip=true,save_reopen="NOT RUN",viewer="NOT RUN",motion="NOT RUN",
  instructions="Save, close and reopen disposable project, then Verify."}
end
function M.verify(comp)
 local list,err=tools(comp)
 if not list then return nil,err end
 if type(comp.GetData)~="function" then return nil,"BLOCKED: no GetData" end
 local ok,id=pcall(function() return comp:GetData(COMP) end)
 if not ok or type(id)~="string" then return nil,"BLOCKED: no persisted probe ID found" end
 local kinds,number={},0
 for _,tool in pairs(list) do
  if data(tool,ID)==id then
   local kind=data(tool,KIND)
   local expected
   for _,s in ipairs(SPEC) do if s.kind==kind then expected=s.regid end end
   if not expected or kinds[kind] or attr(tool,"TOOLS_RegID")~=expected then
    return nil,"FAILED: unexpected/duplicate node identity for "..tostring(kind)
   end
   kinds[kind]=true;number=number+1
  end
 end
 if number~=#SPEC then
  return nil,"FAILED: expected "..#SPEC.." native nodes but found "..number
 end
 return {nodes_with_native_metadata=number,probe_id=id,
  save_reopen="VERIFY MANUALLY that project was actually saved/closed/reopened",
  viewer="NOT RUN",motion="NOT RUN",
  instructions="Compare physical connections in Node Editor and inspect Viewer."}
end
return M

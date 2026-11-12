-- Isolated Fuse API model (not Resolve Viewer acceptance).
-- Render worker must read only its own linked inputs, never enumerate the graph.
local oldenv=os.getenv
local root="tests/fixtures/region-fuse-local"
local rel="regions/sample.lua"
local path=root.."\\CartoRig\\App\\data\\regions\\sample.lua"
local stream=assert(io.open(path,"wb"))
stream:write('return {source_id="country-test",version="test-v1",scale="1:50m",bbox={-55,-18,-54,-17},rings={{-55,-18,-54,-18,-54,-17,-55,-17}},ring_roles={"outer"},topology_schema=2}\n')
stream:close()
os.getenv=function(key) if key=="LOCALAPPDATA" then return root end return oldenv(key) end
CT_Tool=1
FuRegisterClass=function(id,kind) assert(id=="CartoRigRegion" and kind==CT_Tool) end
local inputs={}
local original={Width=1920,Height=1080}
function original:CopyOf() return {Width=self.Width,Height=self.Height,paints={}} end
self={metadata={
 ["CartoRig.V1.GeometryFile"]=rel,
 ["CartoRig.V1.SourceId"]="country-test",
 ["CartoRig.V1.SourceVersion"]="test-v1",
 ["CartoRig.V1.SourceScale"]="1:50m",
},Comp=setmetatable({}, {__index=function() error("Graph accessed during Process") end})}
function self:AddControlPage(name) assert(name=="Control" or name=="Motion") end
function self:GetData(name) return self.metadata[name] end
function self:AddInput(title,id,attrs)
 local input={id=id,value=attrs.INP_Default or 0}
 function input:GetValue() if id=="Background" then return original end return {Value=self.value} end
 function input:SetSource(value) self.value=value end
 inputs[id]=input
 return input
end
function self:AddOutput(title,id)
 local output={}
 function output:Set(_,image) self.latest=image end
 return output
end
local shape={}
function shape:MoveTo() end
function shape:LineTo() end
function shape:Close() end
function shape:OutlineOfShape() return shape end
Shape=function() return shape end
ImageChannel=function(image,quality)
 assert(quality==8)
 local channel={}
 function channel:SetStyleFill() end
 function channel:ShapeFill() end
 function channel:PutToImage(mode,style)
  assert(mode=="CM_Merge")
  image.paints[#image.paints+1]=style.Color
 end
 return channel
end
ChannelStyle=function() return {} end
FillStyle=function() return {} end
Pixel=function(obj) return obj end
Number=function(x) return x end
assert(loadfile("fuses/CartoRigRegion.fuse"))()
Create()
local req={Time=0}
for i,c in ipairs({"R","G","B"}) do
 inputs["WorldLand"..c].value=({0.2,0.3,0.4})[i]
 inputs["WorldBorder"..c].value=({0.7,0.8,0.9})[i]
end
Process(req)
local p=OutImage.latest.paints
assert(#p==2 and p[1].R==0.2 and p[2].R==0.7)
inputs.WorldLandR.value=0.6
Process(req)
assert(OutImage.latest.paints[1].R==0.6)
inputs.FillR.value=0.1
NotifyChanged(inputs.FillR,nil,0)
assert(inputs.InheritWorldMapFill.value==0)
Process(req)
assert(OutImage.latest.paints[1].R==0.1)
assert(OutImage.latest.paints[2].R==0.7)
inputs.Visibility.value=0
Process(req)
assert(OutImage.latest==original,"hidden Region must preserve input image")
inputs.Visibility.value=1
inputs.InheritWorldMapFill.value=1
inputs.WorldLandR.value=5
local ok,err=pcall(Process,req)
assert(not ok and tostring(err):find("REGION_INHERIT_FAILED",1,true))
os.remove(path)
os.getenv=oldenv
print("PASS Region Fuse mock render live palette/overrides/visibility/rejection")

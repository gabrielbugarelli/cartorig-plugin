-- Independent native Fuse execution test; this is NOT Resolve host acceptance.
local original={FuRegisterClass=_G.FuRegisterClass,CT_Tool=_G.CT_Tool,
  self=_G.self,Number=_G.Number}
CT_Tool=1
FuRegisterClass=function(name,kind,registration)
  assert(name=="CartoRigCamera" and kind==CT_Tool)
end
local inputs={}
local image={Width=1920,Height=1080}
function image:Transform(_,options)
  assert(options.XF_XSize>0 and options.XF_XSize<=64)
  return {pose=options}
end
self={}
function self:AddControlPage(page) assert(page=="Control" or page=="Motion") end
function self:AddInput(title,id,attrs)
  local input={value=attrs.INP_Default or 0}
  function input:GetValue(req)
    assert(type(req)=="table" and req.Time~=nil,
      "Fuse GetValue must receive a render Request, never a numeric event frame")
    if id=="Input" then return image end
    return {Value=self.value}
  end
  function input:GetSource(frame)
    assert(type(frame)=="number",
      "Fuse GetSource must receive the numeric NotifyChanged frame")
    return {Value=self.value}
  end
  function input:SetSource(v,time)
    assert(type(v)=="number")
    self.value=v
  end
  inputs[id]=input
  return input
end
function self:AddOutput(title,id)
  local o={}
  function o:Set(req,img) self.latest=img end
  return o
end
Number=function(v) return v end
assert(loadfile("fuses/CartoRigCamera.fuse"))()
Create()
local function value(id) return inputs[id].value end
local function click(id)
  NotifyChanged(inputs[id],nil,0)
end
click("ResetPose")
assert(value("CenterLatitude")==0 and value("CenterLongitude")==0 and
       value("Zoom")==1 and value("Bearing")==0)
inputs.TargetLatitude.value=-15.6
inputs.TargetLongitude.value=-56.1
click("FocusTarget")
assert(value("CenterLatitude")==-15.6 and value("CenterLongitude")==-56.1)
assert(value("Zoom")==1 and value("Bearing")==0,
       "Focus Target must not touch Zoom/Bearing")
inputs.LocationWest.value=-75
inputs.LocationSouth.value=-35
inputs.LocationEast.value=-30
inputs.LocationNorth.value=6
click("FitToLocation")
assert(value("CenterLatitude")==-14.5 and value("CenterLongitude")==-52.5)
assert(value("Zoom")>1 and value("Zoom")<=64)
inputs.LocationEast.value=-80
local priorLat,priorLon,priorZoom=value("CenterLatitude"),value("CenterLongitude"),value("Zoom")
local ok,err=pcall(click,"FitToLocation")
assert(not ok and err:find("CAMERA_FIT_INVALID",1,true))
assert(value("CenterLatitude")==priorLat and value("CenterLongitude")==priorLon and
       value("Zoom")==priorZoom,"invalid target must not mutate camera")
ok,err=pcall(click,"FitToObjects")
assert(not ok and err:find("CAMERA_FIT_UNAVAILABLE",1,true))
inputs.ObjectsPresent.value=1
inputs.ObjectsWest.value=-74
inputs.ObjectsSouth.value=-55
inputs.ObjectsEast.value=-34
inputs.ObjectsNorth.value=5
click("FitToObjects")
assert(value("CenterLatitude")==-25 and value("CenterLongitude")==-54)
assert(value("Zoom")>1)
local req={Time=0}
Process(req)
assert(OutImage.latest and OutImage.latest.pose and
       OutImage.latest.pose.XF_XSize==value("Zoom"),
       "Camera pose must drive native image Transform")
for k,v in pairs(original) do _G[k]=v end
print("PASS Camera native Focus Target/Fit Location/Fit Objects/Reset/render")

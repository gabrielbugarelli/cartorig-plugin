-- Full Scene UI controller regression with an injected numeric global resolve.
-- The UI callback must use the object returned from bmd.scriptapp("Resolve").
-- All Resolve calls below are mocks; this is not a Studio host test.
local prior={
  resolve=rawget(_G,"resolve"),bmd=rawget(_G,"bmd"),
  fusion=rawget(_G,"fusion"),fu=rawget(_G,"fu"),
  getenv=os.getenv,packagepath=package.path,
  service=package.loaded["CartoRig.timeline_service"]
}
local realResolve={GetProjectManager=function() return {} end}
local calls,created,buttons,history=0,{}, {},{}
local ui={}
local function make_component(_,properties) return properties end
for _,name in ipairs({"VGroup","HGroup","Label","LineEdit","TextEdit","Button"}) do
  ui[name]=function(self,properties)
    assert(type(properties)=="table")
    if name=="Button" then buttons[#buttons+1]=properties.Text end
    return properties
  end
end
local items={
  SceneTitle={Text="Map Scene"},
  SceneList={PlainText=""},
  Status={Text=""}
}
local service={}
function service.create(received,title)
  assert(received==realResolve,"Scene callback passed numeric or wrong Resolve object")
  assert(title=="Map Scene")
  local count=#created+1
  local result={
    scene_id="test-scene-"..count,
    start_frame=count*120,
    end_frame=count*120+119,
    fusion_page_opened=true,
    objects={{name="WorldMap"},{name="Camera"},{name="Scene"}}
  }
  created[#created+1]=result
  return result
end
function service.list_scenes(received)
  assert(received==realResolve)
  local scenes={}
  for n,scene in ipairs(created) do
    scenes[#scenes+1]={
      scene_id=scene.scene_id,track=1,start_frame=scene.start_frame,
      name="Scene "..n,objects=scene.objects
    }
  end
  history[#history+1]=#scenes
  return scenes
end
package.loaded["CartoRig.timeline_service"]=service
local dispatcher={window=nil}
function dispatcher:AddWindow(options,layout)
  assert(options.ID=="CartoRigDevSceneWindow")
  assert(layout~=nil)
  local window={On={
    CreateScene={}, SaveReport={},Close={},CartoRigDevSceneWindow={}
  }}
  function window:GetItems() return items end
  function window:Show() self.visible=true end
  function window:Hide() self.visible=false end
  self.window=window
  return window
end
function dispatcher:RunLoop()
  assert(self.window and self.window.visible)
  assert(type(self.window.On.CreateScene.Clicked)=="function")
  for n=1,5 do self.window.On.CreateScene.Clicked({}) end
end
function dispatcher:ExitLoop() end
local bmd={
  scriptapp=function(application)
    assert(application=="Resolve")
    calls=calls+1
    return realResolve
  end,
  UIDispatcher=function(manager)
    assert(manager==ui)
    return dispatcher
  end
}
_G.resolve=0
_G.bmd=bmd
_G.fusion={UIManager=ui}
_G.fu=nil
os.getenv=function(key)
  if key=="LOCALAPPDATA" then return "C:\\Users\\Test\\AppData\\Local" end
  return prior.getenv(key)
end
local ok,status,reason=pcall(assert(loadfile("host/cartorig-dev-scene.lua")))
assert(ok,"Scene UI must not crash when raw Resolve global is numeric: "..tostring(status))
assert(status==true,"Scene UI should finish normally: "..tostring(reason))
assert(calls==1,"Scene UI failed to recover the Resolve object exactly once")
assert(#created==5,"Five Create Scene clicks should invoke the timeline service five times")
assert(#history==6 and history[1]==0 and history[6]==5,
  "Scene list must refresh after each Create Scene")
assert(items.SceneList.PlainText:find("test%-scene%-5"),
  "Last created Scene missing in automatic structural list")
assert(items.Status.Text:find("Scene created",1,true))
assert(dispatcher.window.visible==false)
assert(#buttons==3,"Only Create Scene, Save Report, Close should exist")
for _,button in ipairs(buttons) do assert(button~="Open Scene") end
_G.resolve=prior.resolve
_G.bmd=prior.bmd
_G.fusion=prior.fusion
_G.fu=prior.fu
os.getenv=prior.getenv
package.path=prior.packagepath
package.loaded["CartoRig.timeline_service"]=prior.service
print("scene_ui_dispatch: PASS (numeric global fallback + five Scene clicks + auto list; host NOT RUN)")

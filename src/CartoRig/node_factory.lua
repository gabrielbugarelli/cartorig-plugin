-- CartoRig V1 | SceneService/NodeFactory structural milestone A implementation.
-- Real Fusion tools, no virtual author nodes. NEVER select tools in Node Editor.
-- Status: host rendering and save/reopen still require Studio 20 acceptance.
local domain = require("CartoRig.domain")
local factory = {}
local P = "CartoRig.V1."
local SCENE_KEY=P.."SceneId"
local OBJECT=P.."ObjectId"
local OWNER=P.."Owned"
local VERSION=P.."SchemaVersion"
local TYPE=P.."ObjectType"
local SOURCE=P.."DatasetSource"
local TITLE=P.."Title"
local DISPLAY=P.."DisplayName"
local FUSES={
  WorldMap="Fuse.CartoRigWorldMap",
  Camera="Fuse.CartoRigCamera",
  Scene="Fuse.CartoRigScene"
}
local FUSE_ORDER={"WorldMap","Camera","Scene"}
local NAMES={WorldMap="CR_WorldMap_Main",Camera="CR_Camera_Main",Scene="CR_Scene_Main"}

local function get(tool,field)
  local ok,val=pcall(function() return tool:GetData(field) end)
  if ok then return val end
end
local function attrs(tool)
  local ok,val=pcall(function() return tool:GetAttrs() end)
  if ok and type(val)=="table" then return val end
  return {}
end
local function inventory(comp)
  if not comp or type(comp.GetToolList)~="function" then
    return nil,"NO_COMPOSITION: open a Fusion Composition"
  end
  local ok,list=pcall(function() return comp:GetToolList(false) end)
  if not ok or type(list)~="table" then
    return nil,"FUSION_API_ERROR: cannot read the tool graph"
  end
  return list
end
local function library_ready(root)
  local drive=root or os.getenv("LOCALAPPDATA")
  if type(drive)~="string" or drive=="" then
    return nil,"DATA_MISSING: local data directory unavailable"
  end
  local dataset=drive.."\\CartoRig\\App\\data\\ne_50m_land.lua"
  local file=io.open(dataset,"rb")
  if not file then return nil,"DATA_MISSING: required Natural Earth 1:50m Land not installed" end
  local length=file:seek("end")
  file:close()
  if not length or length<500000 then return nil,"DATA_INCOMPATIBLE: land resource incomplete" end
  return dataset
end

function factory.inspect(comp)
  local list,err=inventory(comp)
  if not list then return nil,err end
  local objects,owned={},0
  local sid,ids,names=nil,{},{}
  for _,tool in pairs(list) do
    if get(tool,OWNER)==true then
      owned=owned+1
      local kind=get(tool,TYPE)
      if not kind then return nil,"STATE_INVALID: owned node has no type" end
      local obj={type=kind,name=attrs(tool).TOOLS_Name or "",id=get(tool,OBJECT),
        scene_id=get(tool,SCENE_KEY),display_name=get(tool,DISPLAY)}
      if not domain.is_uuid(obj.id) or not domain.is_uuid(obj.scene_id) then
        return nil,"STATE_INVALID: invalid node identity"
      end
      if ids[obj.id] then return nil,"STATE_INVALID: duplicated object UUID "..obj.id end
      if obj.name=="" or names[obj.name] then
        return nil,"STATE_INVALID: missing or duplicated CartoRig node name "..tostring(obj.name)
      end
      ids[obj.id]=true
      names[obj.name]=true
      if sid and obj.scene_id~=sid then
        return nil,"STATE_INVALID: multiple scenes in one composition"
      end
      sid=obj.scene_id
      objects[#objects+1]=obj
    end
  end
  local compid=get(comp,SCENE_KEY)
  if compid~=nil and sid~=compid then
    return nil,"STATE_INVALID: composition and nodes disagree on Scene ID"
  end
  if owned>0 and not compid then
    return nil,"STATE_INVALID: orphaned CartoRig nodes; no implicit repair"
  end
  if compid then
    -- Scene/WorldMap/Camera are the only singleton structural types. Additional
    -- CartoRig authoring nodes (Country, State, Route, Marker, Label, etc.) are
    -- expected and must not invalidate a healthy composition.
    local structural={Scene=0,WorldMap=0,Camera=0}
    for _,o in ipairs(objects) do
      if structural[o.type]~=nil then
        structural[o.type]=structural[o.type]+1
        if structural[o.type]>1 then
          return nil,"STATE_INVALID: duplicated structural type "..tostring(o.type)
        end
      end
    end
    if structural.Scene~=1 or structural.WorldMap~=1 or structural.Camera~=1 then
      return nil,"STATE_INVALID: structural nodes missing or duplicated"
    end
  end
  local title=get(comp,TITLE)
  if title~=nil and (type(title)~="string" or title:match("^%s*$")) then
    return nil,"STATE_INVALID: persisted Scene title is malformed"
  end
  -- 0.6.0-0.6.2 development Scenes did not persist the title on the comp.
  -- They remain readable; every new 0.6.3 Scene is required to persist it.
  local legacyTitleMissing=compid~=nil and title==nil
  table.sort(objects,function(a,b) return a.name<b.name end)
  return {scene_id=compid,title=title,legacy_title_missing=legacyTitleMissing,
    objects=objects,has_scene=compid~=nil,existing_tools=list}
end

-- A TimelineItem Fusion Composition usually already contains MediaOut1.
-- Never create an extra output simply because input discovery failed.
local function input_of(tool,name)
  if type(tool.FindInput)=="function" then
    local ok,value=pcall(function() return tool:FindInput(name) end)
    if ok and value then return value end
  end
  local ok,value=pcall(function() return tool[name] end)
  if ok and value then return value end
end
local function mediaout_candidate(list)
  local found,number=nil,0
  for _,tool in pairs(list) do
    if attrs(tool).TOOLS_RegID=="MediaOut" then
      number=number+1;found=tool
    end
  end
  if number>1 then return nil,"MEDIAOUT_AMBIGUOUS: newly created comp has more than one MediaOut" end
  if number==0 then return nil,nil end
  local input=input_of(found,"Input")
  if not input or type(input.GetConnectedOutput)~="function" then
    return nil,"MEDIAOUT_UNINSPECTABLE: refuse to duplicate the existing MediaOut"
  end
  local ok,value=pcall(function() return input:GetConnectedOutput() end)
  if not ok then return nil,"MEDIAOUT_UNINSPECTABLE: cannot read current MediaOut input" end
  if value~=nil then
    return nil,"MEDIAOUT_ALREADY_CONNECTED: refuse to modify an occupied output"
  end
  return found,nil
end

local function create_node(comp,kind,info,x,y,created)
  local tool=comp:AddTool(FUSES[kind],x,y)
  if not tool then error("NODE_CREATE_FAILED: Fuse '"..FUSES[kind].."' is not registered in Fusion") end
  created[#created+1]=tool
  local observed=attrs(tool).TOOLS_RegID
  -- Scripting API registers Fuse tools under the "Fuse." RegID prefix.
  -- Accept the unprefixed class name only as a host-exposed equivalent.
  if observed~=FUSES[kind] and observed~=FUSES[kind]:sub(6) then
    error("NODE_TYPE_MISMATCH: expected "..FUSES[kind].." got "..tostring(observed))
  end
  tool:SetAttrs({TOOLS_Name=NAMES[kind]})
  if attrs(tool).TOOLS_Name~=NAMES[kind] then
    error("NODE_RENAME_FAILED: "..NAMES[kind])
  end
  for key,value in pairs({
    [OWNER]=true,
    [OBJECT]=info.object_id,
    [TYPE]=kind,
    [SCENE_KEY]=info.scene_id,
    [VERSION]="1.0.0",
    [DISPLAY]=info.display_name
  }) do
    tool:SetData(key,value)
    if get(tool,key)~=value then error("NODE_METADATA_FAILED: "..kind.." / "..key) end
  end
  return tool
end

local function connect(target,port,source)
  if type(target.ConnectInput)~="function" then
    error("FUSION_API_ERROR: ConnectInput missing")
  end
  local success=target:ConnectInput(port,source)
  if success==false then
    error("FUSION_CONNECT_FAILED: "..tostring(port))
  end
  -- nil return may be successful in some host builds. Verify via actual input graph.
  if type(target.FindInput)~="function" then
    if success~=true then error("FUSION_CONNECT_UNVERIFIED: "..port) end
    return
  end
  local input=target:FindInput(port)
  if not input or type(input.GetConnectedOutput)~="function" then
    if success~=true then error("FUSION_CONNECT_UNVERIFIED: "..port) end
    return
  end
  local output=input:GetConnectedOutput()
  if not output then error("FUSION_CONNECT_FAILED: no source on "..port) end
end

function factory.create_scene(comp,title,opts)
  opts=opts or {}
  local ok,existing=factory.inspect(comp)
  if not ok then return nil,existing end
  if ok.has_scene then
    return nil,"SCENE_EXISTS: this Fusion Composition already contains a CartoRig Scene; Create Scene must target a new timeline item"
  end
  local dataset,derr=library_ready(opts.localappdata)
  if not dataset then return nil,derr end
  local state,err=domain.new_scene(title or "Map Scene")
  if not state then return nil,err end
  local existing_media,media_error=mediaout_candidate(ok.existing_tools)
  if media_error then return nil,media_error end
  if not existing_media and opts.disallow_new_mediaout then
    return nil,"MEDIAOUT_UNAVAILABLE: fresh comp has no MediaOut"
  end
  if type(comp.StartUndo)~="function" or type(comp.EndUndo)~="function" then
    return nil,"FUSION_API_ERROR: Undo transactions unavailable"
  end
  local started,beginerr=pcall(function() comp:StartUndo("CartoRig - Create Scene") end)
  if not started then return nil,"FUSION_API_ERROR: StartUndo: "..tostring(beginerr) end
  local created,nodes,modified_external={},{}
  local succeeded,why=pcall(function()
    local bykind={}
    for _,obj in ipairs(state.objects) do bykind[obj.object_type]=obj end
    for index,kind in ipairs(FUSE_ORDER) do
      nodes[kind]=create_node(comp,kind,bykind[kind],-8+index*2,2,created)
    end
    connect(nodes.Camera,"Input",nodes.WorldMap)
    connect(nodes.Scene,"Input",nodes.Camera)
    local output=existing_media
    if not output then
      output=comp:AddTool("MediaOut",0,2)
      if not output then error("MEDIAOUT_CREATE_FAILED: Resolve did not create MediaOut") end
      created[#created+1]=output
      if attrs(output).TOOLS_RegID~="MediaOut" then
        error("MEDIAOUT_CREATE_FAILED: unexpected tool returned by Fusion")
      end
      output:SetAttrs({TOOLS_Name="CR_Output_Main"})
      output:SetData(P.."OwnedHelper",true)
      output:SetData(SCENE_KEY,state.scene_id)
    end
    -- Mark the previously empty external output before trying the write;
    -- if ConnectInput partially mutates it and then fails, rollback disconnects it.
    if existing_media then modified_external=existing_media end
    connect(output,"Input",nodes.Scene)
    local port=input_of(output,"Input")
    if not port or type(port.GetConnectedOutput)~="function" then
      error("MEDIAOUT_LINK_UNVERIFIED: cannot inspect physical output link")
    end
    local src=port:GetConnectedOutput()
    if not src then
      error("MEDIAOUT_LINK_FAILED: MediaOut is not connected to Scene")
    end
    comp:SetData(SCENE_KEY,state.scene_id)
    comp:SetData(VERSION,state.schema_version)
    comp:SetData(SOURCE,"Natural Earth 1:50m land")
    comp:SetData(TITLE,state.title)
    if get(comp,SCENE_KEY)~=state.scene_id or get(comp,TITLE)~=state.title then
      error("SCENE_STATE_FAILED: composition did not persist scene identity/title")
    end
    local observed,observedErr=factory.inspect(comp)
    if not observed or not observed.has_scene or observed.scene_id~=state.scene_id or observed.title~=state.title then
      error("SCENE_STATE_FAILED: post-create reconstruction failed: "..tostring(observedErr))
    end
  end)
  local function rollback_creation()
    local cleanup={}
    if modified_external then
      local disconnected,de=pcall(function() return modified_external:ConnectInput("Input",nil) end)
      if not disconnected then
        cleanup[#cleanup+1]="MediaOut disconnect exception: "..tostring(de)
      else
        local input=input_of(modified_external,"Input")
        if input and type(input.GetConnectedOutput)=="function" then
          local checked,value=pcall(function() return input:GetConnectedOutput() end)
          if not checked or value~=nil then cleanup[#cleanup+1]="MediaOut input still connected after rollback" end
        end
      end
    end
    for i=#created,1,-1 do
      local deleted,de=pcall(function() return created[i]:Delete() end)
      if not deleted then cleanup[#cleanup+1]="node delete exception: "..tostring(de) end
    end
    for _,key in ipairs({SCENE_KEY,VERSION,SOURCE,TITLE}) do
      local cleared,ce=pcall(function() comp:SetData(key,nil) end)
      if not cleared then cleanup[#cleanup+1]="composition metadata cleanup: "..tostring(ce) end
    end
    local ended,endErr=pcall(function() comp:EndUndo(false) end)
    if not ended then cleanup[#cleanup+1]="EndUndo(false): "..tostring(endErr) end
    local observed,inspectErr=factory.inspect(comp)
    if not observed or observed.has_scene then
      cleanup[#cleanup+1]="post-rollback graph invalid: "..tostring(inspectErr or "Scene still present")
    end
    return #cleanup==0,table.concat(cleanup,"; ")
  end
  if not succeeded then
    local clean,cleanupErr=rollback_creation()
    return nil,"SCENE_CREATE_FAILED: "..tostring(why)..
      (clean and "; transaction rolled back" or "; ROLLBACK_INCOMPLETE: "..cleanupErr)
  end
  local ended,e=pcall(function() comp:EndUndo(true) end)
  if not ended then
    local clean,cleanupErr=rollback_creation()
    return nil,"UNDO_ERROR: "..tostring(e)..
      (clean and "; transaction rolled back" or "; ROLLBACK_INCOMPLETE: "..cleanupErr)
  end
  return {scene_id=state.scene_id,title=state.title,objects=state.objects,source=dataset,
    output_connected=true,created_author_nodes=3,
    status="CREATED_NEEDS_FUSION_RENDER_AND_REOPEN_VALIDATION"}
end

return factory

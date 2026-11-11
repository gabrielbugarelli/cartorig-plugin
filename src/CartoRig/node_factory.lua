-- CartoRig V1 | structural Scene NodeFactory.
-- Real Fusion tools only; never selects tools in the Node Editor.
local domain=require("CartoRig.domain")
local fusion=require("CartoRig.fusion_contract")
local factory={}

local P="CartoRig.V1."
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

local function read_data(object,key,label)
  local value,err=fusion.get_data(object,key,label or key)
  if err then return nil,err end
  return value
end

local function inventory(comp)
  local list,err=fusion.tool_list(comp)
  if not list then return nil,"NO_COMPOSITION: "..tostring(err) end
  return list
end

local validated_datasets={}
local function library_ready(root)
  local drive=root or os.getenv("LOCALAPPDATA")
  if type(drive)~="string" or drive=="" then
    return nil,"DATA_MISSING: local data directory unavailable"
  end
  local dataset=drive.."\\CartoRig\\App\\data\\ne_50m_land.lua"
  if validated_datasets[dataset] then return dataset end
  local file=io.open(dataset,"rb")
  if not file then return nil,"DATA_MISSING: required Natural Earth 1:50m Land not installed" end
  file:close()
  local loaded,data=pcall(dofile,dataset)
  if not loaded or type(data)~="table" or #data~=1422 then
    return nil,"DATA_INCOMPATIBLE: expected Natural Earth 1:50m Land with exactly 1422 rings"
  end
  for ringIndex,ring in ipairs(data) do
    if type(ring)~="table" or #ring<8 or #ring%2~=0 then
      return nil,"DATA_INCOMPATIBLE: invalid land ring "..tostring(ringIndex)
    end
    for i=1,#ring,2 do
      local lon,lat=ring[i],ring[i+1]
      if type(lon)~="number" or type(lat)~="number" or lon~=lon or lat~=lat or
         lon<-180 or lon>180 or lat<-90 or lat>90 then
        return nil,"DATA_INCOMPATIBLE: invalid coordinate in land ring "..tostring(ringIndex)
      end
    end
  end
  validated_datasets[dataset]=true
  return dataset
end

function factory.inspect(comp)
  local list,err=inventory(comp)
  if not list then return nil,err end

  local objects,owned={},0
  local sid,ids,names=nil,{},{}
  for index,tool in ipairs(list) do
    local isOwned,ownedErr=read_data(tool,OWNER,"tool "..index.." Owned")
    if ownedErr then return nil,ownedErr end
    if isOwned==true then
      owned=owned+1
      local kind,kindErr=read_data(tool,TYPE,"tool "..index.." ObjectType")
      if kindErr then return nil,kindErr end
      if type(kind)~="string" or kind=="" then
        return nil,"STATE_INVALID: owned node has no type"
      end
      local attr,attrErr=fusion.attrs(tool,"owned tool "..index)
      if not attr then return nil,attrErr end
      local objectId,objectErr=read_data(tool,OBJECT,"tool "..index.." ObjectId")
      if objectErr then return nil,objectErr end
      local sceneId,sceneErr=read_data(tool,SCENE_KEY,"tool "..index.." SceneId")
      if sceneErr then return nil,sceneErr end
      local displayName,displayErr=read_data(tool,DISPLAY,"tool "..index.." DisplayName")
      if displayErr then return nil,displayErr end
      local obj={
        type=kind,name=attr.TOOLS_Name or "",id=objectId,
        scene_id=sceneId,display_name=displayName
      }
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

  local compid,compErr=read_data(comp,SCENE_KEY,"composition SceneId")
  if compErr then return nil,compErr end
  if compid~=nil and sid~=compid then
    return nil,"STATE_INVALID: composition and nodes disagree on Scene ID"
  end
  if owned>0 and not compid then
    return nil,"STATE_INVALID: orphaned CartoRig nodes; no implicit repair"
  end

  if compid then
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

  local title,titleErr=read_data(comp,TITLE,"composition Title")
  if titleErr then return nil,titleErr end
  if title~=nil and (type(title)~="string" or title:match("^%s*$")) then
    return nil,"STATE_INVALID: persisted Scene title is malformed"
  end
  local legacyTitleMissing=compid~=nil and title==nil
  table.sort(objects,function(a,b) return a.name<b.name end)
  return {
    scene_id=compid,title=title,legacy_title_missing=legacyTitleMissing,
    objects=objects,has_scene=compid~=nil,existing_tools=list
  }
end

local function input_of(tool,name)
  local input,err=fusion.find_input(tool,name)
  if err then return nil,err end
  return input
end

-- A Fusion Composition inserted by Resolve is expected to own its MediaOut.
-- TimelineService passes disallow_new_mediaout=true, so a missing output is a
-- hard failure rather than a reason to fabricate another output.
local function mediaout_candidate(list)
  local found,count=nil,0
  for index,tool in ipairs(list) do
    local attr,attrErr=fusion.attrs(tool,"tool "..index)
    if not attr then return nil,attrErr end
    if attr.TOOLS_RegID=="MediaOut" then
      count=count+1
      found=tool
    end
  end
  if count>1 then return nil,"MEDIAOUT_AMBIGUOUS: composition has more than one MediaOut" end
  if count==0 then return nil,nil end

  local input,inputErr=input_of(found,"Input")
  if not input then
    return nil,"MEDIAOUT_UNINSPECTABLE: "..tostring(inputErr or "Input unavailable")
  end
  local value,valueErr=fusion.connected_output(input,"MediaOut.Input")
  if valueErr then return nil,"MEDIAOUT_UNINSPECTABLE: "..tostring(valueErr) end
  if value~=nil then
    return nil,"MEDIAOUT_ALREADY_CONNECTED: refuse to modify an occupied output"
  end
  return found
end

local function create_node(comp,kind,info,x,y,created)
  local tool,toolErr=fusion.add_tool(comp,FUSES[kind],x,y)
  if not tool then error("NODE_CREATE_FAILED: "..tostring(toolErr)) end
  created[#created+1]=tool

  local attr,attrErr=fusion.attrs(tool,kind)
  if not attr then error(attrErr) end
  local observed=attr.TOOLS_RegID
  if observed~=FUSES[kind] and observed~=FUSES[kind]:sub(6) then
    error("NODE_TYPE_MISMATCH: expected "..FUSES[kind].." got "..tostring(observed))
  end

  local renamed,renameErr=fusion.set_attrs(tool,{TOOLS_Name=NAMES[kind]},kind)
  if not renamed then error(renameErr) end
  local renamedAttrs,renamedErr=fusion.attrs(tool,kind)
  if not renamedAttrs then error(renamedErr) end
  if renamedAttrs.TOOLS_Name~=NAMES[kind] then
    error("NODE_RENAME_FAILED: "..NAMES[kind])
  end

  local metadata={
    [OWNER]=true,[OBJECT]=info.object_id,[TYPE]=kind,[SCENE_KEY]=info.scene_id,
    [VERSION]="1.0.0",[DISPLAY]=info.display_name
  }
  for key,value in pairs(metadata) do
    local written,writeErr=fusion.set_data(tool,key,value,kind.." / "..key)
    if not written then error(writeErr) end
  end
  return tool
end

local function connect(target,port,source)
  local ok,err=fusion.connect(target,port,source)
  if not ok then error("FUSION_CONNECT_FAILED: "..tostring(err)) end
end

local function clear_comp_metadata(comp)
  local errors={}
  for _,key in ipairs({SCENE_KEY,VERSION,SOURCE,TITLE}) do
    local cleared,err=fusion.set_data(comp,key,nil,"rollback "..key)
    if not cleared then errors[#errors+1]=tostring(err) end
  end
  return #errors==0,table.concat(errors,"; ")
end

function factory.create_scene(comp,title,opts)
  opts=opts or {}
  local existing,inspectErr=factory.inspect(comp)
  if not existing then return nil,inspectErr end
  if existing.has_scene then
    return nil,"SCENE_EXISTS: this Fusion Composition already contains a CartoRig Scene; Create Scene must target a new timeline item"
  end

  local dataset,dataErr=library_ready(opts.localappdata)
  if not dataset then return nil,dataErr end
  local state,stateErr=domain.new_scene(title or "Map Scene")
  if not state then return nil,stateErr end

  local existingMedia,mediaErr=mediaout_candidate(existing.existing_tools)
  if mediaErr then return nil,mediaErr end
  if not existingMedia and opts.disallow_new_mediaout then
    return nil,"MEDIAOUT_UNAVAILABLE: fresh comp has no MediaOut"
  end

  local started,startErr=fusion.start_undo(comp,"CartoRig - Create Scene")
  if not started then return nil,"FUSION_API_ERROR: StartUndo: "..tostring(startErr) end

  local created,nodes,modifiedExternal={}, {}, nil
  local succeeded,why=pcall(function()
    local bykind={}
    for _,obj in ipairs(state.objects) do bykind[obj.object_type]=obj end
    for index,kind in ipairs(FUSE_ORDER) do
      nodes[kind]=create_node(comp,kind,bykind[kind],-8+index*2,2,created)
    end
    connect(nodes.Camera,"Input",nodes.WorldMap)
    connect(nodes.Scene,"Input",nodes.Camera)

    local output=existingMedia
    if not output then
      local outputErr
      output,outputErr=fusion.add_tool(comp,"MediaOut",0,2)
      if not output then error("MEDIAOUT_CREATE_FAILED: "..tostring(outputErr)) end
      created[#created+1]=output
      local outputAttrs,attrsErr=fusion.attrs(output,"MediaOut")
      if not outputAttrs then error(attrsErr) end
      if outputAttrs.TOOLS_RegID~="MediaOut" then
        error("MEDIAOUT_CREATE_FAILED: unexpected tool returned by Fusion")
      end
      local renamed,renameErr=fusion.set_attrs(output,{TOOLS_Name="CR_Output_Main"},"MediaOut")
      if not renamed then error(renameErr) end
      local owned,ownedErr=fusion.set_data(output,P.."OwnedHelper",true,"MediaOut OwnedHelper")
      if not owned then error(ownedErr) end
      local linked,linkedErr=fusion.set_data(output,SCENE_KEY,state.scene_id,"MediaOut SceneId")
      if not linked then error(linkedErr) end
    end

    if existingMedia then modifiedExternal=existingMedia end
    connect(output,"Input",nodes.Scene)

    local port,portErr=input_of(output,"Input")
    if not port then error("MEDIAOUT_LINK_UNVERIFIED: "..tostring(portErr)) end
    local source,sourceErr=fusion.connected_output(port,"MediaOut.Input")
    if sourceErr then error("MEDIAOUT_LINK_UNVERIFIED: "..tostring(sourceErr)) end
    if not source then error("MEDIAOUT_LINK_FAILED: MediaOut is not connected to Scene") end

    for key,value in pairs({
      [SCENE_KEY]=state.scene_id,[VERSION]=state.schema_version,
      [SOURCE]="Natural Earth 1:50m land",[TITLE]=state.title
    }) do
      local written,writeErr=fusion.set_data(comp,key,value,"composition "..key)
      if not written then error(writeErr) end
    end

    local observed,observedErr=factory.inspect(comp)
    if not observed or not observed.has_scene or
       observed.scene_id~=state.scene_id or observed.title~=state.title then
      error("SCENE_STATE_FAILED: post-create reconstruction failed: "..tostring(observedErr))
    end
  end)

  local function rollback_creation()
    local cleanup={}
    if modifiedExternal then
      local disconnected,disconnectErr=fusion.connect(modifiedExternal,"Input",nil)
      if not disconnected then
        cleanup[#cleanup+1]="MediaOut disconnect: "..tostring(disconnectErr)
      end
    end

    for i=#created,1,-1 do
      local deleted,deleteErr=fusion.delete_tool(created[i])
      if not deleted then cleanup[#cleanup+1]="node delete: "..tostring(deleteErr) end
    end

    local metadataClean,metadataErr=clear_comp_metadata(comp)
    if not metadataClean then cleanup[#cleanup+1]="metadata cleanup: "..metadataErr end

    local ended,endErr=fusion.end_undo(comp,false)
    if not ended then cleanup[#cleanup+1]="EndUndo(false): "..tostring(endErr) end

    local remaining,inventoryErr=inventory(comp)
    if not remaining then
      cleanup[#cleanup+1]="post-rollback inventory unavailable: "..tostring(inventoryErr)
    else
      for _,createdTool in ipairs(created) do
        for _,currentTool in ipairs(remaining) do
          if currentTool==createdTool then
            local attr=fusion.attrs(createdTool,"leaked created tool")
            cleanup[#cleanup+1]="created tool still present after rollback: "..
              tostring(attr and attr.TOOLS_Name or "unknown")
            break
          end
        end
      end
    end

    local observed,postErr=factory.inspect(comp)
    if not observed or observed.has_scene then
      cleanup[#cleanup+1]="post-rollback graph invalid: "..tostring(postErr or "Scene still present")
    end

    for _,key in ipairs({SCENE_KEY,TITLE,VERSION,SOURCE}) do
      local value,readErr=read_data(comp,key,"post-rollback "..key)
      if readErr then
        cleanup[#cleanup+1]=readErr
      elseif value~=nil then
        cleanup[#cleanup+1]="composition metadata remained after rollback: "..key
      end
    end
    return #cleanup==0,table.concat(cleanup,"; ")
  end

  if not succeeded then
    local clean,cleanupErr=rollback_creation()
    return nil,"SCENE_CREATE_FAILED: "..tostring(why)..
      (clean and "; transaction rolled back" or "; ROLLBACK_INCOMPLETE: "..cleanupErr)
  end

  local ended,endErr=fusion.end_undo(comp,true)
  if not ended then
    local clean,cleanupErr=rollback_creation()
    return nil,"UNDO_ERROR: "..tostring(endErr)..
      (clean and "; transaction rolled back" or "; ROLLBACK_INCOMPLETE: "..cleanupErr)
  end

  return {
    scene_id=state.scene_id,title=state.title,objects=state.objects,source=dataset,
    output_connected=true,created_author_nodes=3,
    status="CREATED_NEEDS_FUSION_RENDER_AND_REOPEN_VALIDATION"
  }
end

return factory

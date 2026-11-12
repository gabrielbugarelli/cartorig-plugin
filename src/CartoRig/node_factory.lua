-- CartoRig V1 | structural Scene NodeFactory.
-- Real Fusion tools only; never selects tools in the Node Editor.
local domain=require("CartoRig.domain")
local fusion=require("CartoRig.fusion_contract")
local api=require("CartoRig.blackmagic_api")
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
local DATASET_ID=P.."DatasetId"
local SOURCE_ID=P.."SourceId"
local SOURCE_VERSION=P.."SourceVersion"
local SOURCE_SCALE=P.."SourceScale"
local GEOMETRY_FILE=P.."GeometryFile"
local PARENT_NAME=P.."ParentName"
local DRAW_ORDER=P.."DrawOrder"
local BOUND_WEST=P.."BoundWest"
local BOUND_SOUTH=P.."BoundSouth"
local BOUND_EAST=P.."BoundEast"
local BOUND_NORTH=P.."BoundNorth"

local FUSES={
  WorldMap="Fuse.CartoRigWorldMap",
  Camera="Fuse.CartoRigCamera",
  Scene="Fuse.CartoRigScene",
  Region="Fuse.CartoRigRegion"
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
  if not loaded or type(data)~="table" or #data==0 then
    return nil,"DATA_INCOMPATIBLE: Natural Earth 1:50m Land is empty or unreadable"
  end
  if data.topology_schema~=2 or type(data.ring_roles)~="table" or
     #data.ring_roles~=#data then
    return nil,"DATA_INCOMPATIBLE: Natural Earth Land polygon topology missing"
  end
  for ringIndex,ring in ipairs(data) do
    if data.ring_roles[ringIndex]~="outer" and data.ring_roles[ringIndex]~="hole" then
      return nil,"DATA_INCOMPATIBLE: invalid Land polygon ring role"
    end
    if type(ring)~="table" or #ring<6 or #ring%2~=0 then
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

  local borders=drive.."\\CartoRig\\App\\data\\ne_50m_admin0_borders.lua"
  local borderFile=io.open(borders,"rb")
  if not borderFile then
    return nil,"DATA_MISSING: required Natural Earth 1:50m Admin 0 boundaries not installed"
  end
  borderFile:close()
  local bordersLoaded,borderData=pcall(dofile,borders)
  if not bordersLoaded or type(borderData)~="table" or #borderData==0 then
    return nil,"DATA_INCOMPATIBLE: Natural Earth Admin 0 boundaries are empty or unreadable"
  end
  for lineIndex,line in ipairs(borderData) do
    if type(line)~="table" or #line<4 or #line%2~=0 then
      return nil,"DATA_INCOMPATIBLE: invalid border line "..tostring(lineIndex)
    end
    for i=1,#line,2 do
      local lon,lat=line[i],line[i+1]
      if type(lon)~="number" or type(lat)~="number" or lon~=lon or lat~=lat or
         lon<-180 or lon>180 or lat<-90 or lat>90 then
        return nil,"DATA_INCOMPATIBLE: invalid coordinate in border line "..tostring(lineIndex)
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
      if kind=="Continent" or kind=="Country" or kind=="State" then
        local datasetId,datasetErr=read_data(tool,DATASET_ID,"tool "..index.." DatasetId")
        if datasetErr then return nil,datasetErr end
        local sourceId,sourceErr=read_data(tool,SOURCE_ID,"tool "..index.." SourceId")
        if sourceErr then return nil,sourceErr end
        local sourceVersion,versionErr=read_data(tool,SOURCE_VERSION,"tool "..index.." SourceVersion")
        if versionErr then return nil,versionErr end
        local scale,scaleErr=read_data(tool,SOURCE_SCALE,"tool "..index.." SourceScale")
        if scaleErr then return nil,scaleErr end
        local geometryFile,geometryErr=read_data(tool,GEOMETRY_FILE,"tool "..index.." GeometryFile")
        if geometryErr then return nil,geometryErr end
        local parentName,parentErr=read_data(tool,PARENT_NAME,"tool "..index.." ParentName")
        if parentErr then return nil,parentErr end
        local drawOrder,drawErr=read_data(tool,DRAW_ORDER,"tool "..index.." DrawOrder")
        if drawErr then return nil,drawErr end
        local west,westErr=read_data(tool,BOUND_WEST,"tool "..index.." BoundWest")
        if westErr then return nil,westErr end
        local south,southErr=read_data(tool,BOUND_SOUTH,"tool "..index.." BoundSouth")
        if southErr then return nil,southErr end
        local east,eastErr=read_data(tool,BOUND_EAST,"tool "..index.." BoundEast")
        if eastErr then return nil,eastErr end
        local north,northErr=read_data(tool,BOUND_NORTH,"tool "..index.." BoundNorth")
        if northErr then return nil,northErr end
        if type(datasetId)~="string" or datasetId=="" or
           type(sourceId)~="string" or sourceId=="" or
           type(sourceVersion)~="string" or sourceVersion=="" or
           type(scale)~="string" or scale=="" or
           type(geometryFile)~="string" or geometryFile=="" or
           type(drawOrder)~="number" or type(west)~="number" or
           type(south)~="number" or type(east)~="number" or type(north)~="number" or
           west<-180 or west>180 or east<-180 or east>180 or
           south<-90 or south>90 or north<-90 or north>90 or south>north then
          return nil,"STATE_INVALID: Region provenance/bounds are incomplete"
        end
        obj.source={
          dataset_id=datasetId,source_id=sourceId,source_version=sourceVersion,
          scale=scale,geometry_file=geometryFile,parent_name=parentName,
          bounds={west=west,south=south,east=east,north=north}
        }
        obj.draw_order=drawOrder
      end
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

    local identity=table.concat({
      "Title: "..state.title,
      "Scene UUID: "..state.scene_id,
      "Schema: "..state.schema_version
    },"\n")
    local links="WorldMap → Camera → Scene → MediaOut\nManaged graph verified at creation"
    local dataInfo=table.concat({
      "Natural Earth Land 4.1.0 — 1:50m",
      "Natural Earth Admin 0 boundaries 5.1.0 — 1:50m",
      "Offline runtime; no network dependency"
    },"\n")
    local identityWritten,identityErr=fusion.set_input(nodes.Scene,"SceneIdentity",identity,"Scene Identity")
    if not identityWritten then error(identityErr) end
    local linksWritten,linksErr=fusion.set_input(nodes.Scene,"SceneLinks",links,"Scene Links")
    if not linksWritten then error(linksErr) end
    local dataWritten,dataErr=fusion.set_input(nodes.Scene,"SceneData",dataInfo,"Scene Data")
    if not dataWritten then error(dataErr) end

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


local function safe_geometry_relative(path)
  return type(path)=="string" and path~="" and
    not path:find("..",1,true) and not path:match("^[/\\]") and
    not path:match("^[A-Za-z]:")
end

local function region_data_ready(feature,root)
  if type(feature)~="table" or not safe_geometry_relative(feature.geometry_file) then
    return nil,"DATA_INCOMPATIBLE: Region geometry path is invalid"
  end
  local drive=root or os.getenv("LOCALAPPDATA")
  if type(drive)~="string" or drive=="" then
    return nil,"DATA_MISSING: local data directory unavailable"
  end
  local relative=feature.geometry_file:gsub("/","\\")
  local path=drive.."\\CartoRig\\App\\data\\"..relative
  local file=io.open(path,"rb")
  if not file then return nil,"DATA_MISSING: Region geometry not installed: "..feature.geometry_file end
  file:close()
  local ok,data=pcall(dofile,path)
  if not ok or type(data)~="table" or type(data.rings)~="table" or #data.rings==0 then
    return nil,"DATA_INCOMPATIBLE: Region geometry cannot be loaded"
  end
  if data.topology_schema~=2 or type(data.ring_roles)~="table" or
     #data.ring_roles~=#data.rings then
    return nil,"DATA_INCOMPATIBLE: Region polygon topology unavailable"
  end
  if data.source_id~=feature.source_id or data.version~=feature.source_version or
     data.scale~=feature.scale then
    return nil,"DATA_INCOMPATIBLE: Region geometry provenance does not match catalog"
  end
  if type(data.bbox)~="table" or #data.bbox~=4 then
    return nil,"DATA_INCOMPATIBLE: Region geometry has no valid bounds"
  end
  local west,south,east,north=data.bbox[1],data.bbox[2],data.bbox[3],data.bbox[4]
  if type(west)~="number" or type(south)~="number" or type(east)~="number" or
     type(north)~="number" or west<-180 or west>180 or east<-180 or east>180 or
     south<-90 or south>90 or north<-90 or north>90 or south>north then
    return nil,"DATA_INCOMPATIBLE: Region geometry bounds are invalid"
  end
  for ringIndex,ring in ipairs(data.rings) do
    if data.ring_roles[ringIndex]~="outer" and data.ring_roles[ringIndex]~="hole" then
      return nil,"DATA_INCOMPATIBLE: invalid Region ring role"
    end
    if type(ring)~="table" or #ring<6 or #ring%2~=0 then
      return nil,"DATA_INCOMPATIBLE: invalid Region ring "..tostring(ringIndex)
    end
    for i=1,#ring,2 do
      local lon,lat=ring[i],ring[i+1]
      if type(lon)~="number" or type(lat)~="number" or lon~=lon or lat~=lat or
         lon<-180 or lon>180 or lat<-90 or lat>90 then
        return nil,"DATA_INCOMPATIBLE: invalid coordinate in Region ring "..tostring(ringIndex)
      end
    end
  end
  return {path=path,bounds={west=west,south=south,east=east,north=north}}
end

local function state_from_inspection(existing)
  local state={
    schema_version="1.0.0",scene_id=existing.scene_id,
    title=existing.title or "Map Scene",objects={}
  }
  for _,obj in ipairs(existing.objects) do
    state.objects[#state.objects+1]={
      object_id=obj.id,scene_id=obj.scene_id,object_type=obj.type,
      display_name=obj.display_name,node_name=obj.name,
      draw_order=obj.draw_order or -1,source=obj.source,
      visible=true,style_overrides={},motion={}
    }
  end
  return state
end

local function find_owned_tool(list,kind)
  local found,count=nil,0
  for index,tool in ipairs(list) do
    local owned,ownedErr=read_data(tool,OWNER,"tool "..index.." Owned")
    if ownedErr then return nil,ownedErr end
    if owned==true then
      local objectType,typeErr=read_data(tool,TYPE,"tool "..index.." ObjectType")
      if typeErr then return nil,typeErr end
      if objectType==kind then
        found=tool
        count=count+1
      end
    end
  end
  if count~=1 then
    return nil,"STATE_INVALID: expected exactly one "..tostring(kind).." node, found "..tostring(count)
  end
  return found
end

local function create_region_node(comp,info,x,y,created)
  local tool,toolErr=fusion.add_tool(comp,FUSES.Region,x,y)
  if not tool then error("NODE_CREATE_FAILED: "..tostring(toolErr)) end
  created[#created+1]=tool

  local attr,attrErr=fusion.attrs(tool,info.object_type)
  if not attr then error(attrErr) end
  local observed=attr.TOOLS_RegID
  if observed~=FUSES.Region and observed~=FUSES.Region:sub(6) then
    error("NODE_TYPE_MISMATCH: expected "..FUSES.Region.." got "..tostring(observed))
  end

  local renamed,renameErr=fusion.set_attrs(tool,{TOOLS_Name=info.node_name},info.object_type)
  if not renamed then error(renameErr) end
  local renamedAttrs,renamedErr=fusion.attrs(tool,info.object_type)
  if not renamedAttrs then error(renamedErr) end
  if renamedAttrs.TOOLS_Name~=info.node_name then
    error("NODE_RENAME_FAILED: "..tostring(info.node_name))
  end

  local metadata={
    [OWNER]=true,[OBJECT]=info.object_id,[TYPE]=info.object_type,
    [SCENE_KEY]=info.scene_id,[VERSION]="1.0.0",[DISPLAY]=info.display_name,
    [DATASET_ID]=info.source.dataset_id,[SOURCE_ID]=info.source.source_id,
    [SOURCE_VERSION]=info.source.source_version,[SOURCE_SCALE]=info.source.scale,
    [GEOMETRY_FILE]=info.source.geometry_file,
    [PARENT_NAME]=info.source.parent_name or "",[DRAW_ORDER]=info.draw_order,
    [BOUND_WEST]=info.source.bounds.west,[BOUND_SOUTH]=info.source.bounds.south,
    [BOUND_EAST]=info.source.bounds.east,[BOUND_NORTH]=info.source.bounds.north
  }
  for key,value in pairs(metadata) do
    local written,writeErr=fusion.set_data(tool,key,value,info.object_type.." / "..key)
    if not written then error(writeErr) end
  end

  local identity=table.concat({
    info.object_type.." — "..info.display_name,
    "Object UUID: "..info.object_id,
    "Scene UUID: "..info.scene_id
  },"\n")
  local geography=table.concat({
    "Natural Earth "..info.source.scale.." | "..info.source.dataset_id,
    "Source ID: "..info.source.source_id.." | Version: "..info.source.source_version,
    "Parent: "..tostring(info.source.parent_name or "")
  },"\n")
  local bounds=string.format("W %.6f | S %.6f | E %.6f | N %.6f",
    info.source.bounds.west,info.source.bounds.south,
    info.source.bounds.east,info.source.bounds.north)
  local identityWritten,identityErr=fusion.set_input(tool,"IdentityInfo",identity,"Region Identity")
  if not identityWritten then error(identityErr) end
  local geographyWritten,geographyErr=fusion.set_input(tool,"GeographyInfo",geography,"Region Geography")
  if not geographyWritten then error(geographyErr) end
  local boundsWritten,boundsErr=fusion.set_input(tool,"BoundsInfo",bounds,"Region Bounds")
  if not boundsWritten then error(boundsErr) end
  return tool
end

local function managed_tool_map(existing)
  local map={}
  for index,tool in ipairs(existing.existing_tools) do
    local owned,ownedErr=read_data(tool,OWNER,"tool "..index.." Owned")
    if ownedErr then return nil,ownedErr end
    if owned==true then
      local objectId,idErr=read_data(tool,OBJECT,"tool "..index.." ObjectId")
      if idErr then return nil,idErr end
      if type(objectId)~="string" or objectId=="" then
        return nil,"STATE_INVALID: managed Tool has no object UUID"
      end
      if map[objectId] then return nil,"STATE_INVALID: multiple Tools share object UUID "..objectId end
      map[objectId]=tool
    end
  end
  return map
end

local function connected_source_tool(tool,port,label)
  local input,inputErr=input_of(tool,port)
  if not input then return nil,tostring(label)..": "..tostring(inputErr) end
  local output,outputErr=fusion.connected_output(input,tostring(label))
  if outputErr then return nil,tostring(label)..": "..tostring(outputErr) end
  if not output then return nil,tostring(label)..": no connected output" end
  local source,sourceErr=fusion.output_tool(output,tostring(label).." source")
  if not source then return nil,tostring(label)..": "..tostring(sourceErr) end
  return source
end

local function managed_region_chain(existing)
  local toolMap,mapErr=managed_tool_map(existing)
  if not toolMap then return nil,mapErr end
  local worldObj,cameraObj=nil,nil
  local regions={}
  local drawOrders={}
  for _,obj in ipairs(existing.objects) do
    if obj.type=="WorldMap" then worldObj=obj
    elseif obj.type=="Camera" then cameraObj=obj
    elseif obj.type=="Country" or obj.type=="State" or obj.type=="Continent" then
      if type(obj.draw_order)~="number" then
        return nil,"STATE_INVALID: Region has no numeric draw order"
      end
      if drawOrders[obj.draw_order] then
        return nil,"STATE_INVALID: duplicated Region draw order "..tostring(obj.draw_order)
      end
      drawOrders[obj.draw_order]=true
      regions[#regions+1]=obj
    end
  end
  if not worldObj or not cameraObj then return nil,"STATE_INVALID: WorldMap/Camera missing" end
  local world=toolMap[worldObj.id]
  local camera=toolMap[cameraObj.id]
  if not world or not camera then return nil,"STATE_INVALID: WorldMap/Camera Tool missing" end

  table.sort(regions,function(a,b)
    if a.draw_order~=b.draw_order then return a.draw_order<b.draw_order end
    return a.id<b.id
  end)

  local previous=world
  for _,obj in ipairs(regions) do
    local tool=toolMap[obj.id]
    if not tool then return nil,"STATE_INVALID: Region Tool missing for "..tostring(obj.id) end
    local source,sourceErr=connected_source_tool(tool,"Background",obj.name..".Background")
    if not source then return nil,"UNSAFE_GRAPH: "..tostring(sourceErr) end
    if source~=previous then
      return nil,"UNSAFE_GRAPH: Region chain does not match persisted draw order at "..tostring(obj.name)
    end
    obj._tool=tool
    previous=tool
  end

  local cameraSource,cameraErr=connected_source_tool(camera,"Input","Camera.Input")
  if not cameraSource then return nil,"UNSAFE_GRAPH: "..tostring(cameraErr) end
  if cameraSource~=previous then
    return nil,"UNSAFE_GRAPH: Camera input does not match persisted Region draw order"
  end
  return {world=world,camera=camera,regions=regions}
end

-- Fusion renders Fuses on worker contexts where Comp:GetToolList is not
-- available. Bind the parent WorldMap channels as native Fusion expressions
-- while NodeFactory is on the editor/script thread. Region:Process only
-- evaluates its own six numeric inputs and never traverses the composition.
local function link_region_palette(region,world)
  local attrs,attrsErr=fusion.attrs(world,"palette parent WorldMap")
  if not attrs then error("REGION_PALETTE_BIND_FAILED: "..tostring(attrsErr)) end
  if attrs.TOOLS_Name~=NAMES.WorldMap then
    error("REGION_PALETTE_BIND_FAILED: WorldMap was renamed; cannot bind palette safely")
  end
  for _,prefix in ipairs({"Land","Border"}) do
    for _,suffix in ipairs({"R","G","B"}) do
      local target="World"..prefix..suffix
      local expression=NAMES.WorldMap.."."..prefix..suffix
      local input,inputErr=fusion.find_input(region,target)
      if not input then
        error("REGION_PALETTE_BIND_FAILED: "..target..": "..tostring(inputErr))
      end
      local _,setErr=api.call(input,"SetExpression",expression)
      if setErr then
        error("REGION_PALETTE_BIND_FAILED: SetExpression "..target..": "..tostring(setErr))
      end
      local readback,readErr=api.call(input,"GetExpression")
      if readErr or readback~=expression then
        error("REGION_PALETTE_BIND_FAILED: "..target..
          " expression cannot be verified (observed "..tostring(readback)..
          "; "..tostring(readErr)..")")
      end
    end
  end
end

-- Explicit, idempotent migration for Regions created before native palette
-- bindings existed. It is never run by a render thread, Scene listing, or
-- project-open hook: the user requests it from the structural Scene UI.
function factory.repair_region_palette(comp)
  local existing,inspectErr=factory.inspect(comp)
  if not existing then return nil,inspectErr end
  if not existing.has_scene then return nil,"NO_SCENE: Scene is required for palette repair" end
  local chain,chainErr=managed_region_chain(existing)
  if not chain then return nil,chainErr end
  local changed={}
  local candidates={}
  local worldAttrs,worldErr=fusion.attrs(chain.world,"palette parent WorldMap")
  if not worldAttrs then return nil,"REGION_PALETTE_REPAIR_FAILED: "..tostring(worldErr) end
  if worldAttrs.TOOLS_Name~=NAMES.WorldMap then
    return nil,"REGION_PALETTE_REPAIR_FAILED: WorldMap name differs from managed identity"
  end
  for _,obj in ipairs(chain.regions) do
    for _,prefix in ipairs({"Land","Border"}) do
      for _,suffix in ipairs({"R","G","B"}) do
        local target="World"..prefix..suffix
        local expected=NAMES.WorldMap.."."..prefix..suffix
        local input,inputErr=fusion.find_input(obj._tool,target)
        if not input then
          return nil,"REGION_PALETTE_REPAIR_FAILED: "..obj.name.."."..target..": "..tostring(inputErr)
        end
        local observed,readErr=api.call(input,"GetExpression")
        if readErr then
          return nil,"REGION_PALETTE_REPAIR_FAILED: cannot read "..obj.name.."."..target..
            ": "..tostring(readErr)
        end
        if observed~=nil and observed~="" and observed~=expected then
          return nil,"REGION_PALETTE_REPAIR_FAILED: custom expression preserved at "..
            obj.name.."."..target
        end
        if observed~=expected then
          candidates[#candidates+1]={input=input,expected=expected,
            label=obj.name.."."..target}
        end
      end
    end
  end
  if #candidates==0 then
    return {regions=#chain.regions,expressions_repaired=0}
  end
  local started,startErr=fusion.start_undo(comp,"CartoRig - Repair Region Palette Links")
  if not started then return nil,"REGION_PALETTE_REPAIR_FAILED: "..tostring(startErr) end

  local function rollback(reason)
    local errors={}
    for index=#changed,1,-1 do
      local item=changed[index]
      local _,resetErr=api.call(item.input,"SetExpression",nil)
      local observed,readErr=api.call(item.input,"GetExpression")
      if resetErr or readErr or (observed~=nil and observed~="") then
        errors[#errors+1]="cannot restore "..item.label..": "..
          tostring(resetErr or readErr or observed)
      end
    end
    local ended,endErr=fusion.end_undo(comp,false)
    if not ended then errors[#errors+1]="EndUndo(false): "..tostring(endErr) end
    return nil,"REGION_PALETTE_REPAIR_FAILED: "..tostring(reason)..
      (#errors==0 and "; transaction rolled back" or
        "; ROLLBACK_INCOMPLETE: "..table.concat(errors,"; "))
  end

  for _,item in ipairs(candidates) do
    -- Record before SetExpression: even a thrown proxy call may have changed
    -- the input and must be included in rollback.
    changed[#changed+1]=item
    local _,setErr=api.call(item.input,"SetExpression",item.expected)
    if setErr then return rollback(item.label..": "..tostring(setErr)) end
    local observed,readErr=api.call(item.input,"GetExpression")
    if readErr or observed~=item.expected then
      return rollback(item.label.." expression readback mismatch: "..
        tostring(readErr or observed))
    end
  end
  local ended,endErr=fusion.end_undo(comp,true)
  if not ended then return rollback(endErr) end
  return {regions=#chain.regions,expressions_repaired=#candidates}
end

function factory.add_region(comp,feature,opts)
  opts=opts or {}
  if type(feature)~="table" or (feature.geo_type~="Country" and feature.geo_type~="State") then
    return nil,"REGION_TYPE_UNSUPPORTED: Milestone A adds Country or State only"
  end

  local existing,inspectErr=factory.inspect(comp)
  if not existing then return nil,inspectErr end
  if not existing.has_scene then return nil,"NO_SCENE: create a CartoRig Scene first" end

  local geometry, dataErr=region_data_ready(feature,opts.localappdata)
  if not geometry then return nil,dataErr end

  local state=state_from_inspection(existing)
  local proposal,proposalErr=domain.add_region(state,feature.geo_type,feature)
  if not proposal then return nil,proposalErr end
  proposal.source.bounds=geometry.bounds

  local chain,chainErr=managed_region_chain(existing)
  if not chain then return nil,chainErr end

  local predecessor=chain.world
  local successor=chain.camera
  local successorPort="Input"
  local regionCount=#chain.regions
  for _,obj in ipairs(chain.regions) do
    if obj.draw_order<proposal.draw_order then
      predecessor=obj._tool
    elseif successor==chain.camera then
      successor=obj._tool
      successorPort="Background"
      break
    end
  end

  local started,startErr=fusion.start_undo(comp,"CartoRig - Add "..feature.geo_type)
  if not started then return nil,"FUSION_API_ERROR: StartUndo: "..tostring(startErr) end

  local created={}
  local region=nil
  local succeeded,why=pcall(function()
    region=create_region_node(comp,proposal,-2+regionCount*2,4,created)
    link_region_palette(region,chain.world)
    connect(region,"Background",predecessor)
    connect(successor,successorPort,region)

    local observed,observedErr=factory.inspect(comp)
    if not observed then error(observedErr) end
    local found=nil
    for _,obj in ipairs(observed.objects) do
      if obj.id==proposal.object_id then found=obj;break end
    end
    if not found or found.type~=proposal.object_type or
       not found.source or found.source.source_id~=proposal.source.source_id or
       found.source.geometry_file~=proposal.source.geometry_file or
       found.draw_order~=proposal.draw_order then
      error("REGION_STATE_FAILED: post-create reconstruction differs from proposal")
    end
    local validated,validationErr=managed_region_chain(observed)
    if not validated then error("REGION_CHAIN_FAILED: "..tostring(validationErr)) end
  end)

  local function rollback_region()
    local cleanup={}
    local restored,restoreErr=fusion.connect(successor,successorPort,predecessor)
    if not restored then
      cleanup[#cleanup+1]="managed successor restore: "..tostring(restoreErr)
    end
    for i=#created,1,-1 do
      local deleted,deleteErr=fusion.delete_tool(created[i])
      if not deleted then cleanup[#cleanup+1]="Region delete: "..tostring(deleteErr) end
    end
    local ended,endErr=fusion.end_undo(comp,false)
    if not ended then cleanup[#cleanup+1]="EndUndo(false): "..tostring(endErr) end

    local observed,postErr=factory.inspect(comp)
    if not observed then
      cleanup[#cleanup+1]="post-rollback inspect: "..tostring(postErr)
    else
      for _,obj in ipairs(observed.objects) do
        if obj.id==proposal.object_id then
          cleanup[#cleanup+1]="Region object remained after rollback"
          break
        end
      end
      local restoredChain,chainRestoreErr=managed_region_chain(observed)
      if not restoredChain then
        cleanup[#cleanup+1]="post-rollback chain: "..tostring(chainRestoreErr)
      end
    end
    return #cleanup==0,table.concat(cleanup,"; ")
  end

  if not succeeded then
    local clean,cleanupErr=rollback_region()
    return nil,"REGION_CREATE_FAILED: "..tostring(why)..
      (clean and "; transaction rolled back" or "; ROLLBACK_INCOMPLETE: "..cleanupErr)
  end

  local ended,endErr=fusion.end_undo(comp,true)
  if not ended then
    local clean,cleanupErr=rollback_region()
    return nil,"UNDO_ERROR: "..tostring(endErr)..
      (clean and "; transaction rolled back" or "; ROLLBACK_INCOMPLETE: "..cleanupErr)
  end

  return {
    object_id=proposal.object_id,scene_id=proposal.scene_id,
    object_type=proposal.object_type,display_name=proposal.display_name,
    node_name=proposal.node_name,source=proposal.source,draw_order=proposal.draw_order,
    geometry_path=geometry.path,bounds=proposal.source.bounds
  }
end


local function region_identity_text(info)
  return table.concat({
    info.object_type.." — "..info.display_name,
    "Object UUID: "..info.object_id,
    "Scene UUID: "..info.scene_id
  },"\n")
end

function factory.rename_object(comp,object_id,new_name)
  if type(object_id)~="string" or object_id=="" then
    return nil,"OBJECT_ID_REQUIRED: choose a structural object"
  end
  local existing,inspectErr=factory.inspect(comp)
  if not existing then return nil,inspectErr end
  if not existing.has_scene then return nil,"NO_SCENE: create a CartoRig Scene first" end

  local target=nil
  for _,obj in ipairs(existing.objects) do
    if obj.id==object_id then target=obj;break end
  end
  if not target then return nil,"OBJECT_NOT_FOUND: object UUID is absent from Scene" end
  if target.type~="Country" and target.type~="State" then
    return nil,"RENAME_UNSUPPORTED: Milestone A renames Country/State objects only"
  end

  local state=state_from_inspection(existing)
  local proposed,renameErr=domain.rename(state,object_id,new_name)
  if not proposed then return nil,renameErr end

  local toolMap,mapErr=managed_tool_map(existing)
  if not toolMap then return nil,mapErr end
  local tool=toolMap[object_id]
  if not tool then return nil,"STATE_INVALID: target Tool is missing" end

  local oldDisplay=target.display_name
  local oldIdentity,identityReadErr=fusion.get_input(tool,"IdentityInfo")
  if identityReadErr then return nil,identityReadErr end

  local started,startErr=fusion.start_undo(comp,"CartoRig - Rename "..target.type)
  if not started then return nil,"FUSION_API_ERROR: StartUndo: "..tostring(startErr) end

  local succeeded,why=pcall(function()
    local written,writeErr=fusion.set_data(tool,DISPLAY,proposed.display_name,
      target.type.." / "..DISPLAY)
    if not written then error(writeErr) end
    local identityWritten,identityErr=fusion.set_input(tool,"IdentityInfo",
      region_identity_text(proposed),"Region Identity")
    if not identityWritten then error(identityErr) end

    local observed,observedErr=factory.inspect(comp)
    if not observed then error(observedErr) end
    local renamed=nil
    for _,obj in ipairs(observed.objects) do
      if obj.id==object_id then renamed=obj;break end
    end
    if not renamed or renamed.display_name~=proposed.display_name or
       renamed.name~=target.name or renamed.id~=target.id then
      error("RENAME_STATE_FAILED: identity or physical node name changed")
    end
  end)

  local function rollback()
    local cleanup={}
    local restored,restoreErr=fusion.set_data(tool,DISPLAY,oldDisplay,"rollback DisplayName")
    if not restored then cleanup[#cleanup+1]=tostring(restoreErr) end
    local identityRestored,identityErr=fusion.set_input(tool,"IdentityInfo",oldIdentity,
      "rollback IdentityInfo")
    if not identityRestored then cleanup[#cleanup+1]=tostring(identityErr) end
    local ended,endErr=fusion.end_undo(comp,false)
    if not ended then cleanup[#cleanup+1]=tostring(endErr) end
    local observed,postErr=factory.inspect(comp)
    if not observed then
      cleanup[#cleanup+1]=tostring(postErr)
    else
      for _,obj in ipairs(observed.objects) do
        if obj.id==object_id and
           (obj.display_name~=oldDisplay or obj.name~=target.name or obj.id~=target.id) then
          cleanup[#cleanup+1]="target identity/display not restored"
        end
      end
    end
    return #cleanup==0,table.concat(cleanup,"; ")
  end

  if not succeeded then
    local clean,cleanupErr=rollback()
    return nil,"RENAME_FAILED: "..tostring(why)..
      (clean and "; transaction rolled back" or "; ROLLBACK_INCOMPLETE: "..cleanupErr)
  end

  local ended,endErr=fusion.end_undo(comp,true)
  if not ended then
    local clean,cleanupErr=rollback()
    return nil,"UNDO_ERROR: "..tostring(endErr)..
      (clean and "; transaction rolled back" or "; ROLLBACK_INCOMPLETE: "..cleanupErr)
  end
  return {
    object_id=object_id,object_type=target.type,node_name=target.name,
    display_name=proposed.display_name,scene_id=existing.scene_id
  }
end

return factory

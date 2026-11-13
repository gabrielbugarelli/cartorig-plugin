-- Fusion-specific contract helpers on top of CartoRig.blackmagic_api.
-- The official Blackmagic Fusion Scripting Guide documents Composition
-- GetToolList/StartUndo/EndUndo and Operator ConnectInput/Delete. This module
-- keeps proxy safety and binding-table normalization out of NodeFactory.
local api=require("CartoRig.blackmagic_api")
local fusion={}

function fusion.tool_list(comp)
  local raw,err=api.call(comp,"GetToolList",false)
  if raw==nil and err then return nil,"FUSION_TOOL_LIST_FAILED: "..tostring(err) end
  local list,listErr=api.table_values(raw or {},"Composition.GetToolList")
  if not list then return nil,listErr end
  return list
end

function fusion.attrs(tool,label)
  local raw,err=api.call(tool,"GetAttrs")
  if err then return nil,"FUSION_ATTRS_FAILED: "..tostring(label)..": "..tostring(err) end
  if type(raw)~="table" then
    return nil,"FUSION_ATTRS_INVALID: "..tostring(label).." returned "..type(raw)
  end
  return raw
end

function fusion.get_data(object,key,label)
  local value,err=api.call(object,"GetData",key)
  if err then return nil,"FUSION_DATA_READ_FAILED: "..tostring(label or key)..": "..tostring(err) end
  return value
end

function fusion.set_data(object,key,value,label)
  local _,err=api.call(object,"SetData",key,value)
  if err then return nil,"FUSION_DATA_WRITE_FAILED: "..tostring(label or key)..": "..tostring(err) end
  local observed,readErr=fusion.get_data(object,key,label or key)
  if readErr then return nil,readErr end
  if observed~=value then
    return nil,"FUSION_DATA_WRITE_UNVERIFIED: "..tostring(label or key)
  end
  return true
end

function fusion.get_input(tool,name,time)
  if time~=nil then return api.call(tool,"GetInput",name,time) end
  return api.call(tool,"GetInput",name)
end

function fusion.set_input(tool,name,value,label,time)
  local _,methodErr=api.method(tool,"SetInput")
  if methodErr then return nil,methodErr end
  local _,callErr
  if time~=nil then
    _,callErr=api.call(tool,"SetInput",name,value,time)
  else
    _,callErr=api.call(tool,"SetInput",name,value)
  end
  if callErr then return nil,"FUSION_INPUT_WRITE_FAILED: "..tostring(label or name)..": "..tostring(callErr) end
  local observed,readErr=fusion.get_input(tool,name,time)
  if readErr then return nil,"FUSION_INPUT_READ_FAILED: "..tostring(label or name)..": "..tostring(readErr) end
  if observed~=value then
    return nil,"FUSION_INPUT_WRITE_UNVERIFIED: "..tostring(label or name)..
      " expected "..tostring(value).." got "..tostring(observed)
  end
  return true
end

function fusion.set_attrs(tool,values,label)
  local _,err=api.call(tool,"SetAttrs",values)
  if err then return nil,"FUSION_ATTRS_WRITE_FAILED: "..tostring(label)..": "..tostring(err) end
  return true
end

function fusion.add_tool(comp,regid,x,y)
  -- Fusion's documented signatures vary by host:
  --   AddTool(id,x,y)           (observed in Resolve Studio 20)
  --   AddTool(id,false,x,y)     (documented with defsettings)
  -- A rejected proxy call can return nil without an error. Snapshot the
  -- tool inventory so a retry cannot silently create duplicate/foreign nodes.
  local before,beforeErr=fusion.tool_list(comp)
  if not before then
    return nil,"FUSION_ADD_TOOL_PREFLIGHT_FAILED: "..tostring(beforeErr)
  end
  local prior,priorNames={},{}
  for _,tool in ipairs(before) do
    prior[tool]=true
    local attrs=fusion.attrs(tool,"AddTool baseline")
    if attrs and type(attrs.TOOLS_Name)=="string" and attrs.TOOLS_Name~="" then
      priorNames[attrs.TOOLS_Name]=true
    end
  end
  local function new_tools()
    local after,listErr=fusion.tool_list(comp)
    if not after then return nil,listErr end
    local added={}
    for _,tool in ipairs(after) do
      if not prior[tool] then
        -- Some host proxies produce a new userdata wrapper for the same
        -- existing Tool on each GetToolList(). Fusion Tool names are stable
        -- within this AddTool operation; do not mistake wrapper churn for
        -- new nodes and attempt a dangerous duplicate creation.
        local attrs=fusion.attrs(tool,"AddTool current inventory")
        local name=attrs and attrs.TOOLS_Name
        if type(name)~="string" or not priorNames[name] then
          added[#added+1]=tool
        end
      end
    end
    return added
  end
  local function attempt(explicit_defaults)
    local tool,callErr
    if explicit_defaults then
      tool,callErr=api.call(comp,"AddTool",regid,false,x,y)
    else
      tool,callErr=api.call(comp,"AddTool",regid,x,y)
    end
    if tool then
      local checked,handleErr=api.require_object(tool,"Composition.AddTool","GetAttrs")
      if not checked then
        return nil,"FUSION_ADD_TOOL_INVALID_HANDLE: "..tostring(handleErr),false
      end
      return checked,nil,false
    end
    local added,listErr=new_tools()
    if not added then
      return nil,"FUSION_ADD_TOOL_POSTCHECK_FAILED: "..tostring(listErr),false
    end
    if #added>1 then
      return nil,"FUSION_ADD_TOOL_AMBIGUOUS_SIDE_EFFECTS: "..tostring(regid)..
        " created "..tostring(#added).." unexpected tools",false
    end
    if #added==1 then
      -- Even if the proxy returned nil, one new Tool was actually added.
      -- Return that Tool so the NodeFactory can type-check, track and roll it
      -- back if necessary. Do NOT execute a second AddTool.
      local checked,handleErr=api.require_object(added[1],
        "Composition.AddTool observed side effect","GetAttrs")
      if not checked then
        return nil,"FUSION_ADD_TOOL_UNVERIFIED_SIDE_EFFECT: "..tostring(handleErr),false
      end
      return checked,nil,false
    end
    return nil,callErr or "AddTool returned nil without creating a Tool",true
  end

  local tool,firstErr,mayRetry=attempt(false)
  if tool then return tool end
  if not mayRetry then return nil,firstErr end
  local fallback,secondErr=attempt(true)
  if fallback then return fallback end
  return nil,"FUSION_ADD_TOOL_FAILED: "..tostring(regid)..
    "; AddTool(id,x,y): "..tostring(firstErr)..
    "; AddTool(id,false,x,y): "..tostring(secondErr)..
    "; check Fusion Fuse registration and whether the current composition is editable"
end

function fusion.find_input(tool,name)
  if api.method(tool,"FindInput") then
    local input,err=api.call(tool,"FindInput",name)
    if err then return nil,err end
    if input~=nil then return input end
  end
  local value,err=api.get(tool,name,"Operator input "..tostring(name))
  if err then return nil,err end
  return value
end

function fusion.connected_output(input,label)
  local checked,handleErr=api.require_object(input,label or "Input","GetConnectedOutput")
  if not checked then return nil,handleErr end
  return api.call(input,"GetConnectedOutput")
end

function fusion.output_tool(output,label)
  local checked,handleErr=api.require_object(output,label or "Output","GetTool")
  if not checked then return nil,handleErr end
  return api.call(output,"GetTool")
end

function fusion.connect(tool,input_name,target)
  local _,methodErr=api.method(tool,"ConnectInput")
  if methodErr then return nil,methodErr end
  local success,err=api.call(tool,"ConnectInput",input_name,target)
  if err then return nil,err end
  if success==false then return nil,"FUSION_CONNECT_REJECTED: "..tostring(input_name) end

  local input,inputErr=fusion.find_input(tool,input_name)
  if not input then
    if success==true then return true end
    return nil,"FUSION_CONNECT_UNVERIFIED: "..tostring(input_name)..": "..tostring(inputErr)
  end
  local output,outputErr=fusion.connected_output(input,"Input "..tostring(input_name))
  if outputErr then
    if success==true then return true end
    return nil,"FUSION_CONNECT_UNVERIFIED: "..tostring(input_name)..": "..tostring(outputErr)
  end
  if target==nil then
    if output~=nil then return nil,"FUSION_DISCONNECT_FAILED: "..tostring(input_name) end
    return true
  end
  if output==nil then
    return nil,"FUSION_CONNECT_FAILED: no source on "..tostring(input_name)
  end

  -- Blackmagic documents GetConnectedOutput() -> Output and Link.GetTool() ->
  -- owning Tool. Every CartoRig structural connection targets a Tool, so verify
  -- the upstream Tool identity rather than merely checking for a non-nil link.
  local sourceTool,sourceErr=fusion.output_tool(output,
    "connected output for "..tostring(input_name))
  if not sourceTool then
    return nil,"FUSION_CONNECT_UNVERIFIED: "..tostring(sourceErr)
  end
  if sourceTool~=target then
    return nil,"FUSION_CONNECT_WRONG_SOURCE: "..tostring(input_name)
  end
  return true
end

function fusion.start_undo(comp,name)
  local _,err=api.method(comp,"StartUndo")
  if err then return nil,err end
  local _,callErr=api.call(comp,"StartUndo",name)
  if callErr then return nil,callErr end
  return true
end

function fusion.end_undo(comp,keep)
  local _,err=api.method(comp,"EndUndo")
  if err then return nil,err end
  local _,callErr=api.call(comp,"EndUndo",keep)
  if callErr then return nil,callErr end
  return true
end

function fusion.delete_tool(tool)
  local _,err=api.method(tool,"Delete")
  if err then return nil,err end
  local result,callErr=api.call(tool,"Delete")
  if callErr then return nil,callErr end
  if result==false then return nil,"FUSION_DELETE_REJECTED" end
  return true
end

return fusion

-- CartoRig Blackmagic API boundary.
--
-- Contract sources:
--   Resolve Scripting README shipped by Blackmagic under
--   Support/Developer/Scripting/README.txt. It documents return shapes such as
--   [items...] (lists) and {markers...}/{mark} (dictionaries).
--   Blackmagic Fusion Scripting Guide documents Composition/Operator methods.
--
-- Host observation (Resolve Studio 20.3.1, Lua 5.1):
--   tables returned by the binding can contain an internal "__flags" member.
--   "__flags" is NOT part of the documented list/dictionary contract and is
--   ignored only at this boundary. Any other unexpected key fails closed.
local api={}

local BINDING_METADATA={__flags=true}

local function object_kind(value)
  local kind=type(value)
  if kind=="table" or kind=="userdata" then return kind end
  return nil
end

function api.get(receiver,key,context)
  local kind=object_kind(receiver)
  if not kind then
    return nil,"API_INVALID_RECEIVER: "..tostring(context or key)..
      " needs table/userdata, got "..type(receiver)
  end
  local ok,value=pcall(function() return receiver[key] end)
  if not ok then
    return nil,"API_LOOKUP_FAILED: "..tostring(context or key)..": "..tostring(value)
  end
  return value
end

function api.method(receiver,name,context)
  local value,err=api.get(receiver,name,context or name)
  if err then return nil,err end
  if type(value)~="function" then
    return nil,"API_METHOD_UNAVAILABLE: "..tostring(context or name)..
      "."..tostring(name).." is "..type(value)
  end
  return value
end

function api.call(receiver,name,...)
  local fn,err=api.method(receiver,name,name)
  if not fn then return nil,err end
  local ok,value=pcall(fn,receiver,...)
  if not ok then
    return nil,"API_CALL_FAILED: "..tostring(name)..": "..tostring(value)
  end
  return value
end

-- Blackmagic's global bmd table exposes module functions (dot-call), unlike
-- Resolve/Fusion objects whose methods receive the object as self (colon-call).
function api.call_function(container,name,...)
  local fn,err=api.method(container,name,name)
  if not fn then return nil,err end
  local ok,value=pcall(fn,...)
  if not ok then
    return nil,"API_FUNCTION_FAILED: "..tostring(name)..": "..tostring(value)
  end
  return value
end

function api.strict(receiver,name,...)
  local value,err=api.call(receiver,name,...)
  if value==nil or value==false then
    return nil,err or "API_REJECTED: "..tostring(name)
  end
  return value
end

function api.require_object(value,returned_by,required_method)
  local _,err=api.method(value,required_method,returned_by)
  if err then
    return nil,"API_INVALID_HANDLE: "..tostring(returned_by).." returned "..
      type(value).."; expected object implementing "..tostring(required_method)..
      "; "..tostring(err)
  end
  return value
end

local function metadata_key(key)
  return type(key)=="string" and BINDING_METADATA[key]==true
end

local function table_required(value,label)
  if value==nil then return {} end
  if type(value)~="table" then
    return nil,"API_TABLE_INVALID: "..tostring(label).." returned "..type(value)
  end
  return value
end

-- Normalize a documented Blackmagic [items...] return into a strict 1-based
-- Lua sequence. Internal binding metadata is removed. Sparse or non-numeric
-- public keys violate the documented list contract and are rejected.
function api.sequence(value,label)
  local source,err=table_required(value,label)
  if not source then return nil,err end
  local keys={}
  for key,_ in pairs(source) do
    if metadata_key(key) then
      -- Observed Lua-binding metadata, not a documented list element.
    elseif type(key)=="number" and key>=1 and key==math.floor(key) then
      keys[#keys+1]=key
    else
      return nil,"API_LIST_KEY_INVALID: "..tostring(label)..
        " contains non-list key "..tostring(key).." ["..type(key).."]"
    end
  end
  table.sort(keys)
  local result={}
  for position,key in ipairs(keys) do
    if key~=position then
      return nil,"API_LIST_SPARSE: "..tostring(label)..
        " expected index "..tostring(position).." but found "..tostring(key)
    end
    result[position]=source[key]
  end
  return result
end

-- Normalize a documented numeric-key dictionary, e.g. Timeline:GetMarkers().
function api.numeric_dict(value,label)
  local source,err=table_required(value,label)
  if not source then return nil,err end
  local result={}
  for key,item in pairs(source) do
    if metadata_key(key) then
      -- Observed Lua-binding metadata.
    elseif type(key)=="number" then
      result[key]=item
    else
      return nil,"API_DICT_KEY_INVALID: "..tostring(label)..
        " expected numeric key, got "..tostring(key).." ["..type(key).."]"
    end
  end
  return result
end

-- Normalize a documented dictionary with a closed key set, e.g.
-- Timeline:GetMarkInOut() whose documented keys are "video" and "audio".
function api.named_dict(value,label,allowed)
  local source,err=table_required(value,label)
  if not source then return nil,err end
  local result={}
  for key,item in pairs(source) do
    if metadata_key(key) then
      -- Observed Lua-binding metadata.
    elseif type(key)=="string" and allowed[key] then
      result[key]=item
    else
      return nil,"API_DICT_KEY_INVALID: "..tostring(label)..
        " contains unexpected key "..tostring(key).." ["..type(key).."]"
    end
  end
  return result
end

-- Fusion Composition:GetToolList() is documented only as a table of tool
-- handles, not as a 1-based list. Preserve all public keys and expose values;
-- remove only the observed binding metadata member.
function api.table_values(value,label)
  local source,err=table_required(value,label)
  if not source then return nil,err end
  local result={}
  for key,item in pairs(source) do
    if not metadata_key(key) then result[#result+1]=item end
  end
  return result
end

function api.is_binding_metadata_key(key)
  return metadata_key(key)
end

return api

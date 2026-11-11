-- CartoRig V1 | model of immutable object identity and scene invariants.
-- Only the Fusion adapter may turn model proposals into physical native nodes.
local domain = {}
local VALID_TYPES = {
  Scene = true, WorldMap = true, Camera = true,
  Continent = true, Country = true, State = true,
  Route = true, Marker = true, Label = true
}
local STRUCTURAL_NAMES = {
  Scene = "CR_Scene_Main",
  WorldMap = "CR_WorldMap_Main",
  Camera = "CR_Camera_Main"
}

local accents = {
  ["á"]="a", ["à"]="a", ["â"]="a", ["ã"]="a", ["ä"]="a",
  ["é"]="e", ["ê"]="e", ["è"]="e", ["ë"]="e",
  ["í"]="i", ["ì"]="i", ["î"]="i", ["ï"]="i",
  ["ó"]="o", ["ô"]="o", ["õ"]="o", ["ò"]="o", ["ö"]="o",
  ["ú"]="u", ["û"]="u", ["ü"]="u", ["ù"]="u",
  ["ç"]="c", ["ñ"]="n", ["ý"]="y",
  ["Á"]="A", ["À"]="A", ["Â"]="A", ["Ã"]="A", ["Ä"]="A",
  ["É"]="E", ["Ê"]="E", ["È"]="E", ["Ë"]="E",
  ["Í"]="I", ["Ì"]="I", ["Î"]="I", ["Ï"]="I",
  ["Ó"]="O", ["Ô"]="O", ["Õ"]="O", ["Ò"]="O", ["Ö"]="O",
  ["Ú"]="U", ["Û"]="U", ["Ü"]="U", ["Ù"]="U",
  ["Ç"]="C", ["Ñ"]="N"
}

function domain.slug(text)
  if type(text) ~= "string" then return nil, "display name must be text" end
  text = text:gsub("[\194-\244][\128-\191]+", function(c) return accents[c] or "" end)
  text = text:gsub("[^A-Za-z0-9]+", " ")
  local parts = {}
  for word in text:gmatch("%w+") do
    parts[#parts+1] = word:sub(1, 1):upper() .. word:sub(2)
  end
  if #parts == 0 then return nil, "display name needs an ASCII-readable slug" end
  return table.concat(parts)
end

-- Prefer Fusion's native UUID generator in the host. The pure Lua fallback is
-- retained only for source tests or environments where bmd.createuuid is absent.
local function valid_uuid(s)
  if type(s) ~= "string" or #s ~= 36 then return false end
  if not s:match("^[0-9a-fA-F%-]+$") then return false end
  return s:sub(9,9) == "-" and s:sub(14,14) == "-" and
         s:sub(19,19) == "-" and s:sub(24,24) == "-" and
         s:sub(15,15) == "4" and s:sub(20,20):match("[89aAbB]") ~= nil
end

local seeded = false
local function seed()
  if not seeded then
    local clock = math.floor((os.clock() * 1000000) % 1000000)
    math.randomseed((os.time() % 2147483647) + clock)
    for _ = 1, 16 do math.random() end
    seeded = true
  end
end
function domain.uuid()
  local bmd = rawget(_G, "bmd")
  if type(bmd) == "table" or type(bmd) == "userdata" then
    local ok, native = pcall(function()
      local generator = bmd.createuuid
      if type(generator) ~= "function" then return nil end
      return generator()
    end)
    if ok and valid_uuid(native) then return native end
  end
  seed()
  local chars = {}
  for i = 1, 32 do chars[i] = string.format("%x", math.random(0, 15)) end
  chars[13] = "4"
  chars[17] = string.format("%x", math.random(8, 11))
  local hex = table.concat(chars)
  return hex:sub(1,8) .. "-" .. hex:sub(9,12) .. "-" .. hex:sub(13,16) .. "-" ..
         hex:sub(17,20) .. "-" .. hex:sub(21,32)
end

function domain.is_uuid(s)
  return valid_uuid(s)
end

local function unique_id(used)
  for _ = 1, 50 do
    local candidate = domain.uuid()
    if not used[candidate] then return candidate end
  end
  return nil, "unable to generate unique CartoRig ID"
end

function domain.new_scene(title)
  if type(title) ~= "string" or title:gsub("%s", "") == "" then
    return nil, "scene title is required"
  end
  local used = {}
  local sid = assert(unique_id(used))
  used[sid] = true
  local state = { schema_version = "1.0.0", scene_id = sid, title = title, objects = {} }
  for _, typ in ipairs({"Scene", "WorldMap", "Camera"}) do
    local id = assert(unique_id(used))
    used[id] = true
    state.objects[#state.objects+1] = {
      object_id = id, scene_id = sid, object_type = typ,
      display_name = typ == "Scene" and title or typ,
      node_name = STRUCTURAL_NAMES[typ],
      draw_order = typ == "WorldMap" and 0 or -1,
      visible = true, style_overrides = {}, motion = {}
    }
  end
  return state
end

local function find(state, id)
  if type(state) ~= "table" or type(state.objects) ~= "table" then return nil end
  for i, object in ipairs(state.objects) do
    if object.object_id == id then return object, i end
  end
end
domain.find = find

function domain.validate(state)
  if type(state) ~= "table" or state.schema_version ~= "1.0.0" or
     not domain.is_uuid(state.scene_id) or type(state.objects) ~= "table" then
    return nil, "invalid scene schema or identity"
  end
  local counts, ids, names = {}, {}, {}
  for _, o in ipairs(state.objects) do
    if not VALID_TYPES[o.object_type] then return nil, "unknown object type" end
    if not domain.is_uuid(o.object_id) or ids[o.object_id] or o.object_id == state.scene_id then
      return nil, "duplicate or invalid object UUID"
    end
    if o.scene_id ~= state.scene_id then return nil, "cross-scene object" end
    if type(o.node_name) ~= "string" or names[o.node_name] then
      return nil, "missing or colliding Fusion node name"
    end
    ids[o.object_id] = true
    names[o.node_name] = true
    counts[o.object_type] = (counts[o.object_type] or 0) + 1
  end
  for _, typ in ipairs({"Scene", "WorldMap", "Camera"}) do
    if counts[typ] ~= 1 then return nil, "missing or multiple structural nodes: " .. typ end
  end
  return true
end

function domain.add_region(state, typ, feature)
  local ok, err = domain.validate(state)
  if not ok then return nil, err end
  if typ ~= "Continent" and typ ~= "Country" and typ ~= "State" then
    return nil, "only valid Region types can be added"
  end
  if type(feature) ~= "table" or type(feature.canonical_name) ~= "string" or
     not feature.geometry_available or type(feature.source_id) ~= "string" or
     feature.source_id == "" or type(feature.dataset_id) ~= "string" or
     feature.dataset_id == "" or type(feature.source_version) ~= "string" or
     feature.source_version == "" or feature.source_type ~= typ then
    return nil, "missing real compatible polygon/source data"
  end
  local slug, serr = domain.slug(feature.canonical_name)
  if not slug then return nil, serr end
  local taken, used = {}, { [state.scene_id] = true }
  for _, o in ipairs(state.objects) do
    taken[o.node_name] = true
    used[o.object_id] = true
  end
  local prefix = "CR_" .. typ .. "_" .. slug .. "_"
  local name
  for i = 1, 999 do
    local candidate = prefix .. string.format("%03d", i)
    if not taken[candidate] then name = candidate; break end
  end
  if not name then return nil, "name index exhausted for this feature" end
  local id, ierr = unique_id(used)
  if not id then return nil, ierr end
  local priorities = { Continent = 10, Country = 20, State = 30 }
  local new = {
    object_id = id, scene_id = state.scene_id, object_type = typ,
    display_name = feature.canonical_name, node_name = name,
    source = {
      source_id = feature.source_id, source_version = feature.source_version,
      dataset_id = feature.dataset_id, scale = "1:50m"
    },
    draw_order = priorities[typ], visible = true, style_overrides = {},
    motion = {}
  }
  state.objects[#state.objects+1] = new
  return new
end

function domain.rename(state, object_id, new_name)
  local valid, err = domain.validate(state)
  if not valid then return nil, err end
  local obj = find(state, object_id)
  if not obj then return nil, "unknown object ID" end
  if type(new_name) ~= "string" or new_name:gsub("%s", "") == "" then
    return nil, "new display name required"
  end
  local slug, slugerr = domain.slug(new_name)
  if not slug then return nil, slugerr end
  -- The object UUID and all links intentionally stay unchanged.
  obj.display_name = new_name
  return obj
end

return domain

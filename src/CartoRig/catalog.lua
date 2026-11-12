-- Offline Natural Earth catalog reader. No network, geocoding or synthesized entries.
-- Expected install-time data generated only from the pinned Natural Earth manifest.
-- Dataset scale is preserved per row (Admin 0 1:50m; Admin 1 may be 1:10m where explicitly declared).
local catalog = {}
local accent = {
  ["á"]="a", ["à"]="a", ["â"]="a", ["ã"]="a", ["ä"]="a", ["å"]="a",
  ["é"]="e", ["ê"]="e", ["è"]="e", ["ë"]="e",
  ["í"]="i", ["ì"]="i", ["î"]="i", ["ï"]="i",
  ["ó"]="o", ["ô"]="o", ["õ"]="o", ["ò"]="o", ["ö"]="o",
  ["ú"]="u", ["û"]="u", ["ü"]="u", ["ù"]="u",
  ["ç"]="c", ["ñ"]="n",
  ["Á"]="a", ["À"]="a", ["Â"]="a", ["Ã"]="a", ["Ä"]="a",
  ["É"]="e", ["Ê"]="e", ["È"]="e", ["Ë"]="e",
  ["Í"]="i", ["Ì"]="i", ["Î"]="i", ["Ï"]="i",
  ["Ó"]="o", ["Ô"]="o", ["Õ"]="o", ["Ò"]="o", ["Ö"]="o",
  ["Ú"]="u", ["Û"]="u", ["Ü"]="u", ["Ù"]="u",
  ["Ç"]="c", ["Ñ"]="n"
}
local TYPES = {Continent=true, Country=true, State=true, City=true}
local GEOMETRIES = {Polygon=true,Point=true,Unavailable=true}
local HEAD = "geo_type\tcanonical_name\tparent_name\tsource_id\tdataset_id\tsource_version\tscale\tgeometry\tgeometry_file\taliases\tlatitude\tlongitude"

local function fold(s)
  if type(s) ~= "string" then return "" end
  -- ASCII-casefold and recognize common Portuguese diacritics; unmatched
  -- UTF-8 is retained for exact Unicode searches, never silently discarded.
  s = s:gsub("[\194-\244][\128-\191]+", function(c) return accent[c] or c end)
  return s:lower()
end
catalog.fold = fold

local function split_tsv(line)
  local fields = {}
  for field in (line .. "\t"):gmatch("(.-)\t") do fields[#fields+1] = field end
  return fields
end
local function validate_record(f, line_number)
  if #f ~= 12 or not TYPES[f[1]] or not GEOMETRIES[f[8]] or
     f[2] == "" or f[4] == "" or f[5] == "" or f[6] == "" or f[7] == "" then
    return nil, "invalid Natural Earth index row " .. tostring(line_number)
  end
  if f[8] == "Polygon" and f[9] == "" then
    return nil, "polygon row has no geometry file at " .. tostring(line_number)
  end
  if f[8] == "Point" then
    local lat, lon = tonumber(f[11]), tonumber(f[12])
    if not lat or not lon or lat < -90 or lat > 90 or lon < -180 or lon > 180 then
      return nil, "invalid point in index row " .. tostring(line_number)
    end
  end
  if f[1] == "City" and f[8] == "Polygon" then
    return nil, "City cannot be implicitly promoted to polygon"
  end
  return {
    geo_type = f[1], canonical_name = f[2], parent_name = f[3],
    source_id = f[4], dataset_id = f[5], source_version = f[6],
    scale = f[7], geometry = f[8], geometry_file = f[9], aliases = f[10],
    latitude = tonumber(f[11]), longitude = tonumber(f[12]),
    geometry_available = f[8] == "Polygon",
    source_type = f[1]
  }
end

function catalog.open(path)
  if type(path) ~= "string" or path == "" then
    return nil, "offline index path is required"
  end
  local stream, err = io.open(path, "rb")
  if not stream then
    return nil, "DATA_MISSING: " .. tostring(err)
  end
  local header = stream:read("*l")
  if header ~= HEAD then
    stream:close()
    return nil, "DATA_INCOMPATIBLE: unsupported or incomplete index schema"
  end
  local objects, seen, lineno = {}, {}, 1
  for line in stream:lines() do
    lineno = lineno + 1
    local record, e = validate_record(split_tsv(line), lineno)
    if not record then stream:close(); return nil, e end
    local key = record.dataset_id .. "/" .. record.source_version .. "/" .. record.source_id
    if seen[key] then
      stream:close()
      return nil, "DATA_INTEGRITY: duplicated source ID at " .. tostring(lineno)
    end
    seen[key] = true
    objects[#objects+1] = record
  end
  stream:close()
  if #objects == 0 then return nil, "DATA_MISSING: empty catalog" end
  return { rows = objects, record_count = #objects, schema_version = 1 }
end

function catalog.find(index,dataset_id,source_id)
  if type(index)~="table" or type(index.rows)~="table" then
    return nil,"offline index is not loaded"
  end
  if type(dataset_id)~="string" or dataset_id=="" then
    return nil,"dataset ID is required"
  end
  if type(source_id)~="string" or source_id=="" then
    return nil,"source ID is required"
  end
  local found=nil
  for _,row in ipairs(index.rows) do
    if row.dataset_id==dataset_id and row.source_id==source_id then
      if found then return nil,"DATA_INTEGRITY: dataset/source identity is not unique" end
      found=row
    end
  end
  if not found then
    return nil,"LOCATION_NOT_FOUND: dataset/source identity is absent from installed data"
  end
  return found
end

function catalog.search(index, query, geo_type, limit)
  if type(index) ~= "table" or type(index.rows) ~= "table" then
    return nil, "offline index is not loaded"
  end
  if geo_type ~= nil and geo_type ~= "All" and not TYPES[geo_type] then
    return nil, "unsupported geographic filter"
  end
  if type(query) ~= "string" then return nil, "query must be text" end
  limit = limit or 50
  if type(limit) ~= "number" or limit < 1 or limit > 200 or limit ~= math.floor(limit) then
    return nil, "search limit must be an integer between 1 and 200"
  end
  local needle = fold(query)
  local hits = {}
  for _,row in ipairs(index.rows) do
    if geo_type == nil or geo_type == "All" or row.geo_type == geo_type then
      local rank = nil
      local names = {row.canonical_name}
      for alias in row.aliases:gmatch("[^|]+") do names[#names+1] = alias end
      for _,name in ipairs(names) do
        local normalized = fold(name)
        if needle == "" then
          rank = 3
        elseif normalized == needle then
          rank = 0; break
        elseif normalized:sub(1,#needle) == needle and (not rank or rank > 1) then
          rank = 1
        elseif normalized:find(needle,1,true) and (not rank or rank > 2) then
          rank = 2
        end
      end
      if rank then hits[#hits+1] = {rank=rank,row=row} end
    end
  end
  table.sort(hits, function(a,b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    local an, bn = fold(a.row.canonical_name), fold(b.row.canonical_name)
    if an ~= bn then return an < bn end
    local at, bt = a.row.geo_type, b.row.geo_type
    if at ~= bt then return at < bt end
    return a.row.parent_name < b.row.parent_name
  end)
  local results = {}
  for i=1, math.min(limit, #hits) do results[i] = hits[i].row end
  return results
end

return catalog

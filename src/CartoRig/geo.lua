-- CartoRig V1 | pure geographic coordinate rules used by the future Fusion adapter.
-- No host state, no dataset invention and no side effects.
local geo = {}
local abs, cos, sin, rad = math.abs, math.cos, math.sin, math.rad

local function finite(value)
  return type(value) == "number" and value == value
     and value ~= math.huge and value ~= -math.huge
end

function geo.validate_latitude(value)
  if not finite(value) or value < -90 or value > 90 then
    return nil, "latitude must be finite and between -90 and 90"
  end
  return value
end

function geo.validate_longitude(value)
  if not finite(value) then
    return nil, "longitude must be finite"
  end
  return value
end

-- Present longitudes in [-180,180); do not silently clamp invalid latitude.
function geo.normalize_longitude(value)
  local valid, err = geo.validate_longitude(value)
  if not valid then return nil, err end
  return ((value + 180) % 360) - 180
end

-- Unwrap relative to the camera to avoid a world-wide discontinuity.
function geo.unwrap_near(value, reference)
  local lon, error = geo.normalize_longitude(value)
  if not lon then return nil, error end
  local center, cerror = geo.validate_longitude(reference)
  if not center then return nil, cerror end
  return lon + 360 * math.floor((center - lon) / 360 + 0.5)
end

function geo.validate_pose(pose)
  if type(pose) ~= "table" then return nil, "camera pose required" end
  local lat, err = geo.validate_latitude(pose.latitude)
  if not lat then return nil, err end
  local lon, lerr = geo.validate_longitude(pose.longitude)
  if not lon then return nil, lerr end
  if not finite(pose.zoom) or pose.zoom < 0.25 or pose.zoom > 64 then
    return nil, "zoom must be within 0.25..64"
  end
  if not finite(pose.bearing) or pose.bearing < -180 or pose.bearing > 180 then
    return nil, "bearing must be within -180..180 degrees"
  end
  return true
end

function geo.fit_world_scale(width, height)
  if not finite(width) or not finite(height) or width <= 0 or height <= 0 then
    return nil, "output dimensions must be positive"
  end
  return math.min(width / 360, height / 180)
end

-- Equirectangular WGS84 angular plane, camera-relative, Y down.
-- Return floating-point pixel coordinates for arbitrary output resolution.
function geo.project(latitude, longitude, pose, width, height)
  local lat, err = geo.validate_latitude(latitude)
  if not lat then return nil, err end
  local lon, lerr = geo.unwrap_near(longitude, pose and pose.longitude)
  if not lon then return nil, lerr end
  local ok, perr = geo.validate_pose(pose)
  if not ok then return nil, perr end
  local scale, serr = geo.fit_world_scale(width, height)
  if not scale then return nil, serr end
  local dx = (lon - pose.longitude) * scale * pose.zoom
  local dy = (pose.latitude - lat) * scale * pose.zoom
  local theta = rad(pose.bearing)
  return { x = width / 2 + dx * cos(theta) - dy * sin(theta),
           y = height / 2 + dx * sin(theta) + dy * cos(theta) }
end

function geo.validate_anchor(anchor)
  if type(anchor) ~= "table" then return nil, "anchor required" end
  local lat, err = geo.validate_latitude(anchor.latitude)
  if not lat then return nil, err end
  local lon, lerr = geo.validate_longitude(anchor.longitude)
  if not lon then return nil, lerr end
  return { latitude = lat, longitude = geo.normalize_longitude(lon) }
end

-- Detect co-located anchors after longitude wrap, not merely identical strings.
function geo.distinct_endpoints(a, b)
  local aa, err = geo.validate_anchor(a)
  if not aa then return nil, err end
  local bb, berr = geo.validate_anchor(b)
  if not bb then return nil, berr end
  local dlon = geo.unwrap_near(bb.longitude, aa.longitude) - aa.longitude
  if abs(aa.latitude - bb.latitude) < 1e-12 and abs(dlon) < 1e-12 then
    return nil, "route endpoints must be geographically distinct"
  end
  return true
end

return geo

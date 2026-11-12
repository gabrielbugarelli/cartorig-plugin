-- Shared CartoRig equirectangular geometry for WorldMap and Region Fuses.
-- Shapes in Fusion use image-WIDTH normalized coordinates on both axes.
-- All functions are stateless; no reliance on previous frames or host globals.
local M = {}
local floor,abs,min,max = math.floor,math.abs,math.min,math.max
local function finite(x) return type(x)=="number" and x==x and x~=math.huge and x~=-math.huge end
local function require_number(x,label,positive)
  assert(finite(x) and (not positive or x>0), "GEO_INVALID: "..label.." must be a finite "..(positive and "positive " or "").."number")
end
local function assert_point(lon,lat)
  require_number(lon,"longitude")
  require_number(lat,"latitude")
  assert(lon>=-180 and lon<=180 and lat>=-90 and lat<=90,"GEO_INVALID: coordinate outside WGS84 degrees")
end
local function close(x,y) return abs(x-y)<1e-10 end

function M.frame(width,height,xaspect,yaspect)
  require_number(width,"width",true)
  require_number(height,"height",true)
  xaspect=xaspect or 1
  yaspect=yaspect or 1
  require_number(xaspect,"pixel x aspect",true)
  require_number(yaspect,"pixel y aspect",true)
  local scale=min(width*xaspect/360,height*yaspect/180)
  return {width=width,height=height,xaspect=xaspect,yaspect=yaspect,scale=scale}
end

function M.project(frame,lon,lat)
  assert_point(lon,lat)
  -- Pixel x/y, then Fusion's common width-normalized shape coordinate system.
  local px=frame.width*0.5+lon*frame.scale/frame.xaspect
  local py=frame.height*0.5+lat*frame.scale/frame.yaspect
  return px/frame.width,py/frame.width
end

-- Offset accepted by Image:Transform. It uses normalized image height for Y,
-- whereas Shape's vertex coordinates above normalize both axes by width.
function M.camera_offset(frame,lon,lat,zoom)
  require_number(zoom,"zoom",true)
  require_number(lon,"longitude")
  lon=((lon+180)%360)-180
  assert_point(lon,lat)
  return 0.5-lon*frame.scale/(frame.width*frame.xaspect)*zoom,
         0.5-lat*frame.scale/(frame.height*frame.yaspect)*zoom
end

local function append_line(lines,points)
  if #points>=4 then lines[#lines+1]=points end
end
-- A longitude discontinuity must split the polyline at both sides of the
-- date line, never paint a line through the whole map.
function M.split_line(flat,closed)
  assert(type(flat)=="table" and #flat>=4 and #flat%2==0,"GEO_INVALID: malformed polyline")
  local count=#flat/2
  local out,part={},{}
  local function push(x,y)
    if #part>=2 and close(part[#part-1],x) and close(part[#part],y) then return end
    part[#part+1]=x;part[#part+1]=y
  end
  for i=1,count do assert_point(flat[2*i-1],flat[2*i]) end
  push(flat[1],flat[2])
  local edges=closed and count or count-1
  for i=1,edges do
    local a=2*i-1
    local b=2*(i%count)+1
    local x1,y1=flat[a],flat[a+1]
    local x2,y2=flat[b],flat[b+1]
    local delta=x2-x1
    if delta>180 or delta< -180 then
      local edge=delta>180 and -180 or 180
      local unwrapped=delta>180 and x2-360 or x2+360
      local t=(edge-x1)/(unwrapped-x1)
      assert(t>=0 and t<=1,"GEO_INVALID: seam intersection outside segment")
      local cross=y1+t*(y2-y1)
      push(edge,cross)
      append_line(out,part)
      part={}
      push(-edge,cross)
    end
    push(x2,y2)
  end
  append_line(out,part)
  return out
end

local function clip_one(poly,boundary,keep_greater)
  local result={}
  if #poly==0 then return result end
  local function inside(p)
    return keep_greater and p[1]>=boundary-1e-10 or
      (not keep_greater and p[1]<=boundary+1e-10)
  end
  local function intersection(a,b)
    local d=b[1]-a[1]
    if abs(d)<1e-12 then return {boundary,a[2]} end
    local t=(boundary-a[1])/d
    return {boundary,a[2]+t*(b[2]-a[2])}
  end
  local prev=poly[#poly]
  local was=inside(prev)
  for _,current in ipairs(poly) do
    local yes=inside(current)
    if yes~=was then result[#result+1]=intersection(prev,current) end
    if yes then result[#result+1]=current end
    prev=current;was=yes
  end
  return result
end

local function area(poly)
  local sum=0
  for i=1,#poly do
    local a,b=poly[i],poly[i%#poly+1]
    sum=sum+a[1]*b[2]-b[1]*a[2]
  end
  return sum/2
end

-- Preserve winding/orientation and clip each polygon ring to the 180-degree
-- seam. Thus fill contours stay within map bounds without a trans-world edge.
-- Nested rings (holes) retain opposite winding from the Natural Earth source.
-- Correct nonzero winding rasterization requires an actual Fusion host test.
function M.clip_ring(flat)
  assert(type(flat)=="table" and #flat>=6 and #flat%2==0,"GEO_INVALID: malformed polygon ring")
  local pts={}
  for i=1,#flat,2 do
    assert_point(flat[i],flat[i+1])
    pts[#pts+1]={flat[i],flat[i+1]}
  end
  if #pts>3 and close(pts[1][1],pts[#pts][1]) and close(pts[1][2],pts[#pts][2]) then
    pts[#pts]=nil
  end
  assert(#pts>=3,"GEO_INVALID: polygon ring has fewer than three unique points")
  local unwrapped={{pts[1][1],pts[1][2]}}
  for i=2,#pts do
    local lon=pts[i][1]
    local previous=unwrapped[#unwrapped][1]
    while lon-previous>180 do lon=lon-360 end
    while lon-previous< -180 do lon=lon+360 end
    unwrapped[#unwrapped+1]={lon,pts[i][2]}
  end
  local west,east=math.huge,-math.huge
  for _,point in ipairs(unwrapped) do
    west=min(west,point[1]);east=max(east,point[1])
  end
  local pieces={}
  local lo=floor((west+180)/360)-1
  local hi=floor((east+180)/360)+1
  for shift=lo,hi do
    local moved={}
    for _,point in ipairs(unwrapped) do
      moved[#moved+1]={point[1]-360*shift,point[2]}
    end
    local clipped=clip_one(clip_one(moved,-180,true),180,false)
    if #clipped>=3 and abs(area(clipped))>1e-9 then
      local out={}
      for _,point in ipairs(clipped) do
        out[#out+1]=max(-180,min(180,point[1]));out[#out+1]=point[2]
      end
      pieces[#pieces+1]=out
    end
  end
  return pieces
end

function M.fill_shape(rings,frame)
  assert(type(rings)=="table" and #rings>0,"GEO_INVALID: empty polygon collection")
  local shape=Shape()
  for _,ring in ipairs(rings) do
    for _,piece in ipairs(M.clip_ring(ring)) do
      local x,y=M.project(frame,piece[1],piece[2]);shape:MoveTo(x,y)
      for i=3,#piece,2 do
        x,y=M.project(frame,piece[i],piece[i+1]);shape:LineTo(x,y)
      end
      shape:Close()
    end
  end
  return shape
end

function M.line_shape(lines,frame,closed)
  assert(type(lines)=="table","GEO_INVALID: expected line collection")
  local shape=Shape()
  for _,line in ipairs(lines) do
    for _,piece in ipairs(M.split_line(line,closed)) do
      local x,y=M.project(frame,piece[1],piece[2]);shape:MoveTo(x,y)
      for i=3,#piece,2 do
        x,y=M.project(frame,piece[i],piece[i+1]);shape:LineTo(x,y)
      end
    end
  end
  return shape
end
return M

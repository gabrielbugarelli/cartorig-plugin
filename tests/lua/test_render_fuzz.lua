package.path="src/?.lua;src/?/init.lua;"..package.path
local geo=require("CartoRig.render_geometry")
local function area(flat)
  local a=0
  for i=1,#flat,2 do
    local j=i+2
    if j>#flat then j=1 end
    a=a+flat[i]*flat[j+1]-flat[j]*flat[i+1]
  end
  return math.abs(a)/2
end
local cases=0
-- Rectangles crossing ±180: clipped area must equal the unwrapped area.
-- Uses only planar WGS84-degree geometry; not a host raster comparison.
for _,sign in ipairs({-1,1}) do
  for width=1,20 do
    for height=1,20 do
      local west,east
      if sign==1 then
        west=180-width/2
        east=-180+width/2
      else
        west=-180+width/2
        east=180-width/2
      end
      local ring={west,-height/2,east,-height/2,east,height/2,west,height/2}
      local pieces=geo.clip_ring(ring)
      assert(#pieces==2,"crossing rectangle must occupy two dateline pieces")
      local total=0
      for _,piece in ipairs(pieces) do
        for i=1,#piece,2 do
          assert(piece[i]>=-180 and piece[i]<=180)
          assert(piece[i+1]>=-90 and piece[i+1]<=90)
        end
        total=total+area(piece)
      end
      assert(math.abs(total-width*height)<1e-7,
        "dateline clipping changed polygon area: "..tostring(total).." expected "..tostring(width*height))
      cases=cases+1
    end
  end
end
print("render_fuzz: PASS "..cases.." crossing antimeridian rectangles; area preserved")

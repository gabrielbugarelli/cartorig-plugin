-- Verify the actual vendored Natural Earth payload (no synthetic geometry).
local land=assert(dofile("data/ne_50m_land.lua"))
assert(#land==1422)
local points=0
local minlat,maxlat,minlon,maxlon=90,-90,180,-180
for i,ring in ipairs(land) do
 assert(type(ring)=="table" and #ring>=8 and #ring%2==0)
 for j=1,#ring,2 do
  local lon,lat=ring[j],ring[j+1]
  assert(type(lon)=="number" and type(lat)=="number")
  assert(lon>=-180 and lon<=180 and lat>=-90 and lat<=90)
  points=points+1
  if lon<minlon then minlon=lon end
  if lon>maxlon then maxlon=lon end
  if lat<minlat then minlat=lat end
  if lat>maxlat then maxlat=lat end
 end
end
assert(points==60669)
assert(minlon< -179 and maxlon>179)
assert(minlat < -80 and maxlat > 80)
print("natural_earth: PASS (1422 rings, 60669 authentic source vertices, 1:50m)")

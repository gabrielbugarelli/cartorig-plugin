-- Verify a Natural Earth 1:50m Land runtime payload. The source identity/hash
-- is checked by the build manifest; this test checks the Lua geometry contract.
local source=arg[1] or "data/ne_50m_land.lua"
local land=assert(dofile(source))
assert(type(land)=="table" and #land>0)
local points=0
local minlat,maxlat,minlon,maxlon=90,-90,180,-180
for i,ring in ipairs(land) do
 assert(type(ring)=="table" and #ring>=6 and #ring%2==0)
 for j=1,#ring,2 do
  local lon,lat=ring[j],ring[j+1]
  assert(type(lon)=="number" and type(lat)=="number")
  assert(lon==lon and lat==lat and lon>=-180 and lon<=180 and lat>=-90 and lat<=90)
  points=points+1
  if lon<minlon then minlon=lon end
  if lon>maxlon then maxlon=lon end
  if lat<minlat then minlat=lat end
  if lat>maxlat then maxlat=lat end
 end
end
assert(points>1000,"Land payload is implausibly small")
assert(minlon< -170 and maxlon>170)
assert(minlat < -70 and maxlat > 70)
print("natural_earth: PASS ("..#land.." rings, "..points.." source vertices, 1:50m)")

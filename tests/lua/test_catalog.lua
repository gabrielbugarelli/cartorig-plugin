local catalog=require("CartoRig.catalog")
assert(catalog.open("data/nothing.tsv")==nil)
assert(catalog.open("")==nil)
local source=arg[1] or "tests/fixtures/natural_earth_synthetic.tsv"
local idx=assert(catalog.open(source))
-- Full-data smoke: generated Natural Earth catalog is not the seven-row
-- synthetic fixture and has source-defined IDs, not fixture IDs.
if source:match("ne_catalog%.tsv$") then
  assert(idx.record_count>1000,
    "generated Natural Earth catalog must include actual worldwide coverage")
  local brazil=assert(catalog.search(idx,"Brasil","Country"))
  local argentina=assert(catalog.search(idx,"Argentina","Country"))
  local mato=assert(catalog.search(idx,"Mato Grosso","State"))
  local function unique_region(rows,name)
    local found=nil
    for _,row in ipairs(rows) do
      if row.canonical_name==name then
        assert(not found,"duplicate canonical "..name)
        found=row
      end
    end
    assert(found and found.geometry_available and found.geometry=="Polygon",
      "missing polygon "..name)
    assert(type(found.source_id)=="string" and found.source_id~="" and
      type(found.geometry_file)=="string" and found.geometry_file~="",
      "invalid source or geometry path for "..name)
    return found
  end
  local br=unique_region(brazil,"Brazil")
  local ar=unique_region(argentina,"Argentina")
  local mt=unique_region(mato,"Mato Grosso")
  assert(br.scale=="1:50m" and ar.scale=="1:50m" and mt.scale=="1:10m")
  assert(#assert(catalog.search(idx,"Rio de Janeiro","All"))>=2)
  assert(#assert(catalog.search(idx,"Georgia","All"))>=2)
  print("catalog: PASS (generated Natural Earth Brazil/Argentina/Mato Grosso and provenance)")
  return
end
assert(idx.record_count==7)
local exact=assert(catalog.find(idx,"ne_admin0","ne-id-country-br"))
assert(exact.canonical_name=="Brazil")
assert(catalog.find(idx,"wrong-dataset","ne-id-country-br")==nil)
local r=assert(catalog.search(idx,"Brasil","Country"))
assert(#r==1 and r[1].canonical_name=="Brazil" and r[1].geometry_available)
assert(r[1].scale=="1:50m" and r[1].geometry_file=="regions/ne_admin0/ne-id-country-br.lua")
local r2=assert(catalog.search(idx,"Sao Paulo","City"))
assert(#r2==1 and r2[1].canonical_name=="São Paulo" and r2[1].geometry=="Point" and r2[1].scale=="1:50m")
local saoAll=assert(catalog.search(idx,"Sao Paulo","All"))
assert(#saoAll==2 and saoAll[1].geo_type~=saoAll[2].geo_type,
  "ASCII alias must retain São Paulo State/City disambiguation")
local r3=assert(catalog.search(idx,"São Paulo","All"))
assert(#r3==2 and r3[1].canonical_name=="São Paulo" and r3[2].canonical_name=="São Paulo")
local ambiguous=assert(catalog.search(idx,"Georgia","All"))
assert(#ambiguous==2 and ambiguous[1].geo_type~="City" and ambiguous[1].geo_type~=ambiguous[2].geo_type)
local rio=assert(catalog.search(idx,"Rio de Janeiro","All"))
assert(#rio==2)
local state=assert(catalog.search(idx,"Rio de Janeiro","State"))
assert(#state==1 and state[1].scale=="1:10m" and state[1].geometry_file~="",
  "Admin 1 provenance must preserve its actual scale and geometry file")
local city=assert(catalog.search(idx,"Rio de Janeiro","City"))
assert(#city==1 and city[1].geometry=="Point" and not city[1].geometry_available)
assert(catalog.search(idx,"Brazil","City")[1]==nil)
assert(catalog.search(idx, "Brazil","Polygon")==nil)
assert(catalog.search(idx, "", "All", 250)==nil)
assert(catalog.search(idx, "", "All", 2)[2]~=nil)
print("catalog: PASS (offline aliases, typed ambiguity, point-only, error states)")

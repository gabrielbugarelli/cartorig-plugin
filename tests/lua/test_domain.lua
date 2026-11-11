local d=require("CartoRig.domain")
local state=assert(d.new_scene("Map Scene"))
assert(d.validate(state))
assert(#state.objects==3)
assert(state.objects[1].node_name=="CR_Scene_Main")
assert(state.objects[2].node_name=="CR_WorldMap_Main")
assert(state.objects[3].node_name=="CR_Camera_Main")
local seen={}
for _,o in ipairs(state.objects) do
  assert(d.is_uuid(o.object_id))
  assert(o.scene_id==state.scene_id)
  assert(not seen[o.object_id])
  seen[o.object_id]=true
end
assert(d.is_uuid(state.scene_id))
local original_bmd=rawget(_G,"bmd")
local native_calls=0
_G.bmd={createuuid=function()
  native_calls=native_calls+1
  return "12345678-1234-4123-8123-123456789abc"
end}
assert(d.uuid()=="12345678-1234-4123-8123-123456789abc")
assert(native_calls==1,"domain.uuid must prefer bmd.createuuid inside Fusion")
_G.bmd={createuuid=function() return "invalid-host-uuid" end}
assert(d.is_uuid(d.uuid()),"invalid native UUID must fall back to valid UUID v4")
_G.bmd=original_bmd
assert(d.slug("São Paulo")=="SaoPaulo")
assert(d.slug("Mato Grosso")=="MatoGrosso")
assert(d.slug("///")==nil)
local feature={
  canonical_name="Brazil", geometry_available=true,
  source_id="NE_ID:1", dataset_id="NE_50M_ADM0",
  source_version="test-fixture-v1", source_type="Country"
}
assert(d.add_region(state,"Country",{canonical_name="Nonexistent",source_type="Country"})==nil)
local a=assert(d.add_region(state,"Country",feature))
local b=assert(d.add_region(state,"Country",feature))
assert(a.node_name=="CR_Country_Brazil_001")
assert(b.node_name=="CR_Country_Brazil_002")
assert(a.object_id~=b.object_id)
assert(d.validate(state))
local original=a.object_id
assert(d.rename(state,original,"Brasil"))
assert(a.object_id==original and a.node_name=="CR_Country_Brazil_001")
assert(d.rename(state,original,"")==nil)
assert(d.add_region(state,"City",feature)==nil)
state.objects[4].scene_id="fake"
assert(d.validate(state)==nil)
state.objects[4].scene_id=state.scene_id
assert(d.validate(state))
state.objects[5].object_id=state.objects[4].object_id
assert(d.validate(state)==nil)
print("domain: PASS (UUIDs, cardinality, no fabricated geometry, rename, duplicate identity)")

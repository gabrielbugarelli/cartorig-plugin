local api=require("CartoRig.blackmagic_api")

local function assert_error(value,message,needle)
  assert(value==nil,"expected nil result")
  assert(type(message)=="string" and message:find(needle,1,true),
    "expected "..needle..", got "..tostring(message))
end

-- Guarded proxy lookup/call.
local throwing=setmetatable({},{
  __index=function() error("synthetic proxy lookup failure") end
})
local value,err=api.get(throwing,"Anything","ThrowingProxy")
assert_error(value,err,"API_LOOKUP_FAILED")

local value2,err2=api.call(7,"GetProjectManager")
assert_error(value2,err2,"API_INVALID_RECEIVER")

local object={Ping=function(self,x) return x+1 end}
assert(api.call(object,"Ping",4)==5)
local missing,missingErr=api.call(object,"Missing")
assert_error(missing,missingErr,"API_METHOD_UNAVAILABLE")

-- Official Resolve README documents GetItemListInTrack as [items...].
-- Resolve Studio 20.3.1 host evidence shows internal __flags metadata can be
-- present beside the documented 1-based sequence.
local one,two={id="one"},{id="two"}
local list=assert(api.sequence({[1]=one,[2]=two,__flags=4194304},"GetItemListInTrack"))
assert(#list==2 and list[1]==one and list[2]==two)

local empty=assert(api.sequence({__flags=4194304},"GetItemListInTrack"))
assert(#empty==0)

local sparse,sparseErr=api.sequence({[1]=one,[3]=two,__flags=1},"GetItemListInTrack")
assert_error(sparse,sparseErr,"API_LIST_SPARSE")

local badKey,badKeyErr=api.sequence({[1]=one,unexpected=true},"GetItemListInTrack")
assert_error(badKey,badKeyErr,"API_LIST_KEY_INVALID")

local zeroKey,zeroKeyErr=api.sequence({[0]=one},"GetItemListInTrack")
assert_error(zeroKey,zeroKeyErr,"API_LIST_KEY_INVALID")

-- GetMarkers is documented as frameId -> marker information, not as a list.
local markers=assert(api.numeric_dict({
  [96]={name="A"},[240]={name="B"},__flags=262144
},"GetMarkers"))
assert(markers[96].name=="A" and markers[240].name=="B" and markers.__flags==nil)

local badMarkers,badMarkersErr=api.numeric_dict({foo={}},"GetMarkers")
assert_error(badMarkers,badMarkersErr,"API_DICT_KEY_INVALID")

-- GetMarkInOut is documented with closed keys "video"/"audio".
local marks=assert(api.named_dict({
  video={["in"]=0,["out"]=10},
  audio={["in"]=2,["out"]=8},
  __flags=131072
},"GetMarkInOut",{video=true,audio=true}))
assert(marks.video["out"]==10 and marks.audio["in"]==2)

local extraMark,extraMarkErr=api.named_dict({subtitle={["in"]=1,["out"]=2}},
 "GetMarkInOut",{video=true,audio=true})
assert_error(extraMark,extraMarkErr,"API_DICT_KEY_INVALID")

-- Fusion GetToolList is documented as a table of handles, without promising
-- numeric indexing. Keep values from public keys while stripping binding metadata.
local a,b={name="A"},{name="B"}
local tools=assert(api.table_values({Background1=a,Merge1=b,__flags=1},"GetToolList"))
assert(#tools==2)
local foundA,foundB=false,false
for _,tool in ipairs(tools) do
  if tool==a then foundA=true end
  if tool==b then foundB=true end
end
assert(foundA and foundB)

print("blackmagic_api: PASS (documented list/dict/table contracts + observed __flags metadata)")

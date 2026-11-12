package.path="src/?.lua;src/?/init.lua;"..package.path
local geo=require("CartoRig.render_geometry")
local function near(a,b,tol)
  assert(math.abs(a-b)<(tol or 1e-9),tostring(a).." ~= "..tostring(b))
end
local f=geo.frame(1920,1080,1,1)
local x,y=geo.project(f,0,0)
near(x,.5)
near(y,1080/(2*1920))

local brx,bry=geo.project(f,-47,-15)
for _,res in ipairs({{1920,1080},{2560,1440},{3840,2160}}) do
  local ff=geo.frame(res[1],res[2],1,1)
  local xx,yy=geo.project(ff,-47,-15)
  near(xx,brx);near(yy,bry)
end

local ultra=geo.frame(2048,858,1,1)
local ux,uy=geo.project(ultra,0,0)
near(ux,.5);near(uy,858/(2*2048))
local wide=geo.frame(1920,1080,2,1)
local dx=select(1,geo.project(wide,90,0))-.5
local dy=select(2,geo.project(wide,0,45))-1080/(2*1920)
near(dx*1920*2,dy*1920*2)

local camx,camy=geo.camera_offset(f,-47,-15,2)
near(camx,0.5-(-47*f.scale/f.width)*2)
near(camy,0.5-(-15*f.scale/f.height)*2)
local nonSquareX,nonSquareY=geo.camera_offset(wide,90,45,1)
near(nonSquareX,0.5-90*wide.scale/(wide.width*wide.xaspect))
near(nonSquareY,0.5-45*wide.scale/(wide.height*wide.yaspect))

local seam=geo.split_line({170,0,-170,10},false)
assert(#seam==2 and seam[1][#seam[1]-1]==180 and seam[2][1]==-180)
near(seam[1][#seam[1]],5);near(seam[2][2],5)
local reverse=geo.split_line({-170,-10,170,10},false)
assert(#reverse==2 and reverse[1][#reverse[1]-1]==-180 and reverse[2][1]==180)
near(reverse[1][#reverse[1]],0)
local simple=geo.split_line({-50,0,-49,1,-48,2},false)
assert(#simple==1 and #simple[1]==6)

local pieces=geo.clip_ring({170,-10,-170,-10,-170,10,170,10})
assert(#pieces==2,"seam polygon should split into two bounded rings")
for _,p in ipairs(pieces) do
  for i=1,#p,2 do assert(p[i]>=-180 and p[i]<=180) end
end
local ordinary=geo.clip_ring({-50,-10,-40,-10,-40,10,-50,10})
assert(#ordinary==1 and #ordinary[1]==8)

local moves,lines,closes=0,0,0
Shape=function()
  return {
    MoveTo=function(_,x,y) moves=moves+1 end,
    LineTo=function(_,x,y) lines=lines+1 end,
    Close=function(_) closes=closes+1 end
  }
end
geo.fill_shape({{-50,-10,-40,-10,-40,10,-50,10}},f)
assert(moves==1 and lines==3 and closes==1)
geo.line_shape({{170,0,-170,10}},f,false)
assert(moves==3 and lines==5 and closes==1)

for _,call in ipairs({
  function()geo.frame(0,1)end,
  function()geo.project(f,181,0)end,
  function()geo.clip_ring({1,2,3,4})end
}) do
  local ok=pcall(call)
  assert(not ok,"invalid geometry must fail closed")
end
print("render_geometry: PASS HD/QHD/4K, aspect, seam split/clip, invalid inputs")

-- Preserve the opposite winding of polygon holes. The host must still verify
-- Fusion's actual ShapeFill rasterization with nonzero winding and alpha.
local function signed_area(flat)
  local result=0
  for i=1,#flat,2 do
    local j=i+2
    if j>#flat then j=1 end
    result=result+flat[i]*flat[j+1]-flat[j]*flat[i+1]
  end
  return result/2
end
local outer=geo.clip_ring({-50,-10,-40,-10,-40,10,-50,10})
local hole=geo.clip_ring({-49,-5,-49,5,-41,5,-41,-5})
assert(#outer==1 and #hole==1)
assert(signed_area(outer[1])*signed_area(hole[1])<0,
  "polygon hole orientation must survive clipping")

local beforeMoves,beforeCloses=moves,closes
geo.fill_shape({{170,-10,-170,-10,-170,10,170,10}},f)
assert(moves==beforeMoves+2 and closes==beforeCloses+2,
  "dateline-crossing polygon must have two independent bounded fill contours")
print("render_geometry: PASS polygon hole winding and dateline fill contours")

-- Pure framing plan for exact diagnostic actors; no rendering/LOD overrides.
local M={Version=1}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
function M.Plan(rows,width,height,ground)
 if not(finite(width)and finite(height)and width>0 and height>0)then return nil,'viewport_missing'end
 if type(rows)~='table'or #rows==0 then return nil,'seed_positions_missing'end
 local lo={math.huge,math.huge,math.huge};local hi={-math.huge,-math.huge,-math.huge}
 for _,r in ipairs(rows)do
  if not(finite(r.x)and finite(r.y)and finite(r.z)and finite(r.radius)and r.radius>0)then return nil,'native_seed_geometry_missing'end
  for a,key in ipairs({'x','y','z'})do lo[a]=math.min(lo[a],r[key]-r.radius);hi[a]=math.max(hi[a],r[key]+r.radius)end
  -- Real ordinary MOVE endpoints are framing inputs, not hypothetical teleports.
  if r.move then
   for a=1,3 do if not finite(r.move[a])then return nil,'native_move_endpoint_missing'end end
   lo[1]=math.min(lo[1],r.move[1]-r.radius);hi[1]=math.max(hi[1],r.move[1]+r.radius)
   lo[2]=math.min(lo[2],r.move[2]-r.radius);hi[2]=math.max(hi[2],r.move[2]+r.radius)
   lo[3]=math.min(lo[3],r.move[3]-r.radius);hi[3]=math.max(hi[3],r.move[3]+r.radius)
  end
 end
 local cx,cz=(lo[1]+hi[1])/2,(lo[3]+hi[3])/2
 local good,base=pcall(ground,cx,cz)
 if not good or not finite(base)then return nil,'native_camera_ground_missing'end
 base=math.max(0,base) -- OverheadController uses GetHeightAboveWater.
 local tan=math.tan(math.pi/8);local margin=48
 local altitude=math.max((hi[1]-lo[1])/2/(tan*width/height),(hi[3]-lo[3])/2/tan)*1.12+math.max(0,hi[2]-base)+margin/tan
 local angle=.01
 return{camera={mode=1,name='ta',px=cx,py=base,pz=cz,height=math.max(60,altitude),angle=angle,flipped=-1,fov=45},
  bounds={min=lo,max=hi},viewport={width=width,height=height},expectedRender={cx,base+math.cos(angle)*math.max(60,altitude),cz+math.sin(angle)*math.max(60,altitude)}}
end
return M

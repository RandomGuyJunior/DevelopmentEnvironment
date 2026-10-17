-- Conservative full native-volume swept sphere. No collision/terrain setters.
local M={}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function radius(sx,sy,sz,ox,oy,oz,kind)
 if not(finite(sx)and finite(sy)and finite(sz)and finite(ox)and finite(oy)and finite(oz))or sx<=0 or sy<=0 or sz<=0 then return end
 local r=(kind==3 and sx==sy and sy==sz)and sx*.5 or math.sqrt(sx*sx+sy*sy+sz*sz)*.5
 return r+math.sqrt(ox*ox+oy*oy+oz*oz)
end
function M.New(S)
 assert(S.GetAllUnits and S.GetAllFeatures and S.GetUnitCollisionVolumeData and S.GetFeatureCollisionVolumeData,'Native whole-volume inventory required')
 local function body(id,feature)
  local getPos=feature and S.GetFeaturePosition or S.GetUnitPosition
  local getVolume=feature and S.GetFeatureCollisionVolumeData or S.GetUnitCollisionVolumeData
  local x,y,z,mx,my,mz=getPos(id,true)
  local sx,sy,sz,ox,oy,oz,kind,_,_,disabled=getVolume(id)
  if disabled==true then return false end
  if disabled~=false or type(kind)~='number'or kind<0 or kind>3 then return nil end
  local r=radius(sx,sy,sz,ox,oy,oz,kind)
  if not r or not(finite(mx)and finite(my)and finite(mz))then return nil end
  return {x=mx,y=my,z=mz,r=r,base={x,y,z}}
 end
 local function distance(x,y,z,a,b)
  local dx,dy,dz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
  local n=dx*dx+dy*dy+dz*dz
  local t=n==0 and 0 or math.max(0,math.min(1,((x-a[1])*dx+(y-a[2])*dy+(z-a[3])*dz)/n))
  return (x-a[1]-dx*t)^2+(y-a[2]-dy*t)^2+(z-a[3]-dz*t)^2
 end
 return function(id,x0,y0,z0,x1,y1,z1)
  if not(finite(x0)and finite(y0)and finite(z0)and finite(x1)and finite(y1)and finite(z1))then return false,'position_unknown'end
  local p=body(id,false);if not p then return false,'moving_volume_unknown'end
  local a={p.x+x0-p.base[1],p.y+y0-p.base[2],p.z+z0-p.base[3]}
  local b={p.x+x1-p.base[1],p.y+y1-p.base[2],p.z+z1-p.base[3]}
  local h=S.GetGroundHeight(x1,z1);if not finite(h)or y1<h then return false,'terrain'end
  for _,feature in ipairs({false,true})do
   local list=feature and S.GetAllFeatures()or S.GetAllUnits()
   if type(list)~='table'then return false,'inventory_unknown'end
   for _,other in ipairs(list)do if feature or other~=id then
    local q=body(other,feature)
    if q==nil then return false,'blocking_volume_unknown' end
    if q and distance(q.x,q.y,q.z,a,b)<=(p.r+q.r)^2 then return false,feature and 'possible_feature_intersection'or 'possible_unit_intersection',other end
   end end
  end
  return true
 end
end
return M

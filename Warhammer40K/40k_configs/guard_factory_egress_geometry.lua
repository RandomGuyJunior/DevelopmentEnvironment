-- Read-only conservative horizontal union of actual native yard and collision.
-- ComposeMatrix uses -right/up/front; collider offsets are midPos-relative.
local M={}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
function M.Envelope(S,D,id)
 if type(S.GetUnitCollisionVolumeData)~='function'or type(S.GetUnitVectors)~='function'then return nil,'missing_collision_api'end
 local d=D[S.GetUnitDefID(id)];if not d or not finite(d.xsize)or not finite(d.zsize)or d.xsize<=0 or d.zsize<=0 then return nil,'missing_definition'end
 local x,y,z,mx,my,mz=S.GetUnitPosition(id,true)
 local sx,sy,sz,ox,oy,oz=S.GetUnitCollisionVolumeData(id)
 local front,up,right=S.GetUnitVectors(id)
 local values={x,y,z,mx,my,mz,sx,sy,sz,ox,oy,oz};for i=1,12 do if not finite(values[i])then return nil,'invalid_geometry'end end
 if not finite(mx)or not finite(mz)or not finite(ox)or not finite(oz)or not sx or sx<=0 or not sy or sy<=0 or not sz or sz<=0 then return nil,'invalid_geometry'end
 if not front or not up or not right then return nil,'missing_vectors'end
 for _,v in ipairs({front,up,right})do for i=1,3 do if not finite(v[i])then return nil,'invalid_vectors'end end
  if math.abs(v[1]^2+v[2]^2+v[3]^2-1)>.01 then return nil,'invalid_vectors'end
 end
 local cx=mx-right[1]*ox+up[1]*oy+front[1]*oz
 local cz=mz-right[3]*ox+up[3]*oy+front[3]*oz
 local hx=math.abs(right[1])*sx/2+math.abs(up[1])*sy/2+math.abs(front[1])*sz/2
 local hz=math.abs(right[3])*sx/2+math.abs(up[3])*sy/2+math.abs(front[3])*sz/2
 local yardX,yardZ=d.xsize*4,d.zsize*4;local facing=S.GetUnitBuildFacing(id)or 0
 if facing%2==1 then yardX,yardZ=yardZ,yardX end
 return{minX=math.min(x-yardX,cx-hx),maxX=math.max(x+yardX,cx+hx),minZ=math.min(z-yardZ,cz-hz),maxZ=math.max(z+yardZ,cz+hz),
  collider={sx,sy,sz,ox,oy,oz},midpoint={mx,my,mz},yard={yardX,yardZ},facing=facing}
end
function M.Outside(S,D,factory,body)
 local parent,reason=M.Envelope(S,D,factory);if not parent then return nil,reason end
 local child,why=M.Envelope(S,D,body);if not child then return nil,why end
 local clear=child.maxX<parent.minX or child.minX>parent.maxX or child.maxZ<parent.minZ or child.minZ>parent.maxZ
 return clear,{parent=parent,child=child}
end
return M

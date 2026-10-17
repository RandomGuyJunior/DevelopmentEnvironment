-- Native legal endpoint selection only; actual commanded movement proves egress later.
local M={}
function M.Plan(S,D,child,producer,mapX,mapZ)
 local def=S.GetUnitDefID(child);local pd=S.GetUnitDefID(producer);local d,p=D[def],D[pd]
 local x,y,z=S.GetUnitPosition(child);local fx,fy,fz=S.GetUnitPosition(producer)
 local w={child=child,producer=producer,childDefinition=def,producerDefinition=pd,childPosition={x,y,z},producerPosition={fx,fy,fz},tries={},nativePathProof=false}
 if not d or not p or not x or not z or not fx or not fz then return nil,w,'actual_native_actor_metadata_missing' end
 local sx,sy,sz,ox,oy,oz=S.GetUnitCollisionVolumeData(producer)
 if type(sx)~='number'or type(sz)~='number'or sx<=0 or sz<=0 or type(ox)~='number'or type(oz)~='number'then return nil,w,'actual_parent_volume_missing'end
 w.parentVolume={sx,sy,sz,ox,oy,oz};w.parentFootprint={p.xsize,p.zsize}
 local rx=math.max(sx/2,(p.xsize or 0)*4);local rz=math.max(sz/2,(p.zsize or 0)*4)
 local margin=math.max((d.xsize or 0)*4,(d.zsize or 0)*4,32)
 local function try(xx,zz,label)
  local yy=S.GetGroundHeight(xx,zz);local bounds=xx>=96 and zz>=96 and xx<=mapX-96 and zz<=mapZ-96
  local exterior=math.abs(xx-(fx+ox))>rx+margin or math.abs(zz-(fz+oz))>rz+margin
  local displacement=(xx-x)^2+(zz-z)^2>=180^2
  local legal=false
  local airWitness,airReason
  if bounds and exterior and displacement then
   if d.canFly then
    local candidate;candidate,airWitness,airReason=VFS.Include('40k_configs/paid_air_endpoint_review.lua').Check(S,D,child,xx,zz,mapX,mapZ)
    legal=candidate~=nil;if candidate then yy=candidate[2]end
   else legal=S.TestMoveOrder(def,xx,yy,zz,0,0,0,true,true,false)==true end
  end
  w.tries[#w.tries+1]={x=xx,y=yy,z=zz,label=label,inBounds=bounds,outsideParent=exterior,childDisplacement=displacement,nativeMoveLegal=not d.canFly and legal or nil,airEndpointLegal=d.canFly and legal or nil,airReason=airReason,airVolume=airWitness}
  if legal then return {xx,yy,zz}end
 end
 -- Preserve former endpoint as first candidate when truly legal/exterior.
 local goal=try(fx+220,fz+300,'original')
 if goal then return goal,w end
 for _,distance in ipairs({320,400,480,560})do
  for _,direction in ipairs({{1,0},{0,1},{-1,0},{0,-1},{1,1},{-1,1},{-1,-1},{1,-1}})do
   local scale=direction[1]~=0 and direction[2]~=0 and math.sqrt(.5)or 1
   goal=try(fx+direction[1]*distance*scale,fz+direction[2]*distance*scale,'finite_exterior')
   if goal then return goal,w end
  end
 end
 return nil,w,'all_33_native_exterior_endpoints_refused'
end
return M

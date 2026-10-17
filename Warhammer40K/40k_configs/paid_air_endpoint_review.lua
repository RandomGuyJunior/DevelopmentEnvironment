-- Scoped native aircraft endpoint geometry audit; not a ground-path admission API.
local M={}
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
function M.Check(S,D,id,x,z,mapX,mapZ)
 local d=D[S.GetUnitDefID(id)];local w={id=id,x=x,z=z,policy='native_air_volume_endpoint_v1',nativeFlightAccepted=false}
 if not d or not d.canFly or not finite(d.wantedHeight)or d.wantedHeight<=0 then return nil,w,'actual_air_definition_or_wanted_height_missing'end
 local sx,sy,sz,ox,oy,oz=S.GetUnitCollisionVolumeData(id)
 if not finite(sx)or not finite(sy)or not finite(sz)or not finite(ox)or not finite(oy)or not finite(oz)or sx<=0 or sy<=0 or sz<=0 then return nil,w,'actual_air_volume_missing'end
 local rx,ry,rz=sx/2,sy/2,sz/2;w.volume={sx,sy,sz,ox,oy,oz};w.sourceWantedHeight=d.wantedHeight
 if x+ox-rx<0 or z+oz-rz<0 or x+ox+rx>mapX or z+oz+rz>mapZ then return nil,w,'full_air_volume_outside_map'end
 local highest=-math.huge
 for _,dx in ipairs({-rx,0,rx})do for _,dz in ipairs({-rz,0,rz})do local h=S.GetGroundHeight(x+ox+dx,z+oz+dz);if not finite(h)then return nil,w,'terrain_height_unknown'end;highest=math.max(highest,h)end end
 local y=highest+d.wantedHeight
 if y+oy-ry<=highest then return nil,w,'source_cruise_height_cannot_clear_full_volume'end
 local left,right,low,high=x+ox-rx,x+ox+rx,z+oz-rz,z+oz+rz
 local bottom,top=y+oy-ry,y+oy+ry
 local function overlaps(other,isFeature)
  if not isFeature and other==id then return false end
  local block
  if isFeature then block=S.GetFeatureBlocking(other)else block=S.GetUnitBlocking(other)end
  if block==nil then return nil,'actual_solid_blocking_unknown'end
  if not block then return false end
  local ax,ay,az
  local axx,ayy,azz,aox,aoy,aoz
  if isFeature then ax,ay,az=S.GetFeaturePosition(other);axx,ayy,azz,aox,aoy,aoz=S.GetFeatureCollisionVolumeData(other)
  else ax,ay,az=S.GetUnitPosition(other);axx,ayy,azz,aox,aoy,aoz=S.GetUnitCollisionVolumeData(other)end
  local values={ax,ay,az,axx,ayy,azz,aox,aoy,aoz}
  for n=1,9 do if not finite(values[n])then return nil,'actual_solid_volume_unknown'end end
  return left<ax+aox+axx/2 and right>ax+aox-axx/2 and low<az+aoz+azz/2 and high>az+aoz-azz/2 and bottom<ay+aoy+ayy/2 and top>ay+aoy-ayy/2
 end
 -- GetAllUnits/GetAllFeatures include large volume centres outside endpoint AABB.
 local units=S.GetAllUnits();local features=S.GetAllFeatures()
 if not units or not features or #units+#features>8192 then return nil,w,'bounded_actual_solids_inventory_unavailable'end
 for _,list in ipairs({{ids=units,feature=false},{ids=features,feature=true}})do for _,other in ipairs(list.ids)do
  local hit,why=overlaps(other,list.feature);if hit==nil or hit then w.blocker=other;w.feature=list.feature;return nil,w,why or 'actual_full_volume_solid_overlap'end
 end end
 w.y=y;w.terrainHighest=highest;return {x,y,z},w
end
function M.FlightObserved(S,D,id)
 local d=D[S.GetUnitDefID(id)];if not d or not d.canFly then return false end
 local x,y,z=S.GetUnitPosition(id);local _,sy,_,_,oy=S.GetUnitCollisionVolumeData(id)
 local vx,vy,vz=S.GetUnitVelocity(id)
 return finite(x)and finite(y)and finite(z)and finite(sy)and finite(oy)and finite(vx)and finite(vy)and finite(vz)and y+oy-sy/2>S.GetGroundHeight(x,z)and vx*vx+vy*vy+vz*vz>.0025
end
function M.Target(S,D,C,id)
 local team=S.GetUnitTeam(id);local x,_,z=S.GetUnitPosition(id);local chosen,distance,bestHealth
 local function hash(h)return type(h)=='string'and #h==64 and not h:find('[^0-9a-f]')end
 for _,candidate in ipairs(S.GetAllUnits()or{})do
  local t=S.GetUnitTeam(candidate);local d=D[S.GetUnitDefID(candidate)];local cp=d and d.customParams or{};local u=C.units[candidate]
  local hp,_,_,_,built=S.GetUnitHealth(candidate)
  local opponent=GG and GG.Recoil40KPrimaryPaidOpponent
  local paid=opponent and opponent.Receipt(candidate)
  if t~=team and not S.AreTeamsAllied(team,t)and d and not d.canFly and u and u.team==t and u.finished and hp and hp>0 and built==1
   and (not opponent or paid)and tostring(cp.prototype40k)=='1'and cp.source_entity and hash(cp.source_model_sha256)and hash(cp.source_native_glb_sha256)then
   local tx,_,tz=S.GetUnitPosition(candidate);local dist=(tx-x)^2+(tz-z)^2
   -- Prefer genuinely paid high-health structures to a fragile Slugga; native HP is never altered.
   if not bestHealth or hp>bestHealth or hp==bestHealth and(dist<distance or dist==distance and candidate<chosen)then chosen,distance,bestHealth=candidate,dist,hp end
  end
 end
 return chosen,distance
end
return M

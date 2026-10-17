-- Read-only paid test placement gates. Enclosing native-volume spheres are
-- conservative: separation proves clearance; overlap never proves collision.
local M={}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function envelope(S,id,feature)
 local pos=feature and S.GetFeaturePosition or S.GetUnitPosition
 local volume=feature and S.GetFeatureCollisionVolumeData or S.GetUnitCollisionVolumeData
 if type(pos)~='function'or type(volume)~='function'then return nil,'volume_api_missing' end
 local okay,x,y,z,mx,my,mz=pcall(pos,id,true,true)
 local good,sx,sy,sz,ox,oy,oz=pcall(volume,id)
 if not okay or not good then return nil,'volume_read_failed'end
 local values={x,y,z,mx,my,mz,sx,sy,sz,ox,oy,oz}
 for i=1,12 do if not finite(values[i])then return nil,'volume_incomplete'end end
 -- Explicit count avoids ipairs stopping at a missing field.
 if not(finite(mx)and finite(my)and finite(mz)and finite(sx)and finite(sy)and finite(sz)and finite(ox)and finite(oy)and finite(oz))then return nil,'volume_incomplete'end
 if sx<=0 or sy<=0 or sz<=0 then return nil,'volume_nonpositive'end
 local radius=math.sqrt(sx*sx+sy*sy+sz*sz)/2
 if not feature and type(S.GetUnitVectors)=='function'then
  local ok,front,up,right=pcall(S.GetUnitVectors,id)
  if ok and type(front)=='table'and type(up)=='table'and type(right)=='table'then
   for a=1,3 do if not(finite(front[a])and finite(up[a])and finite(right[a]))then return nil,'vectors_incomplete'end end
   mx,my,mz=mx+right[1]*ox+up[1]*oy+front[1]*oz,my+right[2]*ox+up[2]*oy+front[2]*oz,mz+right[3]*ox+up[3]*oy+front[3]*oz
  else return nil,'vectors_unreadable'end
 else radius=radius+math.sqrt(ox*ox+oy*oy+oz*oz)end
 return {mx,my,mz,radius}
end
function M.Clearance(S,id,producer,at)
 local remaining
 local a,why=envelope(S,id,false);if not a then return false,why end
 if at then
  local x,y,z=S.GetUnitPosition(id)
  if not(finite(x)and finite(y)and finite(z)and finite(at[1])and finite(at[2])and finite(at[3]))then return false,'translated_site_missing'end
  a={a[1]+at[1]-x,a[2]+at[2]-y,a[3]+at[3]-z,a[4]}
 end
 if type(S.GetAllUnits)~='function'or type(S.GetAllFeatures)~='function'then return false,'collision_inventory_missing',remaining end
 local units=S.GetAllUnits();local features=S.GetAllFeatures()
 if type(units)~='table'or type(features)~='table'then return false,'collision_inventory_unreadable',remaining end
 local seen=false
 for _,kind in ipairs({'unit','feature'})do
  local ids=kind=='unit'and units or features;table.sort(ids)
  for _,other in ipairs(ids)do if kind=='feature'or other~=id then
   if kind=='unit'and other==producer then seen=true end
   local b,err=envelope(S,other,kind=='feature');if not b then return false,err,remaining,kind,other end
   local gap=math.sqrt((a[1]-b[1])^2+(a[2]-b[2])^2+(a[3]-b[3])^2)-a[4]-b[4]
   if gap<=0 then return false,'conservative_native_envelopes_overlap',remaining,kind,other,gap end
  end end
 end
 if not seen then return false,'producer_collision_missing',remaining end
 return true,'full_native_envelope_separation',remaining
end
function M.Exit(S,id,producer,target)
 if type(target)~='table'or not(finite(target[1])and finite(target[3]))then return false,'exit_target_missing'end
 local x,_,z=S.GetUnitPosition(id)
 if not(finite(x)and finite(z))then return false,'actor_position_missing'end
 local remaining=math.sqrt((x-target[1])^2+(z-target[3])^2)
 if remaining>24 then return false,'ordered_exit_not_reached',remaining end
 local ok,why,_,kind,other,gap=M.Clearance(S,id,producer)
 return ok,why,remaining,kind,other,gap
end
function M.Movement(S,id,producer,target)
 local out={}
 local good,row=pcall(function()
  local x,y,z=S.GetUnitPosition(id);local vx,vy,vz,speed=S.GetUnitVelocity(id)
  local cmd,options,tag,cx,cy,cz=S.GetUnitCurrentCommand(id)
  local move=type(S.GetUnitMoveTypeData)=='function'and S.GetUnitMoveTypeData(id)or nil
  local clear,why,_,kind,blocker,gap=M.Clearance(S,id,producer)
  return {actor=id,producer=producer,position={x,y,z},velocity={vx,vy,vz},speed=speed,command=cmd,tag=tag,commandPosition={cx,cy,cz},move=move,
   fullClear=clear,clearReason=why,blockKind=kind,blocker=blocker,gap=gap,
   remaining=finite(x)and finite(z)and math.sqrt((x-target[1])^2+(z-target[3])^2)or nil}
 end)
 if good then return row end;return {error='movement_readback_failed'}
end
local function sameTarget(a,b,tolerance)
 return type(a)=='table'and type(b)=='table'and finite(a[1])and finite(a[2])and finite(a[3])and finite(b[1])and finite(b[2])and finite(b[3])
  and math.abs(a[1]-b[1])<=tolerance and math.abs(a[2]-b[2])<=tolerance and math.abs(a[3]-b[3])<=tolerance
end
function M.Witness(row,target,frame,moveCommand)
 local m=row.move
 if row.error or row.command~=moveCommand or not finite(row.tag)or row.tag<0 or not finite(frame)or not sameTarget(row.commandPosition,target,.01)
  or type(m)~='table'or not(finite(m.goalx)and finite(m.goalz))or math.abs(m.goalx-target[1])>.5 or math.abs(m.goalz-target[3])>.5 then return nil end
 if not finite(row.actor)or not finite(row.producer)then return nil end
 return{actor=row.actor,producer=row.producer,tag=row.tag,frame=frame,target={target[1],target[2],target[3]}}
end
function M.RetryReady(row,target,age,stationaryFrames,moveCommand,proof,frame)
 if row.error or not finite(row.speed)or row.speed>=.001 or age<900 or stationaryFrames<300 or not finite(row.remaining)or row.remaining<=24 then return false end
 local m=row.move
 if type(m)~='table'or(m.progressState~='done'and m.progressState~='failed')or not(finite(m.goalx)and finite(m.goalz))then return false end
 if type(proof)~='table'or proof.actor~=row.actor or proof.producer~=row.producer or not finite(proof.tag)or proof.tag<0 or not finite(proof.frame)
  or not finite(frame)or frame<=proof.frame or not sameTarget(proof.target,target,.01)then return false end
 local originalGoal=math.abs(m.goalx-target[1])<=.5 and math.abs(m.goalz-target[3])<=.5
 local p=row.position
 local stoppedHere=type(p)=='table'and finite(p[1])and finite(p[3])and math.abs(m.goalx-p[1])<=.5 and math.abs(m.goalz-p[3])<=.5
 if row.command~=nil then
  if row.command~=moveCommand or row.tag~=proof.tag or not sameTarget(row.commandPosition,target,.01)or not originalGoal then return false end
 elseif not(originalGoal or stoppedHere)then return false end
 return true
end
function M.Alternate(S,Game,id,producer,failed,used)
 if type(S.TestMoveOrder)~='function'then return nil,'native_passability_api_missing'end
 local def=S.GetUnitDefID(id);local x,_,z=S.GetUnitPosition(id);local choices={}
 for ring=1,2 do for i=0,7 do
  local angle=i*math.pi/4;local xx,zz=failed[1]+ring*96*math.cos(angle),failed[3]+ring*96*math.sin(angle)
  local key=math.floor(xx/8)..':'..math.floor(zz/8);local y=S.GetGroundHeight(xx,zz)
  if not used[key]and finite(y)and y>0 and xx>48 and zz>48 and xx<Game.mapSizeX-48 and zz<Game.mapSizeZ-48 then
   local okay,status=pcall(S.TestMoveOrder,def,xx,y,zz,0,0,0,true,true,false)
   if okay and status==true and M.Clearance(S,id,producer,{xx,y,zz})then
    choices[#choices+1]={xx,y,zz,key=key,distance=(xx-x)^2+(zz-z)^2,order=ring*8+i}
   end
  end
 end end
 table.sort(choices,function(a,b)if a.distance~=b.distance then return a.distance<b.distance end;return a.order<b.order end)
 return choices[1],choices[1]and 'native_passable_conservative_site_not_arrival_proof'or 'no_native_passable_clear_alternate'
end
function M.Ground(S,D,W,id,target)
 if not(type(target)=='table'and finite(target[1])and finite(target[2])and finite(target[3]))then return false,'target_missing'end
 local d=D[S.GetUnitDefID(id)];if not d then return false,'actor_definition_missing'end
 local us=S.UnitScript
 if not(us and type(us.GetScriptEnv)=='function'and type(us.CallAsUnit)=='function'and type(S.GetUnitPiecePosDir)=='function')then return false,'query_api_missing'end
 local ok,env=pcall(us.GetScriptEnv,id);local query=ok and env and env.script and env.script.QueryWeapon
 if type(query)~='function'then return false,'query_weapon_missing'end
 local count=0
 for n,mount in ipairs(d.weapons or{})do
  local w=W[mount.weaponDef or mount.weaponDefID]
  if w and w.type~='Melee'and w.type~='Shield'and tostring((w.customParams or{}).source_passive)~='1'then
   count=count+1
   local good,piece=pcall(us.CallAsUnit,id,query,n)
   if not good or not finite(piece)then return false,'query_weapon_unreadable',n end
   local read,mx,my,mz=pcall(S.GetUnitPiecePosDir,id,piece)
   if not read or not(finite(mx)and finite(my)and finite(mz))then return false,'query_marker_position_missing',n,piece end
   for _,entry in ipairs({{'GetUnitWeaponTestTarget','target'},{'GetUnitWeaponTestRange','range'}})do
    if type(S[entry[1]])~='function'then return false,entry[2]..'_api_missing',n,piece end
    local success,value=pcall(S[entry[1]],id,n,target[1],target[2],target[3])
    if not success or value~=true then return false,'native_'..entry[2]..'_refused',n,piece end
   end
   if type(S.GetUnitWeaponHaveFreeLineOfFire)~='function'then return false,'lof_api_missing',n,piece end
   local success,value=pcall(S.GetUnitWeaponHaveFreeLineOfFire,id,n,mx,my,mz,target[1],target[2],target[3])
   if not success or value~=true then return false,'returned_marker_native_lof_refused',n,piece,mx,my,mz end
  end
 end
 return count>0,count>0 and 'all_actual_ranged_markers_native_clear'or 'no_ranged_mounts',count
end
return M

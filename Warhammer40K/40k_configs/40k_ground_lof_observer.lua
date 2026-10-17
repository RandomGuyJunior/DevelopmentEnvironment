-- Opt-in read-only cannon evidence. Estimates are never native obstruction IDs.
local M={Version=2}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function point(x,y,z)if finite(x)and finite(y)and finite(z)then return{x,y,z}end end
local function length(v)return math.sqrt(v[1]*v[1]+v[2]*v[2]+v[3]*v[3])end
local function distance(a,b)return length({a[1]-b[1],a[2]-b[2],a[3]-b[3]})end
local function call(S,name,...)
 if type(S[name])~='function'then return nil,'api_missing:'..name end
 local row={pcall(S[name],...)};if not row[1]then return nil,'read_failed:'..name end
 table.remove(row,1);return row
end
local function volume(values)
 if not values or not finite(values[1])or not finite(values[6])then return nil end
 return{scales={values[1],values[2],values[3]},offsets={values[4],values[5],values[6]},type=values[7],continuous=values[8],primary_axis=values[9],ignore_hits=values[10]}
end
local function object(S,kind,id)
 local feature=kind=='feature';local name=feature and'Feature'or'Unit'
 local pos,err=call(S,'Get'..name..'Position',id,true,true)
 local v,ve=call(S,'Get'..name..'CollisionVolumeData',id)
 local r={id=id,kind=kind,position_error=err,volume_error=ve,collision=volume(v)}
 if pos then r.position=point(pos[1],pos[2],pos[3]);r.midpoint=point(pos[4],pos[5],pos[6])end
 if feature then
  local heading=call(S,'GetFeatureHeading',id);r.heading=heading and heading[1]
  local rotation=call(S,'GetFeatureRotation',id);r.rotation=rotation
 else
  local heading=call(S,'GetUnitHeading',id);r.heading=heading and heading[1]
  local def=call(S,'GetUnitDefID',id);r.def=def and def[1]
  local team=call(S,'GetUnitTeam',id);r.team=team and team[1]
  local vectors=call(S,'GetUnitVectors',id);r.vectors=vectors
  if r.midpoint and r.collision and vectors and type(vectors[1])=='table'and type(vectors[2])=='table'and type(vectors[3])=='table'then
   local front,up,right=vectors[1],vectors[2],vectors[3];local o=r.collision.offsets;r.collision_center={}
   for axis=1,3 do r.collision_center[axis]=r.midpoint[axis]+front[axis]*o[3]+right[axis]*o[1]+up[axis]*o[2]end
   r.center_semantics='native midpoint plus current object-space offset vectors'
  end
 end
 if r.collision then
  r.bounding_radius=length(r.collision.scales)*.5
  if not r.collision_center and r.midpoint then
   r.collision_center=r.midpoint;r.bounding_radius=r.bounding_radius+length(r.collision.offsets)
   r.center_semantics='midpoint sphere expanded by full offset length; rotation unavailable'
  end
 end
 return r
end
-- Double source-equation estimate. Native float/fast-sqrt trajectory and
-- approximate terrain are not exposed; this cannot reproduce native decisions.
function M.Estimate(src,target,speed,gravity,high)
 if not src or not target or not finite(speed)or speed<=0 or not finite(gravity)or(high~=0 and high~=1)then return nil end
 local x,y,z=target[1]-src[1],target[2]-src[2],target[3]-src[3];local d2=x*x+z*z;local ds=d2+y*y;local dxz=math.sqrt(d2)
 if dxz==0 or ds>=1e12 or math.abs(y)>=1e6 then return nil end
 local v2=speed*speed;local a=v2*v2+2*v2*gravity*y-gravity*gravity*d2
 if a<0 then return nil end
 local b=2*d2*ds*(v2+gravity*y+(high==1 and-1 or 1)*math.sqrt(a));if b<0 then return nil end
 local vxz=math.sqrt(b)/(2*ds);local vy=vxz==0 and speed or(vxz*y/dxz-dxz*gravity/(2*vxz));local n=math.sqrt(vxz*vxz+vy*vy)
 if n==0 then return nil end
 local horizontal=math.max(.001,speed*vxz/n);local vertical=speed*vy/n
 return{distance=dxz,dx=x/dxz,dz=z/dxz,linear=(vertical+gravity*.5)/horizontal,quadratic=(gravity*.5)/(horizontal*horizontal),ground_check_distance=math.max(10,.9375*dxz),gravity=gravity,speed=speed,high=high,semantics='pinned source equations in Lua double; not actual native coefficients'}
end
local function path(src,c,d)return{src[1]+c.dx*d,src[2]+c.linear*d+c.quadratic*d*d,src[3]+c.dz*d}end
local function chordDistance(p,a,b)
 local v={b[1]-a[1],b[2]-a[2],b[3]-a[3]};local vv=length(v)^2
 local t=vv==0 and 0 or math.max(0,math.min(1,((p[1]-a[1])*v[1]+(p[2]-a[2])*v[2]+(p[3]-a[3])*v[3])/vv))
 return distance(p,{a[1]+v[1]*t,a[2]+v[2]*t,a[3]+v[3]*t})
end
function M.Snapshot(S,defs,weapons,game,id,n,options)
 options=options or{};if options.enabled~=true then return nil,'diagnostic_disabled' end
 local out={version=M.Version,actor=object(S,'unit',id),weapon=n,exact_cause='unavailable_native_API',limits={},nearby={},samples={},unreadable_objects={}}
 local frame=call(S,'GetGameFrame');out.frame=frame and frame[1]
 local command=call(S,'GetUnitCommands',id,1);local head=command and command[1]and command[1][1]
 out.command=head
 if not head or head.id~=(options.attackCommand or 20)or not head.params or #head.params~=3 then return out,'no_real_ground_attack_head' end
 out.target=point(unpack(head.params));if not out.target then return out,'invalid_native_ground_target' end
 local vectors=call(S,'GetUnitWeaponVectors',id,n);out.muzzle=vectors and point(vectors[1],vectors[2],vectors[3]);out.wanted_direction=vectors and point(vectors[4],vectors[5],vectors[6])
 local wd=defs[out.actor.def];local slot=wd and wd.weapons and wd.weapons[n];local w=slot and weapons[slot.weaponDef];out.weapon_definition=slot and slot.weaponDef
 out.projectile_speed=(call(S,'GetUnitWeaponState',id,n,'projectileSpeed')or{})[1]
 out.accuracy=(call(S,'GetUnitWeaponState',id,n,'accuracy')or{})[1];out.spray_angle=(call(S,'GetUnitWeaponState',id,n,'sprayAngle')or{})[1]
 out.spread=finite(out.accuracy)and finite(out.spray_angle)and(out.accuracy+out.spray_angle)*.6*.9 or nil
 out.weapon_target=call(S,'GetUnitWeaponTarget',id,n)
 local pivotPiece=options.pivotPiece
 if options.readScriptAimFrom==true then
  -- Only the audited pure AimFromWeapon query, never AimWeapon/Shot or a setter.
  local us=S.UnitScript
  if us and type(us.GetScriptEnv)=='function'and type(us.CallAsUnit)=='function'then
   local okay,env=pcall(us.GetScriptEnv,id);local query=okay and env and env.script and env.script.AimFromWeapon
   if type(query)=='function'then local good,piece=pcall(us.CallAsUnit,id,query,n)
    if good and finite(piece)then pivotPiece=piece;out.pivot_source='actual current script AimFromWeapon return; native cached origin not exposed'
    else pivotPiece=nil;out.pivot_error='script_aim_query_failed'end
   else pivotPiece=nil;out.pivot_error='script_aim_query_missing'end
  else pivotPiece=nil;out.pivot_error='unit_script_query_api_missing'end
 end
 if pivotPiece~=nil then local p=call(S,'GetUnitPiecePosDir',id,pivotPiece);out.pivot=p and point(p[1],p[2],p[3]);out.pivot_piece=pivotPiece end
 for _,kind in ipairs({'muzzle','pivot'})do if out[kind]then local src=out[kind]
  out[kind..'_native_lof']=(call(S,'GetUnitWeaponHaveFreeLineOfFire',id,n,src[1],src[2],src[3],out.target[1],out.target[2],out.target[3])or{})[1]
 end end
 if not out.muzzle or not w then return out,'missing_muzzle_or_native_weapon_definition' end
 local fps=game.gameSpeed;local gravity=finite(w.myGravity)and w.myGravity~=0 and-w.myGravity or(finite(game.gravity)and finite(fps)and fps>0 and-game.gravity/(fps*fps)or nil)
 local high=w.highTrajectory
 out.trajectory_policy=high
 if high==2 then
  local states=call(S,'GetUnitStates',id);local state=states and states[1]
  local highState=type(state)=='table'and state.trajectory
  if type(highState)=='boolean'then high=highState and 1 or 0;out.trajectory_state=highState
  else high=nil;out.trajectory_error='dynamic_native_trajectory_state_unavailable'end
  out.limits[#out.limits+1]='Dynamic unit trajectory toggle is a native readback; Cannon caches it at SlowUpdate, so a just-changed toggle can temporarily differ.'
 end
 out.effective_trajectory_estimate=high
 out.avoid_flags=(call(S,'GetUnitWeaponState',id,n,'avoidFlags')or{})[1]
 out.estimate=M.Estimate(out.muzzle,out.target,out.projectile_speed,gravity,high)
 out.weapon_flags={avoidFriendly=w.avoidFriendly,avoidFeature=w.avoidFeature,avoidNeutral=w.avoidNeutral,avoidGround=w.avoidGround,collideFriendly=w.collideFriendly,collideGround=w.collideGround}
 local c=out.estimate;if not c then return out,'trajectory_estimate_unavailable' end
 local step=options.step or 8;if not finite(step)or step<8 then step=8 end
 local cap=options.maxSamples;if not finite(cap)or cap<1 then cap=128 end;cap=math.min(256,math.floor(cap));local dist=0
 while dist<c.ground_check_distance and #out.samples<cap do
  local p=path(out.muzzle,c,dist);local ground,err=call(S,'GetGroundHeight',p[1],p[3]);local h=ground and ground[1]
  out.samples[#out.samples+1]={distance=dist,position=p,ground_real=h,clearance=finite(h)and p[2]-h or nil,error=err}
  dist=dist+step
 end
 out.sample_truncated=dist<c.ground_check_distance
 out.limits[#out.limits+1]='GroundHeight is real terrain; native rejection uses GetApproximateHeight and float32/fast-sqrt coefficients.'
 local allUnits,ue=call(S,'GetAllUnits');local allFeatures,fe=call(S,'GetAllFeatures');out.unit_inventory_error=ue;out.feature_inventory_error=fe
 local lists={{kind='unit',ids=allUnits and allUnits[1]},{kind='feature',ids=allFeatures and allFeatures[1]}}
 local limit=options.maxObjects;if not finite(limit)or limit<1 then limit=128 end;limit=math.min(256,math.floor(limit));local endPos=path(out.muzzle,c,c.distance)
 for _,list in ipairs(lists)do if type(list.ids)=='table'then table.sort(list.ids)
  for _,other in ipairs(list.ids)do if not(list.kind=='unit'and other==id)then
   local r=object(S,list.kind,other);local eligible=list.kind=='feature'
   if list.kind=='unit'then
    local allied=call(S,'AreTeamsAllied',out.actor.team,r.team);local neutral=call(S,'GetUnitNeutral',other)
    eligible=(allied and allied[1]==true)or(neutral and neutral[1]==true)
    r.allied=allied and allied[1];r.neutral=neutral and neutral[1]
   end
   local center=r.collision_center or r.position
   if eligible and not center then out.unreadable_objects[#out.unreadable_objects+1]={id=other,kind=list.kind,error='native_position_missing'}end
   if eligible and center then
    local sphere=r.bounding_radius or 0
    -- Feature midpoint/rotation may be unavailable. Include it as nearby and
    -- explicitly withhold a candidate classification rather than assume zero.
    local near=distance(center,out.muzzle)<=c.distance+sphere+128
    if near then
     if #out.nearby>=limit then out.objects_truncated=true;break end
     if r.collision_center and r.bounding_radius then
      local d=math.max(0,math.min(c.distance,(center[1]-out.muzzle[1])*c.dx+(center[3]-out.muzzle[3])*c.dz));local hit=path(out.muzzle,c,d)
      local a,b=out.muzzle,hit;if 2*c.quadratic*d+c.linear<=0 then a,b=hit,endPos end
      r.chord_sphere_distance=chordDistance(center,a,b);r.possible_blocker=r.chord_sphere_distance<=r.bounding_radius
      r.candidate_semantics='conservative enclosing sphere against estimated native-selected chord; not DetectHit or exact native cause'
     end
     out.nearby[#out.nearby+1]=r
    end
   end
  end end
 end end
 out.limits[#out.limits+1]='Native QuadMapRays collidable bits, quad selection, exact primitive/piece DetectHit and blocked object ID are not exposed; nearby objects are readbacks, not causal attribution.'
 return out
end
return M

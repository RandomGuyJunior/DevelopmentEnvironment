-- Read-only extension of the existing default-off Hellfire scene, never a fixture.
-- Only this Basilisk's declared cannons; no orders, callbacks, damage or particles.
local M={}
function M.New(S,actor,definition,weapons,game,ground,attackCommand,emit)
 local R={Weapons={},entries={},byID={},closed=false,readErrors={},overflow=0,explosionOverflow=0}
 local mounts,byWeapon={},{}
 local function read(name,...)
  if type(S[name])~='function'then R.readErrors[name]='missing';return end
  local ok,a,b,c,d,e,f=pcall(S[name],...)
  if not ok then R.readErrors[name]='read_failed';return end
  return a,b,c,d,e,f
 end
 local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
 local function point(x,y,z)if finite(x)and finite(y)and finite(z)then return{x,y,z}end end
 local function dist(a,b)if a and b then return math.sqrt((a[1]-b[1])^2+(a[2]-b[2])^2+(a[3]-b[3])^2)end end
 local function frame()return read('GetGameFrame')end
 local function log(event,row)row=row or{};row.actor=actor;row.frame=frame();emit('basilisk_'..event,row)end
 local map=read('GetUnitPieceMap',actor)or{}
 if not definition or not definition.weapons or #definition.weapons~=2 then R.refused='two_native_cannon_definitions_required'
 else for slot,entry in ipairs(definition.weapons)do
  local wid=entry.weaponDef or entry.weaponDefID;local w=weapons[wid];local cp=w and w.customParams or{}
  if not w or w.type~='Cannon'or type(cp.source_muzzle)~='string'or not map[cp.source_muzzle]or cp.source_muzzle_pair or byWeapon[wid]then
   R.refused='actual_single_cannon_muzzle_required';break
  end
  mounts[slot]={weapon=wid,piece=map[cp.source_muzzle],sourceMuzzle=cp.source_muzzle,highTrajectory=w.highTrajectory}
  byWeapon[wid]=slot;R.Weapons[#R.Weapons+1]=wid
 end end
 if R.refused then mounts={};byWeapon={};R.Weapons={}end
 function R.Begin(f)
  if R.closed or R.start then return end;R.start=f
  log('observer_begin',{revision='owned_cannon_v1',accepted=not R.refused,reason=R.refused,mounts=mounts,
   maxProjectiles=32,maxSamplesPerProjectile=64,maxExplosionsPerProjectile=4,sampleFrames=15,paidAcceptance=false,visualAcceptance=false})
 end
 function R.Projectile(pid,owner,weapon)
  if R.closed or not R.start or R.refused or owner~=actor or not byWeapon[weapon]then return end
  if #R.entries>=32 then R.overflow=R.overflow+1;return end
  local slot=byWeapon[weapon];local m=mounts[slot];local f=frame()
  local p=point(read('GetProjectilePosition',pid));local v=point(read('GetProjectileVelocity',pid))
  local muzzle=point(read('GetUnitWeaponVectors',actor,slot))
  local piece=read('GetUnitRulesParam',actor,'40k_last_muzzle_'..slot)
  local shot=read('GetUnitRulesParam',actor,'40k_last_shot_'..slot)
  local source=point(read('GetUnitPiecePosDir',actor,m.piece))
  local targetType,_,target=read('GetUnitWeaponTarget',actor,slot)
  local separation,sourceDistance=dist(p,muzzle),dist(p,source)
  local verified=shot==f and piece==m.piece and separation~=nil and separation<=.01 and sourceDistance~=nil and sourceDistance<=.01
  local e={id=pid,serial=#R.entries+1,slot=slot,weapon=weapon,birth=f,position=p,last=p,maxTravel=0,samples=0,explosions=0,originVerified=verified}
  R.entries[#R.entries+1]=e;R.byID[pid]=e
  log('projectile',{id=pid,serial=e.serial,owner=owner,weapon=weapon,slot=slot,position=p,velocity=v,muzzle=muzzle,
   sourcePosition=source,sourcePiece=m.piece,shotPiece=piece,shotFrame=shot,muzzleDistance=separation,sourceDistance=sourceDistance,
   targetType=targetType,target=target,originVerified=verified,phase=f-R.start<450 and'idle_move_window'or f-R.start<780 and'fire_window'or'return_window',
   originSemantics='actual Shot rule and current native muzzle/source marker; no AimWeapon invocation'})
 end
 function R.Tick(f)
  if R.closed or not R.start or R.refused then return end
  if f%15==0 then for _,e in ipairs(R.entries)do if not e.deleted then
   local p=point(read('GetProjectilePosition',e.id));local travel=dist(p,e.position)
   if travel then e.maxTravel=math.max(e.maxTravel,travel);e.last=p end
   if e.samples<64 then
    e.samples=e.samples+1;local h=p and read('GetGroundHeight',p[1],p[3])
    log('flight',{id=e.id,serial=e.serial,weapon=e.weapon,slot=e.slot,position=p,velocity=point(read('GetProjectileVelocity',e.id)),
     maxDistance=e.maxTravel,ground=h,clearance=p and finite(h)and p[2]-h or nil,readback=p and'observed'or'unavailable'})
   else e.samplesTruncated=true end
  end end end
  local age=f-R.start
  if age==480 or age==720 then
   for slot in ipairs(mounts)do
    local ready,reloaded,reloadFrame,salvoLeft=read('GetUnitWeaponState',actor,slot)
    local targetType,_,target=read('GetUnitWeaponTarget',actor,slot)
    log('native_gate',{slot=slot,weapon=mounts[slot].weapon,canFire=read('GetUnitWeaponCanFire',actor,slot),
     aimReady=ready,reloaded=reloaded,reloadFrame=reloadFrame,salvoLeft=salvoLeft,targetType=targetType,target=target,
     semantics='native CanFire excludes final LoF, BlockShot and resource checks'})
   end
   local defID=read('GetUnitDefID',actor);local okay,row,reason=false,nil,'native_definition_unavailable'
   if defID and ground and type(ground.Snapshot)=='function'then
    okay,row,reason=pcall(ground.Snapshot,S,{[defID]=definition},weapons,game,actor,1,
     {enabled=true,readScriptAimFrom=true,attackCommand=attackCommand,maxSamples=64,maxObjects=64})
   end
   log('ground_snapshot',{observation=okay and row or nil,reason=okay and reason or'observer_read_failed',
    semantics='native supplied-source LoF; estimated path is not an exact collision cause'})
  end
 end
 function R.Explosion(weapon,x,y,z,owner,pid)
  if R.closed or not R.start or owner~=actor then return end
  local e=R.byID[pid];if not e or e.weapon~=weapon then return end
  if e.explosions>=4 then R.explosionOverflow=R.explosionOverflow+1;return end
  e.explosions=e.explosions+1;local p=point(x,y,z);local h=p and read('GetGroundHeight',x,z)
  local clearance=p and finite(h)and y-h or nil
  log('explosion',{id=pid,serial=e.serial,owner=owner,weapon=weapon,slot=e.slot,position=p,ground=h,clearance=clearance,
   nearGround=clearance~=nil and math.abs(clearance)<=2,collisionCause='unavailable_native_API',
   semantics='owned native Explosion; ground proximity does not identify the collided object'})
 end
 function R.Deleted(pid)
  if R.closed then return end;local e=R.byID[pid];if not e or e.deleted then return end;e.deleted=true
  log('deleted',{id=pid,serial=e.serial,weapon=e.weapon,slot=e.slot,maxDistance=e.maxTravel,explosions=e.explosions,
   impactStatus=e.explosions>0 and'native_explosion_observed'or'unknown_no_explosion_callback'})
 end
 function R.Close(reason)
  if R.closed then return end
  local pending,verified,travelled,explosions,truncated={},0,0,0,0
  for _,e in ipairs(R.entries)do
   if not e.deleted then pending[#pending+1]={id=e.id,serial=e.serial,weapon=e.weapon,lastPosition=e.last,status='unknown_still_unresolved'}end
   if e.samplesTruncated then truncated=truncated+1 end
   if e.originVerified then verified=verified+1 end;if e.maxTravel>=10 then travelled=travelled+1 end;explosions=explosions+e.explosions
  end
  local status=R.refused and'refused_observation_contract'or not R.start and'unknown_window_not_reached'or #R.entries==0 and'unknown_no_owned_projectile_birth'or'observed_owned_native_projectiles'
  if R.overflow>0 or R.explosionOverflow>0 then status='refused_observation_limit'end
  log('observer_summary',{status=status,reason=R.refused or reason,births=#R.entries,verifiedOrigins=verified,travelled=travelled,
   nativeExplosions=explosions,flightSamplesTruncated=truncated,pending=pending,overflow=R.overflow,explosionOverflow=R.explosionOverflow,readErrors=R.readErrors,paidAcceptance=false,visualAcceptance=false})
  R.closed=true
 end
 return R
end
return M

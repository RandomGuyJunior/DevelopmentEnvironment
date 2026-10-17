-- Paid fixture real-unit fallback; only ordinary orders to its actual Marine.
-- Ground firing remains unaccepted. No free actors/resources/health or movement edits.
local M={}
local function sorted(a)table.sort(a);return a end
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
function M.New(S,D,W,CMD,Game,opts,team,reviewRegistry,log)
 if opts.prototype_diagnostic~='expandedproduction'or not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(opts.prototype_source_progression)or opts.prototype_source_acceptance~='imperium'then return nil end
 local R={initial={},state=nil};local fps=Game.gameSpeed or 30
 local function live(id,owner,def)
  local hp,_,_,_,built=S.GetUnitHealth(id)
  return hp and hp>0 and built and built>=1 and S.GetUnitTeam(id)==owner and S.GetUnitDefID(id)==def,hp
 end
 function R.CaptureInitial()
  if R.captured then return false end;R.captured=true
  for _,id in ipairs(sorted(S.GetAllUnits()or{}))do
   local def=S.GetUnitDefID(id);local owner=S.GetUnitTeam(id);local cp=(D[def]or{}).customParams or{}
   local marked=cp.prototype40k_vital=='commander'or cp.iscommander==true or cp.iscommander==1 or cp.iscommander=='1' or cp.iscommander=='true'
   if owner~=team and not S.AreTeamsAllied(team,owner)and marked and live(id,owner,def)then R.initial[id]={team=owner,def=def}end
  end
  return next(R.initial)~=nil
 end
 local function radius(id,feature)
  local position=feature and S.GetFeaturePosition or S.GetUnitPosition
  local volume=feature and S.GetFeatureCollisionVolumeData or S.GetUnitCollisionVolumeData
  local x,y,z,mx,my,mz=position(id,true);local sx,sy,sz,ox,oy,oz=volume(id)
  if not(finite(x)and finite(y)and finite(z)and finite(mx)and finite(my)and finite(mz)and finite(sx)and finite(sy)and finite(sz)and finite(ox)and finite(oy)and finite(oz))then return nil end
  return x,y,z,math.sqrt(sx*sx+sy*sy+sz*sz)/2+math.sqrt(ox*ox+oy*oy+oz*oz)+math.sqrt((mx-x)^2+(my-y)^2+(mz-z)^2)
 end
 local function clear(id,x,z)
  local _,_,_,own=radius(id,false);if not own then return false end
  for _,other in ipairs(S.GetAllUnits()or{})do if other~=id then
   local xx,_,zz,r=radius(other,false);if not r or (xx-x)^2+(zz-z)^2<(own+r+8)^2 then return false end
  end end
  for _,feature in ipairs(S.GetAllFeatures()or{})do
   local xx,_,zz,r=radius(feature,true);if not r or (xx-x)^2+(zz-z)^2<(own+r+8)^2 then return false end
  end
  return true
 end
 local function stance(s,frame)
  local tx,_,tz=S.GetUnitPosition(s.target);local x,_,z=S.GetUnitPosition(s.actor);local candidates={}
  for ring=1,3 do for i=0,7 do local angle=i*math.pi/4;local r=s.range*({.92,.80,.65})[ring]
   local xx,zz=tx+r*math.cos(angle),tz+r*math.sin(angle);local y=S.GetGroundHeight(xx,zz)
   local key=math.floor(xx/8)..':'..math.floor(zz/8)
   if not s.visited[key]and finite(y)and y>0 and xx>64 and zz>64 and xx<Game.mapSizeX-64 and zz<Game.mapSizeZ-64
    and (xx-x)^2+(zz-z)^2>64^2 and clear(s.actor,xx,zz)
    and S.TestMoveOrder(s.def,xx,y,zz,0,0,0,true,true,false)then candidates[#candidates+1]={xx,y,zz,key=key,distance=(xx-x)^2+(zz-z)^2}end
  end end
  table.sort(candidates,function(a,b)if a.distance~=b.distance then return a.distance<b.distance end;return a.key<b.key end)
  local pos=candidates[1];if not pos then return false,'no_dry_clear_native_stance' end
  s.visited[pos.key]=true;s.attempt=s.attempt+1;s.position=pos;s.phase='move';s.phaseFrame=frame;s.sawMoving=false;s.shot=false;s.damage=0
  S.GiveOrderToUnit(s.actor,CMD.MOVE,{pos[1],pos[2],pos[3]},{})
  log('UNIT_TARGET_NATIVE_MOVE',s.actor,s.target,s.attempt,pos[1],pos[3]);return true
 end
 function R.Begin(id,frame,groundFailed)
  if not groundFailed or not R.captured or R.state then return false,'fallback_requires_preserved_ground_failure' end
  local def=S.GetUnitDefID(id);local d=D[def]or{};local cp=d.customParams or{};local review=reviewRegistry()and reviewRegistry()[id]
  if d.name~='imp_marine'or tostring(cp.prototype40k_source_progression)~='1'or not live(id,team,def)or not review then return false,'actual_paid_marine_or_private_review_missing' end
  local range=math.huge;for _,mount in ipairs(d.weapons or{})do local w=W[mount.weaponDef or mount.weaponDefID]
   if w and w.type~='Melee'and w.type~='Shield'and tostring((w.customParams or{}).source_passive)~='1'then range=math.min(range,w.range or 0)end
  end
  if not finite(range)or range<=0 then return false,'actual_ranged_weapon_missing' end
  local x,_,z=S.GetUnitPosition(id);local targets={}
  for target,row in pairs(R.initial)do if live(target,row.team,row.def)and not S.AreTeamsAllied(team,row.team)then
   local tx,_,tz=S.GetUnitPosition(target);targets[#targets+1]={id=target,row=row,distance=(x-tx)^2+(z-tz)^2}
  end end
  table.sort(targets,function(a,b)if a.distance~=b.distance then return a.distance<b.distance end;return a.id<b.id end)
  if not targets[1]then return false,'initial_enemy_commander_missing_or_changed' end
  local t=targets[1];R.state={actor=id,def=def,target=t.id,targetDef=t.row.def,targetTeam=t.row.team,range=range,review=review,
   start=frame,visited={},attempt=0,damage=0,groundPending=true}
  log('UNIT_TARGET_INITIAL_ENEMY',id,t.id,t.row.team,t.row.def,select(2,live(t.id,t.row.team,t.row.def)))
  local okay,why=stance(R.state,frame);if not okay then R.state.failure=why end;return okay,why
 end
 local function predicates(s)
  local ally=S.GetUnitAllyTeam(s.actor);local los=S.GetUnitLosState(s.target,ally,false)or{}
  local mx,my,mz=S.GetUnitWeaponVectors(s.actor,1)
  return los.los==true,S.GetUnitWeaponTestTarget(s.actor,1,s.target)==true,S.GetUnitWeaponTestRange(s.actor,1,s.target)==true,
   mx and S.GetUnitWeaponHaveFreeLineOfFire(s.actor,1,mx,my,mz,s.target)==true,
   S.GetUnitWeaponHaveFreeLineOfFire(s.actor,1,s.target)==true,mx,my,mz
 end
 function R.Frame(frame)
  local s=R.state;if not s then return nil end;if s.failure then return false,s.failure end
  if not live(s.actor,team,s.def)or not live(s.target,s.targetTeam,s.targetDef)or S.AreTeamsAllied(team,s.targetTeam)then s.failure='unit_target_actor_or_initial_enemy_changed';return false,s.failure end
  if reviewRegistry()[s.actor]~=s.review then s.failure='private_script_review_replaced';return false,s.failure end
  if frame-s.start>18000 then s.failure='unit_target_native_timeout';return false,s.failure end
  if s.phase=='move'then
   if s.review.moving==true then s.sawMoving=true end
   local x,_,z=S.GetUnitPosition(s.actor)
   if (x-s.position[1])^2+(z-s.position[3])^2<24^2 then
    s.phase='settle';s.phaseFrame=frame;S.GiveOrderToUnit(s.actor,CMD.STOP,{},{});log('UNIT_TARGET_NATIVE_STOP',s.actor,s.target,frame)
   elseif frame-s.phaseFrame>5400 then
    if s.attempt>=24 then s.failure='unit_target_stance_attempt_limit';return false,s.failure end
    local okay,why=stance(s,frame);if not okay then s.failure=why;return false,why end
   end
  elseif s.phase=='settle'then
   local _,_,_,speed=S.GetUnitVelocity(s.actor)
   if speed and speed<.001 and s.sawMoving and s.review.moving==false and frame-s.phaseFrame>=30 then
    local los,target,range,muzzle,pivot,mx,my,mz=predicates(s)
    log('UNIT_TARGET_NATIVE_PREREQUISITES',s.actor,s.target,'los',los,'target',target,'range',range,'muzzleLOF',muzzle,'pivotLOF',pivot,'muzzleClearance',my and my-S.GetGroundHeight(mx,mz),'privateStopObserved',true)
    if los and target and range and muzzle and pivot and my>=S.GetGroundHeight(mx,mz)then
     s.phase='attack';s.phaseFrame=frame;s.attackHealth=select(2,live(s.target,s.targetTeam,s.targetDef));s.attackFrame=frame
     S.GiveOrderToUnit(s.actor,CMD.ATTACK,{s.target},{});log('UNIT_TARGET_NATIVE_ATTACK',s.actor,s.target,s.attackHealth,frame)
    else local okay,why=stance(s,frame);if not okay then s.failure=why;return false,why end end
   elseif frame-s.phaseFrame>600 then s.failure='native_velocity_or_private_stop_not_observed';return false,s.failure end
  elseif s.phase=='attack'then
   local targetType,_,target=S.GetUnitWeaponTarget(s.actor,1)
   local _,hp=live(s.target,s.targetTeam,s.targetDef)
   if s.shot and s.damage>0 and hp<s.attackHealth and targetType==1 and target==s.target then
    log('UNIT_TARGET_NATIVE_HIT_PROVEN',s.actor,s.target,s.damage,s.attackHealth,hp,'GROUND_FIRING_UNACCEPTED');s.complete=true;return true
   elseif frame-s.phaseFrame>900 then
    if s.attempt>=24 then s.failure='unit_target_stance_attempt_limit';return false,s.failure end
    local okay,why=stance(s,frame);if not okay then s.failure=why;return false,why end
   end
  end
  return nil
 end
 function R.NoteShot(id,mount,frame)
  local s=R.state;if not s or s.actor~=id or s.phase~='attack'or frame<s.attackFrame then return false end
  local targetType,_,target=S.GetUnitWeaponTarget(id,mount)
  if targetType~=1 or target~=s.target then return false end;s.shot=true;return true
 end
 function R.UnitDamaged(id,def,owner,damage,paralyzer,weapon,projectile,attacker,attackerDef,attackerTeam)
  local s=R.state;if not s or s.phase~='attack'or id~=s.target or def~=s.targetDef or owner~=s.targetTeam
   or attacker~=s.actor or attackerDef~=s.def or attackerTeam~=team or paralyzer or not finite(damage)or damage<=0 then return false end
  local mounted=false;for _,m in ipairs(D[s.def].weapons or{})do if (m.weaponDef or m.weaponDefID)==weapon then mounted=true end end
  if not mounted or not live(s.actor,team,s.def)then return false end
  s.damage=s.damage+damage;log('UNIT_TARGET_NATIVE_DAMAGE',attacker,id,weapon,damage,S.GetGameFrame());return true
 end
 function R.Clear()R.state=nil end
 return R
end
return M

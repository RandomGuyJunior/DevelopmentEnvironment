-- Current human brief section16: exact four ranged loadouts; unpaid diagnostic.
local M={Keys={'ork_kan_twin_shoota','ork_kan_twin_kmb','ork_kan_twin_rokkit','ork_dread_ranged_fourarm'}}
local function yes(v)return v==true or v==1 or v=='1'end
function M.Enabled(o)return o and yes(o.prototype_ork_ranged_weapon_fixture)and yes(o.prototype_development_playtest)and not yes(o.prototype_source_paid_match)and(o.prototype_diagnostic==nil or o.prototype_diagnostic=='normal')or false end
function M.Apply(defs,o)
 if not M.Enabled(o)then return false end
 for _,key in ipairs(M.Keys)do local d=assert(defs[key],'Exact walker missing');local c=d.customparams or{}
  assert(c.animsource==key and c.prototype40k_ranged_variant==1 and d.script=='40k_roster.lua','Genuine runtime required');c.diagnostic='roster'
 end
 return true
end
function M.New(S,actor,team,mounts,emit,direct)
 local R={projectiles={}}
 local function fail(reason)R.failed=R.failed or reason;emit('FAIL '..reason)end
 function R.Begin(slot,target,ground,moving)
  R.slot=slot;R.target=target;R.ground=ground;R.query=nil;R.hp=target and S.GetUnitHealth(target)or nil
  R.row={queries={},barrels={},hits={},shots=0,cycles=0,damage=0,hpLoss=0,terrain=0,selfDamage=0,moving=moving==true,movingHits={}}
  R.startPosition=moving and{S.GetUnitPosition(actor)}or nil;R.lastMovingShot=false
 end
 local function movingShot(n,f)
  local r=R.row;if not r.moving then return false end
  local US=S.UnitScript
  if not direct or not US or not US.CallAsUnit or not US.GetPieceRotation then fail('direct_native_rotation_api_missing');return false end
  local vx,vy,vz=S.GetUnitVelocity(actor);local x,y,z=S.GetUnitPosition(actor)
  local _,hip=US.CallAsUnit(actor,US.GetPieceRotation,direct.hip)
  local gx,gy,gz=US.CallAsUnit(actor,US.GetPieceRotation,direct.pivots[n])
  local bx,by,bz=US.CallAsUnit(actor,US.GetPieceRotation,direct.body)
  local cmd=S.GetUnitCurrentCommand(actor)
  local values={vx,vy,vz,x,y,z,hip,gx,gy,gz,bx,by,bz}
  for i=1,13 do local v=values[i]
   if type(v)~='number'or v~=v or math.abs(v)==math.huge then fail('direct_native_motion_readback_missing');return false end
  end
  if not(R.startPosition[1]and R.startPosition[3])then fail('direct_native_motion_readback_missing');return false end
  local travel=(x-R.startPosition[1])^2+(z-R.startPosition[3])^2
  local speed=math.sqrt(vx*vx+vz*vz);local localLimit=math.rad(3)+1e-5
  local moving=cmd==direct.moveCommand and speed>.05 and travel>=8^2
  local turned=math.abs(hip)>=math.rad(5)
  local localSafe=math.abs(gx)<=localLimit and math.abs(gy)<=localLimit
  emit((direct.kind=='paired_kan'and'PAIRED_KAN_MOVING_SHOT'or'DIRECT_MOVING_SHOT')..' slot='..n..' frame='..f..' speed_per_frame='..speed..' displacement='..math.sqrt(travel)..' command='..tostring(cmd)..' hip_yaw='..hip..' gun_rotation='..gx..','..gy..','..gz..' body_rotation='..bx..','..by..','..bz..' moving='..tostring(moving)..' hip_turned='..tostring(turned)..' local_cone='..tostring(localSafe))
  if not localSafe then fail('direct_shot_outside_local_cone')end
  return moving and turned and localSafe
 end
 function R.Query(id,n,piece)
  if R.closed or id~=actor or n~=R.slot then return end
  if not mounts[n].pieces[piece]then fail('wrong_actual_query_piece');return end
  local x,y,z=S.GetUnitPiecePosDir(id,piece);if not x or not y or not z or x~=x or y~=y or z~=z then fail('native_query_position_missing');return end
  R.query={piece=piece,x=x,y=y,z=z};R.row.queries[piece]=true;emit('QUERY slot='..n..' piece='..piece..' xyz='..x..','..y..','..z)
 end
 function R.Shot(id,n,f)
  if R.closed or id~=actor then return end
  if n~=R.slot then fail('nonselected_shot');return end
  local m,r=mounts[n],R.row
  if r.shots%m.salvo==0 then
   local reload=S.GetUnitWeaponState(actor,n,'reloadTimeXP')
   if type(reload)~='number'or reload<=0 then fail('native_reload_missing');return end
   if r.lastCycle and f-r.lastCycle<math.floor(reload*30)-1 then fail('native_cycle_too_fast');return end
   r.lastCycle=f;r.cycles=r.cycles+1
  end
  local angleGood=S.GetUnitWeaponState(actor,n);if angleGood~=true then fail('native_angleGood_missing');return end
  R.lastMovingShot=movingShot(n,f)
  r.shots=r.shots+1;r.lastShot=f;emit('SHOT slot='..n..' frame='..f..' cycle='..r.cycles..' native_angleGood='..tostring(S.GetUnitWeaponState(actor,n)))
 end
 function R.Projectile(pid,owner,wd)
  if R.closed or owner~=actor or not R.slot then return end
  local m=mounts[R.slot];if wd~=m.weapon then fail('nonselected_projectile');return end
  local q=R.query;local x,y,z=S.GetProjectilePosition(pid);local mx,my,mz,dx,dy,dz=S.GetUnitWeaponVectors(actor,R.slot)
  if not q or not x or not mx or not R.row.lastShot or S.GetGameFrame()-R.row.lastShot>2 then fail('shot_query_projectile_link_missing');return end
  local tolerance=math.max(16,m.speed+4)
  if(x-q.x)^2+(y-q.y)^2+(z-q.z)^2>tolerance^2 or(mx-q.x)^2+(my-q.y)^2+(mz-q.z)^2>4^2 then fail('projectile_not_actual_query_muzzle');return end
  R.row.barrels[q.piece]=true;R.projectiles[pid]={row=R.row,cycle=R.row.cycles,moving=R.lastMovingShot};emit('PROJECTILE slot='..R.slot..' pid='..pid..' piece='..q.piece..' muzzle='..mx..','..my..','..mz..' native_dir='..tostring(dx)..','..tostring(dy)..','..tostring(dz))
 end
 function R.Damaged(id,damage,para,wd,pid,attacker)
  if R.closed or attacker~=actor then return end
  if wd~=mounts[R.slot].weapon then fail('nonselected_damage');return end
  local p=R.projectiles[pid];if not p or p.row~=R.row then fail('damage_projectile_missing');return end
  if para or damage<=0 then return end
  if id==actor then R.row.selfDamage=R.row.selfDamage+damage;emit('SELF_SPLASH '..damage);return end
  if R.ground or id~=R.target then emit('COLLATERAL '..id..' '..damage);return end
  local hp=S.GetUnitHealth(id);if not hp then fail('target_hp_missing');return end
  local loss=math.max(0,R.hp-hp);R.hp=hp;R.row.hpLoss=R.row.hpLoss+loss;R.row.damage=R.row.damage+damage;if loss>0 then R.row.hits[p.cycle]=true;if p.moving then R.row.movingHits[p.cycle]=true end end
  emit('NATIVE_HIT slot='..R.slot..' amount='..damage..' hpLoss='..loss..' cycle='..p.cycle)
 end
 function R.Explosion(wd,x,y,z,owner,pid)
  if R.closed or owner~=actor or not R.ground or wd~=mounts[R.slot].weapon then return end
  local p=R.projectiles[pid];if p and p.row==R.row and math.abs(y-S.GetGroundHeight(x,z))<=12 then R.row.terrain=R.row.terrain+1;emit('NATIVE_TERRAIN slot='..R.slot..' xyz='..x..','..y..','..z)end
 end
 function R.Ready()
  if R.failed or R.closed or not R.row or S.GetUnitIsDead(actor)or S.GetUnitTeam(actor)~=team then return false end
  local r=R.row;local hitCycles=0;for cycle,hit in pairs(r.hits)do if hit and cycle>=1 and cycle<=r.cycles then hitCycles=hitCycles+1 end end;for p in pairs(mounts[R.slot].pieces)do if not r.queries[p]or not r.barrels[p]then return false end end
  if r.moving then
   local count=0;for cycle in pairs(r.movingHits)do if cycle>=1 and cycle<=r.cycles then count=count+1 end end
   if count<2 then return false end
  end
  return r.shots>0 and(R.ground and r.terrain>0 or not R.ground and r.cycles>=2 and r.shots>=mounts[R.slot].salvo+1 and r.damage>0 and r.hpLoss>0 and hitCycles>=2)
 end
 function R.Close()R.closed=true end
 return R
end
return M

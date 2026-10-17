-- Funded diagnostic leaf: native orders and readbacks, no aiming/weapon changes.
local M={Version=1,Markers={'marker_turret_barrel','marker_small_cannon_barrel','marker_l_heavy_bolter','marker_r_heavy_bolter'}}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function yes(v)return v==true or v==1 or v=='1'end
function M.Enabled(o)
 if not o or not yes(o.prototype_russ_four_mount_fixture)then return false end
 assert(yes(o.prototype_development_playtest)and o.prototype_diagnostic=='normal'and not yes(o.prototype_source_paid_match),'Owned funded normal diagnostic required')
 for k,v in pairs(o)do if yes(v)and(k:match('_fixture$')or k:match('_paid_driver$')or k:find('benchmark')or k=='prototype_mount_burst_observer')then assert(k=='prototype_russ_four_mount_fixture','Competing diagnostic owner:'..k)end end
 return true
end
function M.New(S,D,W,actor,target,emit)
 local C={actor=actor,target=target,mounts={},shots={},pids={},stage=0,phase='waiting',rows=0,counts={}}
 local function fail(reason)C.result=C.result or'INCONCLUSIVE '..reason;return C.result end
 local function output(label,...)C.rows=C.rows+1;if C.rows>1024 then return fail('bounded_trace_exhausted')end;emit(label,...)end
 local def=D[S.GetUnitDefID(actor)];local map=S.GetUnitPieceMap(actor)
 if not def or def.name~='imp_russ'or #def.weapons~=4 then fail('exact_current_Russ_four_mounts_required');return C end
 local seen={}
 for n,e in ipairs(def.weapons)do
  local w=W[e.weaponDef];local p=map[M.Markers[n]]
  if seen[e.weaponDef]or not w or w.type~='Cannon'or not p or not finite(w.salvoSize)or w.salvoSize%1~=0 or w.salvoSize<1 or not finite(w.salvoDelay)or not finite(w.reload)or w.reload<=0 then fail('actual_unique_WD_native_timing_muzzle_required');return C end
  seen[e.weaponDef]=true;C.mounts[n]={wd=e.weaponDef,piece=p,salvo=w.salvoSize,delay=w.salvoDelay}
  output('MOUNT',n,e.weaponDef,p,M.Markers[n],w.salvoSize,w.salvoDelay,w.reload)
 end
 C.team=S.GetUnitTeam(actor);C.targetTeam=S.GetUnitTeam(target);C.targetHP=S.GetUnitHealth(target)
 if C.team==C.targetTeam or not finite(C.targetHP)or C.targetHP<=0 then fail('genuine_native_hostile_target_required')end
 function C.Begin(ground,position)
  if C.result then return C.result end
  C.stage=C.stage+1;C.ground=ground;C.groundPosition=position;C.phase='firing';C.counts={};C.targetHP=S.GetUnitHealth(target)
  if ground then for i=1,3 do if not position or not finite(position[i])then return fail('exact_native_ground_order_required')end end end
  for n=1,4 do C.counts[n]={shots=0,cycles=0,pids=0,hits={},terrain=0}end
  output('STAGE',C.stage,ground and'ground'or'hostile','funded_non_economy=true')
 end
 function C.Telemetry(row)
  if C.result or row.owner~=actor then return end
  local m=C.mounts[row.mount];if not m then return fail('unmapped_Russ_mount')end
  if C.phase~='firing'and C.phase~='drain'then return end
  local r=C.counts[row.mount]
  if row.kind=='SHOT'then
   local p=row.snapshot
   if row.ambiguous or row.frame~=S.GetGameFrame()or not p or p.muzzle_piece~=m.piece or p.muzzle_name~=M.Markers[row.mount]or C.shots[row.serial]then return fail('actual_native_shot_identity')end
   if not C.ground and(not row.native_target or row.native_target[1]~=1 or row.native_target[3]~=target)then return fail('actual_native_shot_target')end
   if C.ground then
    local t=row.native_target;local pos=t and t[3]
    if not t or t[1]~=2 or type(pos)~='table'then return fail('actual_native_ground_shot_target')end
    for i=1,3 do if not finite(pos[i])or math.abs(pos[i]-C.groundPosition[i])>.1 then return fail('actual_native_ground_order_identity')end end
   end
   if r.shots%m.salvo==0 then
    local reload=S.GetUnitWeaponState(actor,row.mount,'reloadTimeXP')
    if not finite(reload)or reload<=0 or r.lastCycle and row.frame-r.lastCycle<math.floor(reload*30)-1 then return fail('actual_native_reload_clock')end
    r.cycles=r.cycles+1;r.lastCycle=row.frame
   elseif r.lastShot and row.frame-r.lastShot<math.floor(m.delay*30)-1 then return fail('actual_native_salvo_clock')end
   if S.GetUnitWeaponState(actor,row.mount)~=true then return fail('native_angleGood_not_true')end
   r.shots=r.shots+1;r.lastShot=row.frame;C.shots[row.serial]={frame=row.frame,mount=row.mount,cycle=r.cycles,stage=C.stage}
   local v=p.muzzle_position;local d=p.muzzle_direction
   for i=1,3 do if not v or not d or not finite(v[i])or not finite(d[i])then return fail('native_muzzle_world_missing')end end
   output('SHOT',C.stage,row.mount,row.serial,row.frame,m.piece,table.concat(v,','),table.concat(d,','),'geometry_calibration_pending=true')
  elseif row.kind=='PROJECTILE'then
   local s=C.shots[row.shot_serial];local q=row.actual_query;local qp=q and q.snapshot and q.snapshot.muzzle_position
   if C.pids[row.projectile]or row.duplicate_pid or row.weapondef~=m.wd or row.association~='unique_same_frame_unconsumed_shot'or not s or s.stage~=C.stage or s.mount~=row.mount or s.frame~=row.frame or row.frame~=S.GetGameFrame()or not q or q.frame~=row.frame or q.piece~=m.piece or not qp or not row.position then return fail('unique_same_frame_native_Query_Shot_PID_WD_required')end
   local dist=0;for i=1,3 do if not finite(qp[i])or not finite(row.position[i])then return fail('finite_native_Query_origin_required')end;dist=dist+(qp[i]-row.position[i])^2 end
   if dist>64^2 then return fail('native_PID_not_Query_origin')end
   C.pids[row.projectile]={wd=m.wd,stage=C.stage,mount=row.mount,cycle=s.cycle};r.pids=r.pids+1
   output('QUERY_PID',C.stage,row.mount,row.projectile,m.wd,row.frame,q.piece,table.concat(qp,','),table.concat(row.position,','))
  end
 end
 function C.Damaged(id,def,team,damage,para,wd,pid,attacker)
  if C.result then return end
  if id==actor and finite(damage)and damage>0 then return fail('native_actor_damage_or_self_splash')end
  if id~=target then return end
  local p=C.pids[pid];local hp=S.GetUnitHealth(target)
  if attacker~=actor or not p or p.wd~=wd or para or not finite(damage)or damage<=0 or not finite(hp)or hp>=C.targetHP then return fail('owned_native_PID_WD_target_HP_required')end
  local loss=C.targetHP-hp;C.targetHP=hp
  if p.stage==C.stage and not C.ground then C.counts[p.mount].hits[p.cycle]=true;output('HIT',C.stage,p.mount,pid,wd,damage,loss,hp)end
  if hp<=0 then return fail('target_died_before_complete_all_mounts')end
 end
 function C.Explosion(wd,x,y,z,owner,pid)
  if C.result or owner~=actor then return false end
  local p=C.pids[pid]
  if not p or p.wd~=wd or not finite(x)or not finite(y)or not finite(z)then fail('owned_native_explosion_PID_WD_required');return false end
  local h=S.GetGroundHeight(x,z)
  if C.ground and p.stage==C.stage and finite(h)and math.abs(y-h)<=12 then C.counts[p.mount].terrain=C.counts[p.mount].terrain+1;output('GROUND',C.stage,p.mount,pid,wd,x,y,z,h)end
  return false
 end
 function C.Ready()
  if C.result or not C.counts[1]then return false end
  for n,m in ipairs(C.mounts)do local r=C.counts[n];local hits=0;for cycle in pairs(r.hits)do if cycle<=r.cycles then hits=hits+1 end end
   if r.shots<2*m.salvo or r.shots%m.salvo~=0 or r.pids~=r.shots or r.cycles<2 or(C.ground and r.terrain<1 or not C.ground and hits<2)then return false end
  end
  return true
 end
 function C.Close()C.phase='closed'end
 return C
end
return M

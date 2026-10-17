-- Optional follow-on to verified ordinary-paid Guard future cohort; no normal hook.
local M={}
function M.New(S,defs,weapons,actor,leader,team,frame,emit)
 local d=defs[S.GetUnitDefID(actor)];local entry=d and d.weapons and d.weapons[1];local wd=entry and weapons[entry.weaponDef];local cp=wd and wd.customParams or{}
 local C={started=frame,phase='site',shots=0,cycles=0,hits=0,projectiles={}}
 local piece=(S.GetUnitPieceMap(actor)or{}).marker_flamer_muzzle
 if not d or d.name~='imp_guardsman_flamer_member'or(d.customParams or{}).animsource~='guardsman_flamer'or not wd or wd.type~='Flame'or cp.source_muzzle~='marker_flamer_muzzle'or cp.source_fireclip~='fire'or not piece then C.result='FAIL genuine_guard_flamer_contract';return C end
 local enemy;for _,t in ipairs(S.GetTeamList())do if t~=S.GetGaiaTeamID()and not S.AreTeamsAllied(team,t)then enemy=t;break end end
 if not enemy then C.result='INCONCLUSIVE hostile_team_required';return C end
 C.weapon=entry.weaponDef
 local function fail(why)C.result=C.result or('FAIL '..why)end
 function C.Query(id,n,p)
  if C.closed or C.phase~='fire'or id~=actor or n~=1 then return end
  if p~=piece then fail('wrong_genuine_flamer_query_piece');return end
  local x,y,z=S.GetUnitPiecePosDir(actor,p);if not x or not y or not z then fail('native_query_position_missing');return end
  C.query={x=x,y=y,z=z,frame=S.GetGameFrame()};emit('FLAMER_QUERY','piece='..p,'frame='..C.query.frame,'xyz='..x..','..y..','..z)
 end
 function C.Shot(id,n,f)
  if C.closed or C.phase~='fire'or id~=actor or n~=1 then return end
  local size=S.GetUnitWeaponState(actor,1,'burst');local delay=S.GetUnitWeaponState(actor,1,'burstRate');local reload=S.GetUnitWeaponState(actor,1,'reloadTimeXP')
  if size~=4 or type(delay)~='number'or math.abs(delay-.2)>.001 or type(reload)~='number'or reload<=0 then fail('native_flamer_clock_contract');return end
  if S.GetUnitWeaponState(actor,1)~=true then C.result='INCONCLUSIVE native_angle_not_ready';return end
  if C.shots%size==0 then
   if C.lastCycle and f-C.lastCycle<math.floor(reload*Game.gameSpeed)-1 then fail('native_flamer_cycle_too_fast');return end
   C.lastCycle=f;C.cycles=C.cycles+1
  elseif C.lastShot and f-C.lastShot<math.floor(delay*Game.gameSpeed)-1 then fail('native_flamer_subshot_too_fast');return end
  C.shots=C.shots+1;C.lastShot=f;emit('FLAMER_SHOT','frame='..f,'cycle='..C.cycles,'count='..C.shots,'native_reload_seconds='..reload,'native_burst_rate_seconds='..delay)
 end
 function C.Projectile(pid,owner,weapon)
  if C.closed or C.phase~='fire'or owner~=actor or weapon~=C.weapon then return end
  local q=C.query;local x,y,z=S.GetProjectilePosition(pid);local mx,my,mz=S.GetUnitWeaponVectors(actor,1);local speed=S.GetUnitWeaponState(actor,1,'projectileSpeed')
  if not q or not x or not mx or not C.lastShot or q.frame<C.lastShot or S.GetGameFrame()-C.lastShot>2 or type(speed)~='number'or speed<=0 then fail('native_flame_projectile_link_missing');return end
  if(x-q.x)^2+(y-q.y)^2+(z-q.z)^2>math.max(16,speed+4)^2 or(mx-q.x)^2+(my-q.y)^2+(mz-q.z)^2>16 then fail('flame_projectile_not_native_muzzle');return end
  if C.projectiles[pid]then fail('duplicate_flame_projectile_birth');return end
  C.projectiles[pid]={cycle=C.cycles};emit('FLAMER_PROJECTILE','pid='..pid,'cycle='..C.cycles,'muzzle='..mx..','..my..','..mz,'xyz='..x..','..y..','..z)
 end
 function C.Damaged(id,damage,para,weapon,pid,attacker)
  if C.closed or C.phase~='fire'or id~=C.target or attacker~=actor or weapon~=C.weapon or para or damage<=0 then return end
  local p=C.projectiles[pid];if not p then fail('native_flame_damage_missing_projectile');return end
  local hp=S.GetUnitHealth(id);if not hp or not C.lastHP or hp>=C.lastHP then fail('native_flame_damage_no_health_loss');return end
  C.lastHP=hp
  if not p.hit then p.hit=true;C.hits=C.hits+1 end
  emit('FLAMER_NATIVE_HIT','pid='..pid,'cycle='..p.cycle,'damage='..damage,'health='..hp,'distinct_hit_projectiles='..C.hits,'other_cohort_weapons_remain_ordinary=true')
 end
 local function site()
  local target=UnitDefNames.imp_russ;local td=target and defs[target.id];if not td then return end
  local x,y,z=S.GetUnitPosition(actor);local sight=d.sightDistance or d.losRadius
  if type(sight)~='number'or sight<=0 then return end
  local clearance=(math.max(d.xsize,d.zsize)+math.max(td.xsize,td.zsize))*4+16
  for factor=5,8 do local radius=math.min(wd.range*factor/10,sight*.75)
   for j=0,15 do local a=j*math.pi/8;local tx,tz=x+radius*math.sin(a),z+radius*math.cos(a);local ty=S.GetGroundHeight(tx,tz)
    if radius>clearance and(tx-x)^2+(ty-y)^2+(tz-z)^2<(wd.range*.9)^2 and tx>64 and tz>64 and tx<Game.mapSizeX-64 and tz<Game.mapSizeZ-64 and ty>=0
     and S.TestMoveOrder(target.id,tx,ty,tz,0,0,0,true,true,false)and S.IsPosInLos(tx,ty,tz,S.GetUnitAllyTeam(actor))then return tx,ty,tz end
   end
  end
 end
 function C.Step(f)
  if C.result then return C.result end
  if S.GetUnitIsDead(actor)or S.GetUnitTeam(actor)~=team or S.GetUnitIsDead(leader)or S.GetUnitTeam(leader)~=team then return'FAIL paid_guard_cohort_lost_or_transferred'end
  if C.phase=='site'and f>C.started and f%15==0 then
   local x,y,z=site()
   if x then
    C.target=S.CreateUnit('imp_russ',x,y,z,0,enemy);if not C.target then return'FAIL disclosed_enemy_target_birth'end
    S.GiveOrderToUnit(C.target,CMD.FIRE_STATE,{0},0);S.GiveOrderToUnit(C.target,CMD.MOVE_STATE,{0},0)
    C.phase='settle';C.stage=f;emit('FLAMER_TARGET','id='..C.target,'unpaid_hostile_target=true ordinary_own_economy_unchanged=true')
   elseif f-C.started>=300 then return'INCONCLUSIVE no_legal_naturally_visible_guard_target'end
  elseif C.phase=='settle'then
   if S.GetUnitIsDead(C.target)or S.AreTeamsAllied(team,S.GetUnitTeam(C.target))then return'FAIL settled_hostile_target_invalid'end
   local los=S.GetUnitLosState(C.target,S.GetUnitAllyTeam(actor),false)or{};local hp,_,_,_,progress=S.GetUnitHealth(C.target)
   if f>C.stage and los.los==true and progress==1 then
    C.lastHP=hp;C.phase='fire';C.stage=f
    local accepted=S.GiveOrderToUnit(leader,CMD.ATTACK,{C.target},0);emit('FLAMER_COMBAT_ORDER','normal_cohort_leader_ATTACK=true return='..tostring(accepted))
    if accepted==false then return'INCONCLUSIVE native_cohort_attack_rejected'end
   elseif f-C.stage>=300 then return'INCONCLUSIVE natural_enemy_unit_visibility'end
  elseif C.phase=='fire'then
   if C.cycles>=2 and C.shots>=8 and C.hits>=2 then return'PASS paid_Guard_future_cohort genuine_Flame native_Query_Shot_projectile_damage two_clock_checked_bursts'end
   if S.GetUnitIsDead(C.target)then return'INCONCLUSIVE hostile_lost_before_flamer_witness'end
   if f-C.stage>=1800 then return'INCONCLUSIVE native_flamer_combat_timeout'end
  end
 end
 function C.Close()
  C.closed=true
  if C.target and S.ValidUnitID(C.target)and not S.GetUnitIsDead(C.target)then S.DestroyUnit(C.target,false,true)end
 end
 return C
end
return M

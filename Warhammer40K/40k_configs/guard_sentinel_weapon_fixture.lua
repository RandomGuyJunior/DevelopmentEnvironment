-- Optional funded hostile-target weapon follow-on; own Sentinel remains ordinarily paid.
local M={}
function M.New(S,defs,weapons,actor,leader,team,frame,emit)
 local d=defs[S.GetUnitDefID(actor)];local entry=d and d.weapons and d.weapons[1];local wd=entry and weapons[entry.weaponDef];local cp=wd and wd.customParams or{}
 local C={started=frame,phase='site',shots=0,cycles=0,hits=0,projectiles={},hitCycles={},cycleShots={}}
 local piece=(S.GetUnitPieceMap(actor)or{}).marker_multilaser_muzzle
 -- BAR UnitDef_Post sanitizes authored burstrate to full frames before engine parsing.
 -- WeaponDefs.salvoDelay exposes that sanitized definition; live burstRate is
 -- CWeapon's int(seconds * GAME_SPEED) / GAME_SPEED, a separate native read.
 local speed=Game.gameSpeed
 local expectedDelay=type(speed)=='number'and speed>0 and math.max(1,math.floor((.22+1e-3)*speed))/speed or nil
 local reasons={};local function requireField(ok,name)if not ok then reasons[#reasons+1]=name end end
 requireField(d~=nil,'unit_definition');requireField(d and d.name=='imp_sentinel','unit_name')
 requireField(d and(d.customParams or{}).animsource=='imp_sentinel','animation_source')
 requireField(wd~=nil,'weapon_definition');requireField(wd and wd.type=='LaserCannon','weapon_type')
 requireField(wd and wd.salvoSize==3,'salvo_size')
 requireField(expectedDelay and wd and type(wd.salvoDelay)=='number'and math.abs(wd.salvoDelay-expectedDelay)<=.001,'bar_sanitized_definition_delay')
 requireField(cp.source_muzzle=='marker_multilaser_muzzle','source_muzzle');requireField(cp.source_fireclip=='fire','source_fireclip');requireField(piece~=nil,'native_muzzle_piece')
 emit('SENTINEL_CONTRACT','actor='..tostring(actor),'unit_def='..tostring(S.GetUnitDefID(actor)),
  'unit_name='..tostring(d and d.name),'animation_source='..tostring(d and(d.customParams or{}).animsource),
  'weapon_id='..tostring(entry and entry.weaponDef),'weapon_name='..tostring(wd and wd.name),'weapon_type='..tostring(wd and wd.type),
  'salvo_size='..tostring(wd and wd.salvoSize),'definition_delay_seconds='..tostring(wd and wd.salvoDelay),
  'authored_delay_seconds=.22','game_speed='..tostring(speed),'expected_BAR_definition_delay_seconds='..tostring(expectedDelay),
  'live_burst_rate_seconds='..tostring(wd and S.GetUnitWeaponState and S.GetUnitWeaponState(actor,1,'burstRate')),
  'source_muzzle='..tostring(cp.source_muzzle),'source_fireclip='..tostring(cp.source_fireclip),'native_muzzle_piece='..tostring(piece),
  'metal_cost='..tostring(d and d.metalCost),'energy_cost='..tostring(d and d.energyCost),'build_time='..tostring(d and d.buildTime),
  'contract_refusals='..(#reasons==0 and'none'or table.concat(reasons,',')))
 if #reasons>0 then C.result='FAIL genuine_guard_sentinel_contract';return C end
 local enemy;for _,t in ipairs(S.GetTeamList())do if t~=S.GetGaiaTeamID()and not S.AreTeamsAllied(team,t)then enemy=t;break end end
 if not enemy then C.result='INCONCLUSIVE hostile_team_required';return C end
 C.weapon=entry.weaponDef
 local function fail(why)C.result=C.result or('FAIL '..why)end
 function C.Query(id,n,p)
  if C.closed or C.phase~='fire'or id~=actor or n~=1 then return end
  if p~=piece then fail('wrong_genuine_sentinel_query_piece');return end
  local x,y,z=S.GetUnitPiecePosDir(actor,p);if not x or not y or not z then fail('native_query_position_missing');return end
  C.query={x=x,y=y,z=z,frame=S.GetGameFrame()};emit('SENTINEL_QUERY','piece='..p,'frame='..C.query.frame,'xyz='..x..','..y..','..z)
 end
 function C.Shot(id,n,f)
  if C.closed or C.phase~='fire'or id~=actor or n~=1 then return end
  local size=S.GetUnitWeaponState(actor,1,'burst');local delay=S.GetUnitWeaponState(actor,1,'burstRate');local reload=S.GetUnitWeaponState(actor,1,'reloadTimeXP')
  if size~=3 or type(delay)~='number'or math.abs(delay-math.floor(wd.salvoDelay*Game.gameSpeed)/Game.gameSpeed)>.001 or type(reload)~='number'or reload<=0 then fail('native_sentinel_clock_contract');return end
  local angle=S.GetUnitWeaponState(actor,1)
  -- A started native salvo continues while periodic LUS re-aim clears angleGood.
  -- Keep real Shot/PID evidence and require later natural readiness before PASS.
  if angle~=true then
   C.anglePending=C.anglePending or f
   emit('SENTINEL_ANGLE_PENDING','frame='..f,'angle='..tostring(angle),'native_subshot_preserved=true natural_readiness_required=true')
  end
  -- Native UpdateSalvo decrements salvoLeft before calling this real Shot.
  local left=S.GetUnitWeaponState(actor,1,'salvoLeft')
  if type(left)~='number'or left%1~=0 or left<0 or left>=size then fail('native_salvo_identity_missing');return end
  if left==size-1 then
   if C.remaining and C.remaining>0 then fail('native_incomplete_burst_restart');return end
   if C.lastCycle and f-C.lastCycle<math.floor(reload*Game.gameSpeed)-1 then fail('native_sentinel_cycle_too_fast');return end
   C.lastCycle=f;C.cycles=C.cycles+1
  else
   if not C.remaining or C.remaining~=left+1 or C.cycles<1 then fail('native_salvo_sequence_missing');return end
   if C.lastShot and f-C.lastShot<math.floor(delay*Game.gameSpeed)-1 then fail('native_sentinel_subshot_too_fast');return end
  end
  C.remaining=left
  C.shots=C.shots+1;C.cycleShots[C.cycles]=(C.cycleShots[C.cycles]or 0)+1;C.lastShot=f;emit('SENTINEL_SHOT','frame='..f,'cycle='..C.cycles,'count='..C.shots,'native_reload_seconds='..reload,'native_burst_rate_seconds='..delay)
 end
 function C.Projectile(pid,owner,weapon)
  if C.closed or C.phase~='fire'or owner~=actor or weapon~=C.weapon then return end
  local q=C.query;local x,y,z=S.GetProjectilePosition(pid);local mx,my,mz=S.GetUnitWeaponVectors(actor,1);local speed=S.GetUnitWeaponState(actor,1,'projectileSpeed')
  if not q or not x or not mx or not C.lastShot or q.frame<C.lastShot or S.GetGameFrame()-C.lastShot>2 or type(speed)~='number'or speed<=0 then fail('native_multilaser_projectile_link_missing');return end
  if(x-q.x)^2+(y-q.y)^2+(z-q.z)^2>math.max(16,speed+4)^2 or(mx-q.x)^2+(my-q.y)^2+(mz-q.z)^2>16 then fail('multilaser_projectile_not_native_muzzle');return end
  if C.projectiles[pid]then fail('duplicate_multilaser_projectile_birth');return end
  C.projectiles[pid]={cycle=C.cycles};emit('SENTINEL_PROJECTILE','pid='..pid,'cycle='..C.cycles,'muzzle='..mx..','..my..','..mz,'xyz='..x..','..y..','..z)
 end
 function C.Damaged(id,damage,para,weapon,pid,attacker)
  if C.closed or C.phase~='fire'or id~=C.target then return end
  local hp=S.GetUnitHealth(id);local loss=hp and C.lastHP and C.lastHP-hp;C.lastHP=hp
  if attacker~=actor then emit('SENTINEL_OTHER_NATIVE_HIT','attacker='..tostring(attacker),'baseline_updated=true');return end
  if weapon~=C.weapon or para or not damage or damage<=0 then fail('wrong_primary_native_damage');return end
  local p=C.projectiles[pid];if not p then fail('native_multilaser_damage_missing_projectile');return end
  if not loss or loss<=0 then fail('native_multilaser_damage_no_health_loss');return end
  C.hitCycles[p.cycle]=true
  if not p.hit then p.hit=true;C.hits=C.hits+1 end
  emit('SENTINEL_NATIVE_HIT','pid='..pid,'cycle='..p.cycle,'damage='..damage,'health='..hp,'distinct_hit_projectiles='..C.hits,'native_damage_authority=true')
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
  if C.target and not S.GetUnitIsDead(C.target)and S.GetUnitTeam(C.target)~=enemy then return'FAIL hostile_target_transferred'end
  if S.GetUnitIsDead(actor)or S.GetUnitTeam(actor)~=team or S.GetUnitIsDead(leader)or S.GetUnitTeam(leader)~=team then return'FAIL paid_Sentinel_lost_or_transferred'end
  if C.phase=='site'and f>C.started and f%15==0 then
   local x,y,z=site()
   if x then
    C.target=S.CreateUnit('imp_russ',x,y,z,0,enemy);if not C.target then return'FAIL disclosed_enemy_target_birth'end
    S.GiveOrderToUnit(C.target,CMD.FIRE_STATE,{0},0);S.GiveOrderToUnit(C.target,CMD.MOVE_STATE,{0},0)
    C.phase='settle';C.stage=f;emit('SENTINEL_TARGET','id='..C.target,'unpaid_hostile_target=true funded_target_only=true ordinary_own_economy_unchanged=true')
   elseif f-C.started>=300 then return'INCONCLUSIVE no_legal_naturally_visible_guard_target'end
  elseif C.phase=='settle'then
   if S.GetUnitIsDead(C.target)or S.AreTeamsAllied(team,S.GetUnitTeam(C.target))then return'FAIL settled_hostile_target_invalid'end
   local los=S.GetUnitLosState(C.target,S.GetUnitAllyTeam(actor),false)or{};local hp,_,_,_,progress=S.GetUnitHealth(C.target)
   if f>C.stage and los.los==true and progress==1 then
    C.lastHP=hp;C.phase='fire';C.stage=f
    local accepted=S.GiveOrderToUnit(leader,CMD.ATTACK,{C.target},0);emit('SENTINEL_COMBAT_ORDER','normal_paid_Sentinel_ATTACK=true return='..tostring(accepted))
    if accepted==false then return'INCONCLUSIVE native_cohort_attack_rejected'end
   elseif f-C.stage>=300 then return'INCONCLUSIVE natural_enemy_unit_visibility'end
  elseif C.phase=='fire'then
   if not S.GetUnitWeaponTestTarget or not S.GetUnitWeaponTestRange or not S.GetUnitWeaponHaveFreeLineOfFire then return'INCONCLUSIVE native_readiness_read_API_missing'end
   if S.GetUnitIsDead(C.target)then return'INCONCLUSIVE hostile_lost_before_sentinel_witness'end
   local los=S.GetUnitLosState(C.target,S.GetUnitAllyTeam(actor),false)or{}
   local angle=S.GetUnitWeaponState(actor,1)
   local targetOkay=S.GetUnitWeaponTestTarget(actor,1,C.target)==true
   local rangeOkay=S.GetUnitWeaponTestRange(actor,1,C.target)==true
   local lineOkay=S.GetUnitWeaponHaveFreeLineOfFire(actor,1,C.target)==true
   local ready=angle==true and los.los==true and targetOkay and rangeOkay and lineOkay
   if ready then
    if C.anglePending then emit('SENTINEL_ANGLE_RECOVERED','frame='..f,'wait_frames='..(f-C.anglePending),'native_angle=true natural_LOS=true native_target=true native_range=true native_LOF=true')end
    C.anglePending=nil
   elseif angle~=true then C.anglePending=C.anglePending or f end
   if C.anglePending and f-C.anglePending>=300 then return'INCONCLUSIVE native_angle_not_ready_after_bounded_wait'end
   if ready and C.cycles>=2 and C.cycleShots[1]==3 and C.cycleShots[2]==3 and C.hitCycles[1]and C.hitCycles[2]then return'PASS ordinary_paid_Sentinel genuine_LaserCannon native_Query_Shot_projectile_HP_loss two_complete_clock_checked_bursts funded_hostile_target_only'end
   if S.GetUnitIsDead(C.target)then return'INCONCLUSIVE hostile_lost_before_sentinel_witness'end
   if f-C.stage>=1800 then return'INCONCLUSIVE native_sentinel_combat_timeout'end
  end
 end
 function C.Close()
  C.closed=true
  if C.target and S.ValidUnitID(C.target)and not S.GetUnitIsDead(C.target)then S.DestroyUnit(C.target,false,true)end
 end
 return C
end
return M

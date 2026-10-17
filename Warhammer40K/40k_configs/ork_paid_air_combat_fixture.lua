-- Default-off paid-Fighta follow-on. Only enemy target birth is unpaid/disclosed.
local M={}
local expected={'fb_fx_nose_gun_l','fb_fx_nose_gun_r','fb_fx_wing_gun_l','fb_fx_wing_gun_r'}
function M.New(S,defs,weapons,actor,team,frame,emit)
 local d=defs and defs[S.GetUnitDefID(actor)];local entry=d and d.weapons and d.weapons[1];local wd=entry and weapons and weapons[entry.weaponDef];local cp=wd and wd.customParams or{}
 local C={started=frame,phase='site',shots=0,hits=0,barrels={},projectiles={}};local pieces=S.GetUnitPieceMap(actor)or{};local allowed={}
 if not d or not entry or not wd or not d.canFly or(d.customParams or{}).animsource~='ork_fighta_bomba'or wd.type~='Cannon'or cp.source_muzzle_pair~=table.concat(expected,',')then C.result='FAIL genuine_primary_mount_contract';return C end
 for _,name in ipairs(expected)do if not pieces[name]then C.result='FAIL genuine_primary_muzzle_missing';return C end;allowed[pieces[name]]=true end
 local enemy;for _,t in ipairs(S.GetTeamList())do if t~=S.GetGaiaTeamID()and not S.AreTeamsAllied(team,t)then enemy=t;break end end
 if not enemy then C.result='INCONCLUSIVE hostile_team_required';return C end
 C.weapon=entry.weaponDef;C.actor=actor;C.team=team
 local function fail(why)C.result=C.result or('FAIL '..why)end
 function C.Query(id,n,piece)
  if C.closed or C.phase~='fire'or id~=actor or n~=1 then return end
  if not allowed[piece]then fail('primary_query_wrong_source_piece');return end
  local x,y,z=S.GetUnitPiecePosDir(actor,piece)
  if not x or not y or not z then fail('primary_query_position_missing');return end
  C.query={piece=piece,x=x,y=y,z=z,frame=S.GetGameFrame()}
  emit('PRIMARY_QUERY','piece='..piece,'frame='..C.query.frame)
 end
 function C.Shot(id,n,f)
  if C.closed or C.phase~='fire'or id~=actor or n~=1 then return end
  local angle=S.GetUnitWeaponState(actor,1)
  if angle~=true then fail('primary_native_angle_not_ready');return end
  C.shots=C.shots+1;C.lastShot=f;emit('PRIMARY_SHOT','frame='..f,'count='..C.shots)
 end
 function C.Projectile(pid,owner,weapon)
  if C.closed or C.phase~='fire'or owner~=actor or weapon~=C.weapon then return end
  local q=C.query;local x,y,z=S.GetProjectilePosition(pid);local mx,my,mz=S.GetUnitWeaponVectors(actor,1)
  if not q or not x or not mx or not C.lastShot or q.frame<C.lastShot or S.GetGameFrame()-C.lastShot>2 then fail('primary_shot_query_projectile_missing');return end
  local speed=S.GetUnitWeaponState(actor,1,'projectileSpeed')
  if type(speed)~='number'or speed<=0 then fail('primary_native_projectile_speed_missing');return end
  if(x-q.x)^2+(y-q.y)^2+(z-q.z)^2>math.max(16,speed+4)^2 or(mx-q.x)^2+(my-q.y)^2+(mz-q.z)^2>4^2 then fail('primary_projectile_not_native_query_muzzle');return end
  C.projectiles[pid]={piece=q.piece};C.barrels[q.piece]=true;emit('PRIMARY_PROJECTILE','pid='..pid,'piece='..q.piece)
 end
 function C.Damaged(id,damage,para,weapon,pid,attacker)
  if C.closed or C.phase~='fire'or id~=C.target or attacker~=actor or weapon~=C.weapon or para or damage<=0 then return end
  if not C.projectiles[pid]then fail('primary_damage_missing_projectile');return end
  if C.projectiles[pid].hit then fail('duplicate_primary_target_hit');return end
  local hp=S.GetUnitHealth(id)
  if not hp or not C.lastHP or hp>=C.lastHP then fail('primary_damage_no_native_health_loss');return end
  C.projectiles[pid].hit=true;C.hits=C.hits+1;C.lastHP=hp;emit('PRIMARY_NATIVE_HIT','pid='..pid,'damage='..damage,'health='..hp,'count='..C.hits,'other_mounts_remain_ordinary=true')
 end
 local function site()
  local x,y,z=S.GetUnitPosition(actor);local targetDef=UnitDefNames.imp_russ
  if not targetDef then return end
  local sight=d.sightDistance or d.losRadius;local minimum=tonumber(cp.source_minrange)or 0
  if type(sight)~='number'or sight<=0 then return end
  local radius=math.min(wd.range*.55,sight*.75)
  local td=defs[targetDef.id];if not td then return end;local clearance=(math.max(d.xsize,d.zsize)+math.max(td.xsize,td.zsize))*4+16
  for direction=0,15 do local a=direction*math.pi/8;local tx,tz=x+radius*math.sin(a),z+radius*math.cos(a);local ty=S.GetGroundHeight(tx,tz)
   local dist=(tx-x)^2+(ty-y)^2+(tz-z)^2
   if radius>=clearance and dist>minimum^2 and dist<(wd.range*.95)^2 and tx>64 and tz>64 and tx<Game.mapSizeX-64 and tz<Game.mapSizeZ-64 and ty>=0
    and S.TestMoveOrder(targetDef.id,tx,ty,tz,0,0,0,true,true,false)and S.IsPosInLos(tx,ty,tz,S.GetUnitAllyTeam(actor))then return tx,ty,tz end
  end
 end
 function C.Step(f)
  if C.result then return C.result end
  if S.GetUnitIsDead(actor)or S.GetUnitTeam(actor)~=team then return'FAIL paid_aircraft_lost_or_transferred'end
  if C.phase=='site'and f>C.started and f%15==0 then
   local x,y,z=site()
   if x then
    C.target=S.CreateUnit('imp_russ',x,y,z,0,enemy)
    if not C.target then return'FAIL exact_enemy_target_birth'end
    S.GiveOrderToUnit(C.target,CMD.FIRE_STATE,{0},0);S.GiveOrderToUnit(C.target,CMD.MOVE_STATE,{0},0)
    C.phase='settle';C.stage=f;emit('COMBAT_TARGET','id='..C.target,'enemy='..enemy,'unpaid_enemy_target=true ordinary_own_resources_unchanged=true')
   elseif f-C.started>=300 then return'INCONCLUSIVE no_legal_naturally_visible_air_target'end
  elseif C.phase=='settle'then
   if S.GetUnitIsDead(C.target)or S.AreTeamsAllied(team,S.GetUnitTeam(C.target))then return'FAIL settled_enemy_target_invalid'end
   local los=S.GetUnitLosState(C.target,S.GetUnitAllyTeam(actor),false)or{};local hp,_,_,_,progress=S.GetUnitHealth(C.target)
   if f>C.stage and los.los==true and progress==1 then
    C.lastHP=hp;C.phase='fire';C.stage=f
    S.GiveOrderToUnit(actor,CMD.ATTACK,{C.target},0);emit('PRIMARY_COMBAT_ORDER','native_ATTACK=true no_mount_isolation=true')
   elseif f-C.stage>=300 then return'INCONCLUSIVE natural_enemy_unit_visibility'end
  elseif C.phase=='fire'then
   if C.result then return C.result end
   local complete=C.hits>=2;for piece in pairs(allowed)do if not C.barrels[piece]then complete=false end end
   if complete then return'PASS paid_native_factory paid_genuine_Fighta native_release normal_MOVE_airborne_travel primary_native_Query_Shot_projectile_damage four_source_muzzles'end
   if S.GetUnitIsDead(C.target)then return'INCONCLUSIVE enemy_lost_before_primary_witness'end
   if f-C.stage>=1800 then return'INCONCLUSIVE primary_air_weapon_timeout'end
  end
 end
 function C.Close()
  C.closed=true
  if C.target and S.ValidUnitID(C.target)and not S.GetUnitIsDead(C.target)then S.DestroyUnit(C.target,false,true)end
 end
 return C
end
return M

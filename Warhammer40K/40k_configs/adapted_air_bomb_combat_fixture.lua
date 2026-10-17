-- Source-only observer for paid native corshad adaptation. Enemy target funded.
local M={}
function M.New(S,defs,weapons,actor,team,frame,emit)
 local d=defs and defs[S.GetUnitDefID(actor)];local entry=d and d.weapons and d.weapons[1];local w=entry and weapons and weapons[entry.weaponDef]
 local C={phase='site',started=frame,actor=actor,team=team,projectiles={},hits=0,spawns=0}
 if not d or not d.canFly or not w or w.type~='AircraftBomb' or(d.customParams or{}).prototype40k_native_donor~='corshad' or #d.weapons~=1 then C.result='FAIL exact_native_light_bomber_contract';return C end
 local enemy;for _,t in ipairs(S.GetTeamList())do if t~=S.GetGaiaTeamID()and not S.AreTeamsAllied(team,t)then enemy=t;break end end
 if not enemy then C.result='INCONCLUSIVE hostile_team_required';return C end
 C.weapon=entry.weaponDef
 local function visible()
  return C.target and (S.GetUnitLosState(C.target,S.GetUnitAllyTeam(actor),false)or{}).los==true
 end
 function C.Projectile(pid,owner,weapon)
  if C.closed or C.phase~='fire' or owner~=actor or weapon~=C.weapon then return end
  if C.projectiles[pid]then C.result='FAIL duplicate_native_bomb_birth';return end
  local x,y,z=S.GetProjectilePosition(pid);local mx,my,mz=S.GetUnitWeaponVectors(actor,1)
  if not x or not mx or not visible()then C.result='FAIL native_bomb_position_or_natural_LOS_missing';return end
  local ax,ay,az=S.GetUnitPosition(actor)
  if not ax or ay-S.GetGroundHeight(ax,az)<40 then C.result='FAIL native_bomb_not_airborne';return end
  if(x-mx)^2+(y-my)^2+(z-mz)^2>64^2 then C.result='FAIL native_bomb_outside_weapon_origin';return end
  C.projectiles[pid]={birth=S.GetGameFrame(),x=x,y=y,z=z};C.spawns=C.spawns+1
  emit('NATIVE_BOMB','pid='..pid,'weapon='..weapon,'natural_LOS=true','airborne=true','native_weapon_vectors=true')
 end
 function C.Damaged(id,damage,para,weapon,pid,attacker)
  if C.closed or C.phase~='fire'or id~=C.target or attacker~=actor or weapon~=C.weapon or para or damage<=0 then return end
  local p=C.projectiles[pid];if not p then C.result='FAIL bomb_damage_missing_native_projectile';return end
  if p.hit then C.result='FAIL duplicate_bomb_target_damage';return end
  local hp=S.GetUnitHealth(id)
  if not hp or not C.lastHP or hp>=C.lastHP then C.result='FAIL bomb_damage_missing_native_health_loss';return end
  p.hit=true;C.lastHP=hp;C.hits=C.hits+1;emit('NATIVE_BOMB_HIT','pid='..pid,'health='..hp,'damage='..damage,'hits='..C.hits)
 end
 local function site()
  local td=UnitDefNames.imp_russ;local x,y,z=S.GetUnitPosition(actor);local sight=d.sightDistance or d.losRadius
  if not td or not x or type(sight)~='number' or sight<=0 then return end
  local radius=math.min(w.range*.55,sight*.75);local target=defs[td.id]
  if not target then return end
  local clearance=(math.max(d.xsize,d.zsize)+math.max(target.xsize,target.zsize))*4+16
  for dir=0,15 do local a=dir*math.pi/8;local tx,tz=x+radius*math.sin(a),z+radius*math.cos(a);local ty=S.GetGroundHeight(tx,tz)
   if radius>=clearance and tx>64 and tz>64 and tx<Game.mapSizeX-64 and tz<Game.mapSizeZ-64 and ty>=0 and(tx-x)^2+(ty-y)^2+(tz-z)^2<(w.range*.95)^2
    and S.TestMoveOrder(td.id,tx,ty,tz,0,0,0,true,true,false)and S.IsPosInLos(tx,ty,tz,S.GetUnitAllyTeam(actor))then return tx,ty,tz end
  end
 end
 function C.Step(f)
  if C.result then return C.result end
  if S.GetUnitIsDead(actor)or S.GetUnitTeam(actor)~=team then return'FAIL paid_bomber_lost_or_transferred'end
  if C.phase=='site'and f>C.started and f%15==0 then
   local x,y,z=site()
   if x then
    C.target=S.CreateUnit('imp_russ',x,y,z,0,enemy)
    if not C.target then return'FAIL exact_funded_enemy_target_birth'end
    S.GiveOrderToUnit(C.target,CMD.FIRE_STATE,{0},0);S.GiveOrderToUnit(C.target,CMD.MOVE_STATE,{0},0)
    C.phase='settle';C.stage=f;emit('FUNDED_ENEMY_TARGET','id='..C.target,'enemy='..enemy,'enemy_only_non_economy_setup=true own_resources_ordinary=true')
   elseif f-C.started>=300 then return'INCONCLUSIVE naturally_visible_legal_bomb_target_missing'end
  elseif C.phase=='settle'then
   if S.GetUnitIsDead(C.target)or S.AreTeamsAllied(team,S.GetUnitTeam(C.target))then return'FAIL funded_enemy_target_invalid'end
   local hp,_,_,_,progress=S.GetUnitHealth(C.target)
   if f>C.stage and visible()and progress==1 then
    C.lastHP=hp;C.phase='fire';C.stage=f;S.GiveOrderToUnit(actor,CMD.ATTACK,{C.target},0);emit('NATIVE_ATTACK','target='..C.target,'natural_LOS=true')
   elseif f-C.stage>=300 then return'INCONCLUSIVE natural_target_visibility'end
  elseif C.phase=='fire'then
   if C.hits>=2 then return'PASS ordinary_paid_native_factory paid_native_light_bomber native_release native_airborne_travel actual_bomb_projectiles_and_native_health_loss funded_enemy_only'end
   if S.GetUnitIsDead(C.target)then return'INCONCLUSIVE enemy_lost_before_two_bomb_hits'end
   if f-C.stage>=1800 then return'INCONCLUSIVE native_bomb_combat_timeout'end
  end
 end
 function C.Close()
  C.closed=true
  if C.target and S.ValidUnitID(C.target)and not S.GetUnitIsDead(C.target)then S.DestroyUnit(C.target,false,true)end
 end
 return C
end
return M

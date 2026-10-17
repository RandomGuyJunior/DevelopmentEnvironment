-- Ordinary own paid utility; funded hostile combat/salvage is non-economy setup.
local M={}
function M.New(S,D,W,F,builder,team,frame,choose,arrived,emit)
 local C={phase='approach',start=frame,projectiles={},hits=0,births={},baseline={}}
 local key='fortyk_ork_water_torpedo_defence';local targetKey='fortyk_guard_naval_constructor'
 local tn,en=UnitDefNames[key],UnitDefNames[targetKey];local td=tn and D[tn.id];local ed=en and D[en.id];local bd=D[S.GetUnitDefID(builder)]
 local entry=td and td.weapons and td.weapons[1];local w=entry and W and W[entry.weaponDef]
 local dead=FeatureDefNames[targetKey..'_dead'];local heap=FeatureDefNames[targetKey..'_heap']
 if not bd or not bd.isBuilder or not bd.canReclaim or not td or not ed or not F or not w or w.type~='TorpedoLauncher' or not w.waterWeapon
  or(td.customParams or{}).prototype40k_native_donor~='cortl'or(ed.customParams or{}).prototype40k_native_donor~='corcs'
  or td.minWaterDepth~=12 or td.metalCost~=170 or td.energyCost~=1800 or td.buildTime~=3750 or ed.wreckName~=targetKey..'_dead' or not dead or not heap
  or not F[dead.id]or not F[heap.id]or F[dead.id].metal~=100 or F[heap.id].metal~=50 then C.result='FAIL exact_native_water_combat_and_remains_contract';return C end
 local has=false;for _,v in ipairs(bd.buildOptions or{})do if v==tn.id then has=true end end
 if not has or not GG.Recoil40KResearch.CanBuild(team,tn.id,builder,false)then C.result='FAIL active_paid_torpedo_menu_or_gate';return C end
 C.weapon=entry.weaponDef;C.expected={[dead.id]=true,[heap.id]=true}
 local enemy;for _,t in ipairs(S.GetTeamList())do if t~=S.GetGaiaTeamID()and not S.AreTeamsAllied(team,t)then enemy=t;break end end
 if not enemy then C.result='INCONCLUSIVE hostile_team_required';return C end
 local site,stance=choose(tn.id)
 if not site then C.result='INCONCLUSIVE legal_paid_torpedo_site_missing';return C end
 C.site=site;C.stance=stance;S.GiveOrderToUnit(builder,CMD.MOVE,stance,0)
 emit('TORPEDO_BILL','170M1800E3750work native_draft12 native_weapon=true ordinary_own_resources=true')
 function C.UnitCreated(id,def,t,owner)
  if C.closed or def~=tn.id or t~=team then return end
  if C.phase~='build' or C.turret or owner~=builder then C.result='FAIL torpedo_unpaid_duplicate_or_foreign_birth';return end
  C.turret=id;emit('PAID_TORPEDO_BIRTH',id,owner)
 end
 function C.Projectile(pid,owner,weapon)
  if C.closed or C.phase~='fire'or owner~=C.turret or weapon~=C.weapon then return end
  if C.projectiles[pid]then C.result='FAIL duplicate_native_torpedo_birth';return end
  local los=S.GetUnitLosState(C.target,S.GetUnitAllyTeam(C.turret),false)or{}
  local x,y,z=S.GetProjectilePosition(pid);local mx,my,mz=S.GetUnitWeaponVectors(C.turret,1)
  if not x or not mx or not los.los or y>4 or(x-mx)^2+(y-my)^2+(z-mz)^2>32^2 then C.result='FAIL native_torpedo_origin_water_or_LOS';return end
  C.projectiles[pid]={};emit('NATIVE_TORPEDO',pid,weapon,'natural_LOS=true native_water_origin=true')
 end
 function C.Damaged(id,damage,para,weapon,pid,attacker)
  if C.closed or C.phase~='fire'or id~=C.target or attacker~=C.turret or weapon~=C.weapon or para or damage<=0 then return end
  local p=C.projectiles[pid];if not p then C.result='FAIL torpedo_damage_missing_projectile';return end
  if p.hit then C.result='FAIL duplicate_target_torpedo_hit';return end
  local hp=S.GetUnitHealth(id);if not hp or not C.lastHP or hp>=C.lastHP then C.result='FAIL torpedo_native_health_loss_missing';return end
  p.hit=true;C.lastHP=hp;C.hits=C.hits+1;emit('NATIVE_TORPEDO_HIT',pid,damage,hp,C.hits)
 end
 function C.UnitDestroyed(id,attacker)
  if C.closed or id~=C.target then return end
  if C.phase~='fire'or attacker~=C.turret or C.hits<1 then C.result='FAIL target_death_without_native_torpedo_hits';return end
  C.death=S.GetGameFrame();C.phase='wreck';emit('NATIVE_ENEMY_DEATH',id,attacker,'funded_enemy_combat_non_economy=true')
  S.GiveOrderToUnit(C.turret,CMD.STOP,{},0)
 end
 function C.FeatureCreated(id)
  if not C.closed and C.target then C.births[id]=S.GetGameFrame()end
 end
 function C.BuildStep(id,t,f,part)
  if not C.closed and f==C.feature and part<0 then
   if id~=builder or t~=team or not C.ordered then C.result='FAIL foreign_or_unordered_salvage_work'
   else C.lastStep=S.GetGameFrame();emit('NATIVE_SALVAGE_WORK',id,f,part)end
  end
 end
 function C.FeatureDestroyed(id)
  if C.closed or id~=C.feature then return end
  if not C.ordered or not C.lastStep or S.GetGameFrame()-C.lastStep>1 then C.result='FAIL wreck_lost_without_native_reclaim';return end
  C.destroyed=S.GetGameFrame();emit('NATIVE_SALVAGE_DELETED',id,'funded_enemy_salvage_non_economy=true')
 end
 local function wrecks()
  local ids={}
  for _,id in ipairs(S.GetFeaturesInCylinder(C.tx,C.tz,64)or{})do
   if not C.baseline[id]and C.expected[S.GetFeatureDefID(id)]then ids[#ids+1]=id end
  end
  return ids
 end
 local function targetSite()
  local x,y,z=S.GetUnitPosition(C.turret);local radius=math.min(w.range*.55,(td.sightDistance or td.losRadius or 0)*.7,(td.sonarRadius or 0)*.7)
  if radius<96 then return end
  for n=0,23 do local a=n*math.pi/12;local tx,tz=x+radius*math.sin(a),z+radius*math.cos(a);local ty=S.GetGroundHeight(tx,tz)
   if tx>64 and tz>64 and tx<Game.mapSizeX-64 and tz<Game.mapSizeZ-64 and ty<=-ed.minWaterDepth
    and S.TestMoveOrder(en.id,tx,ty,tz,0,0,0,true,true,false)and S.IsPosInLos(tx,0,tz,S.GetUnitAllyTeam(C.turret))
    and #S.GetUnitsInCylinder(tx,tz,96)==0 and #S.GetFeaturesInCylinder(tx,tz,96)==0 then return tx,0,tz end
  end
 end
 function C.Step(f)
  if C.result then return C.result end
  if S.GetUnitIsDead(builder)or S.GetUnitTeam(builder)~=team then return'FAIL paid_naval_builder_lost'end
  if C.turret and(S.GetUnitIsDead(C.turret)or S.GetUnitTeam(C.turret)~=team)then return'FAIL paid_torpedo_lost_or_transferred'end
  if f-C.start>900*(Game.gameSpeed or 30)then return'INCONCLUSIVE paid_torpedo_or_native_reclaim_timeout_'..C.phase end
  if C.phase=='approach'then
   if arrived(tn.id)then C.phase='build';S.GiveOrderToUnit(builder,-tn.id,site,0);emit('PAID_TORPEDO_ORDER',builder,tn.id)end
  elseif C.phase=='build'then
   if C.turret then
    local hp,_,_,_,p=S.GetUnitHealth(C.turret)
    if hp and hp>0 and p==1 then C.phase='site';C.stage=f end
   end
  elseif C.phase=='site'and f%15==0 then
   local x,y,z=targetSite()
   if x then
    for _,id in ipairs(S.GetAllFeatures())do C.baseline[id]=true end
    C.tx,C.tz=x,z;C.target=S.CreateUnit(targetKey,x,y,z,0,enemy)
    if not C.target then return'FAIL funded_enemy_ship_birth'end
    S.GiveOrderToUnit(C.target,CMD.MOVE_STATE,{0},0);S.GiveOrderToUnit(C.target,CMD.FIRE_STATE,{0},0)
    C.phase='settle';C.stage=f;emit('FUNDED_ENEMY_SHIP',C.target,'enemy_only_non_economy=true ordinary_own_costs=true')
   elseif f-C.stage>300 then return'INCONCLUSIVE legal_naturally_visible_water_target_missing'end
  elseif C.phase=='settle'then
   if S.GetUnitIsDead(C.target)or S.AreTeamsAllied(team,S.GetUnitTeam(C.target))then return'FAIL funded_enemy_ship_lost_or_transferred'end
   local los=S.GetUnitLosState(C.target,S.GetUnitAllyTeam(C.turret),false)or{};local hp,_,_,_,p=S.GetUnitHealth(C.target)
   if f>C.stage and los.los and p==1 then C.lastHP=hp;C.phase='fire';C.stage=f;S.GiveOrderToUnit(C.turret,CMD.ATTACK,{C.target},0)
   elseif f-C.stage>300 then return'INCONCLUSIVE natural_ship_LOS_missing'end
  elseif C.phase=='fire'then
   if f-C.stage>1800 then return'INCONCLUSIVE native_torpedo_hit_and_death_timeout'end
  elseif C.phase=='wreck'or C.phase=='reclaim'then
   local ids=wrecks();if #ids>1 then return'FAIL duplicate_salvage_entitlement'end
   if C.destroyed then
    if #ids~=0 then return'FAIL replacement_after_salvage'end
    if f-C.destroyed>=20 then
     if not C.partial or not C.commandSeen then return'FAIL native_partial_or_command_witness_missing'end
     return'PASS ordinary_paid_shipyard_constructor_tidal_torpedo funded_enemy_native_torpedo_death single_native_wreck_partial_and_final_reclaim_non_economy_salvage'
    end
    return
   end
   if #ids==0 then if C.feature then return'FAIL wreck_missing_without_native_callback'end;if f-C.death>120 then return'INCONCLUSIVE native_enemy_remains_missing'end;return end
   local id=ids[1];if not C.births[id]then return'FAIL wreck_birth_callback_missing'end
   if C.feature and C.feature~=id then return'FAIL salvage_feature_identity_changed'end
   C.feature=id;local fd=F[S.GetFeatureDefID(id)];local m,dm,e,de,left=S.GetFeatureResources(id)
   if not fd or not fd.reclaimable or not m or m<0 or m>100.001 or e~=0 or left<0 or left>1 then return'FAIL native_salvage_currency_or_descriptor'end
   if not C.ordered then
    if left~=1 or(m~=100 and m~=50)then return'FAIL nonpristine_native_salvage'end
    C.ordered=f;C.previousMetal,C.previousLeft=m,left;C.phase='reclaim';S.GiveOrderToUnit(builder,CMD.RECLAIM,{Game.maxUnits+id},0);emit('NATIVE_SALVAGE_ORDER',builder,id,m,'funded_enemy_non_economy=true income_overflow_not_salvage_proof=true')
   else
    if C.previousMetal and(m>C.previousMetal+.001 or left>C.previousLeft+.00001)then return'FAIL salvage_currency_or_fraction_increased'end
    C.previousMetal,C.previousLeft=m,left
    local cmd,_,_,param=S.GetUnitCurrentCommand(builder)
    if cmd==CMD.RECLAIM and param==Game.maxUnits+id then C.commandSeen=true end
    if left>0 and left<1 then C.partial=true;emit('NATIVE_SALVAGE_PARTIAL',id,m,left)end
   end
  end
 end
 function C.Close()
  C.closed=true
  if C.target and S.ValidUnitID(C.target)and not S.GetUnitIsDead(C.target)then S.DestroyUnit(C.target,false,true)end
 end
 return C
end
return M

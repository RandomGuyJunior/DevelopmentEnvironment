-- One native BAR cruiser adaptation. Entire diagnostic is explicitly funded.
-- Beam hits use distinct native WD + reload-state witnesses, not invented pids.
local M={}
function M.New(S,D,W,team,enemy,frame,emit)
 local C={start=frame,phase='setup',projectiles={},hit={},shots={}}
 local an=UnitDefNames.fortyk_ork_advanced_cruiser
 local surface=UnitDefNames.fortyk_guard_naval_constructor
 local sub=UnitDefNames.fortyk_guard_submarine
 local d=an and D[an.id];local sd=surface and D[surface.id];local ud=sub and D[sub.id]
 if not d or not sd or not ud or not W or d.minWaterDepth~=30 or not tostring(d.scriptName):lower():match('units/corcrus%.cob$')
  or(d.customParams or{}).prototype40k_native_donor~='corcrus'or(sd.customParams or{}).prototype40k_native_donor~='corcs'
  or(ud.customParams or{}).prototype40k_native_donor~='corsub'or#(d.weapons or{})~=3 or S.AreTeamsAllied(team,enemy)then C.result='FAIL exact_native_cruiser_targets_contract';return C end
 C.entries={};local seen={}
 for i=1,3 do local id=d.weapons[i].weaponDef;local w=W[id]
  if not w or seen[id]then C.result='INCONCLUSIVE duplicated_WD_mount_identity_requires_stronger_observer';return C end
  seen[id]=true;C.entries[id]=i
  if i<=2 and w.type~='BeamLaser'or i==3 and(w.type~='TorpedoLauncher'or not w.waterWeapon)then C.result='FAIL native_cruiser_three_weapon_roles';return C end
 end
 C.beams={d.weapons[1].weaponDef,d.weapons[2].weaponDef};C.torpedo=d.weapons[3].weaponDef
 local function clear(x,z,def)
  local td=D[def];local margin=math.max(td.xsize or 10,td.zsize or 10)*4+16
  if x<margin+64 or z<margin+64 or x>Game.mapSizeX-margin-64 or z>Game.mapSizeZ-margin-64 then return false end
  -- A centre sample alone does not establish footprint draft.
  for _,dx in ipairs({-margin,0,margin})do for _,dz in ipairs({-margin,0,margin})do
   if S.GetGroundHeight(x+dx,z+dz)>-td.minWaterDepth then return false end
  end end
  return S.TestMoveOrder(def,x,0,z,0,0,0,true,true,false)and#(S.GetUnitsInCylinder(x,z,margin+32)or{})==0 and#(S.GetFeaturesInCylinder(x,z,margin+32)or{})==0
 end
 function C.Projectile(pid,owner,weapon)
  -- Native independent underwater mount can fire while beam stage is active.
  -- Record genuine own depthcharge births throughout the active fixture;
  -- target-role, native HP loss and one-hit-per-PID gates remain below.
  if C.result or C.phase=='done'or owner~=C.actor or weapon~=C.torpedo then return end
  if C.projectiles[pid]then C.result='FAIL duplicate_torpedo_projectile';return end
  local x,y,z=S.GetProjectilePosition(pid);local mx,my,mz=S.GetUnitWeaponVectors(C.actor,3)
  if not x or not mx or(x-mx)^2+(y-my)^2+(z-mz)^2>64^2 then C.result='FAIL native_depthcharge_origin';return end
  C.projectiles[pid]={bornPhase=C.phase,owner=owner,weapon=weapon};emit('NATIVE_DEPTHCHARGE',pid,weapon,'born_phase='..C.phase,'origin_sanity_not_rendered_mount_acceptance=true')
 end
 function C.Damaged(id,damage,para,weapon,pid,attacker)
  if C.result or id~=C.target or para or damage<=0 then return end
  if C.phase~='surface'and C.phase~='sub'then
   emit('NATIVE_DAMAGE_OUTSIDE_ACTIVE_TARGET_STAGE','phase='..C.phase,'WD='..tostring(weapon),'pid='..tostring(pid),'no_acceptance_credit=true');return
  end
  if attacker~=C.actor then C.result='FAIL unrelated_native_target_damage';return end
  local slot=C.entries[weapon]
  if not slot then C.result='FAIL unexpected_cruiser_weapon';return end
  if C.phase=='surface'and slot==3 or C.phase=='sub'and slot~=3 then C.result='FAIL native_target_role_mismatch';return end
  local hp=S.GetUnitHealth(id)
  if not hp or not C.lastHP or hp>=C.lastHP then C.result='FAIL native_target_health_loss_missing';return end
  if slot==3 then
   local p=C.projectiles[pid];if not p or p.hit then
    emit('NATIVE_DEPTHCHARGE_HIT_REFUSED','pid='..tostring(pid),'WD='..tostring(weapon),'attacker='..tostring(attacker),'target='..tostring(id),'phase='..C.phase,'recorded='..tostring(p~=nil),'duplicate='..tostring(p and p.hit or false))
    C.result='FAIL native_depthcharge_projectile_hit_missing_or_duplicate';return end;p.hit=true
   emit('NATIVE_DEPTHCHARGE_NATIVE_HIT','pid='..pid,'WD='..weapon,'born_phase='..p.bornPhase,'native_HP_loss='..(C.lastHP-hp))
  else
   -- BeamLaser can deliver damage without a durable projectile id. Native
   -- reload-state change is observed separately; don't fabricate a projectile.
   emit('NATIVE_BEAM_DAMAGE',weapon,pid,'distinct_WD_native_damage_not_per_Query_claim=true')
  end
  C.lastHP=hp;C.hit[slot]=(C.hit[slot]or 0)+1;emit('NATIVE_HEALTH_LOSS',slot,weapon,damage,hp)
 end
 function C.UnitDestroyed(id,attacker)
  if id==C.actor then C.result='FAIL funded_cruiser_destroyed'
  elseif id==C.target then
   if attacker~=C.actor then C.result='FAIL unrelated_target_death'
   elseif C.phase=='surface'and(not C.hit[1]or not C.hit[2])then C.result='INCONCLUSIVE surface_target_died_before_both_beams'
   elseif C.phase=='sub'and not C.hit[3]then C.result='FAIL submarine_death_without_native_projectile_hit'end
  end
 end
 function C.Step(f)
  if C.result then return C.result end
  if f-C.start>1800 then return'INCONCLUSIVE funded_cruiser_weapons_timeout_'..C.phase end
  if C.phase=='setup'then
   local x,z
   for gx=256,Game.mapSizeX-256,128 do for gz=256,Game.mapSizeZ-256,128 do
    if clear(gx,gz,an.id)and clear(gx+240,gz,surface.id)and clear(gx,gz+240,sub.id)then x,z=gx,gz;break end
   end;if x then break end end
   if not x then return'INCONCLUSIVE legal_full_draft_three_actor_water_sites_missing'end
   C.x,C.z=x,z;C.actor=S.CreateUnit('fortyk_ork_advanced_cruiser',x,0,z,0,team)
   C.surface=S.CreateUnit('fortyk_guard_naval_constructor',x+240,0,z,0,enemy)
   C.sub=S.CreateUnit('fortyk_guard_submarine',x,0,z+240,0,enemy)
   if not C.actor or not C.surface or not C.sub then return'FAIL funded_native_unit_birth'end
   for _,id in ipairs({C.actor,C.surface,C.sub})do S.GiveOrderToUnit(id,CMD.MOVE_STATE,{0},0);S.GiveOrderToUnit(id,CMD.FIRE_STATE,{0},0)end
   C.target=C.surface;C.phase='surface_wait';C.stage=f
   emit('FUNDED_SETUP','own_and_enemy_non_economy=true donor_corcrus_1000M12000E23000work_not_paid_acceptance=true native_draft30=true')
  else
   if S.GetUnitIsDead(C.actor)or S.GetUnitTeam(C.actor)~=team then return'FAIL cruiser_lost_or_transferred'end
   if S.GetUnitTeam(C.target)~=enemy and not S.GetUnitIsDead(C.target)then return'FAIL enemy_target_transferred'end
   for slot=1,3 do
    local r=S.GetUnitWeaponState(C.actor,slot,'reloadState')
    if C.reload and r and C.reload[slot]and r>C.reload[slot]then C.shots[slot]=(C.shots[slot]or 0)+1;emit('NATIVE_RELOAD_ADVANCE',slot,r)end
    C.reload=C.reload or{};C.reload[slot]=r
   end
   if C.phase=='surface_wait'or C.phase=='sub_wait'then
    local hp,_,_,_,built=S.GetUnitHealth(C.target);local los=S.GetUnitLosState(C.target,S.GetUnitAllyTeam(C.actor),false)or{}
    local detected=C.phase=='surface_wait'and los.los or C.phase=='sub_wait'and(los.los or los.radar)
    if built==1 and hp and hp>0 and detected then
     C.lastHP=hp;C.phase=C.phase=='surface_wait'and'surface'or'sub';S.GiveOrderToUnit(C.actor,CMD.FIRE_STATE,{2},0);S.GiveOrderToUnit(C.actor,CMD.ATTACK,{C.target},0)
     emit('NORMAL_ATTACK',C.target,'natural_LOS_or_sonar=true')
    elseif f-C.stage>300 then return'INCONCLUSIVE native_completion_or_natural_detection_missing'end
   elseif C.phase=='surface'and C.hit[1]and C.hit[2]and C.shots[1]and C.shots[2]then
    S.GiveOrderToUnit(C.actor,CMD.STOP,{},0);C.target=C.sub;C.phase='sub_wait';C.lastHP=nil;C.stage=f
   elseif C.phase=='sub'and C.hit[3]and C.shots[3]then
    S.GiveOrderToUnit(C.actor,CMD.STOP,{},0);C.phase='done'
    return'PASS funded_non_economy_cruiser_two_distinct_native_beam_health_losses_native_depthcharge_projectile_health_loss_all_three_reload_witnesses mount_render_Query_unaccepted'
   end
  end
 end
 return C
end
return M

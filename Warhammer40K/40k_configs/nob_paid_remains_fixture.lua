-- Paid own cohort; funded hostile native projectile setup only. Observer never owns corpses.
local M={}
function M.New(S,U,F,W,GG,actor,builder,factory,team,frame,emit)
 local C={started=frame,stage='blast',projectiles={},seen={},bodies={}};local R=GG.Recoil40KSquads;local squad=R and R.Get(actor)
 local function stop(reason)C.result=C.result or reason;return C.result end
 function C.Close()C.closed=true end
 if not squad or squad.profile~='ork_nob'or squad.team~=team or not squad.generations or #R.Members(actor)~=3 then stop('FAIL actual_paid_Nob3_required');return C end
 C.seed=squad.id;C.target=actor
 for slot=1,3 do
  local id=squad.slots[slot];if not id or not S.ValidUnitID(id)or not U[S.GetUnitDefID(id)]then stop('FAIL missing_paid_fixed_body');return C end
  local cp=U[S.GetUnitDefID(id)].customParams or{};local work,metal,energy=S.GetUnitCosts(id)
  local hp,_,_,_,built=S.GetUnitHealth(id)
  if not id or cp.animsource~='ork_nob'or not hp or hp<=0 or built~=1 or work~=660 or metal~=55 or energy~=275
   or S.GetUnitRulesParam(id,'40k_squad_schema')~=2 or S.GetUnitRulesParam(id,'40k_squad_generation')~=squad.generations[slot]
   or S.GetUnitRulesParam(id,'40k_squad_investment_metal')~=55 or S.GetUnitRulesParam(id,'40k_squad_investment_work')~=660 then stop('FAIL incomplete_or_nonhistorical_paid_body');return C end
  C.bodies[id]={def=S.GetUnitDefID(id),slot=slot,generation=squad.generations[slot]}
 end
 local enemy;for _,t in ipairs(S.GetTeamList())do if t~=S.GetGaiaTeamID()and not S.AreTeamsAllied(team,t)then enemy=t;break end end
 if not enemy then stop('INCONCLUSIVE hostile_team_required');return C end
 local russ=UnitDefNames.imp_russ;local entry=russ and U[russ.id].weapons[1];local w=entry and W[entry.weaponDef]
 if not w or w.type~='Cannon'or w.noExplode or(w.damageAreaOfEffect or 0)<16 then stop('FAIL genuine_native_blast_weapon_required');return C end
 C.weapon=entry.weaponDef;C.enemy=enemy;C.radius=w.damageAreaOfEffect
 if not Script or type(Script.SetWatchExplosion)~='function'then stop('FAIL native_explosion_watch_API_missing');return C end
 Script.SetWatchExplosion(C.weapon,true)
 function C.Explosion(weapon,x,y,z,owner,pid)
  if not C.closed and not C.result and weapon==C.weapon and C.projectiles[pid]then C.blastFrame=S.GetGameFrame();C.blastPID=pid;emit('NOB_NATIVE_EXPLOSION','pid='..pid,'native_damage_owner=true')end
  return false
 end
 function C.Damaged(id,damage,para,weapon,pid)
  if C.closed or C.result or not C.bodies[id]or weapon~=C.weapon or not C.projectiles[pid]or damage<=0 or para then return end
  local hp=S.GetUnitHealth(id)
  if hp and hp<=0 and C.blastPID==pid and C.blastFrame==S.GetGameFrame()then C.bodies[id].lethal=true;emit('NOB_NATIVE_LETHAL','body='..id,'pid='..pid,'funded_hostile_blast_only=true')end
 end
 function C.BuildStep(id,t,f,def,part)
  if C.closed or C.result or f~=C.feature or part>=0 then return true end
  if id~=builder or t~=team or not C.ordered or def~=S.GetFeatureDefID(f)then stop('FAIL foreign_or_unordered_native_reclaim')else C.lastWork=S.GetGameFrame()end
  return true
 end
 function C.FeatureDestroyed(fid)
  if C.closed or fid~=C.feature or C.result then return end
  if not C.ordered or not C.lastWork or S.GetGameFrame()-C.lastWork>1 then stop('FAIL feature_lost_without_native_reclaim');return end
  C.destroyed=S.GetGameFrame()
 end
 local function features()
  local matches={};local identities={}
  for _,fid in ipairs(S.GetAllFeatures())do
   local d=F[S.GetFeatureDefID(fid)];local cp=d and d.customParams or{}
   if cp.parent_actor=='ork_nob'and tonumber(S.GetFeatureRulesParam(fid,'40k_remains_squad'))==C.seed then
    if S.GetFeatureRulesParam(fid,'40k_remains_version')~=1 or S.GetFeatureRulesParam(fid,'40k_remains_team')~=team then return nil,'corrupt_native_corpse_owner_schema'end
    local slot=S.GetFeatureRulesParam(fid,'40k_remains_slot');local generation=S.GetFeatureRulesParam(fid,'40k_remains_generation');local key=tostring(slot)..':'..tostring(generation)
    if identities[key]then return nil,'duplicate_native_entitlement'end;identities[key]=fid
    local expected;for _,body in pairs(C.bodies)do if body.slot==slot and body.generation==generation then expected=body end end
    if not expected or not expected.lethal or S.GetFeatureRulesParam(fid,'40k_remains_def')~=expected.def then return nil,'unmatched_native_corpse_identity'end
    matches[#matches+1]=fid
    if slot==C.bodies[actor].slot then C.seen[fid]=true;C.feature=C.feature or fid;if C.feature~=fid then return nil,'replacement_entitlement'end end
   end
  end
  return matches
 end
 function C.Step(f)
  if C.closed then return C.result end
  if C.result then return C.result end
  if S.GetUnitIsDead(builder)or S.GetUnitTeam(builder)~=team or S.GetUnitIsDead(factory)or S.GetUnitTeam(factory)~=team then return stop('FAIL original_paid_builder_or_factory_lost_or_captured')end
  for id,body in pairs(C.bodies)do if not body.lethal then
   if not S.ValidUnitID(id)or S.GetUnitIsDead(id)or S.GetUnitTeam(id)~=team then return stop('FAIL paid_Nob_body_captured_or_nonwitness_death')end
   if S.GetUnitTransporter(id)then return stop('FAIL paid_Nob_carried_before_blast')end
  end end
  if f-C.started>2400 then return stop('INCONCLUSIVE bounded_native_Nob_remains_timeout')end
  local found,why=features();if not found then return stop('FAIL '..why)end
  if C.destroyed then
   for _,fid in ipairs(found)do if C.seen[fid]then return stop('FAIL corpse_reappeared_after_reclaim')end end
   if f-C.destroyed>=30 then return stop(C.partial and C.commandSeen and'PASS paid_Nob3 native_lethal_throw_landing historical_quarter partial_complete_builder_reclaim_once native_pose_pending'or'FAIL partial_or_native_command_evidence_missing')end
   return
  end
  if C.stage=='blast'and not C.bodies[actor].lethal and f%30==0 then
   local x,y,z=S.GetUnitPosition(actor)
   for _,id in ipairs({builder,factory})do local ox,_,oz=S.GetUnitPosition(id);if(x-ox)^2+(z-oz)^2<=(C.radius+S.GetUnitRadius(id)+16)^2 then return stop('INCONCLUSIVE no_safe_hostile_blast_site')end end
   if S.GetUnitTransporter(actor)then return stop('FAIL paid_Nob_carried_before_blast')end
   local pid=S.SpawnProjectile(C.weapon,{pos={x,y+35,z},speed={0,-2,0},['end']={x,y,z},team=C.enemy,ttl=120,gravity=0})
   if not pid or pid<0 then return stop('INCONCLUSIVE genuine_hostile_projectile_refused')end
   C.projectiles[pid]=true;emit('NOB_FUNDED_BLAST','pid='..pid,'own_paid_economy_untouched=true','ordinary_combat_economy_acceptance=false')
  end
  if not C.feature then return end
  local fid=C.feature;local m,dm,e,de,left,work=S.GetFeatureResources(fid);local flying=S.GetFeatureRulesParam(fid,'40k_remains_flying')
  if not m or e~=0 or de~=0 or m<0 or m>13.75+.001 or not dm or dm<0 or dm>13.75+.001 or not left or left<0 or left>1 or(flying~=1 and work~=165)then return stop('FAIL native_remains_currency')end
  if flying==1 then if m~=0 or dm~=0 then return stop('FAIL airborne_remains_currency')end;C.airborne=true;return end
  if flying~=0 or not C.airborne then return end
  if S.GetFeatureRulesParam(fid,'40k_remains_metal')~=13.75 or S.GetFeatureRulesParam(fid,'40k_remains_work')~=165 then return stop('FAIL historical_quarter_entitlement')end
  C.stage='reclaim'
  if not C.ordered then
   if m~=13.75 or dm~=13.75 or left~=1 or work~=165 then return stop('FAIL nonpristine_landed_corpse')end
   C.ordered=f;S.GiveOrderToUnit(builder,CMD.RECLAIM,{Game.maxUnits+fid},0);emit('NOB_NATIVE_RECLAIM_ORDER','fid='..fid,'ordinary_builder=true');return
  end
  if C.previousMetal and(m>C.previousMetal+.001 or left>C.previousLeft+.00001)then return stop('FAIL native_reclaim_resource_increase')end
  C.previousMetal=m;C.previousLeft=left
  local cmd,_,_,param=S.GetUnitCurrentCommand(builder);if cmd==CMD.RECLAIM and param==Game.maxUnits+fid then C.commandSeen=true end
  if left>0 and left<1 then C.partial=true;emit('NOB_NATIVE_PARTIAL_RECLAIM','fid='..fid,'metal='..m,'left='..left)end
 end
 return C
end
return M

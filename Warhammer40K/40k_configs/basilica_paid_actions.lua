-- Native orders/readbacks only. No resource, health, position or feature writes.
local M={Option='prototype_basilica_paid_driver'}
local function on(v)return v==true or v==1 or v=='1'end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
function M.Enabled(o)
 return on(o[M.Option])and on(o.prototype_development_playtest)and on(o.prototype_source_progression)
  and on(o.prototype_basilica_wall_observer)and on(o.prototype_squad_state_digest)and on(o.prototype_feature_remains_digest)
  and o.prototype_diagnostic=='normal'and not on(o.prototype_source_paid_match)and not on(o.prototype_scale085_pilot)
end
function M.New(S,D,W,F,R,paid,P,emit,Ledger)
 local C={phase='route',started=S.GetGameFrame(),waypoint=1,projectiles={},credits=0,partial=false,hits=0}
 local team=0;local cohort=paid.cohort;local builder=paid.basic;local russ=paid.russ
 local function fail(why)C.result='INCONCLUSIVE '..why;return C.result end
 for _,name in ipairs({'GetTeamResourceStats','GetTeamResources','GetUnitResources','GetUnitCurrentCommand','GetFeatureResources','GetFeatureHealth','GetUnitWeaponTestRange','TestMoveOrder','ValidFeatureID'})do if type(S[name])~='function'then fail('native_API_missing_'..name);return C end end
 local function live(id)return id and not S.GetUnitIsDead(id)and S.GetUnitTeam(id)==team and select(5,S.GetUnitHealth(id))==1 end
 local row=R.Get(cohort)
 if not row or row.profile~='guard_line'or row.leader~=cohort or row.team~=team or #R.Members(cohort)~=8 or not live(builder)or not live(russ)
  or D[S.GetUnitDefID(builder)].name~='wh40k_armcv'or not D[S.GetUnitDefID(builder)].canReclaim or D[S.GetUnitDefID(russ)].name~='imp_russ'then fail('actual_paid_Guard8_armcv_Russ_context_required');return C end
 C.members={};for slot=1,8 do local id=row.slots[slot]
  if C.members[id]or not live(id)or not paid.finished[id]or not row.generations[slot]or S.GetUnitTransporter(id)
   or S.GetUnitRulesParam(id,'40k_squad_schema')~=2 or S.GetUnitRulesParam(id,'40k_squad_id')~=row.id
   or S.GetUnitRulesParam(id,'40k_squad_slot')~=slot or S.GetUnitRulesParam(id,'40k_squad_generation')~=row.generations[slot]
   or S.GetUnitRulesParam(id,'40k_squad_investment_metal')~=8 or S.GetUnitRulesParam(id,'40k_squad_investment_energy')~=40 or S.GetUnitRulesParam(id,'40k_squad_investment_work')~=100
   or P.Outside(S,D,paid.barracks,id)~=true then fail('paid_full8_finish_private_bill_and_geometry_required');return C end
  C.members[id]={slot=slot,generation=row.generations[slot]}
 end
 for _,id in ipairs({builder,russ})do if not paid.finished[id]or not paid.released[id]then fail('paid_individual_native_finish_and_release_required');return C end end
 for _,id in ipairs(S.GetAllFeatures())do local d=F[S.GetFeatureDefID(id)];local x,_,z=S.GetFeaturePosition(id)
  if d and d.name=='40k_gothic_wall'and x==768 and z==4352 then
   if C.wall then fail('ambiguous_saved_wall');return C end
   if not d.destructable or not d.reclaimable or not d.deathFeatureID or not F[d.deathFeatureID]or F[d.deathFeatureID].name~='40k_rubble_remnant'then fail('actual_native_wall_wreck_binding_required');return C end
   C.wall=id;C.wallDef=S.GetFeatureDefID(id);C.rubbleDef=d.deathFeatureID;C.wallHP=S.GetFeatureHealth(id)
   local m,dm,e,de,left=S.GetFeatureResources(id)
   if C.wallHP~=650 or m~=25 or dm~=25 or e~=0 or de~=0 or left~=1 then fail('pristine_actual_wall_required');return C end
  end
 end
 if not C.wall then fail('saved_wall_missing');return C end
 C.weapons={};for _,entry in ipairs(D[S.GetUnitDefID(russ)].weapons or{})do if W[entry.weaponDef]then C.weapons[entry.weaponDef]=true end end
 local route={{992,3072},{1792,3072},{1792,1536},{3072,1536},{3072,3072}}
 local function intact()
  local r=R.Get(cohort);if not r or r.team~=team or r.leader~=cohort or #R.Members(cohort)~=8 then return false end
  for id,b in pairs(C.members)do if not live(id)or r.slots[b.slot]~=id or r.generations[b.slot]~=b.generation or S.GetUnitTransporter(id)then return false end end
  return live(builder)and live(russ)
 end
 local function move(x,z)
  local y=S.GetGroundHeight(x,z);if not finite(y)or y<0 then return false end
  for _,id in ipairs({cohort,builder,russ})do
   if S.TestMoveOrder(S.GetUnitDefID(id),x,y,z,0,0,0,true,true,false)~=true then return false end
  end
  for _,id in ipairs({cohort,builder,russ})do if S.GiveOrderToUnit(id,CMD.MOVE,{x,y,z},0)==false then return false end end
  C.destination={x,z};return true
 end
 local function arrived(all)
  local actors={builder,russ};if all then for id in pairs(C.members)do actors[#actors+1]=id end end
  for _,id in ipairs(actors)do local x,_,z=S.GetUnitPosition(id);if not x or(x-C.destination[1])^2+(z-C.destination[2])^2>96^2 then return false end end
  return true
 end
 function C.Projectile(pid,owner,wd)
  if C.phase~='fire'or owner~=russ or not C.weapons[wd]then return end
  if C.projectiles[pid]then return fail('reused_wall_attack_PID')end
  C.projectiles[pid]={wd=wd,owner=owner}
 end
 function C.FeatureDamaged(id,def,featureTeam,damage,wd,pid,attacker,attackerDef,attackerTeam)
  if id==C.rubble then return fail('rubble_damaged_not_pure_reclaim')end
  if id~=C.wall or C.phase~='fire'then return end
  local p=C.projectiles[pid];local hp=S.GetFeatureHealth(id)
  if def~=C.wallDef or attacker~=russ or attackerTeam~=team or not p or p.wd~=wd or not finite(damage)or damage<=0 or not finite(hp)or hp>=C.wallHP then return fail('actual_Russ_PID_WD_and_feature_HP_loss_required')end
  C.wallHP=hp;C.hits=C.hits+1;emit('WALL_NATIVE_HIT',pid,wd,damage,hp)
 end
 function C.FeatureCreated(id)
  if S.GetFeatureDefID(id)~=C.rubbleDef then return end
  local x,_,z=S.GetFeaturePosition(id);if x~=768 or z~=4352 then return end
  if C.rubble then return fail('duplicate_native_rubble')end
  if C.phase~='fire'or C.hits<1 then return fail('rubble_not_after_native_wall_attack')end
  C.rubble=id;C.rubbleBorn=S.GetGameFrame();emit('NATIVE_RUBBLE_BIRTH',id)
 end
 local function closeCredit()
  local pending=C.creditBefore;if not pending then return end
  local _,produced,excess,received,sent=S.GetTeamResourceStats(team,'metal')
  local _,energyProduced=S.GetTeamResourceStats(team,'energy')
  local expected=pending.metal
  if C.rubble and S.ValidFeatureID(C.rubble)then expected=expected-select(1,S.GetFeatureResources(C.rubble))end
  if not finite(expected)or expected<0 or S.GetGameFrame()<pending.frame or S.GetGameFrame()>pending.frame+1 then fail('invalid_native_feature_depletion_window')end
  C.credits=C.credits+expected -- Feature entitlement only; never asserted as team payment.
  local make,use,energyMake,energyUse=S.GetUnitResources(builder)
  emit('NATIVE_FEATURE_DEPLETION',expected,'builder_make='..tostring(make),'builder_use='..tostring(use),'builder_energy_make='..tostring(energyMake),'builder_energy_use='..tostring(energyUse),'team_produced_slow='..tostring(produced),'exact_payment_unresolved=true')
  C.creditBefore=nil
 end
 function C.BuildStep(id,t,fid,def,part)
  if fid==C.rubble and not finite(part)then fail('nonfinite_native_reclaim_work');return true end
  if C.ledger then local why=C.ledger.Work(id,t,fid,part);if why then fail(why)end end
  if fid~=C.rubble or part>=0 then return true end
  if C.phase~='reclaim'or id~=builder or t~=team or not C.ordered then fail('foreign_or_unordered_native_reclaim');return true end
  closeCredit()
  local m,dm,e,de,left,time=S.GetFeatureResources(fid)
  if not finite(m)or dm~=2 or e~=0 or de~=0 or time~=60 or left<=0 or left>1 then fail('actual_single_rubble_currency_required');return true end
  local _,produced,excess,received,sent=S.GetTeamResourceStats(team,'metal');local _,energyProduced=S.GetTeamResourceStats(team,'energy')
  C.creditBefore={metal=m,produced=produced,energyProduced=energyProduced,excess=excess,received=received,sent=sent,frame=S.GetGameFrame()}
  C.lastStep=S.GetGameFrame();C.commandSeen=select(1,S.GetUnitCurrentCommand(builder))==CMD.RECLAIM and select(4,S.GetUnitCurrentCommand(builder))==Game.maxUnits+fid
  return true -- observation only; existing native owners retain permission/payment.
 end
 function C.FeatureDestroyed(id)
  if id==C.wall then
   if C.phase~='fire'or C.hits<1 or not C.rubble then return fail('actual_wall_death_and_rubble_birth_required')end
   C.wallGone=true;S.GiveOrderToUnit(russ,CMD.STOP,{},0);S.GiveOrderToUnit(russ,CMD.FIRE_STATE,{0},0);C.phase='rubble'
  elseif id==C.rubble then
   if C.phase~='reclaim'or not C.lastStep or S.GetGameFrame()-C.lastStep>1 then return fail('rubble_lost_without_native_reclaim')end
   closeCredit();C.removed=S.GetGameFrame();C.phase='settle';if C.ledger then local why=C.ledger.Removed();if why then fail(why)end end
  end
 end
 function C.Step(frame)
  if C.result then return C.result end
  closeCredit() -- Next native frame samples prior work, never subtracts estimated income.
  if C.ledger then local why=C.ledger.Step(frame);if why then return fail(why)end end
  if not intact()then return fail('paid_cohort_or_builder_or_Russ_lost_captured_repaired_or_transported')end
  if frame-C.started>=12000 then return fail('bounded_native_actions_timeout_'..C.phase)end
  if C.phase=='route'then
   local p=route[C.waypoint]
   if not p then C.phase='approach';C.destination=nil
   elseif not C.destination then if not move(p[1],p[2])then return fail('native_lane_waypoint_not_passable')end
   elseif arrived(true)then emit('LANE_ALL8_AND_PAID_INDIVIDUALS_ARRIVED',C.waypoint,p[1],p[2],'wall_outside_main_road=true');C.waypoint=C.waypoint+1;C.destination=nil end
  elseif C.phase=='approach'then
   if not C.destination then if not move(768,4096)then return fail('native_local_wall_approach_unavailable')end
   elseif arrived(false)then local x,y,z=S.GetFeaturePosition(C.wall,true)
    if not S.GetUnitWeaponTestRange(russ,1,x,y,z)then return fail('natural_Russ_wall_range_unavailable')end
    C.phase='fire';S.GiveOrderToUnit(russ,CMD.ATTACK,{x,y,z},0);emit('WALL_ATTACK_ORDER','native_ground_attack=true no_feature_damage_setter=true')
   end
  elseif C.phase=='rubble'then
   local m,dm,e,de,left,time=S.GetFeatureResources(C.rubble)
   if m~=2 or dm~=2 or e~=0 or de~=0 or left~=1 or time~=60 then return fail('actual_pristine_two_metal_rubble_required')end
   if not Ledger then return fail('exact_native_builder_rolling_ledger_dependency_missing')end
   C.ledger=Ledger.New(S,D,builder,team,emit);C.ledger.feature=C.rubble;C.phase='baseline';C.ledger.Step(frame)
  elseif C.phase=='baseline'and C.ledger.ready then
   local why=C.ledger.Begin();if why then return fail(why)end
   C.phase='reclaim';C.ordered=frame;S.GiveOrderToUnit(builder,CMD.RECLAIM,{Game.maxUnits+C.rubble},0)
  elseif C.phase=='reclaim'then
   if not S.ValidFeatureID(C.rubble)then return fail('rubble_removed_without_destroy_callback')end
   local m,_,_,_,left=S.GetFeatureResources(C.rubble)
   if left>0 and left<1 then C.partial=true;emit('NATIVE_RUBBLE_PARTIAL',C.rubble,m,left)end
  elseif C.phase=='settle'and frame-C.removed>=30 then
   if S.ValidFeatureID(C.wall)or S.ValidFeatureID(C.rubble)then return fail('second_or_resurrected_feature_entitlement')end
   if not C.partial or not C.commandSeen then return fail('partial_or_native_reclaim_command_unobserved')end
   if math.abs(C.credits-2)>.001 then return fail('actual_two_metal_native_feature_depletion_missing')end
   if not C.ledger or not C.ledger.proved then return end
   C.phase='passage';C.destination=nil;emit('NATIVE_ONE_ENTITLEMENT_REMOVED','actual_feature_depletion=2 native_builder_gross_credit=2 net_budget_not_used=true')
  elseif C.phase=='passage'then
   if not C.destination then if not move(768,4352)then return fail('former_wall_native_local_site_not_passable')end
   elseif arrived(false)then C.phase='exit';C.destination=nil;emit('NATIVE_FORMER_WALL_LOCAL_ARRIVAL','not_main_road_unblocking=true')end
  elseif C.phase=='exit'then
   if not C.destination then if not move(768,4608)then return fail('former_wall_native_local_exit_unavailable')end
   elseif arrived(false)then C.result='PASS ordinary_paid_Guard8_Russ_armcv_native_wall_rubble_partial_final_one_entitlement_two_native_builder_gross_metal_credit_local_passage render_unaccepted';return C.result end
  end
 end
 function C.UnitChanged()if C.ledger then return fail(C.ledger.Changed())end end
 return C
end
return M

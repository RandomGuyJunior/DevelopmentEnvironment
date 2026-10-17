-- Natural hostile fire + native feature/reclaim observation. Never owns death or credit.
local M={Version=1}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function yes(v)return v==true or v==1 or v=='1'end

-- Bounded readbacks only: unavailable/invalid shapes never become path claims.
function M.ReclaimReadback(S,D,builder,fid,frame,stage,elapsed,ordered,emit)
 local function read(api,...)
  if type(S[api])~='function'then return nil,'missing_API'end
  local function pack(...)return {n=select('#',...),...}end
  local out=pack(pcall(S[api],...));if not out[1]then return nil,'API_error'end
  local values={n=out.n-1};for i=2,out.n do values[i-1]=out[i]end;return values
 end
 local function integer(v)return finite(v)and v%1==0 end
 local function dense(t,limit)
  if type(t)~='table'or #t>limit then return false end
  local count=0;for k in pairs(t)do if not integer(k)or k<1 or k>#t then return false end;count=count+1 end
  return count==#t
 end
 local function point(t)return t and finite(t[1])and finite(t[2])and finite(t[3])end
 local bp,bwhy=read('GetUnitPosition',builder);local fp,fwhy=read('GetFeaturePosition',fid)
 local bd=read('GetUnitDefID',builder);local def=bd and D[bd[1]];local range=def and def.buildDistance
 if point(bp)and point(fp)and finite(range)and range>0 then
  local distance=math.sqrt((bp[1]-fp[1])^2+(bp[2]-fp[2])^2+(bp[3]-fp[3])^2)
  emit('RECLAIM_APPROACH_POSITION',builder,fid,frame,stage,elapsed,ordered and frame-ordered or 'not_ordered',
   bp[1],bp[2],bp[3],fp[1],fp[2],fp[3],distance,range,'native_full_build_range_not_inferred=true')
 else emit('RECLAIM_APPROACH_POSITION_UNAVAILABLE',builder,fid,frame,stage,bwhy or 'invalid_position_or_buildDistance',fwhy or 'invalid_feature_position')end
 local cmd,why=read('GetUnitCurrentCommand',builder)
 if cmd and cmd.n==0 then emit('RECLAIM_APPROACH_COMMAND',builder,frame,stage,'empty')
 elseif cmd and integer(cmd[1])and integer(cmd[2])and integer(cmd[3])and cmd.n>=3 and cmd.n<=19 then
  local valid=true;for i=4,cmd.n do if not finite(cmd[i])then valid=false end end
  if valid then emit('RECLAIM_APPROACH_COMMAND',builder,frame,stage,table.concat(cmd,','),'native_scalar_tuple=true')
  else emit('RECLAIM_APPROACH_COMMAND_UNAVAILABLE',builder,frame,stage,'nonfinite_parameter')end
 else emit('RECLAIM_APPROACH_COMMAND_UNAVAILABLE',builder,frame,stage,why or 'invalid_or_overlong_scalar_tuple')end
 local count,cwhy=read('GetUnitCommandCount',builder);local queue,qwhy=read('GetUnitCommands',builder,2)
 local q=queue and queue[1];local rows={};local valid=dense(q,2)and count and integer(count[1])and count[1]>=0
 if valid then for _,row in ipairs(q)do
  if type(row)~='table'or not integer(row.id)or not integer(row.tag)or not dense(row.params,16)then valid=false;break end
  for _,v in ipairs(row.params)do if not finite(v)then valid=false end end
  if not valid then break end
  rows[#rows+1]=row.id..':'..row.tag..':'..table.concat(row.params,',')
 end end
 if valid and #q==math.min(count[1],2)then emit('RECLAIM_APPROACH_QUEUE',builder,frame,stage,count[1],#q,table.concat(rows,';'),'first_two_only=true')
 else emit('RECLAIM_APPROACH_QUEUE_UNAVAILABLE',builder,frame,stage,cwhy or qwhy or 'invalid_native_queue_shape')end
 local movement,mwhy=read('GetUnitMoveTypeData',builder);local m=movement and movement[1]
 if type(m)=='table'and m.name=='ground'and(m.progressState=='done'or m.progressState=='active'or m.progressState=='failed')
  and finite(m.goalx)and finite(m.goaly)and finite(m.goalz)and finite(m.currentSpeed)and finite(m.maxSpeed)then
  emit('RECLAIM_APPROACH_MOVEMENT',builder,frame,stage,m.name,m.progressState,m.goalx,m.goaly,m.goalz,m.currentSpeed,m.maxSpeed,
   'native_move_progress_only_path_viability_not_inferred=true')
 else emit('RECLAIM_APPROACH_MOVEMENT_UNAVAILABLE',builder,frame,stage,mwhy or 'invalid_or_non_ground_native_shape')end
end

function M.Route(o)
 o=o or{};local a=yes(o.prototype_necron_immortal_remains_native_fixture);local b=yes(o.prototype_necron_flayed_remains_native_fixture)
 if not a and not b then return end
 assert(a~=b,'Distinct Necron remains routes are mutually exclusive')
 assert(yes(o.prototype_necron_remains_paid_driver),'Owned ordinary paid driver required')
 assert(type(o.prototype_necron_remains_run_id)=='string'and #o.prototype_necron_remains_run_id>=12 and #o.prototype_necron_remains_run_id<=96
  and o.prototype_necron_remains_run_id:match('^[%w_-]+$'),'Owned fresh run identity required')
 for key,v in pairs(o)do
  if yes(v)and(key:match('_fixture$')or key:match('_paid_driver$')or key=='prototype_body_benchmark'or key=='prototype_mount_burst_observer')then
   assert(key=='prototype_necron_immortal_remains_native_fixture'or key=='prototype_necron_flayed_remains_native_fixture'
    or key=='prototype_necron_remains_native_fixture'or key=='prototype_necron_remains_paid_driver','Competing diagnostic/production owner refused: '..key)
  end
 end
 assert(tonumber(o.prototype_test_speed or 1)==1,'Native timing required')
 local actor=a and'immortal'or'flayed'
 assert(o.prototype_necron_remains_native_actor==actor,'Exact actor recipe and route must agree')
 return actor
end
function M.New(S,D,N,F,W,GG,physical,plan,contexts,emit,sourceBank,ledgerModule)
 local C={phase='separate',started=S.GetGameFrame(),bodies={},cohorts={},projectiles={},shots={},seen={},createdFeatures={},features={},destroyedFeatures={},singleCreditLedgerVerified=false}
 local function stop(reason)C.result=C.result or reason;return C.result end
 local function fail(reason)return stop('FAIL '..reason)end
 local function refuse(reason)return stop('INCONCLUSIVE '..reason)end
 function C.Close()C.closed=true end
 for _,api in ipairs({'GetUnitHealth','GetUnitCosts','GetUnitDefID','GetUnitTeam','GetUnitTransporter','GetUnitPosition','GetUnitRulesParam','GetUnitExperience','GetUnitRadius','GetUnitPieceMap','GetUnitPiecePosDir','GetUnitLosState','GetUnitAllyTeam','GetUnitWeaponTestRange','GetUnitWeaponState','GetUnitCurrentCommand','GetUnitCommands','GetTeamResources','GetUnitResources','GetAllFeatures','GetFeatureDefID','GetFeatureRulesParam','GetFeatureResources','GetFeaturePosition','GetGroundHeight','GetUnitsInRectangle','GetFeaturesInRectangle','TestMoveOrder','IsPosInLos','AreTeamsAllied','GetTeamList','GetGaiaTeamID','ValidUnitID','ValidFeatureID','GetUnitIsDead','CreateUnit','GiveOrderToUnit'})do
  if type(S[api])~='function'then fail('missing_native_API_'..api);return C end
 end
 if not GG.Recoil40KSquads or not GG.Recoil40KTacticalRemains or GG.Recoil40KCorpseAccount or GG.Recoil40KSpyderHarvestReview
  or type(GG.Recoil40KTacticalRemains.AllowFeatureBuildStep)~='function'or not physical or type(physical.Outside)~='function'
  or not contexts or not contexts.builder or not contexts.cohort1 or not contexts.cohort2 or Game.reclaimMethod~=0 then fail('sole_owner_paid_context_or_gradual_native_reclaim_required');return C end
 C.team=contexts.builder.team;C.builder=contexts.builder.product;C.builderDefinition=N.nec_scarab and N.nec_scarab.id
 local function live(id,team)
  if not id or not S.ValidUnitID(id)or S.GetUnitIsDead(id)or S.GetUnitTeam(id)~=team then return false end
  local hp,_,_,_,built=S.GetUnitHealth(id);return finite(hp)and hp>0 and built==1 and not S.GetUnitTransporter(id)
 end
 local function paidBuilder()
  local b=contexts.builder;local finished=b.finished and b.finished[C.builder];local work,metal,energy
  if C.builder then work,metal,energy=S.GetUnitCosts(C.builder)end
  return live(C.builder,C.team)and S.GetUnitDefID(C.builder)==C.builderDefinition and work==3450 and metal==110 and energy==1600
   and b.createdWork==3450 and b.createdMetal==110 and b.createdEnergy==1600 and finite(b.created)and finite(b.released)and b.released>=b.created
   and finished and finished.def==C.builderDefinition and finished.team==C.team and finite(finished.frame)and finished.frame>=b.created and finished.frame<=b.released and N.nec_hq and S.GetUnitDefID(b.factory)==N.nec_hq.id
   and live(b.factory,C.team)and physical.Outside(S,D,b.factory,C.builder)==true
 end
 if not paidBuilder()then fail('actual_paid_native_Scarab_origin_required');return C end
 if type(ledgerModule)~='table'or ledgerModule.period~=15 or type(ledgerModule.New)~='function'then refuse('reviewed_shared_native_credit_collector_required');return C end
 local R=GG.Recoil40KSquads
 for i=1,2 do
  local origin=contexts['cohort'..i];local state=R.Get(origin.product)
  if not state or state.id~=origin.seed or state.profile~=plan.profile or state.team~=C.team or state.leader~=origin.product or #R.Members(origin.product)~=plan.capacity
   or origin.createdMetal~=plan.productBill.metal or origin.createdEnergy~=plan.productBill.energy or origin.createdWork~=plan.productBill.work
   or not finite(origin.created)or not finite(origin.released)or origin.released<origin.created or not origin.slots
   or S.GetUnitDefID(origin.product)~=origin.productDefinition or origin.productDefinition~=N[plan.actor].id
   or S.GetUnitDefID(origin.factory)~=N[plan.factory].id or not live(origin.factory,C.team)then fail('two_actual_paid_released_full_cohorts_required');return C end
  local row={seed=state.id,victim=origin.product,origin=origin,bodies={}}
  for slot=1,plan.capacity do
   local stored=origin.slots[slot];local id=stored and stored.id;local def=id and S.GetUnitDefID(id);local finished=id and origin.finished and origin.finished[id]
   local work,metal,energy;if id then work,metal,energy=S.GetUnitCosts(id)end
   if not stored or C.bodies[id]or state.slots[slot]~=id or stored.def~=def or stored.generation~=1 or state.generations[slot]~=1 or not live(id,C.team)
    or not finished or finished.def~=def or finished.team~=C.team or not finite(finished.frame)or finished.frame<origin.created or finished.frame>origin.released or work~=plan.work or metal~=plan.metal or energy~=plan.energy
    or physical.Outside(S,D,origin.factory,id)~=true or S.GetUnitRulesParam(id,'40k_squad_schema')~=2
    or S.GetUnitRulesParam(id,'40k_squad_id')~=state.id or S.GetUnitRulesParam(id,'40k_squad_slot')~=slot
    or S.GetUnitRulesParam(id,'40k_squad_generation')~=1 or S.GetUnitRulesParam(id,'40k_squad_investment_metal')~=plan.metal
    or S.GetUnitRulesParam(id,'40k_squad_investment_energy')~=plan.energy or S.GetUnitRulesParam(id,'40k_squad_investment_work')~=plan.work then fail('immutable_actual_paid_body_required');return C end
   local hp,max=S.GetUnitHealth(id);if hp~=max then fail('fresh_paid_unwounded_cohort_required');return C end
   local b={id=id,def=def,seed=state.id,slot=slot,generation=1,xp=S.GetUnitExperience(id),cohort=i}
   if not finite(b.xp)then fail('native_XP_required');return C end
   C.bodies[id]=b;row.bodies[#row.bodies+1]=id
  end
  C.cohorts[i]=row
 end
 if C.cohorts[1].seed==C.cohorts[2].seed then fail('distinct_paid_cohorts_required');return C end
 local russ=N.imp_russ;local rd=russ and D[russ.id];local mount,wd
 if rd then for n,entry in ipairs(rd.weapons or{})do local w=W[entry.weaponDef]
  if w and w.type=='Cannon'and not w.noExplode and finite(w.damageAreaOfEffect)and w.damageAreaOfEffect>=16 then
   if mount then fail('ambiguous_genuine_Russ_explosive_mount');return C end;mount=n;wd=entry.weaponDef
  end
 end end
 if not wd then fail('genuine_native_Russ_Cannon_required');return C end
 if not finite(rd.xsize)or not finite(rd.zsize)or rd.xsize<=0 or rd.zsize<=0 or not finite(Game.mapSizeX)or not finite(Game.mapSizeZ)or not finite(Game.maxUnits)then fail('actual_native_shape_map_bounds_required');return C end
 local builderDef=D[C.builderDefinition];if not builderDef or (builderDef.metalMake or 0)~=0 or (builderDef.extractsMetal or 0)~=0 then refuse('passive_builder_metal_make_confounds_native_credit');return C end
 C.enemyDefinition=russ.id;C.mount=mount;C.weapon=wd;C.blastRadius=W[wd].damageAreaOfEffect
 for _,team in ipairs(S.GetTeamList())do if team~=S.GetGaiaTeamID()and not S.AreTeamsAllied(C.team,team)then C.enemyTeam=team;break end end
 if not C.enemyTeam then refuse('hostile_team_required');return C end
 local source=(W[wd].customParams or{}).source_muzzle or(sourceBank and sourceBank.muzzle)
 local inBank=false;for _,name in ipairs(sourceBank and sourceBank.bones or{})do if name==source then inBank=true end end
 if not inBank or sourceBank.scaleDerivative then fail('actual_unscaled_Russ_animation_bank_marker_required');return C end
 if type(source)~='string'or source==''then fail('actual_Russ_source_muzzle_required');return C end
 C.marker=source
 local othersRange=0;for n,entry in ipairs(rd.weapons)do if n~=C.mount then local w=W[entry.weaponDef];if not w or not finite(w.range)then fail('actual_other_Russ_mount_ranges_required');return C end;othersRange=math.max(othersRange,w.range)end end
 C.attackDistance=math.max(othersRange+64,W[wd].range*.8)
 if C.attackDistance>=W[wd].range-32 then refuse('natural_Cannon_only_range_band_unavailable');return C end
 function C.Telemetry(row)
  if C.closed or C.result or row.owner~=C.enemy or row.mount~=C.mount then return end
  if row.kind=='SHOT'then
   local target=C.cohorts[C.active].victim;local los=S.GetUnitLosState(target,S.GetUnitAllyTeam(C.enemy),false)or{}
   if C.phase~='fire'or row.ambiguous or not row.snapshot or row.snapshot.muzzle_name~=C.marker
    or not row.native_target or row.native_target[1]~=1 or row.native_target[3]~=target or los.los~=true then return fail('actual_native_Russ_Shot_target_muzzle_LOS_required')end
   C.shots[row.serial]={frame=row.frame,target=target,piece=row.snapshot.muzzle_piece}
   emit('RUSS_NATIVE_SHOT',row.serial,row.frame,C.enemy,C.mount,target)
  elseif row.kind=='PROJECTILE'then
   local shot=C.shots[row.shot_serial];local q=row.actual_query;local pos=row.position;local qp=q and q.snapshot and q.snapshot.muzzle_position
   if C.seen[row.projectile]or row.duplicate_pid or row.weapondef~=C.weapon or row.association~='unique_same_frame_unconsumed_shot'
    or not shot or shot.frame~=row.frame or not q or q.piece~=shot.piece or not pos or not qp then return fail('owned_native_Russ_PID_WD_Query_required')end
   local dist=0;for j=1,3 do if not finite(pos[j])or not finite(qp[j])then return fail('finite_actual_native_Russ_origin_required')end;dist=dist+(pos[j]-qp[j])^2 end
   if dist>64^2 then return fail('native_Russ_birth_not_Query_origin')end
   C.seen[row.projectile]=true;C.projectiles[row.projectile]={target=shot.target,frame=row.frame,owner=C.enemy}
   emit('RUSS_NATIVE_PROJECTILE',row.projectile,C.weapon,C.enemy,shot.target,row.frame,table.concat(pos,','),table.concat(qp,','))
  end
 end
 function C.Explosion(w,x,y,z,owner,pid)
  if C.closed or C.result or not C.projectiles[pid]then return false end
  if w~=C.weapon or owner~=C.projectiles[pid].owner or not finite(x)or not finite(y)or not finite(z)then fail('owned_native_explosion_identity_required');return false end
  local p=C.projectiles[pid];if p.explosion then fail('duplicate_owned_native_explosion');return false end
  p.explosion=S.GetGameFrame();p.position={x,y,z};emit('NATIVE_EXPLOSION',pid,w,owner,x,y,z,p.explosion)
  return false
 end
 function C.Damaged(id,def,team,damage,paralyzer,w,pid,attacker)
  if C.closed or C.result or not C.bodies[id]then return end
  local b=C.bodies[id];local hp=S.GetUnitHealth(id);local p=C.projectiles[pid]
  if def~=b.def or team~=C.team or not p or attacker~=p.owner or w~=C.weapon or not finite(damage)or damage<=0 or paralyzer then return fail('foreign_or_unbound_native_paid_body_damage')end
  emit('NATIVE_HP_DAMAGE',id,hp,damage,w,pid,attacker)
  if hp and hp<=0 then
   if id~=C.cohorts[C.active].victim or b.lethal or p.target~=id or p.explosion~=S.GetGameFrame()then return fail('unexpected_or_unwitnessed_native_casualty')end
   b.lethal=S.GetGameFrame();b.pid=pid;C.phase='landing'
   if S.GiveOrderToUnit(C.enemy,CMD.FIRE_STATE,{0},0)==false or S.GiveOrderToUnit(C.enemy,CMD.STOP,{},0)==false then return refuse('native_hostile_stop_rejected')end
   emit('MATCHING_NATIVE_LETHAL',id,b.seed,b.slot,b.generation,def,team,pid,w,attacker,b.lethal)
  end
 end
 function C.Destroyed(id,def,team,attacker,attackerDef,attackerTeam,weapon)
  if C.closed or C.result then return end
  C.Changed()
  local b=C.bodies[id];if not b then return end
  local projectile=b.pid and C.projectiles[b.pid]
  if not b.lethal or b.destroyed or b.lethal~=S.GetGameFrame()or def~=b.def or team~=C.team or not projectile
   or attacker~=projectile.owner or attackerDef~=C.enemyDefinition or attackerTeam~=C.enemyTeam or weapon~=C.weapon then
   return fail('direct_native_destroyed_not_same_frame_recognized_lethal_identity')
  end
  b.destroyed=S.GetGameFrame()
  emit('NATIVE_VICTIM_DESTROYED',id,def,team,attacker,attackerDef,attackerTeam,weapon,b.destroyed,b.seed,b.slot,b.generation,b.pid,'PID_bound_from_prior_Damaged_not_Destroyed_argument=true')
 end
 function C.FeatureCreated(fid)if not C.closed then C.createdFeatures[fid]=S.GetGameFrame()end end
 function C.Changed()if C.ledger and not C.ledger.proved and not C.closed then local why=C.ledger.Changed();if why then stop(why)end end end
 function C.UnitWork(builder)if builder==C.builder then C.Changed()end;return true end
 function C.BuildStep(builder,team,fid,def,part)
  if C.ledger and builder==C.builder and not C.closed and not C.result then local why=C.ledger.Work(builder,team,fid,part);if why then stop(why)end end
  if C.closed or C.result or not C.features[fid]then return true end
  if not finite(part)then fail('finite_native_reclaim_step_required');return true end
  if part>=0 then return true end
  local f=C.features[fid];local cmd,_,_,param=S.GetUnitCurrentCommand(C.builder)
  if builder~=C.builder or team~=C.team or not paidBuilder()or C.phase~='reclaim'or not f.land or not f.ordered
   or def~=S.GetFeatureDefID(fid)or cmd~=CMD.RECLAIM or param~=Game.maxUnits+fid
   or GG.Recoil40KTacticalRemains.AllowFeatureBuildStep(builder,team,fid,def,part)~=true then fail('foreign_prelanding_or_noncommand_native_reclaim')
  else f.lastWork=S.GetGameFrame();f.commandSeen=true;emit('NATIVE_RECLAIM_BUILD_STEP',builder,fid,def,part,f.lastWork)end
  return true -- Observer grants nothing. Existing sole owner/native engine decide.
 end
 function C.FeatureDestroyed(fid)
  if C.closed or C.result or not C.features[fid]then return end
  local f=C.features[fid]
  if not f.lastWork or S.GetGameFrame()-f.lastWork>1 or not f.commandSeen or not f.partial or C.destroyedFeatures[fid]then return fail('feature_lost_without_gradual_native_reclaim')end
  if not C.ledger or C.ledger.feature~=fid then return fail('bound_native_credit_collector_missing_at_removal')end
  local why=C.ledger.Removed();if why then return stop(why)end
  C.destroyedFeatures[fid]=S.GetGameFrame();local make,use,emake,euse=S.GetUnitResources(C.builder);emit('NATIVE_RECLAIM_DESTROYED',fid,C.builder,f.lastWork,'single_credit_ledger_verified=false',make,use,emake,euse)
 end
 local function continuity()
  if not paidBuilder()then return false end
  for _,row in ipairs(C.cohorts)do
   local state=R.squads[row.seed];local dead=C.bodies[row.victim].lethal and 1 or 0
   if not state or state.team~=C.team or #R.Members(state.leader)~=plan.capacity-dead then return false end
   local leadFound=false
   for _,id in ipairs(row.bodies)do local b=C.bodies[id]
    if not b.lethal then
     if not live(id,C.team)or state.slots[b.slot]~=id or state.generations[b.slot]~=1 or S.GetUnitDefID(id)~=b.def
      or S.GetUnitExperience(id)~=b.xp or S.GetUnitRulesParam(id,'40k_squad_id')~=row.seed then return false end
     if id==state.leader then leadFound=true end
    elseif state.slots[b.slot]or S.ValidUnitID(id)and not S.GetUnitIsDead(id)then return false end
   end
   if not leadFound then return false end
  end
  return true
 end
 local function sampleFeatures(frame)
  local identities={}
  for _,fid in ipairs(S.GetAllFeatures())do
   local fd=F[S.GetFeatureDefID(fid)];local cp=fd and fd.customParams or{};local seed=S.GetFeatureRulesParam(fid,'40k_remains_squad');local row
   for _,r in ipairs(C.cohorts)do if r.seed==seed then row=r end end
   if row then
    local b=C.bodies[row.victim];local slot=S.GetFeatureRulesParam(fid,'40k_remains_slot');local gen=S.GetFeatureRulesParam(fid,'40k_remains_generation')
    local key=tostring(seed)..':'..tostring(slot)..':'..tostring(gen)
    if identities[key]or C.destroyedFeatures[fid]then return fail('duplicate_or_reappeared_native_entitlement')end;identities[key]=fid
    if not b.lethal or slot~=b.slot or gen~=1 or not fd or fd.name~=plan.feature or cp.parent_actor~=plan.actor or not C.createdFeatures[fid]
     or C.createdFeatures[fid]<b.lethal or S.GetFeatureRulesParam(fid,'40k_remains_def')~=b.def
     or S.GetFeatureRulesParam(fid,'40k_remains_team')~=C.team or S.GetFeatureRulesParam(fid,'40k_remains_version')~=1 then return fail('genuine_native_feature_birth_paid_generation_required')end
    if row.feature and row.feature~=fid then return fail('replacement_native_entitlement')end;row.feature=fid
    local f=C.features[fid]or{cohort=row,birth=C.createdFeatures[fid]};C.features[fid]=f
    local m,dm,e,de,left,work=S.GetFeatureResources(fid);local flying=S.GetFeatureRulesParam(fid,'40k_remains_flying');local x,y,z=S.GetFeaturePosition(fid)
    if not finite(m)or not finite(dm)or not finite(e)or not finite(de)or not finite(left)or not finite(work)or not finite(x)or not finite(y)or not finite(z)then return fail('finite_native_feature_readback_required')end
    if e~=0 or de~=0 or left<0 or left>1 or m<0 or dm<0 or work<0 then return fail('invalid_native_feature_currency')end
    if flying==1 then
     if m~=0 or dm~=0 or left~=1 then return fail('airborne_native_currency')end
     if not f.air then f.air=frame;emit('AIRBORNE_ZERO_CURRENCY',fid,seed,slot,gen,m,dm,x,y,z)end
     if GG.Recoil40KTacticalRemains.AllowFeatureBuildStep(C.builder,C.team,fid,S.GetFeatureDefID(fid),-.01)~=false then return fail('sole_owner_airborne_reclaim_admitted')end
    elseif flying==0 then
     if not f.air or math.abs(dm-plan.salvageMetal)>.001 or math.abs(work-plan.reclaimWork)>.001 or math.abs(m-plan.salvageMetal*left)>.001
      or S.GetFeatureRulesParam(fid,'40k_remains_metal')~=plan.salvageMetal or S.GetFeatureRulesParam(fid,'40k_remains_work')~=plan.reclaimWork
      or math.abs(y-S.GetGroundHeight(x,z))>.02 then return fail('native_landing_quarter_entitlement_or_ground')end
     if not f.land then
      if left~=1 or math.abs(m-plan.salvageMetal)>.001 then return fail('nonpristine_native_landing')end
      f.land=frame;f.position={x,y,z};emit('LANDED_ONE_ENTITLEMENT',fid,seed,slot,gen,dm,work,x,y,z)
     elseif x~=f.position[1]or y~=f.position[2]or z~=f.position[3]then return fail('native_landed_location_changed')end
     if f.previousMetal and(m>f.previousMetal+.001 or left>f.previousLeft+.00001)then return fail('native_reclaim_currency_increased')end
     if left>0 and left<1 then
      if not f.lastWork or frame-f.lastWork>1 or not f.commandSeen then return fail('partial_native_depletion_without_observed_builder_work')end
      f.partial=true;emit('NATIVE_RECLAIM_PARTIAL',fid,m,dm,left,work)
     end
     f.previousMetal=m;f.previousLeft=left
    else return fail('native_flight_marker_missing')end
   end
  end
  for fid in pairs(C.features)do if not C.destroyedFeatures[fid]and not S.ValidFeatureID(fid)then return fail('feature_missing_without_native_destroy_callback')end end
 end
 local function approachReadback(frame,stage)
  local row=C.cohorts[C.active];if not row or not row.feature then return end
  C.approachSamples=C.approachSamples or 0;if C.approachSamples>=32 then return end
  C.approachSamples=C.approachSamples+1
  M.ReclaimReadback(S,D,C.builder,row.feature,frame,stage,C.ledger and frame-C.ledger.started or 0,
   C.features[row.feature]and C.features[row.feature].ordered,emit)
 end
 local function creditBaseline(frame,index)
  C.active=index;local row=C.cohorts[index];local f=row.feature and C.features[row.feature]
  if not f or not f.land or f.ordered or C.destroyedFeatures[row.feature]then return fail('pristine_native_feature_required_for_credit_baseline')end
  C.ledger=ledgerModule.New(S,D,C.builder,C.team,emit,{builderName='nec_scarab',builderDefID=C.builderDefinition,
   featureID=row.feature,featureDefID=S.GetFeatureDefID(row.feature),expectedMetal=plan.salvageMetal,expectedEnergy=0})
  if C.ledger.result then return stop(C.ledger.result)end
  C.phase='credit_baseline';local why=C.ledger.Step(frame);if why then return stop(why)end
  approachReadback(frame,'baseline_admission')
  emit('NATIVE_CREDIT_BASELINE_START',C.builder,row.feature,frame,plan.salvageMetal,'period=15 zero_edge=45')
 end
 local function legal(def,x,z,exclude)
  local d=D[def];local radius=math.max(d.xsize*4,d.zsize*4,tonumber(d.radius)or 0)+24;local y=S.GetGroundHeight(x,z)
  if not finite(y)or y<0 or x-radius<32 or z-radius<32 or x+radius>Game.mapSizeX-32 or z+radius>Game.mapSizeZ-32
   or S.TestMoveOrder(def,x,y,z,0,0,0,true,true,false)~=true or #(S.GetFeaturesInRectangle(x-radius,z-radius,x+radius,z+radius)or{})>0 then return end
  for _,id in ipairs(S.GetUnitsInRectangle(x-radius,z-radius,x+radius,z+radius)or{})do if not exclude or not exclude[id]then return end end
  return{x,y,z}
 end
 local function separate()
  for i,row in ipairs(C.cohorts)do
   local x,_,z=S.GetUnitPosition(row.victim);local site
   for ring=1,4 do for j=0,15 do local a=j*math.pi/8;local tx,tz=x+ring*256*math.cos(a),z+ring*256*math.sin(a);local pos=legal(N[plan.actor].id,tx,tz)
    if pos then
     local safe=true
     for _,id in ipairs({C.builder,row.origin.factory,contexts.builder.factory})do local ox,_,oz=S.GetUnitPosition(id);if(tx-ox)^2+(tz-oz)^2<(C.blastRadius+S.GetUnitRadius(id)+128)^2 then safe=false end end
     if i==2 then local other=C.cohorts[1].site;if(tx-other[1])^2+(tz-other[3])^2<(C.blastRadius+256)^2 then safe=false end end
     if safe then site=pos;break end
    end
   end;if site then break end end
   if not site then return refuse('natural_paid_cohort_separation_site_unavailable')end
   row.site=site
   for _,order in ipairs({{CMD.STOP,{}},{CMD.FIRE_STATE,{0}},{CMD.MOVE_STATE,{0}},{CMD.MOVE,site}})do
    if S.GiveOrderToUnit(row.victim,order[1],order[2],0)==false then return refuse('ordinary_cohort_separation_order_rejected')end
   end
  end
  C.phase='move';emit('NATURAL_COHORT_MOVE','no_forced_positions=true own_paid_bodies_unchanged=true')
 end
 local function enemySite()
  local victim=C.cohorts[C.active].victim;local x,_,z=S.GetUnitPosition(victim);local w=W[C.weapon]
  if not finite(w.range)or w.range<=0 then return end
  for j=0,15 do local a=j*math.pi/8;local pos=legal(C.enemyDefinition,x+C.attackDistance*math.cos(a),z+C.attackDistance*math.sin(a))
   if pos then return pos end
  end
 end
 function C.Step(frame)
  if C.closed or C.result then return C.result end
  for _,id in ipairs({C.enemy or false,C.completedEnemy or false})do if id and(not live(id,C.enemyTeam)or S.GetUnitDefID(id)~=C.enemyDefinition)then return fail('funded_hostile_actor_lost_captured_or_changed')end end
  if not continuity()then return fail('paid_survivor_leader_XP_builder_or_generation_changed')end
  if frame-C.started>7200 then return refuse('bounded_natural_hostile_remains_timeout_'..C.phase)end
  if C.ledger then local why=C.ledger.Step(frame);if why then approachReadback(frame,'ledger_terminal');return stop(why)end end
  if C.phase=='reclaim'then local row=C.cohorts[C.active];local f=row and C.features[row.feature]
   if f and f.ordered and frame>f.ordered and(frame-f.ordered)%60==0 then approachReadback(frame,'periodic')end
  end
  local bad=sampleFeatures(frame);if bad then return bad end
  if C.phase=='landing'or C.phase=='reclaim'then
   local make,use,emake,euse=S.GetUnitResources(C.builder)
   if not finite(make)or not finite(use)or not finite(emake)or not finite(euse)then return fail('finite_native_builder_resource_window_required')end
   emit('BUILDER_RESOURCE_WINDOW',C.builder,frame,make,use,emake,euse,'rolling_two_intervals_not_cumulative=true single_credit_ledger_verified=false')
  end
  if C.phase=='separate'then return separate()end
  if C.phase=='move'then
   local ready=true
   for _,row in ipairs(C.cohorts)do for _,id in ipairs(row.bodies)do local x,_,z=S.GetUnitPosition(id);if(x-row.site[1])^2+(z-row.site[3])^2>96^2 then ready=false end end end
   if ready then C.active=1;C.phase='spawn_enemy'end
  elseif C.phase=='spawn_enemy'then
   local pos=enemySite();if not pos then return refuse('genuine_hostile_native_ground_site_unavailable')end
   C.enemy=S.CreateUnit('imp_russ',pos[1],pos[2],pos[3],0,C.enemyTeam)
   if not C.enemy or not live(C.enemy,C.enemyTeam)or S.GetUnitDefID(C.enemy)~=C.enemyDefinition then return refuse('funded_hostile_native_Russ_birth_refused')end
   if S.GiveOrderToUnit(C.enemy,CMD.FIRE_STATE,{0},0)==false or S.GiveOrderToUnit(C.enemy,CMD.MOVE_STATE,{0},0)==false then return refuse('native_hostile_hold_orders_rejected')end
   emit('FUNDED_HOSTILE_ONLY',C.enemy,C.enemyDefinition,C.enemyTeam,'own_resource_grants=false spawn_projectiles=false')
   C.needsRegistration=true;C.phase='aim'
  elseif C.phase=='aim'then
   if C.needsRegistration then return end
   local victim=C.cohorts[C.active].victim;local x,y,z=S.GetUnitPosition(victim);local los=S.GetUnitLosState(victim,S.GetUnitAllyTeam(C.enemy),false)or{}
   if los.los==true and S.IsPosInLos(x,y,z,S.GetUnitAllyTeam(C.enemy))and S.GetUnitWeaponTestRange(C.enemy,C.mount,x,y,z)==true then
    if not S.GetUnitPieceMap(C.enemy)[C.marker]then return fail('actual_genuine_Russ_muzzle_piece_absent')end
    C.phase='fire';if S.GiveOrderToUnit(C.enemy,CMD.ATTACK,{victim},0)==false then return refuse('ordinary_native_hostile_attack_rejected')end
    emit('NATIVE_HOSTILE_ATTACK',C.enemy,victim,C.weapon,'ordinary_target_command=true no_wound_setup=true')
   end
  elseif C.phase=='landing'then
   local row=C.cohorts[C.active];local f=row.feature and C.features[row.feature]
   if f and f.land and frame-f.land>=30 then
    if C.active==1 then
     -- Keep both real native features alive before reclaim: native feature IDs
     -- may recycle after destruction, so concurrent births bind both generations.
     C.completedEnemy=C.enemy;C.enemy=nil;C.active=2;C.phase='spawn_enemy'
    else
     return creditBaseline(frame,1)
    end
   end
  elseif C.phase=='credit_baseline'then
   if C.ledger.ready then
    local why=C.ledger.Begin();if why then return stop(why)end
    local row=C.cohorts[C.active];local f=C.features[row.feature];f.ordered=frame;C.phase='reclaim'
    if S.GiveOrderToUnit(C.builder,CMD.RECLAIM,{Game.maxUnits+row.feature},0)==false then return refuse('ordinary_native_paid_reclaim_order_rejected')end
    approachReadback(frame,'order_issued')
    emit('NATIVE_RECLAIM_ORDER',C.builder,row.feature,plan.salvageMetal,plan.reclaimWork,'genuine_zero_baseline_ready=true')
   end
  elseif C.phase=='reclaim'then
   local row=C.cohorts[C.active];local destroyed=row.feature and C.destroyedFeatures[row.feature]
   if destroyed and frame-destroyed>=30 and C.ledger.proved then
    C.features[row.feature].gross=C.ledger.gross;emit('NATIVE_FEATURE_GROSS_CREDIT',row.feature,C.ledger.gross,'per_feature_native_AddResources=true')
    if C.active==2 then
     C.singleCreditLedgerVerified=true
     return stop('OBSERVED two_paid_cohorts_natural_hostile_throws_native_builder_reclaims exact_native_gross_credit external_closed_native_receipt_required')
    end
    return creditBaseline(frame,2)
   end
  end
  return C.result
 end
 return C
end
return M

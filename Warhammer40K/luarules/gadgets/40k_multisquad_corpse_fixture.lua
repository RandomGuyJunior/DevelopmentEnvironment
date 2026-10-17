-- Explicit funded/non-economy diagnostic. Native projectile owns lethal damage.
function gadget:GetInfo()return{name='40K two-cohort native corpse fixture',desc='Funded native queue, lethal blast, surviving squads and native reclaim',author='Local project',layer=120,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return false end
local S=Spring;local options=S.GetModOptions()or{}
local on=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled
if not on(options.prototype_multisquad_corpse_fixture)or options.prototype_diagnostic~='normal'or not on(options.prototype_source_progression)or tonumber(options.prototype_test_speed or 1)~=1 then return false end
-- Existing automated casualty fixtures must not own the same fresh match.
for _,key in ipairs({'prototype_squad_fixture','prototype_squad_paid_fixture','prototype_corpse_blast_fixture','prototype_corpse_native_reclaim_fixture'})do if on(options[key])then return false end end
local case=options.prototype_multisquad_corpse_case or'flat'
local cases={flat=true,edge=true,slope=true,water=true,obstruction=true}
if not cases[case]then return false end
local runID=options.prototype_multisquad_corpse_run_id
local phase='prepare';local started,stageFrame=0,0;local team,factory,builder,weapon,projectile,exploded,site
local prior={};local squads={};local victims={};local features={};local workProof={};local destroyed={};local partial={};local commandSeen={};local done;local obstacles={}
local function log(label,...)S.Echo('40K MULTISQUAD CORPSE',S.GetGameFrame(),case,label,...)end
local refusals={requested_terrain_unavailable=true,factory_site_unavailable=true,native_reclaim_builder_position_unavailable=true,gradual_native_reclaim_required=true,owned_run_identity_required=true,fresh_exclusive_scene_required=true}
local function finish(ok,reason)
 if done then return end;done=true;S.SetGameRulesParam('40k_multisquad_corpse_result',ok and 1 or refusals[reason]and-2 or-1)
 log(ok and'PASS'or refusals[reason]and'REFUSAL'or'FAIL',reason,'funded',true,'ordinary_paid_acceptance',false,'script_wound_setup',true)
end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function alive(id)return S.ValidUnitID(id)and not S.GetUnitIsDead(id)end
local function empty(x,z,r)return #S.GetUnitsInCylinder(x,z,r)==0 and #S.GetFeaturesInCylinder(x,z,r)==0 end
local function legal(def,x,z)local y=S.GetGroundHeight(x,z);return x>4 and z>4 and x<Game.mapSizeX-4 and z<Game.mapSizeZ-4 and S.TestMoveOrder(def,x,y,z)end
local function chooseSite(def)
 local xs={};if case=='edge'then xs={Game.mapSizeX-8}else for x=384,Game.mapSizeX-384,128 do xs[#xs+1]=x end end
 for z=384,Game.mapSizeZ-384,128 do for _,x in ipairs(xs)do
  local y=S.GetGroundHeight(x,z);local nextY=S.GetGroundHeight(math.min(x+36,Game.mapSizeX),z)
  local terrain=(case=='water'and y<0 and y>=-4)or(case~='water'and y>0)
  if case=='slope'then terrain=terrain and math.abs(nextY-y)>1 and math.abs(nextY-y)<8 end
  if case=='flat'or case=='obstruction'then terrain=terrain and math.abs(nextY-y)<.5 end
  if terrain and empty(x,z,260)and legal(def,x,z-8)and legal(def,x,z+8)then
   local clear=true;for i=1,6 do if not legal(def,x-220,z-100+i*32)then clear=false end end
   if clear then return{x,y,z}end
  end
 end end
end
local function create(name,x,z)return S.CreateUnit(name,x,S.GetGroundHeight(x,z),z,0,team)end
local function setup()
 started=S.GetGameFrame();stageFrame=started
 if type(runID)~='string'or #runID<12 or #runID>96 or not runID:match('^[%w_-]+$')then finish(false,'owned_run_identity_required');return end
 if Game.reclaimMethod~=0 then finish(false,'gradual_native_reclaim_required');return end
 if not GG.Recoil40KSquads or not GG.Recoil40KTacticalRemains or GG.Recoil40KCorpseAccount or GG.Recoil40KSpyderHarvestReview then finish(false,'authoritative_owner_missing_or_competing');return end
 for seed in pairs(GG.Recoil40KSquads.squads)do prior[seed]=true end
 local actor=UnitDefNames.imp_marine;local russ=UnitDefNames.imp_russ
 if not actor or not russ or not UnitDefNames.imp_marine_barracks or not UnitDefNames.imp_marine_builder then finish(false,'definitions_missing');return end
 weapon=UnitDefs[russ.id].weapons[1].weaponDef
 local w=WeaponDefs[weapon];if not w or w.type~='Cannon'or(w.damageAreaOfEffect or 0)<16 or w.noExplode then finish(false,'native_battle_cannon_missing');return end
 for _,t in ipairs(S.GetTeamList())do if t~=S.GetGaiaTeamID()then team=t;break end end
 if not team then finish(false,'team_missing');return end
 -- This observer belongs only in an isolated root-owned fresh diagnostic.
 if #S.GetAllUnits()>1 or next(prior)then finish(false,'fresh_exclusive_scene_required');return end
 site=chooseSite(actor.id);if not site then finish(false,'requested_terrain_unavailable');return end
 log('OWNED_RUN_ID',runID)
 log('TRACE_SCHEMA',2,Game.mapSizeX,Game.mapSizeZ,Game.maxUnits,team,-1,Game.reclaimMethod)
 log('SITE_DISCRIMINATOR',site[1],site[2],site[3],S.GetGroundHeight(math.min(site[1]+36,Game.mapSizeX),site[3])-site[2],Game.mapSizeX-site[1])
 local bx,bz
 for z=384,Game.mapSizeZ-384,128 do for x=384,Game.mapSizeX-384,128 do
  local y=S.GetGroundHeight(x,z);local result,feature=S.TestBuildOrder(UnitDefNames.imp_marine_barracks.id,x,y,z,0)
  if y>0 and result and result>=2 and not feature and empty(x,z,160)and(x-site[1])^2+(z-site[3])^2>600^2 then bx,bz=x,z;break end
 end;if bx then break end end
 if not bx then finish(false,'factory_site_unavailable');return end
 factory=create('imp_marine_barracks',bx,bz);builder=create('imp_marine_builder',bx+128,bz+128)
 if not factory or not builder then finish(false,'funded_scene_create_failed');return end
 S.SetTeamResource(team,'ms',100000);S.SetTeamResource(team,'es',100000);S.SetTeamResource(team,'m',50000);S.SetTeamResource(team,'e',50000)
 S.SetUnitBuildSpeed(factory,1000)
 S.GiveOrderToUnit(factory,-actor.id,{},0);S.GiveOrderToUnit(factory,-actor.id,{},CMD.OPT_SHIFT)
 Script.SetWatchExplosion(weapon,true);phase='queue';log('FUNDED_NATIVE_QUEUE',factory,builder,actor.id,2,weapon,w.type,w.damageAreaOfEffect,unpack(site))
end
function gadget:Initialize()phase='await_owner';started=S.GetGameFrame()end
function gadget:Explosion(w,x,y,z,owner,p)
 if not done and p==projectile and w==weapon and owner==nil and finite(x)and finite(y)and finite(z)
  and math.abs(x-(site[1]-7))<=2 and math.abs(z-site[3])<=2 and y>=site[2]-4 and y<=site[2]+35 then
  if exploded then finish(false,'duplicate_matching_explosion');return false end
  exploded=S.GetGameFrame();log('NATIVE_EXPLOSION',p,w,x,y,z,-1)end
 return false
end
function gadget:UnitDamaged(id,def,t,damage,paralyzer,w,p,attacker)
 local v=victims[id];if done or not v or p~=projectile or w~=weapon or def~=v.def or t~=team or attacker~=nil
  or S.GetUnitDefID(id)~=v.def or S.GetUnitTeam(id)~=team then return end
 local hp=S.GetUnitHealth(id)
 if not paralyzer and finite(damage)and damage>0 and hp and hp<=0 and exploded==S.GetGameFrame()then v.lethal=true;log('MATCHING_NATIVE_LETHAL',id,v.seed,v.slot,v.generation,damage,def,t,p,w,-1)end
end
function gadget:AllowFeatureBuildStep(id,t,fid,def,part)
 if not done and features[fid]and part<0 then
  if id~=builder or t~=team or not alive(id)or S.GetUnitTeam(id)~=team
   or S.GetUnitDefID(id)~=UnitDefNames.imp_marine_builder.id or def~=S.GetFeatureDefID(fid)or not finite(part)
   or phase~='reclaim'or not features[fid].land then finish(false,'foreign_or_prelanding_reclaim')else workProof[fid]=S.GetGameFrame()end
 end
 return true -- Observation only; sole native reclaim owner remains authoritative.
end
function gadget:FeatureDestroyed(fid)
 if not done and features[fid]then
  if not workProof[fid]or S.GetGameFrame()-workProof[fid]>1 then finish(false,'feature_loss_without_native_reclaim')else destroyed[fid]=S.GetGameFrame();log('NATIVE_RECLAIM_DESTROYED',fid,builder,workProof[fid])end
 end
end
local function continuity()
 local R=GG.Recoil40KSquads
 for _,row in ipairs(squads)do
  local s=R.squads[row.seed];if not s or s.leader==row.victim or s.team~=team or not alive(s.leader)or S.GetUnitTeam(s.leader)~=team or #R.Members(s.leader)~=row.capacity-1 then return false end
  local leaderFound=false;for _,id in ipairs(row.survivors)do if id==s.leader then leaderFound=true end;if not alive(id)or S.GetUnitTeam(id)~=team or S.GetUnitRulesParam(id,'40k_squad_schema')~=2 or S.GetUnitRulesParam(id,'40k_squad_id')~=row.seed or S.GetUnitExperience(id)~=row.xp[id]then return false end end;if not leaderFound then return false end
  if row.orderFrame and S.GetGameFrame()>row.orderFrame then
   for _,id in ipairs(row.survivors)do
    local found=false;for _,order in ipairs(S.GetUnitCommands(id,-1)or{})do if order.id==CMD.PATROL and order.params[1]==site[1]-240 and order.params[3]==site[3]then found=true end end
    if not found then return false end
   end
  end
 end
 return true
end
function gadget:GameFrame(frame)
 if done then return end
 -- Gadget initialization order is not evidence that lower-layer owners exist.
 if phase=='await_owner'then if frame-started>=90 then setup()end;return end
 if frame-started>3600 then finish(false,'bounded_timeout_'..phase);return end
 local R=GG.Recoil40KSquads;if not R then finish(false,'squad_owner_lost');return end
 if phase=='queue'then
  local ids={};for seed,s in pairs(R.squads)do if not prior[seed]and s.team==team and s.profile=='marine_tactical'then ids[#ids+1]=seed end end;table.sort(ids)
  if #ids>2 then finish(false,'unexpected_extra_cohort');return end
  if #ids<2 then return end
  for i,seed in ipairs(ids)do
   local s=R.squads[seed];local members=R.Members(s.leader);local cap=S.GetUnitRulesParam(s.leader,'40k_squad_capacity')
   if not cap or #members~=cap or cap~=4 then finish(false,'partial_or_wrong_capacity_delivery');return end
   local row={seed=seed,victim=s.leader,capacity=cap,survivors={},xp={}}
   S.GiveOrderToUnit(s.leader,CMD.STOP,{},0);S.GiveOrderToUnit(s.leader,CMD.FIRE_STATE,{0},0)
   for _,id in ipairs(members)do
    if id~=s.leader then if S.GetUnitRulesParam(id,'40k_squad_schema')~=2 or S.GetUnitRulesParam(id,'40k_squad_id')~=seed or S.GetUnitTeam(id)~=team then finish(false,'survivor_birth_schema_identity');return end;row.survivors[#row.survivors+1]=id;row.xp[id]=S.GetUnitExperience(id);log('SURVIVOR_WITNESS',seed,id,S.GetUnitDefID(id),team,row.xp[id],S.GetUnitRulesParam(id,'40k_squad_slot'),S.GetUnitRulesParam(id,'40k_squad_generation'))end
   end
   -- Position and one-HP wound are explicit setup probes, never combat proof.
   S.SetUnitPosition(s.leader,site[1],site[3]+(i==1 and-8 or 8));S.SetUnitHealth(s.leader,{health=1})
   for j,id in ipairs(row.survivors)do S.SetUnitPosition(id,site[1]-220,site[3]-100+((i-1)*3+j)*32)end
   local v={seed=seed,slot=S.GetUnitRulesParam(s.leader,'40k_squad_slot'),generation=S.GetUnitRulesParam(s.leader,'40k_squad_generation'),
    metal=S.GetUnitRulesParam(s.leader,'40k_squad_investment_metal'),work=S.GetUnitRulesParam(s.leader,'40k_squad_investment_work'),def=S.GetUnitDefID(s.leader)}
   if S.GetUnitRulesParam(s.leader,'40k_squad_schema')~=2 or not finite(v.slot)or v.slot%1~=0 or v.slot<1 or v.slot>4
    or not finite(v.generation)or v.generation%1~=0 or v.generation<1 or not finite(v.metal)or v.metal<=0 or not finite(v.work)or v.work<=0 or v.def~=UnitDefNames.imp_marine.id then finish(false,'paid_body_provenance_missing');return end
   victims[s.leader]=v;squads[#squads+1]=row;log('FULL_COHORT_WITNESS',seed,#members,s.leader,v.slot,v.generation,v.metal,v.work,v.def,team)
  end
  if case=='obstruction'then
   -- The two radial throws diverge. Put one genuine blocker on each ray,
   -- instead of assuming a centerline building intersects either body.
   for i,row in ipairs(squads)do
    local blocker=create('imp_marine_generator',site[1]+96,site[3]+i*96)
    if not blocker or not S.GetUnitBlocking(blocker)then finish(false,'genuine_solid_obstruction_missing');return end
    local obstacle={radius=S.GetUnitRadius(blocker)}
    if not obstacle.radius or obstacle.radius<=0 then finish(false,'obstruction_geometry_missing');return end
    local dx=obstacle.radius+12;obstacle.x=site[1]+dx;obstacle.z=site[3]+(i==1 and-1 or 1)*(8+dx*8/7)
    S.SetUnitPosition(blocker,obstacle.x,obstacle.z);obstacles[row.seed]=obstacle
    log('SOLID_OBSTRUCTION',blocker,row.seed,obstacle.x,obstacle.z,obstacle.radius,S.GetUnitHeight(blocker))
   end
  end
  phase='settle';stageFrame=frame;return
 elseif phase=='settle'and frame-stageFrame>=30 then
  projectile=S.SpawnProjectile(weapon,{pos={site[1]-7,site[2]+35,site[3]},speed={0,-2,0},['end']={site[1]-7,site[2],site[3]},team=S.GetGaiaTeamID(),ttl=120,gravity=0})
  if not projectile or projectile<0 then finish(false,'native_projectile_refused');return end
  phase='blast';stageFrame=frame;log('NATIVE_PROJECTILE',projectile,weapon);return
 elseif phase=='blast'or phase=='landed'or phase=='reclaim'then
  local lethals=0;for _,v in pairs(victims)do if v.lethal then lethals=lethals+1 end end
  if lethals<2 then if frame-stageFrame>180 then finish(false,'both_matching_lethal_explosions_missing')end;return end
  if not continuity()then finish(false,'surviving_member_identity_xp_or_leader_failure');return end
  local matched={};for _,fid in ipairs(S.GetAllFeatures())do
   local seed=S.GetFeatureRulesParam(fid,'40k_remains_squad');local slot=S.GetFeatureRulesParam(fid,'40k_remains_slot');local gen=S.GetFeatureRulesParam(fid,'40k_remains_generation')
   for _,v in pairs(victims)do if seed==v.seed and slot==v.slot and gen==v.generation then
    if matched[v.seed]then finish(false,'duplicate_entitlement');return end;matched[v.seed]=fid
    if S.GetFeatureRulesParam(fid,'40k_remains_def')~=v.def then finish(false,'corpse_actor_identity_wrong');return end
    if v.feature and v.feature~=fid then finish(false,'feature_identity_changed');return end;v.feature=fid
    local row=features[fid]or{victim=v};features[fid]=row
    local m,dm,e,de,left,work=S.GetFeatureResources(fid);local x,y,z=S.GetFeaturePosition(fid);local flying=S.GetFeatureRulesParam(fid,'40k_remains_flying')
    if not finite(m)or not finite(dm)or not finite(e)or not finite(de)or not finite(left)or not finite(work)
     or not finite(x)or not finite(y)or not finite(z)or left<0 or left>1 or e~=0 or de~=0 or m<0 or dm<0 then finish(false,'currency_invalid');return end
    if flying==1 then
     if m~=0 or dm~=0 then finish(false,'airborne_currency');return end
     if not row.air then row.air=true;log('AIRBORNE_ZERO_CURRENCY',fid,v.seed,v.slot,v.generation,m,dm,e,de,x,y,z)end
     if GG.Recoil40KTacticalRemains.AllowFeatureBuildStep(builder,team,fid,S.GetFeatureDefID(fid),-.01)then finish(false,'airborne_reclaim_admitted');return end
    elseif flying==0 then
     local cap=v.metal*.25;local reclaimWork=math.max(30,math.min(6000,v.work*.25))
     if not row.air or math.abs(dm-cap)>.001 or m>cap+.001 or math.abs(work-reclaimWork)>.001 or math.abs(y-S.GetGroundHeight(x,z))>.02 then finish(false,'landing_entitlement_or_ground');return end
     if not row.land then
      if left~=1 or math.abs(m-cap)>.001 then finish(false,'nonpristine_landing');return end
      row.land=frame;row.x=x;row.y=y;row.z=z;log('LANDED_ONE_ENTITLEMENT',fid,v.seed,v.slot,v.generation,cap,reclaimWork,string.format('%.17g',x),string.format('%.17g',y),string.format('%.17g',z))
     elseif x~=row.x or y~=row.y or z~=row.z then finish(false,'final_location_unstable');return end
     if case=='edge'and(x<0 or x>Game.mapSizeX or z<0 or z>Game.mapSizeZ)then finish(false,'map_edge_escape');return end
     if case=='edge'and(x<=site[1]or Game.mapSizeX-x>3)then finish(false,'edge_contact_not_observed');return end
     if case=='water'and row.y>=0 then finish(false,'water_discriminator_not_observed');return end
     local obstacle=obstacles[v.seed]
     if case=='obstruction'and obstacle and(x>=obstacle.x or(x-obstacle.x)^2+(z-obstacle.z)^2<=(obstacle.radius+4)^2)then finish(false,'solid_obstruction_penetrated');return end
     if phase=='reclaim'then
      if math.abs(m-cap*left)>.001 then finish(false,'partial_currency_fraction_mismatch');return end
      if row.previousM and(m>row.previousM+.001 or left>row.previousLeft+.00001)then finish(false,'reclaim_currency_increased');return end
      row.previousM,row.previousLeft=m,left
      if left>0 and left<1 and not partial[fid]then partial[fid]=true;log('NATIVE_RECLAIM_PARTIAL',fid,m,dm,left,work)end
      local cmd,_,_,param=S.GetUnitCurrentCommand(builder);if cmd==CMD.RECLAIM and param==Game.maxUnits+fid then commandSeen[fid]=true end
     end
    else finish(false,'flight_marker_missing');return end
   end end
  end
  local landed=0;for _,row in pairs(features)do if row.land and frame-row.land>=30 then landed=landed+1 end end
  if phase~='reclaim'and landed==2 then
   local x,z=site[1]-80,site[3];if not legal(UnitDefNames.imp_marine_builder.id,x,z)then finish(false,'native_reclaim_builder_position_unavailable');return end
   S.SetUnitPosition(builder,x,z);local ids={};for fid in pairs(features)do ids[#ids+1]=fid end;table.sort(ids)
   for _,row in ipairs(squads)do
    S.GiveOrderToUnit(R.squads[row.seed].leader,CMD.PATROL,{site[1]-240,S.GetGroundHeight(site[1]-240,site[3]),site[3]},0)
    for _,id in ipairs(row.survivors)do log('SURVIVOR_CONTINUITY',row.seed,id,S.GetUnitDefID(id),S.GetUnitTeam(id),S.GetUnitExperience(id),S.GetUnitRulesParam(id,'40k_squad_slot'),S.GetUnitRulesParam(id,'40k_squad_generation'))end
    row.orderFrame=frame;log('SURVIVOR_ORDER',row.seed,R.squads[row.seed].leader,row.capacity-1,site[1]-240,site[3],unpack(row.survivors))
   end
   for i,fid in ipairs(ids)do S.GiveOrderToUnit(builder,CMD.RECLAIM,{Game.maxUnits+fid},i==1 and 0 or CMD.OPT_SHIFT)end
   phase='reclaim';stageFrame=frame;log('NATIVE_RECLAIM_TWO_FEATURES',builder,unpack(ids));return
  end
  if phase=='reclaim'then
   local gone=0;local last=0;for fid in pairs(features)do if destroyed[fid]then gone=gone+1;last=math.max(last,destroyed[fid]);if not partial[fid]or not commandSeen[fid]then finish(false,'native_partial_or_command_proof_missing');return end elseif not S.ValidFeatureID(fid)then finish(false,'feature_missing_without_native_callback');return end end
   if gone==2 and frame-last>=20 then finish(true,'two_lethal_native_throws_stable_survivors_two_native_reclaims')end
  end
 end
end

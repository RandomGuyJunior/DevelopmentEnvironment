function gadget:GetInfo()
 return{name='40K paid Bike cohort review',desc='Selected native production, HQ upgrade and paid reinforcement proof',author='Local project',layer=110,enabled=true}
end
if not gadgetHandler:IsSyncedCode()then return false end
local opts=Spring.GetModOptions()or{}
if opts.prototype_diagnostic~='expandedproduction'or not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(opts.prototype_source_progression)or opts.prototype_source_acceptance~='imperium'or tostring(opts.prototype_bike_cohort_review)~='1'then return false end
local mixed=VFS.Include('40k_configs/mixed_v2_adapter.lua');if mixed.Enabled(opts)then return false end
local F=VFS.Include('40k_configs/primary_addon_mechanics_facts.lua')
local helper=VFS.Include('40k_configs/source_bike_cohort_review.lua')
local team,commander,base,H=0,nil,nil,nil
local factories,mexes,products,births={},{},{},{}
local active,done,index,buildingIndex=nil,false,1,0
local tasks={
 {'build','imp_mex'},{'build','imp_mex'},{'build','imp_generator'},{'build','imp_generator'},
 {'build','imp_hq'},{'build','imp_marine_hq'},{'build','imp_marine_barracks'},{'build','imp_marine_armoury'},
 {'product','imp_scout','imp_marine_hq'},{'product','imp_marine','imp_marine_barracks'},
 {'product','imp_tactical_bike','imp_marine_barracks'},
 {'addon','imp_source_hq_addon_1','imp_marine_hq'},
 {'support_refusal','imp_tactical_bike','imp_marine_barracks'},
 {'reinforce','imp_tactical_bike'},{'reinforce','imp_tactical_bike'},
}
local function log(...)Spring.Echo('40K SOURCE BIKE COHORT',...)end
local function finish(value,reason)
 if done then return end;done=true;Spring.SetGameRulesParam('40k_source_bike_cohort_result',value)
 log(value==2 and 'LIMITED_PAID_COHORT' or 'FAIL',reason,'frame',Spring.GetGameFrame(),'steps',index-1,'ranged','UNACCEPTED','melee','UNACCEPTED','visual','UNACCEPTED','save','UNACCEPTED')
end
local function fail(reason)finish(-1,reason)end
local function advance(reason)log('STEP_PASS',index,tasks[index][1],tasks[index][2],reason);active=nil;index=index+1 end
local function controller()return GG.Recoil40KResearch end
local function live(id)
 local hp,_,_,_,built=Spring.GetUnitHealth(id);return hp and hp>0 and built and built>=1 and Spring.GetUnitTeam(id)==team
end
local function option(id,name)
 local d=UnitDefNames[name];if not d then return false end
 for _,v in ipairs(UnitDefs[Spring.GetUnitDefID(id)].buildOptions or{})do if v==d.id then return true end end;return false
end
local function issue(task,frame)
 local kind,name,parent=task[1],task[2],task[3];local C=controller();local B=C and C.sourceMarineLifecycle
 if not B or B.failed then fail('native_lifecycle_unavailable_or_refused');return end
 if kind=='build'then
  if not UnitDefNames[name]or not option(commander,name)then fail('ordinary_structure_unavailable_'..name);return end
  local def=UnitDefNames[name].id;buildingIndex=buildingIndex+1;local pos,approach,why
  if name=='imp_mex'then pos,approach=H.Metal(def)
  else local column=(buildingIndex-1)%4;local row=math.floor((buildingIndex-1)/4);pos,approach,why=H.Site(def,base[1]+(column-1.5)*360,base[3]+(row-1)*400,20)end
  if not pos then fail('no_native_build_site_'..name..'_'..tostring(why));return end
  active={kind=kind,name=name,producer=commander,issued=frame}
  Spring.GiveOrderToUnit(commander,CMD.MOVE,approach,{})
  Spring.GiveOrderToUnit(commander,-def,pos,{'shift'});log('ORDINARY_PAID_BUILD',name,commander,pos[1],pos[3],frame)
 elseif kind=='product'then
  local producer=factories[parent]
  if not producer or not option(producer,name)or not C.CanBuild(team,UnitDefNames[name].id,producer,false)then fail('ordinary_product_unavailable_'..name);return end
  active={kind=kind,name=name,producer=producer,issued=frame}
  Spring.GiveOrderToUnit(producer,CMD.REPEAT,{0},{})
  Spring.GiveOrderToUnit(producer,-UnitDefNames[name].id,{},{});log('ORDINARY_PAID_FACTORY_ORDER',name,producer,frame)
 elseif kind=='addon'then
  local producer=factories[parent];local r=C.records[name]
  if not producer or not r or not Spring.FindUnitCmdDesc(producer,r.cmd)then fail('ordinary_paid_addon_unavailable');return end
  local _,max=Spring.GetUnitHealth(producer);local _,otherMax=Spring.GetUnitHealth(factories.imp_marine_barracks)
  active={kind=kind,name=name,producer=producer,issued=frame,steps=0,max=max,barracksMax=otherMax,experience=Spring.GetUnitExperience(producer)}
  Spring.GiveOrderToUnit(producer,r.cmd,{},{});log('ORDINARY_PAID_HQ_ADDON',producer,r.cmd,400,130,90*Game.gameSpeed,frame)
 elseif kind=='support_refusal'then
  local producer=factories[parent];local i,s=B.population.Usage(team);local ci,cs=B.population.Capacity(team)
  local initial=products.imp_tactical_bike;local seed=B.bike.controller.member[initial];local budget=B.population.member[initial]
  if i~=5 or s~=1 or cs~=1 or not B.population.AuthorizeReinforcementOwnedBudget(team,budget)or not B.bike.Enabled(team)or B.bike.controller.jobs[seed]then fail('owned_full_support_budget_missing');return end
  active={kind=kind,name=name,producer=producer,issued=frame,seed=seed,budget=budget,samples=0}
  Spring.GiveOrderToUnit(producer,-UnitDefNames[name].id,{},{});log('ORDINARY_SECOND_BIKE_CAP_ATTEMPT',producer,i,s,ci,cs,frame)
 elseif kind=='reinforce'then
  local id=products.imp_tactical_bike;local seed=B.bike.controller.member[id];local cohort=seed and B.bike.controller.cohorts[seed]
  if not live(id)or not cohort or cohort.leader~=id or not Spring.FindUnitCmdDesc(id,B.command)then fail('ordinary_reinforce_command_unavailable');return end
  local count=0;for _ in pairs(cohort.members)do count=count+1 end
  active={kind=kind,name=name,producer=id,issued=frame,seed=seed,steps=0,count=count+1}
  Spring.GiveOrderToUnit(id,B.command,{},{});log('ORDINARY_PAID_REINFORCE_ORDER',id,B.command,80,40,10*Game.gameSpeed,'target_members',active.count,frame)
 end
end
function gadget:Initialize()Spring.SetGameRulesParam('40k_source_bike_cohort_result',0)end
function gadget:UnitCreated(id,def,owner,builder)
 if done or not commander or owner~=team then return end
 local name=UnitDefs[def].name
 if active and active.kind=='support_refusal'and name=='imp_tactical_bike'then fail('support_cap_unexpected_second_bike_birth');return end
 if active and active.kind=='reinforce'and name=='imp_tactical_bike'then
  local receipt,why,detail=H.ReinforcementBirth(id,def,owner,builder,active)
  if not receipt and detail then
   local failure=detail.lifecycleFailure
   log('REINFORCEMENT_BIRTH_DIAGNOSTIC',id,builder,why,'built',detail.buildProgress,'costs',detail.work,detail.metal,detail.energy,
    'budget',detail.budget or 'absent','member',detail.populationMember or 'absent','paid',detail.paid,'steps',detail.steps,
    'nativeReceipt',detail.receipt,'lifecycleFailure',failure and failure.reason or 'absent','witness',failure and failure.witness or false,
    'witnessReason',failure and failure.witnessReason or 'absent')
  end
  if not receipt or active.receipt then fail(why or 'duplicate_reinforcement_birth');return end
  active.receipt=receipt;births[id]=receipt;log('ACTUAL_PAID_REINFORCEMENT_BIRTH',id,builder,receipt.seed,receipt.budget,receipt.tag,receipt.metal,receipt.energy,receipt.steps,receipt.frame);return
 end
 if active and builder==active.producer and name==active.name and(active.kind=='build'or active.kind=='product')then
  local receipt,why
  if active.kind=='product'then receipt,why=H.InitialBirth(id,def,owner,builder)
  else receipt={unit=id,def=def,team=owner,builder=builder,frame=Spring.GetGameFrame()}end
  if not receipt or active.receipt then fail(why or 'duplicate_initial_birth');return end
  active.receipt=receipt;births[id]=receipt;log('ACTUAL_NATIVE_PAID_BIRTH',name,id,builder,receipt.tag or 'build',receipt.work or 'build',receipt.metal or 'build',receipt.energy or 'build',receipt.frame)
 elseif name=='imp_tactical_bike'or name=='imp_scout'or name=='imp_marine'then fail('unaccounted_source_product_'..name)end
end
function gadget:UnitFinished(id,def,owner)
 if done or owner~=team or not active or not active.receipt or active.receipt.unit~=id then return end
 if active.kind=='build'then
  factories[active.name]=id
  if active.name=='imp_mex'or active.name=='imp_generator'then active.unit=id;active.phase='income';active.finished=Spring.GetGameFrame()
  else advance('actual_paid_structure_finished')end
 end
end
function gadget:UnitFromFactory(id,def,owner,factory)
 if done or owner~=team or not active or active.kind~='product'or not active.receipt or active.receipt.unit~=id then return end
 local okay,why=H.Factory(active.receipt);if not okay then fail(why);return end
 products[active.name]=id;active.unit=id;active.phase='egress';active.finished=Spring.GetGameFrame();active.start={Spring.GetUnitPosition(id)}
 local destination=H.MoveSite(id,index);if not destination then fail('no_native_product_egress_site');return end
 Spring.GiveOrderToUnit(id,CMD.MOVE,destination,{});log('ACTUAL_FACTORY_COMPLETE_COHORT',active.name,id,factory,active.receipt.seed,active.receipt.bikeSeed or 'population_only',active.finished)
end
function gadget:UnitDestroyed(id)
 if done then return end
 if id==commander or births[id]or active and id==active.producer then fail('required_paid_actor_destroyed_'..id)end
end
function gadget:UnitTaken(id)
 if not done and(id==commander or births[id]or active and id==active.producer)then fail('required_paid_actor_changed_owner_'..id)end
end
function gadget:GameFrame(frame)
 if done then return end
 if not commander then
  if frame%30~=0 then return end
  for _,id in ipairs(Spring.GetTeamUnits(team))do local d=UnitDefs[Spring.GetUnitDefID(id)];local cp=d.customParams or{}
   if d.name=='armcom'and cp.prototype40k_vital=='commander'and cp.prototype40k_donor=='imp_commissar'and tostring(cp.prototype40k_source_progression)=='1'then
    commander=id;base={Spring.GetUnitPosition(id)};H=helper.New(Spring,UnitDefs,Game,F,commander,base,factories,mexes,controller);log('START_ENGINE_INITIAL_GUARD_COMMANDER',id,'no_grants');break
   end
  end
  if not commander and frame>=300 then fail('engine_initial_commander_missing')end;return
 end
 local C=controller();local B=C and C.sourceMarineLifecycle
 if not B or B.failed or not live(commander)then fail('native_lifecycle_or_commander_lost');return end
 if frame>108000 then fail('bounded_native_paid_fixture_timeout');return end
 if not active then
  if frame%30~=0 then return end
  if tasks[index]then issue(tasks[index],frame)
  else
   local id=products.imp_tactical_bike;local seed=B.bike.controller.member[id];local c=seed and B.bike.controller.cohorts[seed];local n=0;if c then for _ in pairs(c.members)do n=n+1 end end
   local i,s=B.population.Usage(team)
   if n~=3 or i~=5 or s~=1 or not B.bike.Enabled(team)then fail('final_native_cohort_budget_or_effect');return end
   finish(2,'selected_paid_factory_population_hq_and_three_member_cohort_only')
  end;return
 end
 if frame-active.issued>18000 then fail('bounded_paid_stage_timeout_'..active.kind..'_'..active.name);return end
 if active.kind=='addon'then
  local okay,why=H.AddonSample(active.producer,team,active);if not okay then fail(why);return end
  if C.sourceVariantAdapter.LocalAddon(active.producer,team,active.name)then
   local complete,reason=H.AddonComplete(active.producer,team,active,factories.imp_marine_barracks)
   if not complete then fail(reason);return end
   log('ACTUAL_FULL_PAID_HQ_EFFECT',active.producer,active.tag,400,130,90*Game.gameSpeed,'local_health_plus',500,'reinforcement_enabled',true);advance('actual_paid_whole_hq_effect')
  end
 elseif active.kind=='reinforce'then
  local okay,why=H.ReinforcementSample(active.producer,team,active);if not okay then fail(why);return end
  if active.receipt then
   local complete,reason=H.ReinforcementComplete(active.receipt,active.count)
   if not complete then fail(reason);return end
   log('ACTUAL_COMPLETE_PAID_COHORT',active.producer,active.receipt.unit,active.count,'population',5,1,'source_bike_budget',2,1);advance('actual_paid_reinforcement_same_owned_budget')
  elseif B.bike.controller.failures[active.seed]then fail('native_reinforcement_refused_'..B.bike.controller.failures[active.seed])end
 elseif active.kind=='support_refusal'then
  local row=(Spring.GetFactoryCommands(active.producer,-1)or{})[1]
  if active.phase=='cancel'then
   if Spring.GetUnitIsBuilding(active.producer)or row and row.id==-UnitDefNames.imp_tactical_bike.id then
    if frame-active.cancelled>90 then fail('ordinary_factory_tag_remove_did_not_cancel')end;return
   end
   log('ACTUAL_ORDINARY_CAP_REFUSAL',active.producer,active.samples,'zero_births','zero_factory_spend','owned_reinforcement_budget',true);advance('ordinary_second_bike_refused_and_exact_tag_removed')
  else
   local receipt,why=H.CapRefusal(active.producer,team,UnitDefNames.imp_tactical_bike.id,active.issued)
   if not receipt then
    log('ORDINARY_CAP_REFUSAL_STATE',active.producer,'head',row and row.id or 'absent','tag',row and row.tag or 'absent',
     'curBuild',Spring.GetUnitIsBuilding(active.producer)or 'absent','reservation',B.population.reservations[active.producer]and true or false,why)
    fail(why);return
   end
   if row and(row.id~=receipt.head or row.tag~=receipt.tag)or active.tag and active.tag~=receipt.tag then fail('ordinary_refusal_production_tag_invalid_or_changed');return end
   active.tag=receipt.tag
   if not active.refusal then
    active.refusal=receipt;active.queuePolicy=row and 'retained' or 'stock_dropped'
    log('ACTUAL_SOURCE_CAP_ADMISSION_REFUSAL',active.producer,receipt.frame,receipt.tag,receipt.reason,receipt.infantry,receipt.support,receipt.capInfantry,receipt.capSupport,
     'queue',active.queuePolicy,'curBuild','absent','reservation',false)
   elseif active.queuePolicy=='stock_dropped'and row then fail('refused_production_queue_reappeared');return end
   local _,muse,_,euse=Spring.GetUnitResources(active.producer)
   if muse==nil or euse==nil or math.abs(muse)>.001 or math.abs(euse)>.001 then fail('refused_factory_resource_use');return end
   active.samples=active.samples+1
   if frame-active.issued>=180 then
    -- Native factory STOP only clears new-unit/rally commands. CTRL selects
    -- production commandQue; without ALT, REMOVE matches this exact tag.
    if row then
     Spring.GiveOrderToUnit(active.producer,CMD.REMOVE,{active.tag},{'ctrl'});active.phase='cancel';active.cancelled=frame
     log('ORDINARY_FACTORY_TAG_REMOVE',active.producer,active.tag,'ctrl',frame)
    else
     log('ACTUAL_ORDINARY_CAP_REFUSAL',active.producer,active.samples,'zero_births','zero_factory_spend','stock_dropped',active.tag,'owned_reinforcement_budget',true)
     advance('ordinary_second_bike_source_capacity_refused_native_drop')
    end
   end
  end
 elseif active.kind=='build'and active.phase=='income'and frame%30==0 then
  local metal,_,energy=Spring.GetUnitResources(active.unit);local value=active.name=='imp_mex'and metal or energy
  if value and value>0 then log('ACTUAL_PAID_SOURCE_INCOME',active.name,active.unit,metal,energy);advance('paid_native_economy_active')
  elseif frame-active.finished>3600 then fail('paid_source_income_inactive')end
 elseif active.kind=='product'and active.unit then
  local x,_,z=Spring.GetUnitPosition(active.unit)
  if active.phase=='egress'and x and(x-active.start[1])^2+(z-active.start[3])^2>=160^2 then
   Spring.GiveOrderToUnit(active.unit,CMD.STOP,{},{});active.phase='settle';active.stopped=frame
  elseif active.phase=='settle'and frame-active.stopped>=30 then
   local vx,vy,vz=Spring.GetUnitVelocity(active.unit)
   if vx and vx*vx+vy*vy+vz*vz<.0001 then log('ACTUAL_PAID_PRODUCT_EGRESS',active.name,active.unit,active.receipt.tag,'stopped',frame);advance('native_factory_product_population_and_egress')end
  end
 end
end

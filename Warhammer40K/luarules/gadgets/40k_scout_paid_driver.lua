-- Ordinary Marine commander/native factory orders only; no own grants or target births.
function gadget:GetInfo()return{name='40K ordinary paid Scout factory ladder',desc='Actual commander/economy/basic factory/two Scout products',author='Local project',layer=151,enabled=true}end
local options=Spring.GetModOptions()or{}
local enabled=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled
if not enabled(options.prototype_scout_paid_driver)or not gadgetHandler:IsSyncedCode()then return false end
assert(enabled(options.prototype_marine_scout_squad)and enabled(options.prototype_source_progression),'Scout actual fixed-squad/source options required')
assert(not enabled(options.prototype_scale085_pilot),'Unpaired Scout scale refused')
local S=Spring;local team=0;local phase='initial';local step=1;local task;local units={};local finished={};local started;local contexts={};local priorIDs={}
assert(not GG.Recoil40KScoutPaidContext,'Duplicate paid Scout route');GG.Recoil40KScoutPaidContext={version=1,ready=false,cohorts={},nativeAccepted=false}
local tasks={{key='imp_marine_mex',owner='commander',role='mex1',metal=true},{key='imp_marine_generator',owner='commander',role='power1'},
 {key='imp_marine_generator',owner='commander',role='power2'},{key='imp_marine_mex',owner='commander',role='mex2',metal=true},
 {key='imp_marine_generator',owner='commander',role='power3'},{key='imp_marine_mex',owner='commander',role='mex3',metal=true},
 {key='imp_marine_barracks',owner='commander',role='basicfactory'},
 {key='imp_scout',owner='basicfactory',role='cohort',product=true},{key='imp_scout',owner='basicfactory',role='cohort',product=true}}
local function emit(...)S.Echo('40K_SCOUT_PAID_DRIVER',...)end
local function finish(why)phase='done';emit('COMPLETE',why,'ordinary_native_orders_only=true paid_economy_acceptance=false')end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function complete(id)
 if not finite(id)or id<0 or id%1~=0 or S.ValidUnitID(id)~=true or S.GetUnitIsDead(id)~=false then return false end
 local hp,_,_,_,p=S.GetUnitHealth(id);return finite(hp)and hp>0 and p==1
end
local function contains(list,id)for _,v in ipairs(list or{})do if v==id then return true end end;return false end
local placement=VFS.Include('40k_configs/ordinary_paid_construction_site.lua')
local physical=VFS.Include('40k_configs/guard_factory_egress_geometry.lua')
local endpoint=VFS.Include('40k_configs/paid_factory_egress_review.lua')
local function choose(def,builder,metal)return placement.Choose(S,UnitDefs,GG,Game,def,builder,metal,emit)end

function gadget:UnitCreated(id,def,owner,builder)
 if phase~='building'or not task or def~=task.def then return end
 if owner~=team or builder~=units[task.owner]or task.birth then finish('FAIL non_unique_or_wrong_native_paid_birth');return end
 task.birth=id;local w,m,e=S.GetUnitCosts(id);if task.role=='cohort'then task.queueBill={metal=m,energy=e,work=w};if m~=120 or e~=600 or w~=1200 then finish('FAIL actual_full_four_queue_bill');return end end;emit('BIRTH','id='..id,'key='..task.key,'native_bill='..tostring(m)..','..tostring(e)..','..tostring(w))
end
function gadget:UnitFinished(id,def,owner)
 local d=UnitDefs[def];local cp=d and d.customParams or{}
 if cp.animsource=='imp_scout'then if finished[id]then finish('FAIL duplicate_scout_finish');return end;finished[id]={def=def,team=owner,frame=S.GetGameFrame()};emit('BODY_UNIT_FINISHED',S.GetGameFrame(),id,def,owner,'actual_native_callback=true')end
 if task and id==task.birth then if def~=task.def or owner~=team then finish('FAIL native_finish_mismatch');return end;task.finished=true end end
function gadget:UnitFromFactory(id,def,owner,factory,factoryDef,userOrders)
 if task and task.product and id==task.birth then
  if task.released or def~=task.def or owner~=team or factory~=units[task.owner]or S.GetUnitDefID(factory)~=factoryDef or userOrders then finish('FAIL native_factory_release_mismatch');return end
  task.released=true
  if task.role=='cohort'then
   emit('COHORT_NATIVE_RELEASE',S.GetGameFrame(),id,def,owner,factory,factoryDef,'user_orders=false','queue_bill='..task.queueBill.metal..','..task.queueBill.energy..','..task.queueBill.work)
   local pos,w,reason=endpoint.Plan(S,UnitDefs,id,factory,Game.mapSizeX,Game.mapSizeZ)
   if not pos then finish('INCONCLUSIVE natural_cohort_rally_site_unavailable');return end
   local R=GG.Recoil40KSquads;local cohort=R and R.Get and R.Get(id)
   if not cohort or cohort.profile~='marine_scout'or cohort.team~=team or cohort.slots[1]~=id then finish('INCONCLUSIVE release_full_four_context_missing');return end
   task.origins={}
   for slot=1,4 do local body=cohort.slots[slot];if not complete(body)or S.GetUnitTeam(body)~=team then finish('INCONCLUSIVE release_body_unavailable');return end
    local x,_,z=S.GetUnitPosition(body);if not finite(x)or not finite(z)then finish('INCONCLUSIVE release_position_unavailable');return end;task.origins[body]={x,z}
   end
   task.rally=pos;local accepted=S.GiveOrderToUnit(id,CMD.MOVE,pos,0);if accepted==false then finish('INCONCLUSIVE actual_cohort_rally_rejected');return end
  end
 end
end
function gadget:GameFrame(frame)
 if phase=='done'or frame<1 then return end;started=started or frame;if GG.Recoil40KScoutPaidContext.ready~=true then GG.Recoil40KScoutPaidContext.startedFrame=started end
 if frame-started>=36000 then finish('INCONCLUSIVE bounded_ordinary_paid_ladder_timeout');return end
 if phase=='initial'then
  if frame~=1 or type(S.GetGameFrame)~='function'or S.GetGameFrame()~=1 then finish('FAIL exact_fresh_native_frame_required');return end
  for _,key in ipairs({'prototype_squad_paid_fixture','prototype_squad_fixture','prototype_squad_egress_fixture','prototype_extractor_paid_fixture','prototype_necron_factory_paid_fixture','prototype_immortal_paid_driver','prototype_ork_air_factory_repeat_fixture','prototype_terminator_paid_driver','prototype_centre_march_native_observer'})do if enabled(options[key])then finish('FAIL competing_paid_driver');return end end
  local all=S.GetTeamUnits(team)or{};local m=S.GetTeamResources(team,'metal');local e=S.GetTeamResources(team,'energy')
  if #all~=1 or not UnitDefNames.smcom or S.GetUnitDefID(all[1])~=UnitDefNames.smcom.id or not complete(all[1])or not m or math.abs(m-1000)>5 or not e or math.abs(e-1000)>5 then finish('FAIL ordinary_natural_commander_1000_start_required');return end
  units.commander=all[1];for _,t in ipairs(tasks)do if not UnitDefNames[t.key]then finish('INCONCLUSIVE actual_route_definition_absent_'..t.key);return end end
  phase='next';emit('ROUTE','existing_smcom_Marine_basic_factory_two_Scout4_products','no_separate_HQ_or_grants=true')
 elseif phase=='next'then
  task=tasks[step];if not task then finish('PREPARED ordinary_two_paid_full4_contexts_native_egress_observed_payment_receipt_pending');return end
  task.def=UnitDefNames[task.key].id;local actor=units[task.owner];local d=actor and UnitDefs[S.GetUnitDefID(actor)]
  if not complete(actor)or S.GetUnitTeam(actor)~=team then finish('FAIL native_paid_builder_lost');return end
  if not contains(d.buildOptions,task.def)or(task.product and not d.isFactory)then finish('INCONCLUSIVE current_native_menu_or_factory_'..task.key);return end
  local pos=task.product and{}or choose(task.def,actor,task.metal)
  if not pos then finish('INCONCLUSIVE no_native_legal_productive_site_'..task.key);return end
  phase='building';local accepted=S.GiveOrderToUnit(actor,-task.def,pos,0)
  if accepted==false then finish('INCONCLUSIVE native_paid_queue_rejected');return end
  emit('ORDER','key='..task.key,'builder='..actor,'actual_native_queue=true')
 elseif phase=='building'then
  if not complete(units[task.owner])or S.GetUnitTeam(units[task.owner])~=team then finish('FAIL paid_owner_lost');return end
  if task.birth and task.finished and complete(task.birth)and(not task.product or task.released)then
   if S.GetUnitTeam(task.birth)~=team then finish('FAIL native_paid_product_capture');return end
   if task.role=='cohort'then
    local R=GG.Recoil40KSquads;local cohort=R and R.Get and R.Get(task.birth);local n=0;local seen={}
    if not cohort or cohort.profile~='marine_scout'or cohort.team~=team then finish('INCONCLUSIVE actual_full_four_context_not_ready');return end
    if cohort.slots[1]~=task.birth or not finite(cohort.id)or cohort.id<1 or cohort.id%1~=0 then finish('FAIL original_paid_product_or_squad_identity');return end
    for slot,id in pairs(cohort.slots)do n=n+1;if type(slot)~='number'or slot%1~=0 or slot<1 or slot>4 or type(id)~='number'or id%1~=0 or id<0 or seen[id]or priorIDs[id]or not complete(id)or S.GetUnitTeam(id)~=team then finish('FAIL genuine_full_four_body');return end;seen[id]=true
     local nativeDef=S.GetUnitDefID(id);local names=UnitDefNames;local d=UnitDefs[nativeDef];local cp=d and d.customParams or{};local expected=(id==task.birth and names.imp_scout or names.imp_scout_member)
     if not expected or nativeDef~=expected.id or cp.animsource~='imp_scout'or tonumber(cp.prototype40k_squad_profile_id)~=7 then finish('FAIL exact_scout_body_identity');return end
     if not cohort.generations or cohort.generations[slot]~=1 then finish('FAIL fresh_paid_body_generation');return end
     local observed=finished[id];if not observed or observed.def~=nativeDef or observed.team~=team then finish('INCONCLUSIVE genuine_all_body_UnitFinished_missing');return end
     local w,m,e=S.GetUnitCosts(id);local inv=cohort.investments[slot];if m~=30 or e~=150 or w~=300 or not inv or inv.metal~=30 or inv.energy~=150 or inv.work~=300 then finish('FAIL paid_four_body_allocation');return end
    end
    if n~=4 then finish('FAIL fixed_four_capacity');return end
    for _,id in pairs(cohort.slots)do local clear=physical.Outside(S,UnitDefs,units[task.owner],id);local x,_,z=S.GetUnitPosition(id);local origin=task.origins and task.origins[id];local arrived=finite(x)and finite(z)and task.rally and (x-task.rally[1])^2+(z-task.rally[3])^2<=96^2;local traveled=origin and finite(x)and finite(z)and (x-origin[1])^2+(z-origin[2])^2>=32^2;if clear~=true or not arrived or not traveled then task.clearFrames=0;task.lastClear=nil;task.clearStart=nil;return end end
    task.clearFrames=(task.lastClear==frame-1)and((task.clearFrames or 0)+1)or 1;if task.clearFrames==1 then task.clearStart=frame end;task.lastClear=frame;if task.clearFrames<30 then return end
    emit('ALL4_CLEAR_SPAN',task.clearStart,frame,'frames='..task.clearFrames,'product='..task.birth,'squad='..cohort.id,'team='..team,'slots='..cohort.slots[1]..','..cohort.slots[2]..','..cohort.slots[3]..','..cohort.slots[4],'all4_native_outside=true all4_rally_arrived=true all4_traveled_32=true independent_terrain_pose_proof=false payment_debit_proof=false')
        for _,saved in ipairs(contexts)do
     local previous=R.Get(saved.product)
     if not previous or previous.id~=saved.squad or previous.team~=team or previous.profile~='marine_scout'then finish('FAIL prior_paid_cohort_lost_or_captured');return end
     if previous.id==cohort.id then finish('FAIL repeated_squad_identity');return end
     for slot=1,4 do local id=saved.slots[slot];if previous.slots[slot]~=id or not complete(id)or S.GetUnitTeam(id)~=team then finish('FAIL prior_paid_cohort_changed');return end end
    end
    contexts[#contexts+1]={squad=cohort.id,product=task.birth,team=team,frame=frame,slots={cohort.slots[1],cohort.slots[2],cohort.slots[3],cohort.slots[4]}}
    for _,id in pairs(cohort.slots)do priorIDs[id]=true end
    GG.Recoil40KScoutPaidContext={version=1,ready=#contexts==2,cohorts=contexts,nativeAccepted=false}
    emit('FULL4_NATIVE_EGRESS',frame,task.birth,'four_actual_body_bills=30,150,300','native_yard_clear_30frames=true','paid_economy_acceptance=false')
   end
   units[task.role]=task.birth;step=step+1;phase='next'
  end
 end
end

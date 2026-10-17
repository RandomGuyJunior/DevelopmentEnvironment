-- Ordinary Marine commander/native factory orders only; no own grants or target births.
function gadget:GetInfo()return{name='40K ordinary paid Terminator factory ladder',desc='Actual commander/economy/basic constructor/T2 factory/product',author='Local project',layer=151,enabled=true}end
local options=Spring.GetModOptions()or{}
local pair=VFS.Include('40k_configs/terminator_scale_pair.lua')
local enabled=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled
if not enabled(options.prototype_terminator_paid_driver)or not gadgetHandler:IsSyncedCode()then return false end
assert(enabled(options.prototype_terminator_native_observer)and enabled(options.prototype_scale_native_probe)and enabled(options.prototype_source_progression),'Terminator real observer/source options required');pair.ValidateClosure(options,VFS)
local S=Spring;local team=0;local phase='initial';local step=1;local task;local units={};local finished={};local started
assert(not GG.Recoil40KTerminatorPaidContext,'Duplicate paid Terminator route');GG.Recoil40KTerminatorPaidContext={version=1,ready=false,nativeAccepted=false}
local tasks={{key='imp_marine_mex',owner='commander',role='mex1',metal=true},{key='imp_marine_generator',owner='commander',role='power1'},
 {key='imp_marine_generator',owner='commander',role='power2'},{key='imp_marine_mex',owner='commander',role='mex2',metal=true},
 {key='imp_marine_generator',owner='commander',role='power3'},{key='imp_marine_mex',owner='commander',role='mex3',metal=true},
 {key='imp_marine_barracks',owner='commander',role='basicfactory'},{key='imp_marine_builder',owner='basicfactory',role='basic',product=true},
 {key='imp_marine_advanced_barracks',owner='basic',role='advancedfactory'},{key='imp_terminator',owner='advancedfactory',role='cohort',product=true}}
local function emit(...)S.Echo('40K_TERMINATOR_PAID_DRIVER',...)end
local function finish(why)phase='done';emit('COMPLETE',why,'ordinary_native_orders_only=true paid_economy_acceptance=false')end
local function complete(id)if not id or S.GetUnitIsDead(id)then return false end;local hp,_,_,_,p=S.GetUnitHealth(id);return hp and hp>0 and p==1 end
local function contains(list,id)for _,v in ipairs(list or{})do if v==id then return true end end;return false end
local placement=VFS.Include('40k_configs/ordinary_paid_construction_site.lua')
local physical=VFS.Include('40k_configs/guard_factory_egress_geometry.lua')
local endpoint=VFS.Include('40k_configs/paid_factory_egress_review.lua')
local gait=VFS.Include('40k_configs/terminator_native_gait_path.lua')
local function choose(def,builder,metal)return placement.Choose(S,UnitDefs,GG,Game,def,builder,metal,emit)end

function gadget:UnitCreated(id,def,owner,builder)
 if phase~='building'or not task or def~=task.def then return end
 if owner~=team or builder~=units[task.owner]or task.birth then finish('FAIL non_unique_or_wrong_native_paid_birth');return end
 task.birth=id;local w,m,e=S.GetUnitCosts(id);if task.role=='cohort'then task.queueBill={metal=m,energy=e,work=w};if m~=720 or e~=3900 or w~=5700 then finish('FAIL actual_full_three_queue_bill');return end end;emit('BIRTH','id='..id,'key='..task.key,'native_bill='..tostring(m)..','..tostring(e)..','..tostring(w))
end
function gadget:UnitFinished(id,def,owner)
 local d=UnitDefs[def];local cp=d and d.customParams or{}
 if cp.animsource=='imp_terminator'then if finished[id]then finish('FAIL duplicate_terminator_finish');return end;finished[id]={def=def,team=owner,frame=S.GetGameFrame()};emit('BODY_UNIT_FINISHED',S.GetGameFrame(),id,def,owner,'actual_native_callback=true')end
 if task and id==task.birth then if def~=task.def or owner~=team then finish('FAIL native_finish_mismatch');return end;task.finished=true end end
function gadget:UnitFromFactory(id,def,owner,factory,factoryDef,userOrders)
 if task and task.product and id==task.birth then
  if task.released or def~=task.def or owner~=team or factory~=units[task.owner]or S.GetUnitDefID(factory)~=factoryDef or userOrders then finish('FAIL native_factory_release_mismatch');return end
  task.released=true
  if task.role=='cohort'then
   emit('COHORT_NATIVE_RELEASE',S.GetGameFrame(),id,def,owner,factory,factoryDef,'user_orders=false','queue_bill='..task.queueBill.metal..','..task.queueBill.energy..','..task.queueBill.work)
   local pos,w,reason=endpoint.Plan(S,UnitDefs,id,factory,Game.mapSizeX,Game.mapSizeZ)
   if not pos then finish('INCONCLUSIVE natural_cohort_rally_site_unavailable');return end
   task.rally=pos;local accepted=S.GiveOrderToUnit(id,CMD.MOVE,pos,0);if accepted==false then finish('INCONCLUSIVE actual_cohort_rally_rejected');return end
  end
 end
end
function gadget:GameFrame(frame)
 if phase=='done'or frame<1 then return end;started=started or frame;if GG.Recoil40KTerminatorPaidContext.ready~=true then GG.Recoil40KTerminatorPaidContext.startedFrame=started end
 if frame-started>=36000 then finish('INCONCLUSIVE bounded_ordinary_paid_ladder_timeout');return end
 if phase=='initial'then
  -- Synced native has no saved-game query: root fresh-script/receipt gate excludes SSF/replay.
  if frame~=1 or type(S.GetGameFrame)~='function'or S.GetGameFrame()~=frame then finish('FAIL fresh_native_frame_one_required');return end
  for _,key in ipairs({'prototype_squad_paid_fixture','prototype_squad_fixture','prototype_squad_egress_fixture','prototype_extractor_paid_fixture','prototype_necron_factory_paid_fixture','prototype_immortal_paid_driver','prototype_ork_air_factory_repeat_fixture'})do if enabled(options[key])then finish('FAIL competing_paid_driver');return end end
  local all=S.GetTeamUnits(team)or{};local m=S.GetTeamResources(team,'metal');local e=S.GetTeamResources(team,'energy')
  if #all~=1 or not UnitDefNames.smcom or S.GetUnitDefID(all[1])~=UnitDefNames.smcom.id or not complete(all[1])or not m or math.abs(m-1000)>5 or not e or math.abs(e-1000)>5 then finish('FAIL ordinary_natural_commander_1000_start_required');return end
  units.commander=all[1];for _,t in ipairs(tasks)do if not UnitDefNames[t.key]then finish('INCONCLUSIVE actual_route_definition_absent_'..t.key);return end end
  phase='next';emit('ROUTE','existing_smcom_basic_Marine_factory_basic_constructor_T2_Marine_factory_Terminator3','no_separate_HQ_or_grants=true')
 elseif phase=='next'then
  task=tasks[step];if not task then finish('PREPARED ordinary_paid_full3_context_native_egress_observed_payment_receipt_pending');return end
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
    if not cohort or cohort.profile~='marine_terminator'or cohort.team~=team then finish('INCONCLUSIVE actual_full_three_context_not_ready');return end
    for slot,id in pairs(cohort.slots)do n=n+1;if type(slot)~='number'or slot%1~=0 or slot<1 or slot>3 or type(id)~='number'or id%1~=0 or id<=0 or seen[id]or not complete(id)or S.GetUnitTeam(id)~=team then finish('FAIL genuine_full_three_body');return end;seen[id]=true
     local nativeDef=S.GetUnitDefID(id);local names=UnitDefNames;local d=UnitDefs[nativeDef];local cp=d and d.customParams or{};local expected=(id==task.birth and names.imp_terminator or names.imp_terminator_member)
     if not expected or nativeDef~=expected.id or cp.animsource~='imp_terminator'or tonumber(cp.scale_pilot_factor)~=.85 or cp.scale_animation_bank~='imp_terminator_scale085'then finish('FAIL exact_paired_terminator_body_identity');return end
     local observed=finished[id];if not observed or observed.def~=nativeDef or observed.team~=team then finish('INCONCLUSIVE genuine_all_body_UnitFinished_missing');return end
     local w,m,e=S.GetUnitCosts(id);local inv=cohort.investments[slot];if m~=240 or e~=1300 or w~=1900 or not inv or inv.metal~=240 or inv.energy~=1300 or inv.work~=1900 then finish('FAIL paid_three_body_allocation');return end
    end
    if n~=3 then finish('FAIL fixed_three_capacity');return end
    for _,id in pairs(cohort.slots)do local clear=physical.Outside(S,UnitDefs,units[task.owner],id);if clear~=true then task.clearFrames=0;task.lastClear=nil;task.clearStart=nil;return end end
    task.clearFrames=(task.lastClear==frame-1)and((task.clearFrames or 0)+1)or 1;if task.clearFrames==1 then task.clearStart=frame end;task.lastClear=frame;if task.clearFrames<30 then return end
    emit('ALL3_CLEAR_SPAN',task.clearStart,frame,'frames='..task.clearFrames,'product='..task.birth,'squad='..cohort.id,'team='..team,'slots='..cohort.slots[1]..','..cohort.slots[2]..','..cohort.slots[3],'all3_native_outside=true independent_terrain_pose_proof=false payment_debit_proof=false')
    local path,witness=gait.Plan(S,UnitDefs,physical,cohort,units[task.owner],Game.mapSizeX,Game.mapSizeZ)
    if not path then finish('INCONCLUSIVE '..tostring(witness));return end
    local accepted,reason=gait.Start(S,CMD,task.birth,path,task.rally,emit)
    if accepted~=true then finish('INCONCLUSIVE '..tostring(reason));return end
    GG.Recoil40KTerminatorPaidContext={version=1,ready=true,squad=cohort.id,product=task.birth,team=team,frame=frame,slots={cohort.slots[1],cohort.slots[2],cohort.slots[3]},nativeAccepted=false}
    emit('FULL3_NATIVE_EGRESS',frame,task.birth,'three_actual_body_bills=240,1300,1900','native_yard_clear_30frames=true','paid_economy_acceptance=false')
   end
   units[task.role]=task.birth;step=step+1;phase='next'
  end
 end
end

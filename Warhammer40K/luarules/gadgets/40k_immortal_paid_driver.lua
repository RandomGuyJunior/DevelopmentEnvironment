-- Ordinary native build orders only; funded target belongs to separate observer.
function gadget:GetInfo()return{name='40K ordinary paid Immortal factory ladder',desc='Actual commander/economy/basic constructor/T2 factory/product',author='Local project',layer=151,enabled=true}end
local options=Spring.GetModOptions()or{}
local M=VFS.Include('40k_configs/immortal_native_emitter_fixture.lua')
local enabled=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled
if not M.Enabled(options)or not enabled(options.prototype_immortal_paid_driver)or not gadgetHandler:IsSyncedCode()then return false end
local S=Spring;local team=0;local phase='initial';local step=1;local task;local units={};local started
local tasks={{key='nec_mex',owner='commander',role='mex1',metal=true},{key='nec_generator',owner='commander',role='power1'},
 {key='nec_generator',owner='commander',role='power2'},{key='nec_mex',owner='commander',role='mex2',metal=true},
 {key='nec_generator',owner='commander',role='power3'},{key='nec_mex',owner='commander',role='mex3',metal=true},
 {key='nec_hq',owner='commander',role='basicfactory'},{key='nec_scarab',owner='basicfactory',role='basic',product=true},
 {key='nec_advanced_factory',owner='basic',role='advancedfactory'},{key='nec_immortal',owner='advancedfactory',role='cohort',product=true}}
local function emit(...)S.Echo('40K_IMMORTAL_PAID_DRIVER',...)end
local function finish(why)phase='done';emit('COMPLETE',why,'ordinary_native_orders_only=true paid_economy_acceptance=false')end
local function complete(id)if not id or S.GetUnitIsDead(id)then return false end;local hp,_,_,_,p=S.GetUnitHealth(id);return hp and hp>0 and p==1 end
local function contains(list,id)for _,v in ipairs(list or{})do if v==id then return true end end;return false end
local placement=VFS.Include('40k_configs/ordinary_paid_construction_site.lua')
local function choose(def,builder,metal)return placement.Choose(S,UnitDefs,GG,Game,def,builder,metal,emit)end

function gadget:UnitCreated(id,def,owner,builder)
 if phase~='building'or not task or def~=task.def then return end
 if owner~=team or builder~=units[task.owner]or task.birth then finish('FAIL non_unique_or_wrong_native_paid_birth');return end
 task.birth=id;local w,m,e=S.GetUnitCosts(id);emit('BIRTH','id='..id,'key='..task.key,'native_bill='..tostring(m)..','..tostring(e)..','..tostring(w))
end
function gadget:UnitFinished(id,def,owner)if task and id==task.birth then if def~=task.def or owner~=team then finish('FAIL native_finish_mismatch');return end;task.finished=true end end
function gadget:UnitFromFactory(id,def,owner,factory,factoryDef,userOrders)
 if task and task.product and id==task.birth then
  if task.released or def~=task.def or owner~=team or factory~=units[task.owner]or S.GetUnitDefID(factory)~=factoryDef or userOrders then finish('FAIL native_factory_release_mismatch');return end
  task.released=true
  if task.role=='cohort'then
   local x,_,z=S.GetUnitPosition(factory);local pd=UnitDefs[def]
   local pos={x,0,z+256};pos[2]=S.GetGroundHeight(pos[1],pos[3])
   if pos[1]<32 or pos[3]<32 or pos[1]>Game.mapSizeX-32 or pos[3]>Game.mapSizeZ-32 or S.TestMoveOrder(def,pos[1],pos[2],pos[3],0,0,0,true,true,false)~=true then finish('INCONCLUSIVE natural_cohort_rally_site_unavailable');return end
   local accepted=S.GiveOrderToUnit(id,CMD.MOVE,pos,0);if accepted==false then finish('INCONCLUSIVE actual_cohort_rally_rejected');return end
  end
 end
end
function gadget:GameFrame(frame)
 if phase=='done'or frame<1 then return end;started=started or frame
 if frame-started>=18000 then finish('INCONCLUSIVE bounded_ordinary_paid_ladder_timeout');return end
 if phase=='initial'then
  -- Synced native has no saved-game query: root fresh-script/receipt gate excludes SSF/replay.
  if frame~=1 or type(S.GetGameFrame)~='function'or S.GetGameFrame()~=frame then finish('FAIL fresh_native_frame_one_required');return end
  for _,key in ipairs({'prototype_squad_paid_fixture','prototype_squad_fixture','prototype_squad_egress_fixture','prototype_extractor_paid_fixture','prototype_necron_factory_paid_fixture'})do if enabled(options[key])then finish('FAIL competing_paid_driver');return end end
  local all=S.GetTeamUnits(team)or{};local m=S.GetTeamResources(team,'metal');local e=S.GetTeamResources(team,'energy')
  if #all~=1 or not UnitDefNames.nec_lord or S.GetUnitDefID(all[1])~=UnitDefNames.nec_lord.id or not complete(all[1])or not m or math.abs(m-1000)>5 or not e or math.abs(e-1000)>5 then finish('FAIL ordinary_natural_commander_1000_start_required');return end
  units.commander=all[1];for _,t in ipairs(tasks)do if not UnitDefNames[t.key]then finish('INCONCLUSIVE actual_route_definition_absent_'..t.key);return end end
  phase='next';emit('ROUTE','existing_nec_lord_nec_hq_factory_nec_scarab_nec_advanced_factory_Immortal3','no_separate_HQ_or_grants=true')
 elseif phase=='next'then
  task=tasks[step];if not task then finish('PREPARED ordinary_paid_full3_context_yard_clear_pending_observer');return end
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
   units[task.role]=task.birth;step=step+1;phase='next'
  end
 end
end

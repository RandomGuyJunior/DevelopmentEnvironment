-- Ordinary native build orders only; funded target belongs to separate observer.
function gadget:GetInfo()return{name='40K ordinary paid Basilica Guard ladder',desc='Actual commander/economy/basic constructor/T2 factory/product',author='Local project',layer=151,enabled=true}end
local options=Spring.GetModOptions()or{}
local M=VFS.Include('40k_configs/basilica_paid_actions.lua')
local enabled=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled
if not M.Enabled(options)or not enabled(options.prototype_basilica_paid_driver)or not gadgetHandler:IsSyncedCode()then return false end
local S=Spring;local team=0;local phase='initial';local step=1;local task;local units={};local started
local finished,released={},{};local actions
local geometry=VFS.Include('40k_configs/guard_factory_egress_geometry.lua')
local tasks={{key='imp_mex',owner='commander',role='mex1',metal=true},{key='imp_generator',owner='commander',role='power1'},
 {key='imp_generator',owner='commander',role='power2'},{key='imp_mex',owner='commander',role='mex2',metal=true},
 {key='imp_generator',owner='commander',role='power3'},{key='imp_mex',owner='commander',role='mex3',metal=true},
 {key='imp_barracks',owner='commander',role='barracks'},{key='imp_guardsman',owner='barracks',role='cohort',product=true,bill={64,320,800}},
 {key='imp_tank_factory',owner='commander',role='tank'},{key='armcv',owner='tank',role='basic',product=true,bill={135,1950,4050}},
 {key='armavp',owner='basic',role='advancedfactory'},{key='imp_russ',owner='advancedfactory',role='russ',product=true,bill={480,2400,4000}}}
local function emit(...)S.Echo('40K_BASILICA_PAID_DRIVER',...)end
local function finish(why)phase='done';emit('COMPLETE',why,'ordinary_native_orders_only=true paid_economy_acceptance=false')end
local function complete(id)if not id or S.GetUnitIsDead(id)then return false end;local hp,_,_,_,p=S.GetUnitHealth(id);return hp and hp>0 and p==1 end
local function contains(list,id)for _,v in ipairs(list or{})do if v==id then return true end end;return false end
local placement=VFS.Include('40k_configs/ordinary_paid_construction_site.lua')
local function choose(def,builder,metal)return placement.Choose(S,UnitDefs,GG,Game,def,builder,metal,emit)end

function gadget:UnitCreated(id,def,owner,builder)if actions then actions.UnitChanged()end
 if phase~='building'or not task or def~=task.def then return end
 if owner~=team or builder~=units[task.owner]or task.birth then finish('FAIL non_unique_or_wrong_native_paid_birth');return end
 task.birth=id;local w,m,e=S.GetUnitCosts(id);if task.bill and(m~=task.bill[1]or e~=task.bill[2]or w~=task.bill[3])then finish('FAIL actual_paid_native_bill_mismatch');return end;emit('BIRTH','id='..id,'key='..task.key,'native_bill='..tostring(m)..','..tostring(e)..','..tostring(w))
end
function gadget:UnitFinished(id,def,owner)finished[id]=true;if task and id==task.birth then if def~=task.def or owner~=team then finish('FAIL native_finish_mismatch');return end;task.finished=true end end
function gadget:UnitFromFactory(id,def,owner,factory,factoryDef,userOrders)
 if task and task.product and id==task.birth then
  if task.released or def~=task.def or owner~=team or factory~=units[task.owner]or S.GetUnitDefID(factory)~=factoryDef or userOrders then finish('FAIL native_factory_release_mismatch');return end
  task.released=true;released[id]=true
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
 if frame-started>=36000 then finish('INCONCLUSIVE bounded_ordinary_paid_ladder_timeout');return end
 if phase=='initial'then
  if Game.mapName~='Basilica Fall 0.1'or Game.mapSizeX~=6144 or Game.mapSizeZ~=6144 or type(Game.mapChecksum)~='string'or #Game.mapChecksum~=128 or not Game.mapChecksum:match('^[0-9a-fA-F]+$')then finish('FAIL exact_existing_Basilica_map_required');return end
  local digestSource=options.prototype_squad_state_digest_source;local digestFrames=options.prototype_squad_state_digest_frames
  if type(digestSource)~='string'or #digestSource~=40 or not digestSource:match('^[0-9a-fA-F]+$')or type(digestFrames)~='string'or digestFrames==''then finish('FAIL exact_common_digest_source_and_frames_required');return end
  for key,value in pairs(options)do if key:match('^prototype_')and(key:match('_fixture$')or key:find('benchmark')or key:find('probe')or key:match('_paid_driver$')and key~='prototype_basilica_paid_driver')and enabled(value)then finish('FAIL competing_native_diagnostic_'..key);return end end
  for key,donor in pairs({imp_barracks='armlab',imp_tank_factory='armvp'})do local n=UnitDefNames[key];local cp=n and UnitDefs[n.id].customParams;if not cp or tonumber(cp.prototype40k_native_factory_pilot)~=1 or cp.prototype40k_native_factory_donor~=donor then finish('INCONCLUSIVE actual_native_pilot_'..key);return end end
  -- Synced native has no saved-game query: root fresh-script/receipt gate excludes SSF/replay.
  if frame~=1 or type(S.GetGameFrame)~='function'or S.GetGameFrame()~=frame then finish('FAIL fresh_native_frame_one_required');return end
  for _,key in ipairs({'prototype_squad_paid_fixture','prototype_squad_fixture','prototype_squad_egress_fixture','prototype_extractor_paid_fixture','prototype_necron_factory_paid_fixture','prototype_ork_air_factory_paid_fixture','prototype_immortal_paid_driver','prototype_squad_cancel_fixture','prototype_russ_wreck_paid_fixture'})do if enabled(options[key])then finish('FAIL competing_paid_driver');return end end
  local all=S.GetTeamUnits(team)or{};local m=S.GetTeamResources(team,'metal');local e=S.GetTeamResources(team,'energy')
  if #all~=1 or not UnitDefNames.armcom or S.GetUnitDefID(all[1])~=UnitDefNames.armcom.id or not complete(all[1])or not m or math.abs(m-1000)>5 or not e or math.abs(e-1000)>5 then finish('FAIL ordinary_natural_commander_1000_start_required');return end
  units.commander=all[1];for _,t in ipairs(tasks)do if not UnitDefNames[t.key]then finish('INCONCLUSIVE actual_route_definition_absent_'..t.key);return end end
  phase='next';emit('ROUTE','actual_armcom_barracks_Guard8_tankfactory_armcv_armavp_Russ','no_separate_HQ_or_grants=true')
 elseif phase=='next'then
  task=tasks[step];if not task then if not GG.Recoil40KSquads then finish('INCONCLUSIVE authoritative_squad_owner_missing');return end;for _,e in ipairs(UnitDefs[UnitDefNames.imp_russ.id].weapons or{})do Script.SetWatchWeapon(e.weaponDef,true)end;units.finished=finished;units.released=released;actions=M.New(S,UnitDefs,WeaponDefs,FeatureDefs,GG.Recoil40KSquads,units,geometry,emit,VFS.Include('40k_configs/basilica_builder_reclaim_ledger.lua'));phase='actions';return end
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
   if task.role=='cohort'then local R=GG.Recoil40KSquads;local row=R and R.Get(task.birth);if not row or #R.Members(task.birth)~=8 then return end;for slot=1,8 do local id=row.slots[slot];if not finished[id]or not complete(id)or geometry.Outside(S,UnitDefs,units.barracks,id)~=true then return end end end
   units[task.role]=task.birth;step=step+1;phase='next'
  end
 elseif phase=='actions'then local result=actions.Step(frame);if result then finish(result)end
 end
end

function gadget:ProjectileCreated(...)if actions then actions.Projectile(...)end end
function gadget:FeatureCreated(...)if actions then actions.FeatureCreated(...)end end
function gadget:FeatureDamaged(...)if actions then actions.FeatureDamaged(...)end end
function gadget:FeatureDestroyed(...)if actions then actions.FeatureDestroyed(...)end end
function gadget:AllowFeatureBuildStep(...)if actions then actions.BuildStep(...)end;return true end

function gadget:UnitDestroyed()if actions then actions.UnitChanged()end end
function gadget:UnitTaken()if actions then actions.UnitChanged()end end
function gadget:UnitGiven()if actions then actions.UnitChanged()end end
function gadget:AllowUnitBuildStep(builder)if actions and actions.ledger and builder==units.basic then actions.UnitChanged()end;return true end

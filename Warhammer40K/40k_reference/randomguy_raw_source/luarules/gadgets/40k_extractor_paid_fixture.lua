function gadget:GetInfo()
 return{name='40K ordinary paid extractor replacement witness',desc='Default-off unchanged-yard placement and paid replacement lifecycle',author='Local project',layer=152,enabled=true}
end
local options=Spring.GetModOptions()or{}
local enabled=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled
if not enabled(options.prototype_extractor_paid_fixture)then return false end
if not gadgetHandler:IsSyncedCode()then
 local closeAt
 local function done(_,result)Spring.Echo('40K_EXTRACTOR_PAID owned_autoclose '..result);closeAt=Spring.GetGameFrame()+90 end
 function gadget:Initialize()gadgetHandler:AddSyncAction('40k_extractor_paid_done',done)end
 function gadget:GameFrame(f)if closeAt and f>=closeAt then closeAt=nil;Spring.SendCommands('quitforce')end end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction('40k_extractor_paid_done')end
 return
end
local orderProbe=VFS.Include('40k_configs/native_build_order_probe.lua')
local S=Spring;local team=0;local started;local phase='initial';local step=1;local task;local units={};local site
local route=({guard={'armcom','imp_barracks','armck','armalab','armack','imp_mex','armmoho'},
 marine={'smcom','imp_marine_barracks','imp_marine_builder','imp_marine_advanced_barracks','imp_marine_advanced_builder','imp_marine_mex','armmoho'},
 ork={'corcom','ork_boyz_hut','corck','ork_boyz_hut_t2','corack','ork_listening_post','cormoho'},
 necron={'nec_lord','nec_hq','nec_scarab','nec_advanced_factory','nec_advanced_scarab','nec_mex','armmoho'}})[options.prototype_extractor_paid_faction or'guard']
local tasks
local incomePower=({guard='imp_generator',marine='imp_marine_generator',ork='ork_generator',necron='nec_generator'})[options.prototype_extractor_paid_faction or'guard']
local function emit(event,...)
 local a={...};for i=1,#a do a[i]=tostring(a[i])end;S.Echo('40K_EXTRACTOR_PAID '..event..' '..table.concat(a,' '))
end
local function values(t)
 local parts={};for i,v in ipairs(t or{})do parts[i]=tostring(v)end;return table.concat(parts,',')
end
local function reportOrder(row)
 local b=row.resources or{}
 emit('NATIVE_ORDER_STATE','frame='..row.frame,'elapsed='..row.elapsed,'actor='..row.actor,'team='..tostring(row.team),
  'dead='..tostring(row.dead),'order_return='..tostring(row.orderReturn),'position='..values(row.position),'velocity='..values(row.velocity),
  'site='..values(row.site),'distance='..tostring(row.distance),'buildDistance='..tostring(row.buildDistance),'buildSpeed='..tostring(row.buildSpeed),
  'isBuilder='..tostring(row.isBuilder),'isFactory='..tostring(row.isFactory),'inBuildRange='..tostring(row.inBuildRange),'building='..tostring(row.building),
  'status='..tostring(row.status),'feature='..tostring(row.feature),'groundMetal='..tostring(row.groundMetal),'queue_kind='..tostring(row.queueKind),
  'metal='..tostring(b.metal),'energy='..tostring(b.energy),'metal_income='..tostring(b.metalIncome),'energy_income='..tostring(b.energyIncome),
  'metal_expense='..tostring(b.metalExpense),'energy_expense='..tostring(b.energyExpense),'net_delta_not_exact_bill=true')
 for i,c in ipairs(row.queue)do emit('NATIVE_ORDER_QUEUE','index='..i,'id='..tostring(c.id),'tag='..tostring(c.tag),'params='..values(c.params),
  'coded_options='..tostring(type(c.options)=='table'and c.options.coded or c.options))end
end
local function resources(event)
 local m,_,_,mi=S.GetTeamResources(team,'metal');local e,_,_,ei=S.GetTeamResources(team,'energy')
 emit(event,'metal='..tostring(m),'energy='..tostring(e),'income_m='..tostring(mi),'income_e='..tostring(ei),'net_delta_not_exact_bill=true')
 return m,e
end
local function finish(reason)
 if phase=='done'then return end;phase='done';resources('FINAL');emit('COMPLETE',reason)
 SendToUnsynced('40k_extractor_paid_done',reason)
end
local function complete(id)
 if not id or S.GetUnitIsDead(id)then return false end
 local hp,_,_,_,p=S.GetUnitHealth(id);return hp and hp>0 and p==1
end
local function contains(list,id)for _,value in ipairs(list or{})do if value==id then return true end end;return false end
local function choose(def,builder,metal)
 local cx,_,cz=S.GetUnitPosition(builder);local d=UnitDefs[def]
 if metal then
  local api=GG.resource_spot_finder
  if not api then return end -- Never bypass stock spot admission with a guessed pixel.
  if not api.isMetalMap then
   if type(api.metalSpotsList)~='table'or type(api.GetBuildingPositions)~='function'or type(api.IsMexPositionValid)~='function'then return end
   local candidates={}
   for _,spot in ipairs(api.metalSpotsList)do for _,p in ipairs(api.GetBuildingPositions(spot,def,0,true)or{})do
    local distance=(p.x-cx)^2+(p.z-cz)^2
    if distance<=2048^2 then candidates[#candidates+1]={spot=spot,x=p.x,z=p.z,distance=distance}end
   end end
   table.sort(candidates,function(a,b)if a.distance~=b.distance then return a.distance<b.distance end;if a.x~=b.x then return a.x<b.x end;return a.z<b.z end)
   for _,c in ipairs(candidates)do
    local x,y,z=S.Pos2BuildPos(def,c.x,0,c.z,0);y=S.GetGroundHeight(x,z)
    local status,feature=S.TestBuildOrder(def,x,y,z,0)
    if x>d.xsize*4+32 and z>d.zsize*4+32 and x<Game.mapSizeX-d.xsize*4-32 and z<Game.mapSizeZ-d.zsize*4-32
     and status==2 and not feature and api.IsMexPositionValid(c.spot,x,z)
     and #(S.GetUnitsInRectangle(x-d.xsize*4-32,z-d.zsize*4-32,x+d.xsize*4+32,z+d.zsize*4+32)or{})==0 then
     local free=true
     for _,id in ipairs(S.GetUnitsInCylinder(c.spot.x,c.spot.z,Game.extractorRadius or 96)or{})do
      local existing=UnitDefs[S.GetUnitDefID(id)]
      if existing and(existing.extractsMetal or 0)>0 and S.GetUnitIsDead(id)==false then free=false;break end
     end
     if free then emit('STOCK_MEX_SITE','x='..x,'z='..z,'full_yield_provider=true','final_snapped_valid=true');return{x,y,z,0}end
    end
   end
   return
  end
 end
 for ring=6,64 do for angle=0,15 do
  local a=angle*math.pi/8;local x,y,z=S.Pos2BuildPos(def,cx+ring*32*math.cos(a),0,cz+ring*32*math.sin(a),0)
  if x>d.xsize*4+32 and z>d.zsize*4+32 and x<Game.mapSizeX-d.xsize*4-32 and z<Game.mapSizeZ-d.zsize*4-32 then
   y=S.GetGroundHeight(x,z);local status,feature=S.TestBuildOrder(def,x,y,z,0)
   if status==2 and not feature and #(S.GetUnitsInRectangle(x-d.xsize*4-32,z-d.zsize*4-32,x+d.xsize*4+32,z+d.zsize*4+32)or{})==0
    and(not metal or(select(3,S.GetGroundInfo(x,z))or 0)>0)then return{x,y,z,0}end
  end
 end end
end
local function probe(def,pos,event)
 local d=UnitDefs[def];local x,y,z=S.Pos2BuildPos(def,pos[1],pos[2],pos[3],pos[4]);local status,feature=S.TestBuildOrder(def,x,y,z,pos[4])
 emit(event,'def='..def,'status='..status,'feature='..tostring(feature),'x='..x,'z='..z,'xsize='..d.xsize,'zsize='..d.zsize,'yard_identity_from_frozen_source=true')
 -- Different footprint parity is evidence, never silently shift the old centre.
 if math.abs(x-pos[1])>.01 or math.abs(z-pos[3])>.01 then return false,'centre_parity_changed' end
 return status==2 and not feature,'native_status_'..status
end
function gadget:UnitCreated(id,def,owner,builder)
 if phase~='building'or not task or def~=task.def then return end
 if owner~=team or builder~=units[task.owner]or task.birth then finish('FAIL non_unique_or_wrong_owner_paid_birth');return end
 if task.provision and task.metal then
  local x,_,z=S.GetUnitPosition(id);local pos=task.expectedSite;local api=GG.resource_spot_finder
  if not pos or not x or not z or math.abs(x-pos[1])>.01 or math.abs(z-pos[3])>.01 then finish('FAIL paid_income_mex_wrong_birth_site');return end
  local productive=false
  if api and api.isMetalMap then productive=(select(3,S.GetGroundInfo(x,z))or 0)>0
  elseif api and type(api.IsMexPositionValid)=='function'then
   for _,spot in ipairs(api.metalSpotsList or{})do if api.IsMexPositionValid(spot,x,z)then productive=true;break end end
  end
  if not productive then finish('FAIL paid_income_mex_unproductive_birth');return end
  emit('PAID_INCOME_SITE','id='..id,'x='..x,'z='..z,'productive_provider_verified=true')
 end
 task.birth=id;emit('BIRTH','id='..id,'def='..def,'builder='..builder,'progress='..tostring(select(5,S.GetUnitHealth(id))))
end
function gadget:UnitDestroyed(id)
 if task and task.cancel and id==task.birth then task.destroyed=true;task.destroyedFrame=S.GetGameFrame();emit('CANCEL_DESTROYED','partial='..id,'frame='..task.destroyedFrame)end
 if task and task.old and id==task.old then task.oldDestroyed=true end
end
function gadget:UnitFinished(id,def,owner)
 if phase~='building'or not task or not task.upgrade or task.birth~=id then return end
 local observer=GG.Recoil40KExtractorRefundProbe;local row=observer and observer.Read(id)
 if not row or row.frame~=S.GetGameFrame()or row.old~=task.old or row.team~=team or row.oldTeam~=team or type(row.multiplier)~='number'then
  finish('INCONCLUSIVE missing_or_mismatched_same_callback_refund_observer');return
 end
 local after=S.GetTeamResources(team,'metal');local expected=math.min(row.definitionMetal*row.multiplier,math.max(0,row.storage-row.metal))
 local actual=after-row.metal
 emit('REFUND_CALLBACK','old='..row.old,'owner='..owner,'before='..row.metal,'after='..after,'delta='..actual,'expected_storage_clamped='..expected,'income_multiplier='..row.multiplier)
 if math.abs(actual-expected)>.01 then finish('INCONCLUSIVE unexpected_same_callback_budget_delta');return end
 task.refundObserved=true;observer.Forget(id)
end
function gadget:GameFrame(frame)
 if phase=='done'or frame<1 then return end
 started=started or frame
 if frame-started>3600*(Game.gameSpeed or 30)then finish('INCONCLUSIVE ordinary_economic_or_native_queue_timeout');return end
 if phase=='initial'then
  if not enabled(options.prototype_extractor_fixed_tier_pilot)then finish('INCONCLUSIVE fixed_tier_pilot_not_enabled');return end
  for _,key in ipairs({'prototype_squad_paid_fixture','prototype_squad_fixture','prototype_squad_paid_research_fixture'})do
   if enabled(options[key])then finish('INCONCLUSIVE conflicting_owned_fixture_'..key);return end
  end
  if not route then finish('INCONCLUSIVE unknown_faction');return end
  for _,key in ipairs(route)do if not UnitDefNames[key]then finish('INCONCLUSIVE missing_route_'..key);return end end
  if not incomePower or not UnitDefNames[incomePower]then finish('INCONCLUSIVE missing_ordinary_income_power');return end
  local base=UnitDefNames[route[6]].id
  for tier=1,3 do local key=route[6]..(tier==1 and''or'_t'..tier);local d=UnitDefNames[key]and UnitDefs[UnitDefNames[key].id]
   if not d or tonumber(d.customParams.listening_post_version)~=2 or tonumber(d.customParams.extractor_tier)~=tier then finish('INCONCLUSIVE fixed_candidate_not_active_'..key);return end
  end
  if options.prototype_extractor_paid_faction=='ork'then
   local facts,reason=VFS.Include('40k_configs/ork_extractor_fixture_contract.lua').Check(UnitDefs,UnitDefNames,WeaponDefs)
   if not facts then finish('INCONCLUSIVE ork_family_preflight_'..tostring(reason));return end
   for _,row in ipairs(facts)do emit('ORK_SOURCE_STAGE','key='..row.key,'tier='..row.tier,'stage='..row.stage,'weapon='..row.weapon,
    'metal='..row.metal,'energy='..row.energy,'work='..row.work,'extractsmetal='..row.yield,'muzzle='..tostring(row.muzzle),'fireclip='..tostring(row.fireclip),'definition_only_not_weapon_combat=true')end
  end
  local all=S.GetTeamUnits(team)or{};local m,e=resources('INITIAL')
  if #all~=1 or S.GetUnitDefID(all[1])~=UnitDefNames[route[1]].id or not complete(all[1])or not m or math.abs(m-1000)>5 or math.abs(e-1000)>5 then finish('INCONCLUSIVE need_ordinary_natural_commander_1000_start');return end
  units.commander=all[1]
  tasks={{key=route[6],owner='commander',role='mex',metal=true},
   -- Ordinary paid income, built by the actual commander. Primary test site stays fixed.
   {key=incomePower,owner='commander',role='incomePower1',provision=true},
   {key=incomePower,owner='commander',role='incomePower2',provision=true},
   {key=route[6],owner='commander',role='incomeMex1',metal=true,provision=true},
   {key=route[6],owner='commander',role='incomeMex2',metal=true,provision=true},
   {key=route[2],owner='commander',role='lab'},{key=route[3],owner='lab',role='basic',product=true},
   {key=route[4],owner='basic',role='advancedlab'},{key=route[5],owner='advancedlab',role='advanced',product=true},
   {key=route[6]..'_t2',owner='advanced',role='mex',upgrade=true},
   {key=route[6]..'_t3',owner='advanced',role='cancelled',upgrade=true,cancel=true},
   {key=route[6]..'_t3',owner='advanced',role='mex',upgrade=true}}
  emit('ROUTE','natural_commander='..all[1],'base='..base,'no_spawns_grants_speed_changes=true','ally_capture_and_stock_paid_actor_control_pending=true')
  phase='next'
 elseif phase=='next'then
  task=tasks[step];if not task then finish('PASS ordinary_paid_t1_t2_t3_unique_replacement_partial_cancel_same_callback_refund');return end
  local actor=units[task.owner];task.def=UnitDefNames[task.key].id
  if not complete(actor)or S.GetUnitTeam(actor)~=team then finish('FAIL constructor_lost');return end
  if not contains(UnitDefs[S.GetUnitDefID(actor)].buildOptions,task.def)then finish('INCONCLUSIVE current_native_menu_'..task.key);return end
  if task.product and not UnitDefs[S.GetUnitDefID(actor)].isFactory then finish('INCONCLUSIVE advanced_factory_classification');return end
  local pos={}
  if not task.product then
   if task.upgrade then
    task.old=units.mex;task.oldDef=S.GetUnitDefID(task.old);task.oldMetal=UnitDefs[task.oldDef].metalCost
    local ok,reason=probe(task.def,site,'UPGRADE_PLACEMENT')
    if not ok then finish('INCONCLUSIVE unchanged_yard_'..reason);return end
    pos=site
   else pos=choose(task.def,actor,task.metal);if not pos then finish('INCONCLUSIVE no_legal_'..(task.metal and'productive_metal_'or'')..task.key);return end end
  end
  if task.metal and not task.provision then site=pos;local ok=probe(UnitDefNames[route[7]].id,pos,'STOCK_REFERENCE_EMPTY_TEST');emit('STOCK_REFERENCE','placement_only='..tostring(ok),'no_paid_stock_menu_or_spawn_claim=true')end
  task.expectedSite=pos
  phase='building';resources('ORDER');local result=S.GiveOrderToUnit(actor,-task.def,pos,0)
  task.orderProbe=orderProbe.New(S,UnitDefs,actor,task.def,pos,frame,result)
  emit('ORDER','key='..task.key,'native_metal='..UnitDefs[task.def].metalCost,'native_energy='..UnitDefs[task.def].energyCost,'native_work='..UnitDefs[task.def].buildTime)
 elseif phase=='cancel_settle'then
  -- UnitDestroyed precedes actual native deletion/UnBlock. Observe, never force it.
  if not complete(task.old)or S.GetUnitTeam(task.old)~=team then finish('FAIL cancellation_lost_predecessor_during_settle');return end
  local elapsed=frame-task.settleStart;local d=UnitDefs[task.def]
  local x,y,z=S.Pos2BuildPos(task.def,site[1],site[2],site[3],site[4])
  if math.abs(x-site[1])>.01 or math.abs(z-site[3])>.01 then finish('INCONCLUSIVE cancellation_retry_centre_parity_changed');return end
  local status,feature=S.TestBuildOrder(task.def,x,y,z,site[4]);local valid=S.ValidUnitID(task.birth)
  local removed=valid==false;local ready=removed and status==2 and not feature
  if elapsed==0 or elapsed==1 or elapsed==2 or elapsed==3 or elapsed==5 or elapsed==10 or elapsed==30 or elapsed==60 or elapsed==90 or ready then
   local dead=S.GetUnitIsDead(task.birth);local blocking
   if type(S.GetUnitBlocking)=='function'then blocking=S.GetUnitBlocking(task.birth)end
   local kind,blocker
   if type(S.GetGroundBlocked)=='function'then kind,blocker=S.GetGroundBlocked(x-d.xsize*4,z-d.zsize*4,x+d.xsize*4-8,z+d.zsize*4-8)end
   emit('CANCEL_SETTLE','frame='..frame,'elapsed='..elapsed,'destroyed_frame='..tostring(task.destroyedFrame),'partial='..task.birth,
    'partial_valid='..tostring(valid),'partial_dead='..tostring(dead),'partial_blocking='..tostring(blocking),
    'ground_blocker_kind='..tostring(kind),'ground_blocker_id='..tostring(blocker),'status='..tostring(status),'feature='..tostring(feature),
    'predecessor='..task.old,'predecessor_owner='..S.GetUnitTeam(task.old),'predecessor_complete=true','removed='..tostring(removed),'ready='..tostring(ready))
  end
  if ready then emit('CANCEL_SETTLED','partial='..task.birth,'predecessor='..task.old,'elapsed='..elapsed,'actual_native_removed=true','unchanged_status_2=true');step=step+1;phase='next'
  elseif elapsed>=90 then finish('INCONCLUSIVE cancellation_retry_did_not_settle_status_'..tostring(status)..'_valid_'..tostring(valid));return end
 elseif phase=='building'then
  if task.orderProbe then local row,expired=task.orderProbe.Observe(frame,task.birth);if row then reportOrder(row)end
   if expired then finish('INCONCLUSIVE native_no_birth_timeout_step_'..step);return end end
  if task.birth and task.cancel and not task.cancelling then
   local _,_,_,_,p=S.GetUnitHealth(task.birth)
   if p and p>=.05 and p<1 then
    task.cancelling=true;S.GiveOrderToUnit(units.advanced,CMD.STOP,{},0);S.GiveOrderToUnit(units.advanced,CMD.RECLAIM,{task.birth},0)
    emit('CANCEL','partial_id='..task.birth,'progress='..p,'native_stop_and_reclaim=true')
   elseif p==1 then finish('INCONCLUSIVE missed_partial_cancel_window');return end
  elseif task.cancel and task.cancelling then
   if task.destroyed then
    if not complete(task.old)or S.GetUnitTeam(task.old)~=team then finish('FAIL cancellation_lost_predecessor');return end
    emit('CANCEL_COMPLETE','predecessor='..task.old,'partial='..task.birth,'stock_selectability_unsynced_pending=true');task.settleStart=frame;phase='cancel_settle'
   end
  elseif task.birth and complete(task.birth)then
   if S.GetUnitTeam(task.birth)~=team then finish('FAIL completed_wrong_owner');return end
   if task.upgrade and(not task.oldDestroyed or(S.ValidUnitID(task.old)and not S.GetUnitIsDead(task.old)))then finish('FAIL replacement_predecessor_not_removed');return end
   if task.upgrade and not task.refundObserved then finish('INCONCLUSIVE no_native_same_callback_refund');return end
   units[task.role]=task.birth;resources('COMPLETED');emit('COMPLETED','id='..task.birth,'old='..tostring(task.old),'expected_stock_refund='..tostring(task.oldMetal),'same_callback_refund_observed='..tostring(task.refundObserved))
   if task.metal and not task.provision then
    local ok,reason=probe(UnitDefNames[route[6]..'_t2'].id,site,'UNCHANGED_CURRENT_T2_TEST')
    probe(UnitDefNames[route[7]].id,site,'STOCK_REFERENCE_OCCUPIED_TEST')
    if not ok then finish('INCONCLUSIVE unchanged_yard_'..reason..'_after_real_paid_t1');return end
   end
   step=step+1;phase='next'
  end
 end
 if frame%300==0 then emit('STATE','phase='..phase,'step='..step,'frame='..frame);resources('PERIODIC')end
end

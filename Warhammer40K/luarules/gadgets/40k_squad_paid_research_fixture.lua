function gadget:GetInfo()return{name='40K ordinary paid Marine specialist research fixture',desc='Default-off native economy, research and preserved real slot roles',author='Local project',layer=151,enabled=true}end
local options=Spring.GetModOptions()or{}
local enabled=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled
if not enabled(options.prototype_squad_paid_research_fixture)then return false end
if not gadgetHandler:IsSyncedCode()then
 local closeAt
 local function done(_,result)Spring.Echo('40K_SQUAD_PAID_RESEARCH owned_fixture_autoclose '..tostring(result));closeAt=Spring.GetGameFrame()+90 end
 function gadget:Initialize()gadgetHandler:AddSyncAction('fortyk_squad_paid_research_done',done)end
 function gadget:GameFrame(frame)if closeAt and frame>=closeAt then closeAt=nil;Spring.SendCommands('quitforce')end end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction('fortyk_squad_paid_research_done')end
 return
end
local S=Spring;local team=0;local phase='initial';local start;local mark;local timeout=1800*Game.gameSpeed
local commander,factory,armoury,firstProduct,futureProduct,seed,profile,record
local oldSpecial,missingOrdinary,heavyKilled,saved,missingInvestment,specialInvestment,replacementSpecialCost
local departure,departureAt
local born={};local finished={};local jobObserved=false;local paid={steps=0,metal=0,energy=0};local healObserved=false;local lateProbe=false
local function emit(event,...)
 local a={...};for i=1,#a do a[i]=tostring(a[i])end;S.Echo('40K_SQUAD_PAID_RESEARCH '..event..' '..table.concat(a,' '))
end
local function resources(event)
 local m,_,_,mi,me=S.GetTeamResources(team,'metal');local e,_,_,ei,ee=S.GetTeamResources(team,'energy')
 emit(event,'metal='..tostring(m),'energy='..tostring(e),'metal_income='..tostring(mi),'energy_income='..tostring(ei),
  'metal_expense='..tostring(me),'energy_expense='..tostring(ee),'net_delta_is_not_exact_bill=true');return m,e
end
local function finish(reason)
 if phase=='done'then return end;phase='done';resources('FINAL_RESOURCES')
 emit('COMPLETE',reason,'ordinary_resources=true scripted_state_probe_only=true weapon_combat_acceptance=false hud_click_acceptance=false')
 SendToUnsynced('fortyk_squad_paid_research_done',reason)
end
local function fail(reason)finish('FAIL '..reason)end
local function live(id)
 if not id or S.GetUnitIsDead(id)then return false end
 local h,_,_,_,p=S.GetUnitHealth(id);return h and h>0 and p and p>=1 and S.GetUnitTeam(id)==team
end
local function contains(a,id)for _,v in ipairs(a or{})do if v==id then return true end end;return false end
local function near(a,b)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<.001 end
local function copyCost(c)return{metal=c.metal,energy=c.energy,work=c.work}end
local function bill(id,c)
 local work,m,e=S.GetUnitCosts(id)
 return near(work,c.work)and near(m,c.metal)and near(e,c.energy)
end
local function receipt(a,b)return a and near(a.metal,b.metal)and near(a.energy,b.energy)and near(a.work,b.work)end
local function count(s)local n=0;for _ in pairs(s.slots)do n=n+1 end;return n end
local function current()return GG.Recoil40KSquads and GG.Recoil40KSquads.squads[seed]end
local function role(id,name)return live(id)and S.GetUnitDefID(id)==UnitDefNames[name].id end
local function probeTrace(event,frame)
 local s=current();local active=s and s.slots[4];local function body(prefix,id)
  local def=id and S.GetUnitDefID(id);local d=def and UnitDefs[def];local h,m
  if id then h,m=S.GetUnitHealth(id)end
  return prefix..'_id='..tostring(id)..' '..prefix..'_def='..tostring(def)..' '..prefix..'_hp='..tostring(h)..' '..prefix..'_max='..tostring(m)
   ..' '..prefix..'_xp='..tostring(id and S.GetUnitExperience(id))..' '..prefix..'_autoHeal='..tostring(d and d.autoHeal)
   ..' '..prefix..'_idleAutoHeal='..tostring(d and d.idleAutoHeal)..' '..prefix..'_idleTime='..tostring(d and d.idleTime)
 end
 local q=S.GetUnitCommands(commander,3)or{};local head=q[1];local args={}
 local building=S.GetUnitIsBuilding(commander)
 for _,v in ipairs(head and head.params or{})do args[#args+1]=tostring(v)end
 local cx,_,cz=S.GetUnitPosition(commander);local x,z
 if active then local px,py,pz=S.GetUnitPosition(active);x,z=px,pz end
 local distance=cx and cz and x and z and math.sqrt((cx-x)^2+(cz-z)^2)
 local commanderDef=S.GetUnitDefID(commander);local cd=commanderDef and UnitDefs[commanderDef]
 emit(event,'frame='..frame,'paid_steps='..paid.steps,body('old',oldSpecial),body('slot4',active),
  'saved_fraction='..tostring(saved and saved.fraction),'commander='..tostring(commander),'commander_def='..tostring(commanderDef),
  'commander_building='..tostring(building),'commander_queue_sample_count='..#q,
  'commander_head='..tostring(head and head.id),'commander_tag='..tostring(head and head.tag),'commander_params='..table.concat(args,','),
  'commander_distance='..tostring(distance),'commander_buildDistance='..tostring(cd and cd.buildDistance),'native_healing_and_builder_mechanics_unchanged=true')
end
local function healthy(s)for _,id in pairs(s.slots)do local h,m=S.GetUnitHealth(id);if not h or h<m-.01 then return false end end;return true end
local function clear(def,x,z)
 local d=UnitDefs[def];local hx,hz=d.xsize*4,d.zsize*4
 if x-hx<64 or z-hz<64 or x+hx>Game.mapSizeX-64 or z+hz>Game.mapSizeZ-64 then return false end
 for _,id in ipairs(S.GetUnitsInRectangle(x-hx-32,z-hz-32,x+hx+32,z+hz+32)or{})do
  if id~=commander then return false end
  local cx,_,cz=S.GetUnitPosition(id);local cd=UnitDefs[S.GetUnitDefID(id)]
  if math.abs(cx-x)<hx+cd.xsize*4+8 and math.abs(cz-z)<hz+cd.zsize*4+8 then return false end
 end
 return #(S.GetFeaturesInRectangle(x-hx-16,z-hz-16,x+hx+16,z+hz+16)or{})==0
end
local function exits(def,x,z)
 local fd=UnitDefs[def];local pd=UnitDefs[UnitDefNames.imp_marine.id]
 local radius=math.max(fd.xsize,fd.zsize)*4+math.max(pd.xsize,pd.zsize)*4+32;local n=0
 for j=0,15 do local a=j*math.pi/8;local ex,ez=x+radius*math.cos(a),z+radius*math.sin(a);local ey=S.GetGroundHeight(ex,ez)
  if ex>32 and ez>32 and ex<Game.mapSizeX-32 and ez<Game.mapSizeZ-32 and ey>=0
   and S.TestMoveOrder(pd.id,ex,ey,ez,0,0,0,true,true,false)then n=n+1 end
 end;return n>=4
end
local function site(def,isFactory)
 local cx,_,cz=S.GetUnitPosition(commander)
 for ring=6,30 do for j=0,15 do local a=j*math.pi/8
  local x,y,z=S.Pos2BuildPos(def,cx+ring*32*math.cos(a),0,cz+ring*32*math.sin(a),0);y=S.GetGroundHeight(x,z)
  local status,feature=S.TestBuildOrder(def,x,y,z,0)
  if y>=0 and status==2 and not feature and clear(def,x,z)and(not isFactory or exits(def,x,z))then return{x,y,z,0}end
 end end
end
local function outsideSquadRepair(s,x,z)
 local d=UnitDefs[S.GetUnitDefID(commander)];local range=d and d.buildDistance
 if type(range)~='number'or range<=0 then return false end
 for _,id in pairs(s.slots)do
  local px,_,pz=S.GetUnitPosition(id);local body=UnitDefs[S.GetUnitDefID(id)]
  local margin=range+math.max(body.xsize,body.zsize)*4+128
  if not px or (px-x)^2+(pz-z)^2<=margin^2 then return false end
 end
 return true
end
local function depart(frame)
 local s=current();local def=S.GetUnitDefID(commander);local cx,_,cz=S.GetUnitPosition(commander)
 local stopped=S.GiveOrderToUnit(commander,CMD.STOP,{},0)
 if stopped==false then finish('INCONCLUSIVE native_builder_departure_stop_rejected');return end
 for ring=6,40 do for j=0,15 do local a=j*math.pi/8;local x,z=cx+ring*32*math.cos(a),cz+ring*32*math.sin(a);local y=S.GetGroundHeight(x,z)
  if x>64 and z>64 and x<Game.mapSizeX-64 and z<Game.mapSizeZ-64 and y>=0 and outsideSquadRepair(s,x,z)
   and clear(def,x,z)and S.TestMoveOrder(def,x,y,z,0,0,0,true,true,false)then
   departure={x,y,z};departureAt=frame;phase='builder_departure'
   local accepted=S.GiveOrderToUnit(commander,CMD.MOVE,departure,0)
   emit('BUILDER_DEPARTURE','native_move=true no_teleport=true','x='..x,'z='..z,'return='..tostring(accepted))
   if accepted==false then finish('INCONCLUSIVE native_builder_departure_order_rejected')end
   return
  end
 end end
 finish('INCONCLUSIVE no_legal_builder_departure_site')
end
local function construct(name,nextPhase)
 local d=UnitDefNames[name];local c=GG.Recoil40KResearch
 if not contains(UnitDefs[S.GetUnitDefID(commander)].buildOptions,d.id)or not c.CanBuild(team,d.id,commander,false)then fail('unreachable_paid_build '..name);return end
 local p=site(d.id,UnitDefs[d.id].isFactory);if not p then finish('INCONCLUSIVE no_native_clear_site '..name);return end
 phase=nextPhase;resources('BUILD_ORDER_RESOURCES')
 local ok=S.GiveOrderToUnit(commander,-d.id,p,0)
 emit('BUILD_ORDER','name='..name,'native_command=true native_approach=true','return='..tostring(ok))
 if ok==false then finish('INCONCLUSIVE native_build_order_rejected '..name)end
end
local function queue(future)
 local d=UnitDefNames.imp_marine;local c=GG.Recoil40KResearch
 if not c.CanBuild(team,d.id,factory,false)then finish('INCONCLUSIVE paid_product_gate');return end
 phase=future and'future_product'or'first_product';resources('PRODUCT_ORDER_RESOURCES')
 local ok=S.GiveOrderToUnit(factory,-d.id,{},0)
 emit('PRODUCT_ORDER','cohort='..(future and'future'or'current'),'full_metal='..UnitDefs[d.id].metalCost,'full_energy='..UnitDefs[d.id].energyCost,'full_work='..UnitDefs[d.id].buildTime)
 if ok==false then finish('INCONCLUSIVE native_product_order_rejected')end
end
function gadget:UnitCreated(id,def,owner,builder)
 if owner~=team then return end
 local name=UnitDefs[def].name
 if phase=='build_factory'and name=='imp_marine_barracks'or phase=='build_armoury'and name=='imp_marine_armoury'then
  if builder~=commander or born[name]then fail('not_single_native_commander_build '..name);return end
  local _,_,_,_,p=S.GetUnitHealth(id);if not p or p>=1 then fail('structure_not_native_incomplete '..name);return end
  born[name]=id;emit('STRUCTURE_BIRTH','name='..name,'builder='..builder,'progress='..p)
 elseif name=='imp_marine'and(phase=='first_product'or phase=='future_product')then
  if builder~=factory or(phase=='first_product'and firstProduct)or(phase=='future_product'and futureProduct)then fail('not_single_native_factory_product');return end
  if phase=='first_product'then firstProduct=id else futureProduct=id end
  emit('PRODUCT_BIRTH','id='..id,'builder='..builder,'cohort_phase='..phase)
 end
end
function gadget:UnitFinished(id)finished[id]=true end
function gadget:GameFrame(frame)
 if phase=='done'then return end;if not start then start=frame end
 if frame-start>timeout then finish('INCONCLUSIVE timeout ordinary_economic_or_native_gate phase='..phase);return end
 if phase=='initial'then
  for _,key in ipairs({'prototype_squad_fixture','prototype_squad_paid_fixture','prototype_squad_egress_fixture','prototype_corpse_blast_fixture'})do if enabled(options[key])then fail('conflicting_fixture '..key);return end end
  for _,key in ipairs({'smcom','imp_marine_barracks','imp_marine_armoury','imp_marine','imp_marine_member','imp_marine_heavy_member'})do if not UnitDefNames[key]then fail('missing_definition '..key);return end end
  local R,C=GG.Recoil40KSquads,GG.Recoil40KResearch
  if not R or not C or next(R.squads)then fail('missing_or_preexisting_controller_squads');return end
  profile=VFS.Include('40k_configs/active_squad_profiles.lua').profiles.marine_tactical
  local special=UnitDefs[UnitDefNames[profile.special].id]
  replacementSpecialCost={metal=special.metalCost,energy=special.energyCost,work=special.buildTime}
  record=C.records[profile.research]
  if profile.capacity~=4 or profile.specialSlot~=4 or not record or record.producer~='imp_marine_armoury'
   or record.row.cost.metal~=350 or record.row.cost.energy~=1500 or record.row.time~=50 or record.frames~=50*Game.gameSpeed then fail('wrong_genuine_research_contract');return end
  local units=S.GetTeamUnits(team)or{};if #units~=1 or not role(units[1],'smcom')then fail('need_natural_single_smcom');return end;commander=units[1]
  local m,e=resources('INITIAL_RESOURCES');if not near(m,1000)and math.abs((m or 0)-1000)>5 or not near(e,1000)and math.abs((e or 0)-1000)>5 then fail('not_ordinary_start');return end
  local pd,md=UnitDefs[UnitDefNames.imp_marine.id],UnitDefs[UnitDefNames[profile.member].id]
  if not UnitDefs[UnitDefNames.imp_marine_barracks.id].isFactory
   or not contains(UnitDefs[UnitDefNames.imp_marine_barracks.id].buildOptions,pd.id)
   or not near(pd.metalCost,md.metalCost*4)or not near(pd.energyCost,md.energyCost*4)or not near(pd.buildTime,md.buildTime*4)then fail('wrong_native_full_price_product');return end
  if C.HasResearch(team,profile.research)then fail('research_pregranted');return end
  emit('CONTRACT','ordinary_start=1000/1000 cohorts=2 no_spawns_or_grants=true','scale_pilot='..tostring(options.prototype_scale085_pilot))
  construct('imp_marine_barracks','build_factory')
 elseif phase=='build_factory'then
  local id=born.imp_marine_barracks;if id and live(id)and finished[id]then factory=id;queue(false)end
 elseif phase=='first_product'then
  local s=firstProduct and GG.Recoil40KSquads.Get(firstProduct)
  if s then
   if s.profile~='marine_tactical'or count(s)~=4 then fail('not_full_current_cohort');return end
   seed=s.id;oldSpecial=s.slots[4];missingOrdinary=s.slots[2]
   if not role(oldSpecial,profile.member)then fail('unresearched_special_not_ordinary');return end
   missingInvestment=copyCost(s.investments[2]);specialInvestment=copyCost(s.investments[4])
   for slot,id in pairs(s.slots)do if not bill(id,s.investments[slot])then fail('current_native_body_bill');return end end
   S.GiveOrderToUnit(s.leader,CMD.STOP,{},0);S.GiveOrderToUnit(s.leader,CMD.FIRE_STATE,{0},0);S.GiveOrderToUnit(s.leader,CMD.MOVE_STATE,{0},0)
   mark=frame;phase='delivery_checkpoint';emit('DELIVERY','cohort=current members=4 native_product=true native_capture_grace=30')
  end
 elseif phase=='delivery_checkpoint'and frame-mark>=30 then construct('imp_marine_armoury','build_armoury')
 elseif phase=='build_armoury'then
  local id=born.imp_marine_armoury;if id and live(id)and finished[id]then
   armoury=id;local s=current();if not s or count(s)~=4 or not live(oldSpecial)then fail('current_cohort_lost');return end
   depart(frame)
  end
 elseif phase=='builder_departure'then
  local s=current();local x,_,z=S.GetUnitPosition(commander);local queue=S.GetUnitCommands(commander,1)or{};local building=S.GetUnitIsBuilding(commander)
  if frame-departureAt>120*Game.gameSpeed then finish('INCONCLUSIVE native_builder_departure_stalled');return end
  if not s or not x then fail('builder_departure_cohort_lost');return end
  if queue[1]and queue[1].id~=CMD.MOVE then finish('INCONCLUSIVE native_builder_departure_interrupted');return end
  if not queue[1]and not building and (x-departure[1])^2+(z-departure[3])^2<=32^2 and outsideSquadRepair(s,x,z)then
   S.GiveOrderToUnit(commander,CMD.STOP,{},0)
   emit('BUILDER_DEPARTURE_COMPLETE','native_arrival=true all_survivors_outside_repair_range_plus128=true','x='..x,'z='..z)
   S.SetUnitExperience(oldSpecial,.7);mark=frame;phase='experience_settle'
   emit('STATE_PROBE','fixture_only_XP=.7 weapon_combat_acceptance=false')
  end
 elseif phase=='experience_settle'and frame-mark>=15 then
  local _,max=S.GetUnitHealth(oldSpecial);S.SetUnitHealth(oldSpecial,{health=max*.62});mark=frame;phase='wound_settle'
  emit('STATE_PROBE','fixture_only_wound_fraction=.62 no_builder_repair=true native_idle_healing_unchanged=true')
 elseif phase=='wound_settle'and frame-mark>=15 then
  local h,m=S.GetUnitHealth(oldSpecial);local states=S.GetUnitStates(oldSpecial)
  saved={fraction=h/m,xp=S.GetUnitExperience(oldSpecial),heading=S.GetUnitHeading(oldSpecial),fire=states.firestate,move=states.movestate}
  local hp=S.GetUnitHealth(missingOrdinary);phase='casualty_before_research';S.AddUnitDamage(missingOrdinary,hp*4+10000,0,nil,-1)
  emit('MISSING_SLOT_PROBE','slot=2 scripted_native_damage=true no_free_research_reinforcement_expected=true')
 elseif phase=='casualty_before_research'then
  local s=current();if not s or count(s)~=3 or s.slots[2]or live(missingOrdinary)then fail('scripted_missing_slot_not_three_survivors');return end
  local found=false;for _,d in ipairs(S.GetUnitCmdDescs(armoury)or{})do if d.id==record.cmd and not d.disabled then found=true end end
  if not found then finish('INCONCLUSIVE actual_research_descriptor_unavailable');return end
  phase='research';resources('RESEARCH_ORDER_RESOURCES')
  local ok=S.GiveOrderToUnit(armoury,record.cmd,{},0)
  emit('RESEARCH_ORDER','native_cmd='..record.cmd,'metal=350 energy=1500 native_seconds=50','return='..tostring(ok))
  if ok==false then finish('INCONCLUSIVE native_research_order_rejected')end
 elseif phase=='research'then
  local C=GG.Recoil40KResearch;local s=current();if not s or s.slots[2]or count(s)~=3 then fail('research_free_missing_slot_birth');return end
  local job=C.jobs[armoury]and C.jobs[armoury][profile.research]
  if job then
   if job.team~=team or job.cmd~=record.cmd or job.steps<paid.steps or job.metal<paid.metal or job.energy<paid.energy
    or not near(job.metal,350*job.steps/record.frames)or not near(job.energy,1500*job.steps/record.frames)then fail('actual_research_payment_receipt');return end
   jobObserved=jobObserved or job.steps>0;paid={steps=job.steps,metal=job.metal,energy=job.energy}
   if job.steps>=record.frames-30 and not lateProbe and role(oldSpecial,profile.member)then
    probeTrace('PROBE_BEFORE_REFRESH',frame)
    lateProbe=true;S.AddUnitDamage(oldSpecial,1,0,nil,-1) -- Reset native idle healing timer.
    local _,max=S.GetUnitHealth(oldSpecial);S.SetUnitHealth(oldSpecial,{health=max*.62})
    probeTrace('PROBE_AFTER_REFRESH',frame)
    emit('STATE_PROBE','final30_paid_steps=true bounded_fixture_wound_refresh=.62 native_damage_idle_timer_reset=true weapon_combat_acceptance=false')
   end
  end
  if lateProbe and role(oldSpecial,profile.member)then
   local h,m=S.GetUnitHealth(oldSpecial);local states=S.GetUnitStates(oldSpecial)
   saved={fraction=h/m,xp=S.GetUnitExperience(oldSpecial),heading=S.GetUnitHeading(oldSpecial),fire=states.firestate,move=states.movestate}
  end
  if lateProbe and frame%15==0 then probeTrace('PROBE_NATIVE_STATE',frame)end
  if C.HasResearch(team,profile.research)then
   probeTrace('PROBE_RESEARCH_COMPLETE',frame)
   if not jobObserved or paid.steps<record.frames-2 or S.GetTeamRulesParam(team,'40k_research_'..profile.research)~=1 then fail('completion_without_observed_native_paid_job');return end
   local new=s.slots[4]
   if role(new,profile.special)then
    if not lateProbe or saved.fraction>=.999 then finish('INCONCLUSIVE state_probe_healed_during_ordinary_research_stall');return end
    local h,m=S.GetUnitHealth(new);local states=S.GetUnitStates(new)
    if new==oldSpecial or live(oldSpecial)or math.abs(h/m-saved.fraction)>.003 or math.abs(S.GetUnitExperience(new)-saved.xp)>.003
     or math.abs((S.GetUnitHeading(new)-saved.heading+32768)%65536-32768)>1 or states.firestate~=saved.fire or states.movestate~=saved.move
     or not receipt(s.investments[4],specialInvestment)or not bill(new,specialInvestment)then fail('live_specialist_state_or_slot_bill_not_preserved');return end
    emit('RESEARCH_COMPLETE','actual_job_last_steps='..paid.steps,'actual_job_last_metal='..paid.metal,'actual_job_last_energy='..paid.energy,
     'registered_full_bill=350/1500 observed_native_completion=true missing_slot_still_empty=true','new_special='..new,'wound_fraction='..h/m,'xp='..S.GetUnitExperience(new))
    resources('HEAL_THEN_RESTORE_ORDER_RESOURCES');phase='heal_restore';S.GiveOrderToUnit(commander,CMD.REPAIR,{s.leader},0)
   end
  end
 elseif phase=='heal_restore'then
  local s=current();if not s then fail('heal_repair_cohort_lost');return end
  if healthy(s)and not healObserved then healObserved=true;emit('HEAL_CHECKPOINT','survivors_healthy=true healing_energy_separate_from_missing_slot_bill=true')end
  if s.slots[2]then
   local id=s.slots[2]
   if not healObserved or count(s)~=4 or id==missingOrdinary or not role(id,profile.member)
    or s.generations[2]~=2 or not receipt(s.investments[2],missingInvestment)or not bill(id,missingInvestment)then fail('paid_ordinary_restoration_receipt_or_heal_order');return end
   emit('ORDINARY_RESTORE','generation=2','metal='..s.investments[2].metal,'energy='..s.investments[2].energy,'work='..s.investments[2].work)
   S.GiveOrderToUnit(commander,CMD.STOP,{},0);heavyKilled=s.slots[4];local hp=S.GetUnitHealth(heavyKilled)
   phase='heavy_casualty';S.AddUnitDamage(heavyKilled,hp*4+10000,0,nil,-1)
  end
 elseif phase=='heavy_casualty'then
  local s=current();if not s or count(s)~=3 or s.slots[4]or live(heavyKilled)then fail('specialist_casualty_not_empty');return end
  phase='heavy_restore';resources('HEAVY_RESTORE_ORDER_RESOURCES');S.GiveOrderToUnit(commander,CMD.REPAIR,{s.leader},0)
 elseif phase=='heavy_restore'then
  local s=current();if not s then fail('specialist_repair_cohort_lost');return end
  if s.slots[4]then local id=s.slots[4]
   if count(s)~=4 or id==heavyKilled or not role(id,profile.special)or s.generations[4]~=2
    or not receipt(s.investments[4],replacementSpecialCost)or not bill(id,replacementSpecialCost)or math.abs(S.GetUnitExperience(id))>.003 then fail('paid_specialist_restoration_role_job_bill');return end
   emit('SPECIALIST_RESTORE','native_special_definition=true generation=2 fresh_XP=0 role_template_bill_at_job_start=true',
    'metal='..replacementSpecialCost.metal,'energy='..replacementSpecialCost.energy,'work='..replacementSpecialCost.work,
    'historical_live_research_investment_metal='..specialInvestment.metal)
   S.GiveOrderToUnit(commander,CMD.STOP,{},0);queue(true)
  end
 elseif phase=='future_product'then
  local s=futureProduct and GG.Recoil40KSquads.Get(futureProduct)
  if s then
   if s.id==seed or s.profile~='marine_tactical'or count(s)~=4 or not role(s.slots[4],profile.special)then fail('future_specialist_full_delivery');return end
   for slot,id in pairs(s.slots)do
    if not role(id,slot==4 and profile.special or(slot==1 and'imp_marine'or profile.member))then fail('future_slot_role');return end
    if s.generations[slot]~=1 or not receipt(s.investments[slot],specialInvestment)or not bill(id,s.investments[slot])then fail('future_full_price_slot_receipt');return end
   end
   emit('FUTURE_DELIVERY','members=4 exactly_one_specialist=true full_native_factory_price=true');finish('PASS ordinary_paid_research current_state_preserved no_free_missing_birth paid_normal_and_special_restore future_specialist')
  end
 end
 if frame%300==0 then emit('STATE','phase='..phase,'frame='..frame,'research_steps='..paid.steps,'research_metal='..paid.metal,'research_energy='..paid.energy);resources('PERIODIC_RESOURCES')end
end

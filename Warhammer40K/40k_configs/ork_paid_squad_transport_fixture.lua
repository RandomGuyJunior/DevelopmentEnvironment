-- Owned paid research follow-on. Real factory products and native cargo only.
local M={}
function M.New(c)
 local S,D,N,A=c.Spring,c.UnitDefs,c.UnitDefNames,c.Squads
 local T={phase='initial',started=c.frame,cycle=1,loaded={},unloaded={},products={},finished={},deliveries={}}
 function T.Step()return T.result end -- Constructor refusals remain safely pollable.
 local frame=c.frame;local squad=c.squad;local seed=squad.id;local bodies={};local total=0
 local function emit(e,...)c.Emit('TRANSPORT_'..e,...)end
 local function stop(why)T.result=T.result or why;return T.result end
 local function count(t)local n=0;for _ in pairs(t or{})do n=n+1 end;return n end
 local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
 local function valid(id)
  if not id or S.GetUnitIsDead(id)or S.GetUnitTeam(id)~=c.team then return false end
  local hp,_,_,_,p=S.GetUnitHealth(id);return hp and hp>0 and p==1
 end
 local required={'GetUnitIsDead','GetUnitTeam','GetUnitHealth','GetUnitDefID','GetUnitMass','GetUnitPosition',
  'GetUnitIsTransporting','GetUnitTransporter','GetUnitCosts','GetUnitExperience','GetUnitCommands','GetUnitRulesParam',
  'GiveOrderToUnit','GetGroundHeight','TestMoveOrder','GetGameFrame'}
 for _,name in ipairs(required)do if type(S[name])~='function'then stop('INCONCLUSIVE transport_api_missing '..name);return T end end
 if not A or not A.Get or not c.Transport or not c.Transport.Reserved or not c.Research or not c.Research.CanBuild
  or not c.Site or not c.Resources or squad.profile~='ork_shoota'or count(squad.slots)~=8 then stop('INCONCLUSIVE transport_dependencies');return T end
 for slot=1,8 do
  local id=squad.slots[slot];local mass=id and S.GetUnitMass(id)
  if not valid(id)or not finite(mass)or mass<=0 then stop('FAIL transport_full_paid_cohort');return T end
  bodies[slot]=id;total=total+mass
 end
 if math.abs(total-114)>.001 then stop('INCONCLUSIVE transport_current_eight_body_mass_not_114 actual='..total);return T end
 local function witness(stage,carrier)
  local nativeFrame=S.GetGameFrame();local current=A.squads[seed]
  emit('NATIVE_COHORT','stage='..stage,'cycle='..T.cycle,'frame='..nativeFrame,'seed='..seed,
   'leader='..tostring(current and current.leader),'profile='..tostring(current and current.profile),
   'team='..c.team,'fixed_capacity=8')
  for slot,id in ipairs(bodies)do
   local hp,max,_,_,progress=S.GetUnitHealth(id)
   local work,metal,energy=S.GetUnitCosts(id)
   emit('NATIVE_BODY','stage='..stage,'cycle='..T.cycle,'frame='..nativeFrame,'slot='..slot,'id='..id,
    'current_slot='..tostring(current and current.slots[slot]),'generation='..tostring(current and current.generations and current.generations[slot]),
    'def='..tostring(S.GetUnitDefID(id)),'team='..tostring(S.GetUnitTeam(id)),'dead='..tostring(S.GetUnitIsDead(id)),
    'hp='..tostring(hp),'max_hp='..tostring(max),'progress='..tostring(progress),'xp='..tostring(S.GetUnitExperience(id)),
    'work='..tostring(work),'metal='..tostring(metal),'energy='..tostring(energy),
    'transporter='..tostring(S.GetUnitTransporter(id)))
  end
  if carrier then
   local list=S.GetUnitIsTransporting(carrier);local ids={}
   if type(list)=='table'then for _,id in ipairs(list)do ids[#ids+1]=id end;table.sort(ids)end
   emit('NATIVE_CARGO','stage='..stage,'cycle='..T.cycle,'frame='..nativeFrame,'carrier='..carrier,
    'cargo='..(type(list)=='table'and(#ids==0 and'none'or table.concat(ids,','))or'unavailable'),
    'reserved='..tostring(not not c.Transport.Reserved(seed)))
  end
 end
 local function sameBodies()
  local current=A.squads[seed]
  if not current or current.profile~='ork_shoota'or count(current.slots)~=8 then return false end
  for slot,id in ipairs(bodies)do if current.slots[slot]~=id or not valid(id)then return false end end
  squad=current;return true
 end
 local function menu(builder,name)
  local def=N[name];local d=builder and D[S.GetUnitDefID(builder)]
  if not def or not d then return false end
  for _,id in ipairs(d.buildOptions or{})do if id==def.id then return c.Research.CanBuild(c.team,id,builder,false)end end
  return false
 end
 local function order(id,cmd,p)
  local ok=S.GiveOrderToUnit(id,cmd,p,0);emit('ORDER','frame='..frame,'unit='..id,'cmd='..cmd,'accepted='..tostring(ok))
  if ok==false then stop('INCONCLUSIVE transport_native_order_rejected')end
 end
 local function paid(builder,name,construction)
  if not menu(builder,name)then stop('INCONCLUSIVE transport_current_paid_menu_unreachable '..name);return end
  local def=N[name];local d=D[def.id]
  if not finite(d.metalCost)or d.metalCost<=0 or not finite(d.energyCost)or d.energyCost<=0 or not finite(d.buildTime)or d.buildTime<=0 then stop('FAIL transport_native_paid_cost_missing '..name);return end
  local p={};if construction then
   local productDef=name=='ork_mek_shop'and N.wh40k_corcv or N.ork_looted_rhino
   p=c.Site(builder,def.id,true,productDef and productDef.id)
   if not p then stop('INCONCLUSIVE transport_no_legal_factory_site '..name);return end
  end
  T.pending={name=name,builder=builder,def=def.id,factory=not construction};T.phase='paid_'..name
  c.Resources('TRANSPORT_PAID_ORDER_RESOURCES');emit('PAID_ORDER','name='..name,'builder='..builder,'metal='..d.metalCost,'energy='..d.energyCost,'work='..d.buildTime,'ordinary_resources=true')
  order(builder,-def.id,p)
 end
 function T.Created(id,def,team,builder)
  local p=T.pending;if T.result or not p or def~=p.def or team~=c.team then return end
  if builder~=p.builder or p.id then stop('FAIL transport_wrong_or_duplicate_native_product');return end
  local _,_,_,_,progress=S.GetUnitHealth(id)
  if not finite(progress)or progress>=1 then stop('FAIL transport_product_not_native_incomplete');return end
  p.id=id;emit('BIRTH','name='..p.name,'id='..id,'builder='..builder,'progress='..progress)
 end
 function T.Finished(id)if T.pending and T.pending.id==id then T.finished[id]=true;emit('UNIT_FINISHED','id='..id,'name='..T.pending.name,'frame='..S.GetGameFrame(),'def='..tostring(S.GetUnitDefID(id)),'team='..tostring(S.GetUnitTeam(id)))end end
 function T.FromFactory(id,def,team,producer)
  local p=T.pending;if not p or id~=p.id then return end
  if not p.factory or def~=p.def or team~=c.team or producer~=p.builder then stop('FAIL transport_wrong_factory_delivery_callback');return end
  T.deliveries[id]=true;emit('DELIVERY_CALLBACK','id='..id,'producer='..producer,'frame='..S.GetGameFrame())
 end
 local function product()
  local p=T.pending;if not p or not p.id or not T.finished[p.id]or not valid(p.id)or(p.factory and not T.deliveries[p.id])then return end
  local work,m,e=S.GetUnitCosts(p.id);local d=D[p.def]
  if not finite(work)or math.abs(work-d.buildTime)>.001 or not finite(m)or math.abs(m-d.metalCost)>.001 or not finite(e)or math.abs(e-d.energyCost)>.001 then stop('FAIL transport_actual_product_native_bill');return end
  T.products[p.name]=p.id;T.pending=nil;emit('PAID_DELIVERY','name='..p.name,'id='..p.id,'work='..work,'metal='..m,'energy='..e);return p.name,p.id
 end
 local function cargo(carrier)
  local list=S.GetUnitIsTransporting(carrier);if type(list)~='table'then stop('INCONCLUSIVE transport_native_cargo_unreadable');return end
  local set={};for _,id in ipairs(list)do if set[id]then stop('FAIL transport_duplicate_native_cargo');return end;set[id]=true end;return set,count(set)
 end
 local function mark(event,id,carrier,team,def)
  if T.result or carrier~=T.rhino then return end
  local slot;for i,body in ipairs(bodies)do if body==id then slot=i end end
  if not slot or team~=c.team or def~=S.GetUnitDefID(id)then stop('FAIL transport_callback_foreign_body');return end
  local book=event=='LOADED'and T.loaded or T.unloaded
  if book[id]then stop('FAIL transport_duplicate_'..event..'_callback');return end
  book[id]=true;local x,y,z=S.GetUnitPosition(id)
  if not finite(x)or not finite(y)or not finite(z)then stop('FAIL transport_callback_position_missing');return end
  emit(event,'cycle='..T.cycle,'frame='..S.GetGameFrame(),'id='..id,'slot='..slot,'carrier='..carrier,'position='..x..','..y..','..z)
 end
 function T.Loaded(id,def,team,carrier)mark('LOADED',id,carrier,team,def)end
 function T.Unloaded(id,def,team,carrier)mark('UNLOADED',id,carrier,team,def)end
 local function pickup()
  if not sameBodies()then stop('FAIL transport_paid_body_identity_changed');return end
  local set,n=cargo(T.rhino);if not set then return end
  if n~=0 or c.Transport.Reserved(seed)then stop('FAIL transport_pickup_stale_cargo_or_reservation');return end
  T.loaded={};T.unloaded={};T.phase='loading';T.stage=frame
  order(T.rhino,CMD.LOAD_UNITS,{squad.leader})
 end
 local function unloadSite()
  local x,_,z=S.GetUnitPosition(T.rhino);local def=S.GetUnitDefID(T.rhino)
  if not finite(x)or not finite(z)then return end
  for r=192,512,64 do for j=0,15 do local a=j*math.pi/8;local px,pz=x+r*math.cos(a),z+r*math.sin(a);local py=S.GetGroundHeight(px,pz)
   if finite(py)and py>=0 and px>128 and pz>128 and px<Game.mapSizeX-128 and pz<Game.mapSizeZ-128
    and S.TestMoveOrder(def,px,py,pz,0,0,0,true,true,false)then
    local okay=true
    for _,id in ipairs(bodies)do if not S.TestMoveOrder(S.GetUnitDefID(id),px,py,pz,0,0,0,true,true,false)then okay=false end end
    if okay then return{px,py,pz,128}end
   end
  end end
 end
 local function refused(label)
  local set,n=cargo(T.trukk);if not set then return end
  if n~=0 or c.Transport.Reserved(seed)then stop('FAIL transport_Trukk_partial_pickup_or_reservation '..label);return end
  for _,id in pairs(squad.slots)do if S.GetUnitTransporter(id)then stop('FAIL transport_Trukk_attached_body '..label);return end end
  local commands=S.GetUnitCommands(T.trukk,-1)
  if type(commands)~='table'then stop('INCONCLUSIVE transport_Trukk_queue_unreadable');return end
  for _,cmd in ipairs(commands)do if cmd.id==CMD.LOAD_UNITS or cmd.id==CMD.LOAD_ONTO then stop('FAIL transport_Trukk_rejected_order_still_queued');return end end
  emit('TRUKK_REFUSAL','probe='..label,'living='..count(squad.slots),'fixed_capacity=8 actual_native_cargo=0 reservation=false')
  return true
 end
 emit('BEGIN','seed='..seed,'members=8 actual_mass='..total,'ordinary_resources=true scripted_attach_drop_heal_teleport=false')
 witness('initial',nil)
 function T.Step(f)
  if T.result then return T.result end;frame=f
  if f-T.started>1800*Game.gameSpeed then return stop('INCONCLUSIVE transport_timeout phase='..T.phase)end
  if T.phase~='casualty_settle'and T.phase~='Trukk_six_refusal'and not sameBodies()then return stop('FAIL transport_cohort_lost_or_replaced')end
  if T.rhino and not valid(T.rhino)then return stop('FAIL transport_paid_Rhino_lost_or_transferred')end
  if T.phase=='initial'then paid(c.commander,'ork_mek_shop',true)
  elseif T.pending then
   local name,id=product();if T.result then return T.result end
   if name=='ork_mek_shop'then paid(id,'wh40k_corcv',false)
   elseif name=='wh40k_corcv'then paid(id,'ork_resource_factory',true)
   elseif name=='ork_resource_factory'then paid(id,'ork_looted_rhino',false)
   elseif name=='ork_looted_rhino'then
    T.rhino=id;local d=D[S.GetUnitDefID(id)];local cp=d.customParams or{}
    if cp.animsource~='ork_looted_rhino'or cp.source_transport_policy~='one_fixed8_hidden_real_bodies_v1'
     or tonumber(cp.source_transport_actor_capacity)~=8 or cp.prototype40k_transport_profile~='ork_shoota'
     or tonumber(cp.prototype40k_transport_squad_limit)~=1 or math.abs(d.transportMass-114)>.001 or d.releaseHeld~=false then return stop('FAIL transport_genuine_Rhino_contract')end
    pickup()
   elseif name=='ork_trukk'then
    T.trukk=id;local d=D[S.GetUnitDefID(id)];local cp=d.customParams or{}
    if cp.animsource~='ork_trukk'or(tonumber(cp.source_transport_actor_capacity)or d.transportCapacity)~=6 then return stop('FAIL transport_six_actor_Trukk_contract')end
    T.phase='Trukk_full_refusal';T.stage=f;order(id,CMD.LOAD_UNITS,{squad.leader})
   end
  elseif T.phase=='loading'then
   local set,n=cargo(T.rhino);if not set then return T.result end
   if n>8 then return stop('FAIL transport_Rhino_foreign_native_cargo')end
   for id in pairs(set)do local known=false;for _,body in ipairs(bodies)do if id==body then known=true end end;if not known then return stop('FAIL transport_Rhino_foreign_body')end end
   if n==8 then
    for _,id in ipairs(bodies)do if not T.loaded[id]or S.GetUnitTransporter(id)~=T.rhino then return stop('FAIL transport_native_loaded_callbacks_missing')end end
    if not c.Transport.Reserved(seed)then return stop('FAIL transport_full_cargo_reservation_missing')end
    witness('loaded',T.rhino)
    local p=unloadSite();if not p then return stop('INCONCLUSIVE transport_no_legal_native_unload_site')end
    T.unload=p;T.phase='unloading';T.stage=f;order(T.rhino,CMD.UNLOAD_UNITS,p)
   end
  elseif T.phase=='unloading'then
   local set,n=cargo(T.rhino);if not set then return T.result end
   if n==0 and not c.Transport.Reserved(seed)then
    for _,id in ipairs(bodies)do
     local x,y,z=S.GetUnitPosition(id)
     if not T.unloaded[id]or S.GetUnitTransporter(id)or not finite(x)or not finite(y)or not finite(z)then return stop('FAIL transport_native_unloaded_callbacks_missing')end
     if (x-T.unload[1])^2+(z-T.unload[3])^2>256^2 then return stop('FAIL transport_native_unload_positions_outside_bounded_site')end
    end
    witness('unloaded',T.rhino)
    emit('CYCLE_PASS','cycle='..T.cycle,'same_eight_paid_native_bodies=true all_load_unload_callbacks=true reservation_released=true')
    if T.cycle==1 then T.cycle=2;pickup()else
     emit('RHINO_REPEAT_PASS','cycles=2 current_native_mass=114 ordinary_paid_production=true')
     -- Reuse actual current vehicle menu. Missing approved Trukk exposure is a
     -- dependency refusal, never a fixture-only build-menu mutation.
     paid(T.products.ork_mek_shop,'ork_trukk',false)
    end
   end
  elseif T.phase=='Trukk_full_refusal'and f>T.stage+30 then
   if refused('full8')then
    if not c.casualtyProbe then return stop('INCONCLUSIVE Rhino_repeat_and_full8_Trukk_pass six_survivor_probe_not_enabled')end
    if type(S.AddUnitDamage)~='function'then return stop('INCONCLUSIVE transport_casualty_damage_api_missing')end
    -- Optional scripted state probe on already paid bodies. No funded births,
    -- resource changes, repair or claim of native weapon/combat acceptance.
    T.phase='casualty_settle';T.stage=f;T.killed={bodies[2],bodies[3]}
    emit('CASUALTY_PROBE','scripted_native_damage=true paid_bodies=true grants=false economy_combat_acceptance=false')
    for _,id in ipairs(T.killed)do local hp=S.GetUnitHealth(id);S.AddUnitDamage(id,hp*4+10000,0,nil,-1)end
   end
  elseif T.phase=='casualty_settle'and f>T.stage+15 then
   squad=A.squads[seed]
   if not squad or count(squad.slots)~=6 or squad.slots[2]or squad.slots[3]then return stop('FAIL transport_six_survivor_state_probe')end
   for slot,id in pairs(squad.slots)do if id~=bodies[slot]or not valid(id)then return stop('FAIL transport_survivor_identity_changed')end end
   T.phase='Trukk_six_refusal';T.stage=f;order(T.trukk,CMD.LOAD_UNITS,{squad.leader})
  elseif T.phase=='Trukk_six_refusal'and f>T.stage+30 then
   squad=A.squads[seed]
   if not squad or count(squad.slots)~=6 then return stop('FAIL transport_Trukk_six_survivor_cohort_changed')end
   if refused('six_survivors_fixed8')then return stop('PASS ordinary_paid_Rhino_two_cycles native_eight_body_callbacks_positions full8_and_six_survivor_Trukk_refusal scripted_casualty_state_probe_not_combat')end
  end
  if T.stage and f-T.stage>600*Game.gameSpeed then return stop('INCONCLUSIVE transport_native_stage_timeout '..T.phase)end
  return T.result
 end
 return T
end
return M

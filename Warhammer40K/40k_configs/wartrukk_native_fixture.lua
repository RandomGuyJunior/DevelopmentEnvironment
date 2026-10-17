-- Spawned factory setup, real native queues/cargo. Not ordinary progression.
local M={Option='prototype_wartrukk_native_fixture'}
local function yes(v)return v==true or v==1 or v=='1'end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
function M.New(S,D,N,F,G,Game,CMD,geometry,options,emit)
 local C={phase='initial',owned={},initial={},products={},finished={},released={},loaded={},unloaded={},cycle=1}
 local function log(event,...)
  local a={...};a[#a+1]='frame='..S.GetGameFrame();a[#a+1]='spawned_factory_setup=true';a[#a+1]='own_resource_grants=false'
  a[#a+1]='ordinary_progression_accepted=false';a[#a+1]='visual_accepted=false';emit(event,unpack(a))
 end
 local function live(id,def,team)
  if not id or not S.ValidUnitID(id)or S.GetUnitIsDead(id)or S.GetUnitDefID(id)~=def or S.GetUnitTeam(id)~=(team or 0)then return false end
  local hp,_,_,_,p=S.GetUnitHealth(id);return finite(hp)and hp>0 and p==1
 end
 local function finish(reason)
  if C.result then return C.result end;C.result=reason;C.phase='done';log('COMPLETE',reason);return reason
 end
 local function fail(why)return finish('FAIL '..why)end
 local function count(t)local n=0;for _ in pairs(t or{})do n=n+1 end;return n end
 local function field(id,member)
  local hp,max,_,_,built=S.GetUnitHealth(id);local work,m,e=S.GetUnitCosts(id)
  return{hp=hp,max=max,built=built,work=work,metal=m,energy=e,xp=S.GetUnitExperience(id),def=S.GetUnitDefID(id),team=S.GetUnitTeam(id),slot=member.slot,generation=member.generation}
 end
 local function sameBodies()
  local a=G.Recoil40KSquads;local state=a and a.squads[C.seed]
  if not state or state.profile~='ork_slugga'or state.team~=0 or count(state.slots)~=8 then return false end
  for id,row in pairs(C.bodies)do
   if state.slots[row.slot]~=id or state.generations[row.slot]~=row.generation or not live(id,row.def)then return false end
   local now=field(id,row)
   for _,key in ipairs({'hp','max','built','work','metal','energy','xp','def','team'})do if now[key]~=row[key]then return false end end
  end
  return true
 end
 local function witness(stage)
  for id,row in pairs(C.bodies)do
   local p={S.GetUnitPosition(id)};local now=field(id,row)
   log('BODY_STATE','stage='..stage,'cycle='..C.cycle,'body='..id,'slot='..row.slot,'generation='..row.generation,
    'def='..now.def,'team='..now.team,'hp='..now.hp,'max_hp='..now.max,'xp='..now.xp,'work='..now.work,'metal='..now.metal,'energy='..now.energy,
    'x='..p[1],'y='..p[2],'z='..p[3],'transporter='..tostring(S.GetUnitTransporter(id)or'none'))
  end
 end
 local function cargo(expected)
  local ids=S.GetUnitIsTransporting(C.trukk);if type(ids)~='table'then return false end
  local seen={};for _,id in ipairs(ids)do if seen[id]or not C.bodies[id]or S.GetUnitTransporter(id)~=C.trukk then return false end;seen[id]=true end
  return #ids==expected,seen
 end
 local function site()
  for _,xf in ipairs({.2,.4,.6})do for _,zf in ipairs({.2,.4,.6})do
   local x,z=Game.mapSizeX*xf,Game.mapSizeZ*zf
   if x+1200<Game.mapSizeX-128 and z+900<Game.mapSizeZ-128
    and #(S.GetUnitsInRectangle(x-256,z-256,x+1200,z+900)or{})==0
    and #(S.GetFeaturesInRectangle(x-256,z-256,x+1200,z+900)or{})==0 then
    local good=true
    for _,r in ipairs({{C.ids.hut,x,z},{C.ids.shop,x+512,z}})do
     local y=S.GetGroundHeight(r[2],r[3]);if y<0 or S.TestBuildOrder(r[1],r[2],y,r[3],0)~=2 then good=false end
    end
    for _,r in ipairs({{x+256,z+256},{x+800,z+384},{x+800,z+704}})do
     local y=S.GetGroundHeight(r[1],r[2]);if y<0 or not S.TestMoveOrder(C.ids.trukk,r[1],y,r[2],0,0,0,true,true,false)or not S.TestMoveOrder(C.ids.body,r[1],y,r[2],0,0,0,true,true,false)then good=false end
    end
    if good then return{x=x,z=z}end
   end
  end end
 end
 local function order(id,cmd,p)if S.GiveOrderToUnit(id,cmd,p,0)==false then return fail('native_order_refused_'..cmd)end end
 function C.Created(id,def,team,builder)
  if C.result or team~=0 then return end
  local key=def==C.ids.trukk and'trukk'or def==C.ids.product and'leader'
  if key then
   local parent=key=='trukk'and C.shop or C.hut
   if C[key]or builder~=parent then return fail('foreign_or_duplicate_'..key..'_birth')end
   local _,_,_,_,built=S.GetUnitHealth(id);if not finite(built)or built>=1 then return fail('product_not_native_incomplete')end
   C[key]=id;C.owned[id]={def=def,team=0};log('BIRTH','key='..key,'body='..id,'factory='..builder)
  end
 end
 function C.Finished(id)if C.trukk==id or C.leader==id then C.finished[id]=true;log('FINISHED','body='..id)end end
 function C.Released(id,def,team,parent)
  if C.result or(id~=C.trukk and id~=C.leader)then return end
  if team~=0 or parent~=(id==C.trukk and C.shop or C.hut)or C.released[id]then return fail('foreign_or_duplicate_release')end
  C.released[id]=true;log('RELEASED','body='..id,'factory='..parent)
 end
 function C.Loaded(id,def,team,carrier)
  if C.result or carrier~=C.trukk then return end
  if C.phase~='loading'or not C.bodies[id]or def~=C.bodies[id].def or team~=0 or C.loaded[id]then return fail('unexpected_load_callback')end
  C.loaded[id]=true;log('LOADED','cycle='..C.cycle,'body='..id,'carrier='..carrier)
 end
 function C.Unloaded(id,def,team,carrier)
  if C.result or carrier~=C.trukk then return end
  if C.phase~='unloading'or not C.bodies[id]or def~=C.bodies[id].def or team~=0 or C.unloaded[id]then return fail('unexpected_unload_callback')end
  C.unloaded[id]=true;log('UNLOADED','cycle='..C.cycle,'body='..id,'carrier='..carrier)
 end
 local function pickup(frame)
  if not sameBodies()or not cargo(0)or G.Recoil40KSquadTransport.Reserved(C.seed)then return fail('pickup_identity_cargo_or_stale_reservation')end
  C.loaded={};C.unloaded={};C.phase='loading';C.stage=frame
  order(C.trukk,CMD.LOAD_UNITS,{C.leader});log('PICKUP_ORDER','cycle='..C.cycle,'leader='..C.leader,'carrier='..C.trukk)
 end
 function C.Step(frame)
  if C.result or C.closed then return C.result end
  if C.phase=='initial'then
   if frame==0 then return end
   if frame~=1 or Game.gameSpeed~=30 or not yes(options[M.Option])or options.prototype_diagnostic~='normal' or yes(options.prototype_source_bounds_capture)
    or options.prototype_source_acceptance~=''or not yes(options.prototype_wartrukk_transport_pilot)
    or not yes(options.prototype_squad_transport_pilot)or not yes(options.prototype_ork_slugga_squad)then return fail('exclusive_fresh_native_clock30_transport_context')end
   for key,value in pairs(options)do if yes(value)and key~=M.Option and(key:match('_fixture$')or key:match('_driver$')or key:match('benchmark')or key:match('probe'))then return fail('conflicting_diagnostic_'..key)end end
   C.started=frame;C.ids={}
   for key,name in pairs({hut='ork_boyz_hut',shop='ork_mek_shop',trukk='ork_trukk',product='ork_slugga',body='ork_slugga_member'})do
    if not N[name]then return fail('actual_definition_missing_'..name)end;C.ids[key]=N[name].id
   end
   local d=D[C.ids.trukk];local cp=d.customParams or{}
   if cp.source_transport_policy~='wartrukk_fixed8_hidden_real_bodies_v1'or tonumber(cp.source_transport_actor_capacity)~=8
    or tonumber(cp.prototype40k_transport_squad_limit)~=1 or d.releaseHeld~=true or d.metalCost~=150 or d.energyCost~=750 or d.buildTime~=1800 then return fail('actual_full8_genuine_Trukk_contract')end
   if not G.Recoil40KSquads or not G.Recoil40KSquadTransportAPI or not G.Recoil40KResearch then return fail('actual_existing_owners_missing')end
   for _,id in ipairs(S.GetAllUnits()or{})do C.initial[id]={def=S.GetUnitDefID(id),team=S.GetUnitTeam(id)}end
   C.site=site();if not C.site then return finish('INCONCLUSIVE isolated_native_ground_site_absent')end
   local p=C.site
   for key,name in pairs({hut='ork_boyz_hut',shop='ork_mek_shop'})do
    local x=p.x+(key=='shop'and 512 or 0);local id=S.CreateUnit(name,x,S.GetGroundHeight(x,p.z),p.z,0,0)
    if not live(id,C.ids[key])or C.initial[id]then return fail('exact_spawned_setup_'..key)end
    C[key]=id;C.owned[id]={def=C.ids[key],team=0}
   end
   for _,r in ipairs({{C.hut,C.ids.product},{C.shop,C.ids.trukk}})do
    local found=false;for _,v in ipairs(D[S.GetUnitDefID(r[1])].buildOptions or{})do if v==r[2]then found=true end end
    if not found or not G.Recoil40KResearch.CanBuild(0,r[2],r[1],false)then return fail('actual_sole_factory_menu_or_gate')end
   end
   C.phase='production';C.stage=frame
   order(C.hut,-C.ids.product,{});order(C.shop,-C.ids.trukk,{})
   log('BEGIN','scene=spawned_two_factories_paid_native_queues','start_resource_grant=false');return
  end
  if frame-C.started>3600 then return finish('INCONCLUSIVE bounded_timeout_'..C.phase)end
  for id,row in pairs(C.initial)do if not live(id,row.def,row.team)then return fail('initial_actor_lost_or_transferred')end end
  if C.phase~='death'and C.trukk and not live(C.trukk,C.ids.trukk)and C.finished[C.trukk]then return fail('Trukk_lost_or_transferred')end
  if C.phase=='production'and C.trukk and C.leader and C.finished[C.trukk]and C.finished[C.leader]and C.released[C.trukk]and C.released[C.leader]then
   local state=G.Recoil40KSquads.Get(C.leader)
   if not state or state.profile~='ork_slugga'or count(state.slots)~=8 then return fail('actual_complete_paid_Slugga8_absent')end
   C.seed=state.id;C.bodies={}
   for slot,id in pairs(state.slots)do
    local row={slot=slot,generation=state.generations[slot]};if not live(id,C.ids.body)and id~=C.leader then return fail('foreign_internal_body')end
    C.bodies[id]=field(id,row);C.owned[id]={def=C.bodies[id].def,team=0}
    local b=C.bodies[id];if b.work~=144 or b.metal~=12 or b.energy~=60 then return fail('actual_native_paid_body_bill')end
   end
   local work,m,e=S.GetUnitCosts(C.trukk);if work~=1800 or m~=150 or e~=750 then return fail('actual_native_vehicle_bill')end
   witness('paid_complete')
   C.phase='exit';C.stage=frame
   local p=C.site;C.pickup={p.x+256,S.GetGroundHeight(p.x+256,p.z+256),p.z+256}
   order(C.leader,CMD.MOVE,C.pickup);order(C.trukk,CMD.MOVE,{p.x+384,C.pickup[2],p.z+256})
  elseif C.phase=='exit'and frame%15==0 then
   if not sameBodies()then return fail('paid_body_identity_or_state_changed')end
   local okay=geometry.Outside(S,D,C.shop,C.trukk)==true
   for id in pairs(C.bodies)do if geometry.Outside(S,D,C.hut,id)~=true then okay=false end end
   if okay then log('ALL_BODY_FACTORY_EXIT','members=8','vehicle=1');return pickup(frame)end
  elseif C.phase=='loading'then
   if not sameBodies()then return fail('loading_changed_paid_body_state')end
   if cargo(8)then
    if count(C.loaded)~=8 or not G.Recoil40KSquadTransport or not G.Recoil40KSquadTransport.Reserved(C.seed)then return fail('eight_native_callbacks_and_reservation_required')end
    C.phase='carry';C.stage=frame;C.carryOrigin={S.GetUnitPosition(C.trukk)}
    local p=C.site;C.unload={p.x+800,S.GetGroundHeight(p.x+800,p.z+(C.cycle==1 and 384 or 704)),p.z+(C.cycle==1 and 384 or 704),128}
    order(C.trukk,CMD.MOVE,{C.unload[1],C.unload[2],C.unload[3]});log('WHOLE8_NATIVE_CARGO','cycle='..C.cycle);witness('native_carried')
   end
  elseif C.phase=='carry'and frame%15==0 then
   if not sameBodies()or not cargo(8)then return fail('carried_identity_membership_or_state_changed')end
   local x,_,z=S.GetUnitPosition(C.trukk);local travel=(x-C.carryOrigin[1])^2+(z-C.carryOrigin[3])^2
   if travel>=128^2 and(x-C.unload[1])^2+(z-C.unload[3])^2<96^2 then
    C.phase='unloading';C.stage=frame;order(C.trukk,CMD.UNLOAD_UNITS,C.unload);log('UNLOAD_ORDER','cycle='..C.cycle,'travel='..math.sqrt(travel))
   end
  elseif C.phase=='unloading'then
   if not sameBodies()then return fail('unload_changed_paid_body_state')end
   if cargo(0)and count(C.unloaded)==8 and not G.Recoil40KSquadTransport.Reserved(C.seed)then
    C.phase='settle';C.stage=frame
   end
  elseif C.phase=='settle'and frame-C.stage>=30 then
   if not sameBodies()or not cargo(0)then return fail('settled_identity_or_cargo')end
   for id in pairs(C.bodies)do
    local x,y,z=S.GetUnitPosition(id);local ground=S.GetGroundHeight(x,z)
    if S.GetUnitTransporter(id)~=nil or not finite(y)or math.abs(y-ground)>4 or(x-C.unload[1])^2+(z-C.unload[3])^2>256^2 then return fail('native_ground_detach_or_bounded_unload')end
   end
   log('CYCLE_PASS','cycle='..C.cycle,'members=8','same_hp_xp_cost_equipment_generations=true','ground_detached=true')
   witness('native_ground_detached')
   if C.cycle==1 then C.cycle=2;return pickup(frame)end
   C.phase='death_depart';C.stage=frame
   local x,z=C.unload[1]+320,C.unload[3]
   if not S.TestMoveOrder(C.ids.trukk,x,S.GetGroundHeight(x,z),z,0,0,0,true,true,false)then return finish('INCONCLUSIVE no_clear_empty_carrier_death_site')end
   C.deathSite={x,S.GetGroundHeight(x,z),z};order(C.trukk,CMD.MOVE,C.deathSite)
  elseif C.phase=='death_depart'and frame%15==0 then
   if not sameBodies()or not cargo(0)then return fail('empty_departure_changed_paid_bodies')end
   local x,_,z=S.GetUnitPosition(C.trukk);local safe=(x-C.deathSite[1])^2+(z-C.deathSite[3])^2<96^2
   for id in pairs(C.bodies)do local bx,_,bz=S.GetUnitPosition(id);if(x-bx)^2+(z-bz)^2<256^2 then safe=false end end
   if not safe then return end
   C.phase='death';C.stage=frame;C.featuresBefore={}
   for _,fid in ipairs(S.GetAllFeatures()or{})do C.featuresBefore[fid]=true end
   S.DestroyUnit(C.trukk,false,false);log('EMPTY_CARRIER_DEATH','native_releaseheld_unchanged=true','loaded_cargo_death_accepted=false','capture_accepted=false')
  elseif C.phase=='death'and frame-C.stage>=30 then
   if not sameBodies()then return fail('empty_carrier_death_changed_unloaded_cohort')end
   local found={};for _,fid in ipairs(S.GetAllFeatures()or{})do if not C.featuresBefore[fid]then found[#found+1]=fid end end
   if #found~=1 then return fail('native_single_vehicle_wreck_count')end
   local f=found[1];local fd=F[S.GetFeatureDefID(f)];local cp=fd and fd.customParams or{}
   local m,dm,e,de,left=S.GetFeatureResources(f)
   if cp.parent_actor~='ork_trukk'or m~=37.5 or dm~=m or e~=0 or de~=0 or left~=1 then return fail('actual_single_vehicle_remaining_salvage')end
   log('ONE_WRECK','feature='..f,'metal='..m,'energy='..e)
   return finish('PASS scoped_paid_native_products_all_body_exit_ground8_two_cycles_empty_carrier_one_wreck')
  end
 end
 function C.Close()
  if C.closed then return end;C.closed=true
  -- Leave cargo and squad bodies to native game teardown. Killing a partially
  -- loaded carrier here would mutate its cargo and fabricate an extra test.
  -- No timed cleanup, rescue, refund or scripted passenger destruction occurs.
 end
 return C
end
return M

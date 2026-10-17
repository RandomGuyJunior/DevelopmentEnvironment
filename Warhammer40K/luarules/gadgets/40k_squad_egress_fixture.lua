function gadget:GetInfo()
 return{name='40K paid squad factory egress diagnostic',desc='Default-off two paid products and native rally/release evidence',author='Local project',layer=152,enabled=true}
end
local options=Spring.GetModOptions()or{}
local enabled=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled
if not enabled(options.prototype_squad_egress_fixture)then return false end
if not gadgetHandler:IsSyncedCode()then
 local closeAt
 local function done(_,result)Spring.Echo('40K_SQUAD_EGRESS owned_fixture_autoclose '..tostring(result));closeAt=Spring.GetGameFrame()+90 end
 function gadget:Initialize()gadgetHandler:AddSyncAction('fortyk_squad_egress_done',done)end
 function gadget:GameFrame(frame)if closeAt and frame>=closeAt then closeAt=nil;Spring.SendCommands('quitforce')end end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction('fortyk_squad_egress_done')end
 return
end
local S=Spring;local phase='initial';local team=0;local startFrame
local sentinelCombat;local sentinelEnabled=enabled(options.prototype_guard_sentinel_weapon_fixture)
local family=options.prototype_squad_egress_faction or'marine'
local routes={marine={commander='smcom',factory='imp_marine_barracks',product='imp_marine',profile='marine_tactical'},
 guard={commander='imp_field_commander',factory='imp_barracks',product='imp_guardsman',profile='guard_line'},
 ork={commander='ork_big_mek_commander',factory='ork_boyz_hut',product='ork_boy',profile='ork_shoota'},
 necron={commander='nec_lord',factory='nec_hq',product='nec_warrior',profile='necron_warrior'}}
local route=routes[family];local profile,capacity,commander,factory,site,rally,bornFactory
local products,productByID,memberOwner={},{},{};local twoQueueSeen=false;local nativeFinished={}
local geometryReceipt
local physical=VFS.Include('40k_configs/guard_factory_egress_geometry.lua');local vehicleMode=false;local expectedProducts=2;local infantryEvidence;local idleStart
local rate=Game.gameSpeed or 30;local timeout=1200*rate;local exitGrace=120*rate
local function emit(event,...)
 local a={...};for i=1,#a do a[i]=tostring(a[i])end;S.Echo('40K_SQUAD_EGRESS '..event..' '..table.concat(a,' '))
end
local function resources(event)
 local m,_,_,mi,me=S.GetTeamResources(team,'metal');local e,_,_,ei,ee=S.GetTeamResources(team,'energy')
 emit(event,'metal='..tostring(m),'energy='..tostring(e),'metal_income='..tostring(mi),'energy_income='..tostring(ei),'metal_expense='..tostring(me),'energy_expense='..tostring(ee),'net_delta_is_not_exact_cost=true')
 return m,e,mi,ei
end
local function finish(reason)
 if phase=='done'then return end;phase='done';if sentinelCombat and sentinelCombat.Close then sentinelCombat.Close()end;GG.Recoil40KSentinelWeaponWitness=nil;resources('FINAL_RESOURCES')
 emit('COMPLETE',reason,'paid_automated_egress=true visual_occlusion_acceptance=false stock_hud_acceptance=false')
 SendToUnsynced('fortyk_squad_egress_done',reason)
end
if enabled(options.prototype_guard_factory_geometry_receipt)then
 assert(family=='guard','Guard geometry receipt requires actual Guard egress route')
 geometryReceipt=VFS.Include('40k_configs/guard_factory_geometry_receipt.lua').New(S,UnitDefs,UnitDefNames,physical,nativeFinished,emit)
end
local function live(id)
 if not id or S.GetUnitIsDead(id)then return false end
 local hp,_,_,_,p=S.GetUnitHealth(id);return hp and hp>0 and p and p>=1
end
local function contains(t,id)for _,v in ipairs(t or{})do if v==id then return true end end;return false end
local function clear(def,x,z)
 local d=UnitDefs[def];local hx,hz=d.xsize*4,d.zsize*4
 if x-hx<64 or z-hz<64 or x+hx>Game.mapSizeX-64 or z+hz>Game.mapSizeZ-64 then return false end
 for _,id in ipairs(S.GetUnitsInRectangle(x-hx-32,z-hz-32,x+hx+32,z+hz+32)or{})do
  if id~=commander then return false end
  local cx,_,cz=S.GetUnitPosition(id)
  local c=UnitDefs[S.GetUnitDefID(id)]
  if math.abs(cx-x)<hx+c.xsize*4+8 and math.abs(cz-z)<hz+c.zsize*4+8 then return false end
 end
 return #(S.GetFeaturesInRectangle(x-hx-16,z-hz-16,x+hx+16,z+hz+16)or{})==0
end
local function exits(def,product,x,z)
 local fd,pd=UnitDefs[def],UnitDefs[product]
 local radius=math.max(fd.xsize,fd.zsize)*4+math.max(pd.xsize,pd.zsize)*4+32
 local valid=0
 for j=0,15 do
  local angle=j*math.pi/8;local ex,ez=x+radius*math.cos(angle),z+radius*math.sin(angle)
  local ey=S.GetGroundHeight(ex,ez)
  if ey>=0 and ex>32 and ez>32 and ex<Game.mapSizeX-32 and ez<Game.mapSizeZ-32
   and S.TestMoveOrder(product,ex,ey,ez,0,0,0,true,true,false)then valid=valid+1 end
 end
 return valid
end
local function chooseSite(def)
 local cx,_,cz=S.GetUnitPosition(commander);local cd=UnitDefs[S.GetUnitDefID(commander)]
 local range=cd.buildDistance;local fd=UnitDefs[def]
 for ring=6,18 do for j=0,15 do
  local angle=j*math.pi/8
  local x,y,z=S.Pos2BuildPos(def,cx+ring*32*math.cos(angle),0,cz+ring*32*math.sin(angle),0)
  y=S.GetGroundHeight(x,z)
  local status,feature=S.TestBuildOrder(def,x,y,z,0)
  if y>=0 and status==2 and not feature and clear(def,x,z)
   and exits(def,UnitDefNames[route.product].id,x,z)>=capacity then
   for k=0,15 do
    local a=k*math.pi/8;local sx,sz=x+(range-24)*math.cos(a),z+(range-24)*math.sin(a)
    local sy=S.GetGroundHeight(sx,sz)
    local outside=math.abs(sx-x)>=fd.xsize*4+cd.xsize*4+8 or math.abs(sz-z)>=fd.zsize*4+cd.zsize*4+8
    if outside and sy>=0 and sx>32 and sz>32 and sx<Game.mapSizeX-32 and sz<Game.mapSizeZ-32
     and(sx-x)^2+(sy-y)^2+(sz-z)^2<(range-8)^2
     and S.TestMoveOrder(cd.id,sx,sy,sz,0,0,0,true,true,false)then
      return {x,y,z,0},{sx,sy,sz}
    end
   end
  end
 end end
end

local function chooseRally()
 local fd,pd=UnitDefs[S.GetUnitDefID(factory)],UnitDefNames[route.product].id
 local fx,_,fz=S.GetUnitPosition(factory)
 local radius=math.max(fd.xsize,fd.zsize)*4+224
 for j=0,15 do
  local a=j*math.pi/8;local x,z=fx+radius*math.cos(a),fz+radius*math.sin(a);local y=S.GetGroundHeight(x,z)
  if x>64 and z>64 and x<Game.mapSizeX-64 and z<Game.mapSizeZ-64 and y>=0
   and S.TestMoveOrder(pd,x,y,z,0,0,0,true,true,false)then return{x,y,z}end
 end
end
local function queues(event)
 local building=S.GetUnitIsBuilding(factory) -- assignment coerces native zero-return to nil
 local q=S.GetFactoryCommands(factory,-1)or{};local a={}
 for _,c in ipairs(q)do a[#a+1]=tostring(c.id)..':'..tostring(c.tag)end
 local full=S.GetFullBuildQueue(factory)or{};local b={};local count=0;local pd=UnitDefNames[route.product].id
 for key,row in pairs(full)do
  if type(row)=='table'then for def,n in pairs(row)do b[#b+1]=tostring(def)..':'..tostring(n);if tonumber(def)==pd then count=count+n end end
  else b[#b+1]=tostring(key)..':'..tostring(row);if tonumber(key)==pd then count=count+row end end
 end
 local outgoing={};for _,cmd in ipairs(S.GetUnitCommands(factory,-1)or{})do outgoing[#outgoing+1]=tostring(cmd.id)..':'..tostring(cmd.tag)end
 if count==2 then twoQueueSeen=true end
 table.sort(b);emit(event,'factory='..factory,'native_building='..tostring(building),'commands='..table.concat(a,','),'full_queue='..table.concat(b,','),'actual_product_queue_count='..count,'stock_rally_queue='..table.concat(outgoing,','));return count
end
local function movement(id)
 local q=S.GetUnitCommands(id,-1)or{};local a={};local rallyOrder=false
 for _,c in ipairs(q)do
  local p=c.params or{};a[#a+1]=tostring(c.id)..':'..tostring(c.tag)..'@'..tostring(p[1])..','..tostring(p[2])..','..tostring(p[3])
  if c.id==CMD.MOVE and c.params and #c.params>=3 and(c.params[1]-rally[1])^2+(c.params[3]-rally[3])^2<16 then rallyOrder=true end
 end
 return table.concat(a,','),rallyOrder
end
function gadget:UnitCreated(id,def,t,builder)
 if t~=team or not route then return end
 if phase=='build_factory'and def==UnitDefNames[route.factory].id then
  if builder~=commander or bornFactory then finish('FAIL foreign_or_duplicate_factory_birth');return end
  bornFactory=id;emit('FACTORY_BIRTH','unit='..id,'builder='..builder)
 elseif phase=='observe'and def==UnitDefNames[route.product].id then
  if builder~=factory or productByID[id]or #products>=expectedProducts then finish('FAIL foreign_or_excess_product_birth');return end
  local x,_,z=S.GetUnitPosition(id);local row={id=id,born=S.GetGameFrame(),ordinal=#products+1,productDefinition=def,origin={x,z},firstPositions={}};products[#products+1]=row;productByID[id]=row
  emit('PRODUCT_BIRTH','ordinal='..row.ordinal,'original='..id,'factory='..builder,'frame='..row.born);queues('BIRTH_QUEUE')
 end
end
function gadget:UnitFinished(id,def,t)
 if phase=='done'then return end
 -- Internal real bodies finish inside nested native births before squad links exist.
 nativeFinished[id]={def=def,team=t,frame=S.GetGameFrame()}
 local row=productByID[id];if row then if t~=team or def~=row.productDefinition or row.finished then finish('FAIL mismatched_or_duplicate_product_finish');return end;row.finished=S.GetGameFrame();emit('PRODUCT_FINISHED','original='..id,'frame='..row.finished)end
end
function gadget:UnitFromFactory(id,def,t,owner,ownerDef,userOrders)
 local row=productByID[id];if not row then return end
 if owner~=factory or t~=team or def~=UnitDefNames[route.product].id or ownerDef~=UnitDefNames[route.factory].id or row.released or userOrders then finish('FAIL mismatched_or_duplicate_native_release');return end
 row.released=S.GetGameFrame();local q,has=movement(id);row.nativeRally=has
 emit('NATIVE_RELEASE','original='..id,'factory='..owner,'frame='..row.released,'user_orders='..tostring(userOrders),'rally_command='..tostring(has),'unit_queue='..q)
end
local function sample(row,frame)
 local R=GG.Recoil40KSquads;local squad=R.Get(row.id)
 if not squad then
  if S.GetUnitRulesParam(row.id,'40k_squad_delivery_failed')==1 then finish('FAIL real_squad_delivery_refused')end
  return false
 end
 local members=R.Members(squad.leader)
 if squad.profile~=route.profile or squad.team~=team or #members~=capacity then finish('FAIL incomplete_or_wrong_real_squad');return false end
 if not row.delivered then row.delivered=frame;row.seed=squad.id;emit('DELIVERY','ordinal='..row.ordinal,'original='..row.id,'current_leader='..squad.leader,'count='..#members,'frame='..frame)end
 if row.seed~=squad.id or squad.leader~=row.id then finish('FAIL original_product_leader_changed');return false end
 local fx,_,fz=S.GetUnitPosition(factory);local fd=UnitDefs[S.GetUnitDefID(factory)]
 local hx,hz=fd.xsize*4,fd.zsize*4
 local facing=S.GetUnitBuildFacing(factory)or 0;if facing%2==1 then hx,hz=hz,hx end
 local outside=true;local originalCentre,originalOverlap;local moved=true;local allFinished=true
 if not row.fixedBodies then row.fixedBodies={};for _,id in ipairs(members)do row.fixedBodies[id]=S.GetUnitDefID(id)end end
 for _,id in ipairs(members)do
  if not live(id)or S.GetUnitTeam(id)~=team or(memberOwner[id]and memberOwner[id]~=row.id)then finish('FAIL lost_or_shared_real_body');return false end
  if row.fixedBodies[id]~=S.GetUnitDefID(id)then finish('FAIL paid_real_cohort_identity_changed');return false end
  local native=nativeFinished[id];if not native or native.def~=S.GetUnitDefID(id)or native.team~=team then allFinished=false end
  memberOwner[id]=row.id
  local x,y,z=S.GetUnitPosition(id);local d=UnitDefs[S.GetUnitDefID(id)]
  local centre=math.abs(x-fx)<=hx and math.abs(z-fz)<=hz
  local overlap=math.abs(x-fx)<=hx+d.xsize*4 and math.abs(z-fz)<=hz+d.zsize*4
  do
   local actual,witness=physical.Outside(S,UnitDefs,factory,id)
   if actual==nil then finish('FAIL actual_collision_geometry_'..tostring(witness));return false end
   overlap=not actual
   if frame%30==0 then emit('NATIVE_ENVELOPE','body='..id,'parent_minx='..witness.parent.minX,'parent_maxx='..witness.parent.maxX,'parent_minz='..witness.parent.minZ,'parent_maxz='..witness.parent.maxZ,'collision_and_yard_union_clear='..tostring(actual))end
  end
  if overlap then outside=false end
  if id==row.id then originalCentre=centre;originalOverlap=overlap end
  local q,has=movement(id)
  -- After arrival native MOVE may already be consumed. Arrival itself is evidence.
  local arrived=(x-rally[1])^2+(z-rally[3])^2<=96^2
  local origin=row.firstPositions[id];if not origin then origin={x,z};row.firstPositions[id]=origin end
  local traveled=(x-origin[1])^2+(z-origin[2])^2>=32^2
  if not arrived or not traveled then moved=false end
  if frame%30==0 then emit('BODY','ordinal='..row.ordinal,'unit='..id,'original='..tostring(id==row.id),'x='..x,'y='..y,'z='..z,'centre_inside='..tostring(centre),'native_union_overlap='..tostring(overlap),'rally_command='..tostring(has),'rally_arrived='..tostring(arrived),'traveled_32='..tostring(traveled),'queue='..q)end
 end
 if row.finished and allFinished and row.released and outside and moved and frame-row.released>=30 then
  if not row.clear then if geometryReceipt then geometryReceipt.Capture('infantry',factory,row,members,capacity,team,frame)end;row.clear=frame;emit('EGRESS_CLEAR','original='..row.id,'count='..capacity,'frame='..frame,'actual_native_release=true all_body_footprints_clear=true')end
  return true
 end
 if frame-row.delivered>=exitGrace then
  local building=S.GetUnitIsBuilding(factory)
  if not row.finished or not allFinished then finish('FAIL paid_real_body_finish_callback_missing original='..row.id)
  elseif not row.released then finish('FAIL original_leader_not_released original='..row.id..' factory_still_building_original='..tostring(building==row.id)..' centre_inside='..tostring(originalCentre))
  elseif originalOverlap then finish('FAIL released_original_still_overlaps_native_factory original='..row.id..' centre_inside='..tostring(originalCentre))
  elseif not outside then finish('FAIL released_squad_body_overlap_after_grace original='..row.id)
  else finish('FAIL native_rally_not_preserved_or_arrived original='..row.id)end
 end
 return false
end
local function sampleVehicle(row,frame)
 if S.GetUnitIsDead(row.id)or S.GetUnitTeam(row.id)~=team then finish('FAIL paid_vehicle_lost_or_captured');return false end
 if not live(row.id)then return false end
 local outside,w=physical.Outside(S,UnitDefs,factory,row.id)
 if outside==nil then finish('FAIL actual_collision_geometry_'..tostring(w));return false end
 local x,_,z=S.GetUnitPosition(row.id);local q,has=movement(row.id)
 local arrived=(x-rally[1])^2+(z-rally[3])^2<=96^2
 local traveled=(x-row.origin[1])^2+(z-row.origin[2])^2>=32^2
 if frame%30==0 then emit('VEHICLE_NATIVE_EGRESS','id='..row.id,'actual_release='..tostring(row.released),'union_clear='..tostring(outside),'rally_arrived='..tostring(arrived),'traveled_32='..tostring(traveled),'queue='..q)end
 if row.finished and row.released and outside and arrived and traveled and frame-row.released>=30 then if geometryReceipt then geometryReceipt.Capture('vehicle',factory,row,{row.id},1,team,frame)end;return true end
 if frame-row.born>=exitGrace then finish('FAIL paid_vehicle_release_or_native_egress_missing')end
 return false
end
function gadget:GameFrame(frame)
 if phase=='done'then return end;if not startFrame then startFrame=frame end
 if infantryEvidence then
  for id in pairs(memberOwner)do
   if not live(id)or S.GetUnitTeam(id)~=team then finish('FAIL proven_Guard_cohort_lost_during_vehicle_route');return end
  end
 end
 if frame-startFrame>timeout then
  if #products<2 or not products[2].delivered then finish('INCONCLUSIVE ordinary_economy_or_native_build_timeout products='..#products)
  else finish('FAIL bounded_egress_timeout')end;return
 end
 if phase=='initial'then
  if not route then finish('FAIL unsupported_family');return end
  if sentinelEnabled and(family~='guard'or enabled(options.prototype_infantry_scale_085))then finish('FAIL Sentinel_requires_unscaled_Guard_egress');return end
  if enabled(options.prototype_squad_fixture)or enabled(options.prototype_squad_paid_fixture)then finish('FAIL conflicting_fixture');return end
  local m,e=resources('INITIAL_RESOURCES');if not m or not e or math.abs(m-1000)>5 or math.abs(e-1000)>5 then finish('FAIL not_ordinary_1000_start');return end
  profile=VFS.Include('40k_configs/active_squad_profiles.lua').profiles[route.profile];capacity=profile and profile.capacity
  if not capacity then finish('FAIL missing_real_profile');return end
  if family=='guard'and capacity~=8 then finish('FAIL Guard_fixed_capacity_must_be_8');return end
  for _,key in ipairs({route.commander,route.factory,route.product,profile.member})do if not UnitDefNames[key]then finish('FAIL missing_definition '..key);return end end
  local units=S.GetTeamUnits(team)or{};if #units~=1 or S.GetUnitDefID(units[1])~=UnitDefNames[route.commander].id or not live(units[1])then finish('FAIL need_natural_single_commander');return end
  commander=units[1];local cd=UnitDefs[S.GetUnitDefID(commander)];local fd=UnitDefs[UnitDefNames[route.factory].id];local pd=UnitDefs[UnitDefNames[route.product].id];local bd=UnitDefs[UnitDefNames[profile.member].id]
  if not fd.isFactory or not contains(cd.buildOptions,fd.id)or not contains(fd.buildOptions,pd.id)then finish('FAIL native_factory_graph');return end
  if (pd.customParams or{}).prototype40k_squad_product~=route.profile or tonumber((pd.customParams or{}).prototype40k_squad_capacity)~=capacity
   or math.abs(pd.metalCost-bd.metalCost*capacity)>.001 or math.abs(pd.energyCost-bd.energyCost*capacity)>.001 or math.abs(pd.buildTime-bd.buildTime*capacity)>.001 then finish('FAIL wrong_full_paid_product_bill');return end
  if family=='guard'then
   local tank=UnitDefNames.imp_tank_factory;local vehicle=UnitDefNames.imp_sentinel
   local cp=fd.customParams or{}
   if not tank or not vehicle or not UnitDefs[tank.id].isFactory or not contains(cd.buildOptions,tank.id)or not contains(UnitDefs[tank.id].buildOptions,vehicle.id)then finish('FAIL actual_Guard_vehicle_graph');return end
   local vd=UnitDefs[vehicle.id]
   if not vd.metalCost or vd.metalCost<=0 or not vd.energyCost or vd.energyCost<=0 or not vd.buildTime or vd.buildTime<=0 then finish('FAIL actual_Guard_vehicle_paid_bill');return end
   if tonumber(cp.prototype40k_native_factory_pilot)~=1 or cp.prototype40k_native_factory_donor~='wh40k_armlab'
    or tonumber((UnitDefs[tank.id].customParams or{}).prototype40k_native_factory_pilot)~=1 or(UnitDefs[tank.id].customParams or{}).prototype40k_native_factory_donor~='wh40k_armvp'then finish('FAIL integrated_native_Guard_pilots_required');return end
   if not S.GetUnitVectors or not S.GetUnitCollisionVolumeData then finish('FAIL actual_collision_api_required');return end
   emit('GUARD_PILOT_LOAD','infantry_donor=armlab','vehicle_donor=armvp','capacity=8','vehicle=imp_sentinel','FactoryGuard_SETTING_RECORD_REQUIRED=true')
  end
  if not GG.Recoil40KSquads or next(GG.Recoil40KSquads.squads)then finish('FAIL missing_or_preexisting_squads');return end
  emit('BUDGET','factory_metal='..fd.metalCost,'factory_energy='..fd.energyCost,'two_products_metal='..pd.metalCost*2,'two_products_energy='..pd.energyCost*2,'one_product_work='..pd.buildTime,'native_economy_may_stall=true')
  site=chooseSite(fd.id);if not site then finish('FAIL no_clear_reachable_native_site');return end
  phase='build_factory';S.GiveOrderToUnit(commander,-fd.id,site,0);emit('PAID_FACTORY_ORDER','commander='..commander,'native_approach=true site_x='..site[1]..' site_z='..site[3])
 elseif phase=='build_factory'then
  if not live(commander)or S.GetUnitTeam(commander)~=team then finish('FAIL commander_lost_or_captured');return end
  if bornFactory and S.GetUnitTeam(bornFactory)~=team then finish('FAIL factory_captured_before_completion');return end
  if bornFactory and live(bornFactory)then
   factory=bornFactory;rally=chooseRally();if not rally then finish('FAIL no_native_passable_rally');return end
   -- Native factory MOVE is its stock outgoing-unit rally queue, not a direct
   -- unit move/teleport. Unmodified factory builds append one product each;
   -- SHIFT is a native five-product modifier, not a generic queue append.
   S.GiveOrderToUnit(factory,CMD.MOVE,rally,0);phase='observe'
   S.GiveOrderToUnit(factory,-UnitDefNames[route.product].id,{},0)
   if not vehicleMode then S.GiveOrderToUnit(factory,-UnitDefNames[route.product].id,{},0)end
   emit(vehicleMode and'ONE_PAID_VEHICLE_QUEUE'or'TWO_PAID_QUEUE','count='..expectedProducts..' no_acceleration=true','rally_x='..rally[1],'rally_z='..rally[3]);queues('INITIAL_QUEUE');resources('QUEUE_RESOURCES')
  end
 elseif phase=='observe'then
  if not live(factory)or not live(commander)or S.GetUnitTeam(factory)~=team or S.GetUnitTeam(commander)~=team then finish('FAIL ordinary_factory_or_commander_lost');return end
  local all=#products==expectedProducts
  for _,row in ipairs(products)do if not(vehicleMode and sampleVehicle(row,frame)or not vehicleMode and sample(row,frame))then all=false end;if phase=='done'then return end end
  if all then
   if not twoQueueSeen then finish('INCONCLUSIVE two_product_native_queue_never_observed');return end
   if queues('FINAL_QUEUE')~=0 or S.GetUnitIsBuilding(factory)then finish('FAIL factory_retains_build_after_two_releases');return end
   resources('DELIVERY_RESOURCES')
   if family=='guard'and not vehicleMode then
    infantryEvidence={factory=factory,products=products,clearFrame=frame};idleStart=frame;phase='Guard_idle'
    emit('GUARD_INFANTRY_COMPLETE','two_squads=true','sixteen_real_bodies_native_union_clear=true','actual_native_release_and_rally_arrival=true')
   elseif vehicleMode then
    if sentinelEnabled then
     local actor=products[1].id
     sentinelCombat=VFS.Include('40k_configs/guard_sentinel_weapon_fixture.lua').New(S,UnitDefs,WeaponDefs,actor,actor,team,frame,emit)
     if sentinelCombat.result then finish(sentinelCombat.result);return end
     if not Script or not Script.SetWatchProjectile then finish('FAIL native_projectile_watch_API_missing');return end
     Script.SetWatchProjectile(sentinelCombat.weapon,true);GG.Recoil40KSentinelWeaponWitness=sentinelCombat;phase='Sentinel_weapon'
     emit('SENTINEL_WEAPON_START','actual_paid_finish_release_rally_verified=true','funded_hostile_target_only=true','paid_weapon_acceptance=false')
    else finish('PASS two_paid_full8_Guard_squads native_release_all16_collision_yard_clear_actual_rally_travel paid_Sentinel_native_release_union_clear_actual_rally_travel')end
   else finish('PASS two_distinct_paid_squads native_release_observed native_rally_preserved all_real_body_footprints_clear')end
  end
 elseif phase=='Sentinel_weapon'then
  local result=sentinelCombat.Step(frame);if result then finish(result)end
 elseif phase=='Guard_idle'then
  if not live(factory)or not live(commander)or S.GetUnitTeam(factory)~=team or S.GetUnitTeam(commander)~=team then finish('FAIL Guard_factory_lost_during_idle');return end
  if #((S.GetFactoryCommands(factory,-1))or{})~=0 or S.GetUnitIsBuilding(factory)then finish('FAIL Guard_factory_not_idle_after_two_releases');return end
  if frame-idleStart>=8*rate then
   route={commander='imp_field_commander',factory='imp_tank_factory',product='imp_sentinel'};vehicleMode=true;expectedProducts=1;capacity=1
   local tank=UnitDefs[UnitDefNames.imp_tank_factory.id];local vehicle=UnitDefs[UnitDefNames.imp_sentinel.id]
   emit('PAID_VEHICLE_BILL','factory_metal='..tank.metalCost,'factory_energy='..tank.energyCost,'product_metal='..vehicle.metalCost,'product_energy='..vehicle.energyCost,'product_work='..vehicle.buildTime)
   site=chooseSite(tank.id);if not site then finish('INCONCLUSIVE no_clear_Guard_vehicle_site');return end
   products={};bornFactory=nil;phase='build_factory';S.GiveOrderToUnit(commander,-tank.id,site,0)
   emit('PAID_FACTORY_ORDER','guard_vehicle=true','idle_frames='..(frame-idleStart),'site_x='..site[1],'site_z='..site[3])
  end
 end
 if phase~='done'and frame%300==0 then emit('STATE','phase='..phase,'frame='..frame,'products='..#products);resources('PERIODIC_RESOURCES');if factory then queues('PERIODIC_QUEUE')end end
end

function gadget:ProjectileCreated(pid,owner,wd)if sentinelCombat and sentinelCombat.Projectile then sentinelCombat.Projectile(pid,owner,wd)end end
function gadget:UnitDamaged(id,def,t,damage,para,wd,pid,attacker)if sentinelCombat and sentinelCombat.Damaged then sentinelCombat.Damaged(id,damage,para,wd,pid,attacker)end end
function gadget:Shutdown()if sentinelCombat and sentinelCombat.Close then sentinelCombat.Close()end;GG.Recoil40KSentinelWeaponWitness=nil end

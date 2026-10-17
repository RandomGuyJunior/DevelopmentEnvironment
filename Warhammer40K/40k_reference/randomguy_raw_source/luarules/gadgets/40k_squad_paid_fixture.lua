function gadget:GetInfo()
 return {name='40K ordinary paid squad pilot',desc='Default-off native starting commander, paid factory/product and casualty repair',author='Local project',layer=151,enabled=true}
end
local options=Spring.GetModOptions()or{}
local enabled=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled
if not enabled(options.prototype_squad_paid_fixture)then return false end
if not gadgetHandler:IsSyncedCode()then
 local closeAt
 local function done(_,result)
  Spring.Echo('40K_SQUAD_PAID owned_fixture_autoclose '..tostring(result))
  closeAt=Spring.GetGameFrame()+90
 end
 function gadget:Initialize()gadgetHandler:AddSyncAction('fortyk_squad_paid_done',done)end
 function gadget:GameFrame(frame)if closeAt and frame>=closeAt then closeAt=nil;Spring.SendCommands('quitforce')end end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction('fortyk_squad_paid_done')end
 return
end
local S=Spring;local phase='initial';local startFrame;local team=0
local family=options.prototype_squad_paid_faction or'marine'
local routes={
 marine={commander='smcom',factory='imp_marine_barracks',product='imp_marine',profile='marine_tactical'},
 guard={commander='armcom',factory='imp_barracks',product='imp_guardsman',profile='guard_line'},
 ork={commander='corcom',factory='ork_boyz_hut',product='ork_boy',profile='ork_shoota'},
 necron={commander='nec_lord',factory='nec_hq',product='nec_warrior',profile='necron_warrior'}}
local route=routes[family];local profile,capacity,bodyCost
local commander,factory,site,stance,seed,deadLeader,missingSlot,deliveryFrame
local bornFactory,bornProduct;local originalMembers={};local initialMetal,initialEnergy
local pendingFinish,pendingSince
function gadget:Initialize()
 GG.Recoil40KSquadPaidFixture={CheckpointContext=function()
  local originals={};for id,value in pairs(originalMembers)do originals[id]=value end
  return{phase=phase,seed=seed,commander=commander,missingSlot=missingSlot,team=team,originalMembers=originals,
   proof={paid_factory=not not(factory and bornFactory==factory),paid_full_squad=not not(seed and bornProduct),
    ordinary_start=not not(initialMetal and initialEnergy and math.abs(initialMetal-1000)<=5 and math.abs(initialEnergy-1000)<=5)}}
 end}
end
function gadget:Shutdown()GG.Recoil40KSquadPaidFixture=nil end
local timeout=1200*(Game.gameSpeed or 30)
local function emit(event,...)
 local a={...};for i=1,#a do a[i]=tostring(a[i])end
 S.Echo('40K_SQUAD_PAID '..event..' '..table.concat(a,' '))
end
local function resources(event)
 local m,ms,mp,mi,me=S.GetTeamResources(team,'metal')
 local e,es,ep,ei,ee=S.GetTeamResources(team,'energy')
 emit(event,'metal='..tostring(m),'energy='..tostring(e),'metal_income='..tostring(mi),'energy_income='..tostring(ei),
  'metal_expense='..tostring(me),'energy_expense='..tostring(ee),'income_in_snapshot=true net_delta_is_not_exact_cost=true')
 return m,e
end
local function finish(reason)
 if reason:match('^PASS ')and enabled(options.prototype_squad_save_checkpoint_fixture)then
  local observer=GG.Recoil40KSquadSaveCheckpoint
  local status=observer and observer.Status()
  if status=='failed'then reason='FAIL native_save_checkpoint_observer_failed'
  elseif status~='complete'then pendingFinish=reason;pendingSince=pendingSince or S.GetGameFrame();return end
 end
 if phase=='done'then return end;phase='done'
 resources('FINAL_RESOURCES')
 emit('COMPLETE',reason,'ordinary_resources_automation=true stock_launcher_hud_click_acceptance=false')
 SendToUnsynced('fortyk_squad_paid_done',reason)
end
local function live(id)
 if not id or S.GetUnitIsDead(id)then return false end
 local hp,_,_,_,p=S.GetUnitHealth(id);return hp and hp>0 and p and p>=1
end
local function contains(t,value)for _,v in ipairs(t or{})do if v==value then return true end end;return false end
local function costs(d,m,e,w)
 return d and math.abs(d.metalCost-m)<.001 and math.abs(d.energyCost-e)<.001 and math.abs(d.buildTime-w)<.001
end
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
function gadget:UnitCreated(id,def,unitTeam,builder)
 if unitTeam~=team then return end
 if phase=='build_factory'and def==UnitDefNames[route.factory].id then
  if builder~=commander or bornFactory then finish('FAIL factory_not_single_commander_paid_birth');return end
  bornFactory=id;emit('FACTORY_BIRTH','builder='..builder,'native_incomplete='..tostring(select(5,S.GetUnitHealth(id))))
 elseif phase=='queue_product'and def==UnitDefNames[route.product].id then
  if builder~=factory or bornProduct then finish('FAIL product_not_single_factory_paid_birth');return end
  bornProduct=id;emit('PRODUCT_BIRTH','builder='..builder)
 end
end
function gadget:GameFrame(frame)
 if phase=='done'then return end
 if pendingFinish then
  if frame-pendingSince>=300 then pendingFinish=nil;finish('FAIL native_save_checkpoint_terminal_timeout');return end
  finish(pendingFinish);return
 end
 if not startFrame then startFrame=frame end
 if frame-startFrame>timeout then finish('FAIL timeout phase='..phase);return end
 if phase=='initial'then
  if not route then finish('FAIL unsupported_faction '..tostring(family));return end
  local profiles=VFS.Include('40k_configs/active_squad_profiles.lua')
  profile=profiles.profiles[route.profile]
  if not profile or profile.product~=route.product then finish('FAIL family_profile_not_active');return end
  capacity=profile.capacity
  for _,key in ipairs({route.commander,route.factory,route.product,profile.member})do if not UnitDefNames[key]then finish('FAIL missing_family_definition '..key);return end end
  if enabled(options.prototype_squad_fixture)then finish('FAIL funded_fixture_conflict');return end
  initialMetal,initialEnergy=resources('INITIAL_RESOURCES')
  if not initialMetal or math.abs(initialMetal-1000)>5 or not initialEnergy or math.abs(initialEnergy-1000)>5 then finish('FAIL not_ordinary_1000_start');return end
  local units=S.GetTeamUnits(team)or{}
  if #units~=1 or S.GetUnitDefID(units[1])~=UnitDefNames[route.commander].id or not live(units[1])then finish('FAIL need_natural_single_commander '..route.commander);return end
  commander=units[1]
  local cd=UnitDefs[S.GetUnitDefID(commander)];local fd=UnitDefNames[route.factory];local pd=UnitDefNames[route.product]
  local member=UnitDefs[UnitDefNames[profile.member].id]
  bodyCost={metal=member.metalCost,energy=member.energyCost,work=member.buildTime}
  if not UnitDefs[fd.id].isFactory then finish('FAIL unsupported_native_factory_classification '..route.factory);return end
  if not contains(cd.buildOptions,fd.id)or not contains(UnitDefs[fd.id].buildOptions,pd.id)then finish('FAIL native_constructor_menu');return end
  local product=UnitDefs[pd.id];local cp=product.customParams or{}
  if cp.prototype40k_squad_product~=route.profile or tonumber(cp.prototype40k_squad_capacity)~=capacity
   or not costs(product,bodyCost.metal*capacity,bodyCost.energy*capacity,bodyCost.work*capacity)then finish('FAIL wrong_full_product_cost');return end
  emit('ROUTE','faction='..family,'commander='..route.commander,'factory='..route.factory,'product='..route.product,'capacity='..capacity,
   'factory_xsize='..UnitDefs[fd.id].xsize,'factory_zsize='..UnitDefs[fd.id].zsize,'native_factory_classification=true')
  if not GG.Recoil40KSquads or next(GG.Recoil40KSquads.squads)then finish('FAIL missing_or_preexisting_squad');return end
  site,stance=chooseSite(fd.id);if not site then finish('FAIL no_clear_native_factory_site');return end
  -- As in ordinary player placement, the native build command owns approach,
  -- range, clearance and birth. A fixture MOVE tolerance must not place the
  -- builder inside its own future yard before issuing the build command.
  phase='build_factory';resources('FACTORY_ORDER_RESOURCES')
  S.GiveOrderToUnit(commander,-fd.id,site,0)
  emit('FACTORY_BUILD_ORDER','native_build_order=true native_approach=true','commander='..commander,'site_x='..site[1],'site_z='..site[3])
 elseif phase=='build_factory'then
  if bornFactory and live(bornFactory)then
   factory=bornFactory
   if not contains(UnitDefs[S.GetUnitDefID(factory)].buildOptions,UnitDefNames[route.product].id)then finish('FAIL completed_factory_menu');return end
   phase='queue_product';resources('PRODUCT_ORDER_RESOURCES')
   S.GiveOrderToUnit(factory,-UnitDefNames[route.product].id,{},0)
   emit('QUEUE','exactly_one=true metal_cost='..bodyCost.metal*capacity,'energy_cost='..bodyCost.energy*capacity,'native_work='..bodyCost.work*capacity,'no_acceleration=true')
  end
 elseif phase=='queue_product'then
  local R=GG.Recoil40KSquads
  if bornProduct then
   local s=R.Get(bornProduct)
   if s then
    if s.team~=team or s.profile~=route.profile or #R.Members(s.leader)~=capacity then finish('FAIL partial_or_wrong_delivery');return end
    seed=s.id;deadLeader=s.leader
    for slot,id in pairs(s.slots)do
     if not live(id)or originalMembers[id]then finish('FAIL not_full_distinct_live_actors');return end
     if S.GetUnitMass then
      local mass=S.GetUnitMass(id);local expected=UnitDefs[UnitDefNames[profile.member].id].mass
      emit('BODY_MASS','unit='..id,'slot='..slot,'actual='..tostring(mass),'ordinary_body='..tostring(expected))
      if type(mass)~='number'or type(expected)~='number'or math.abs(mass-expected)>.001 then finish('FAIL aggregate_price_inflated_body_mass');return end
     end
     originalMembers[id]=true;if id==deadLeader then missingSlot=slot end
    end
    resources('DELIVERY_RESOURCES');emit('DELIVERY','members='..capacity,'native_factory_product='..bornProduct,'full_native_product_cost=true')
    S.GiveOrderToUnit(s.leader,CMD.STOP,{},0);S.GiveOrderToUnit(s.leader,CMD.FIRE_STATE,{0},0)
    phase='delivery_checkpoint';deliveryFrame=frame
    emit('DELIVERY_CHECKPOINT','native_frames=30 owned_capture_grace=true no_health_or_cost_changes=true')
   elseif S.GetUnitRulesParam(bornProduct,'40k_squad_delivery_failed')==1 then finish('FAIL delivery_refused')end
  end
 elseif phase=='delivery_checkpoint'then
  local tags=GG.Recoil40KSquadOrderTagsFixture
  if tags then local hold,result=tags.Hold(GG.Recoil40KSquadPaidFixture.CheckpointContext(),frame);if result then finish(result);return end;if hold then return end end
  local gait=GG.Recoil40KGaitMovementFixture
  if gait and gait.HoldPaidCheckpoint(GG.Recoil40KSquadPaidFixture.CheckpointContext(),frame)then
   if GG.Recoil40KNativeGaitObserve then GG.Recoil40KNativeGaitObserve(frame)end
   return
  end
  if frame-deliveryFrame>=30 then
   local R=GG.Recoil40KSquads;local s=R.squads[seed]
   if not s or #R.Members(s.leader)~=capacity or not live(deadLeader)then finish('FAIL full_squad_lost_during_checkpoint');return end
   phase='casualty'
   local hp=S.GetUnitHealth(deadLeader)
   S.AddUnitDamage(deadLeader,hp*4+10000,0,nil,-1)
   emit('CASUALTY_DAMAGE','leader='..deadLeader,'native_damage=true scripted_casualty=true weapon_combat_acceptance=false')
  end
 elseif phase=='casualty'then
  local R=GG.Recoil40KSquads;local s=R.squads[seed]
  if not s or live(deadLeader)or s.leader==deadLeader or #R.Members(s.leader)~=capacity-1 or s.slots[missingSlot]then finish('FAIL leader_casualty_or_survivorship');return end
  if not live(commander)then finish('FAIL commander_lost');return end
  resources('REPAIR_ORDER_RESOURCES');phase='repair'
  S.GiveOrderToUnit(commander,CMD.REPAIR,{s.leader},0)
  emit('REPAIR_ORDER','normal_native_commander_repair=true surviving_leader='..s.leader)
 elseif phase=='repair'then
  local R=GG.Recoil40KSquads;local s=R.squads[seed]
  if not s or not live(commander)then finish('FAIL repair_owner_lost');return end
  if #R.Members(s.leader)==capacity then
   local new=s.slots[missingSlot];local c=s.investments[missingSlot]
   if not new or originalMembers[new]or not live(new)or s.generations[missingSlot]~=2 or not c
    or math.abs(c.metal-bodyCost.metal)>.001 or math.abs(c.energy-bodyCost.energy)>.001 or math.abs(c.work-bodyCost.work)>.001 then finish('FAIL distinct_paid_body_receipt');return end
   for _,id in ipairs(R.Members(s.leader))do if id~=new and not originalMembers[id]then finish('FAIL survivor_replaced');return end end
   S.GiveOrderToUnit(commander,CMD.STOP,{},0)
   emit('RESTORE','members='..capacity,'distinct_new_body='..new,'generation=2 actual_owner_receipt_metal='..c.metal,'actual_owner_receipt_energy='..c.energy,'actual_owner_receipt_work='..c.work)
   finish('PASS paid_factory paid_full_squad real_leader_loss normal_repair distinct_paid_restoration')
  end
 end
 if frame%300==0 then emit('STATE','phase='..phase,'frame='..frame,'factory='..tostring(factory),'product='..tostring(bornProduct));resources('PERIODIC_RESOURCES')end
end

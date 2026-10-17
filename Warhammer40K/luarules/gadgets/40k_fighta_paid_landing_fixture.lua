function gadget:GetInfo()
 return{name='40K paid Fighta primary combat and native landing fixture',desc='Default-off physical landing after paid genuine Fighta combat',author='Local project',layer=157,enabled=true}
end
local options=Spring.GetModOptions()or{}
local function enabled(v)return v==true or v==1 or v=='1'end
if not enabled(options.prototype_fighta_paid_landing_fixture)then return false end
if not gadgetHandler:IsSyncedCode()then
 local closeAt
 local function done(_,reason)
  Spring.Echo('40K_FIGHTA_PAID_LANDING owned_fixture_autoclose '..tostring(reason))
  closeAt=Spring.GetGameFrame()+90
 end
 function gadget:Initialize()gadgetHandler:AddSyncAction('fortyk_fighta_paid_landing_done',done)end
 function gadget:GameFrame(frame)if closeAt and frame>=closeAt then closeAt=nil;Spring.SendCommands('quitforce')end end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction('fortyk_fighta_paid_landing_done')end
 return
end
local combatEnabled=true;local combat,landing;local productRetired=false
local S=Spring;local phase='initial';local started;local commander,factory,bornFactory,product,site,stance,release,origin,moveAt
local factoryKey='fortyk_ork_air_factory';local productKey='ork_fighta_bomba';local team=0
local function emit(event,...)
 local a={...};for i=1,#a do a[i]=tostring(a[i])end
 S.Echo('40K_FIGHTA_PAID_LANDING '..event..' '..table.concat(a,' '))
end
local function resources(event)
 local m,_,_,mi,me=S.GetTeamResources(team,'metal');local e,_,_,ei,ee=S.GetTeamResources(team,'energy')
 emit(event,'metal='..tostring(m),'energy='..tostring(e),'metal_income='..tostring(mi),'energy_income='..tostring(ei),'metal_expense='..tostring(me),'energy_expense='..tostring(ee),'net_delta_not_exact_cost=true');return m,e
end
local function finish(reason)
 if phase=='done'then return end;phase='done';if combat and combat.Close then combat.Close()end;if GG.Recoil40KStompaWeaponWitness==combat then GG.Recoil40KStompaWeaponWitness=nil end;resources('FINAL');emit('COMPLETE',reason,combatEnabled and'ordinary_paid_own_production_and_flight=true unpaid_enemy_target=true primary_and_physical_landing_only=true source_landing_pose_death_reclaim_unaccepted=true'or'ordinary_paid_flight_only=true weapon_combat_landing_water_gait_pending=true')
 SendToUnsynced('fortyk_fighta_paid_landing_done',reason)
end
local function live(id)
 if not id or S.GetUnitIsDead(id)then return false end
 local hp,_,_,_,p=S.GetUnitHealth(id);return hp and hp>0 and p and p>=1
end
local function contains(t,value)for _,v in ipairs(t or{})do if v==value then return true end end;return false end
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
local function chooseSite(def)
 local cx,_,cz=S.GetUnitPosition(commander);local cd=UnitDefs[S.GetUnitDefID(commander)]
 local range=cd.buildDistance;local fd=UnitDefs[def]
 for ring=6,18 do for j=0,15 do
  local angle=j*math.pi/8
  local x,y,z=S.Pos2BuildPos(def,cx+ring*32*math.cos(angle),0,cz+ring*32*math.sin(angle),0)
  y=S.GetGroundHeight(x,z)
  local status,feature=S.TestBuildOrder(def,x,y,z,0)
  if y>=0 and status==2 and not feature and clear(def,x,z)then
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
function gadget:UnitCreated(id,def,t,builder)
 if t~=team then return end
 if phase=='build_factory'and def==UnitDefNames[factoryKey].id then
  if builder~=commander or bornFactory then finish('FAIL duplicate_or_unpaid_factory');return end
  bornFactory=id;local _,_,_,_,progress=S.GetUnitHealth(id);emit('FACTORY_BIRTH',id,builder,progress)
 elseif phase=='queue_product'and def==UnitDefNames[productKey].id then
  if builder~=factory or product then finish('FAIL duplicate_or_unpaid_product');return end
  product=id;emit('PRODUCT_BIRTH',id,builder)
 end
end
function gadget:UnitFromFactory(id,def,t,producer)
 if product~=nil and id==product then
  if productRetired or t~=team or def~=UnitDefNames[productKey].id or producer~=factory or S.GetUnitDefID(id)~=def or S.GetUnitTeam(id)~=team or S.GetUnitIsDead(id)~=false then finish('FAIL original_paid_Fighta_release_identity');return end
  release=Spring.GetGameFrame();emit('NATIVE_RELEASE',id,producer,release)
 end
end
local function retireProduct(id,reason)
 if product~=nil and id==product then productRetired=true;if landing and landing.Retire then landing.Retire(id,reason)end;finish('FAIL original_paid_Fighta_'..reason)end
end
function gadget:UnitDestroyed(id)retireProduct(id,'destroyed')end
function gadget:UnitTaken(id)retireProduct(id,'taken')end
function gadget:UnitGiven(id)retireProduct(id,'given')end
function gadget:GameFrame(frame)
 if phase=='done'then return end
 if product~=nil and(productRetired or S.GetUnitIsDead(product)~=false or S.GetUnitDefID(product)~=UnitDefNames[productKey].id or S.GetUnitTeam(product)~=team)then finish('FAIL original_paid_Fighta_lost_transferred_or_replaced');return end
 if not started then started=frame end
 if frame-started>1200*(Game.gameSpeed or 30)then finish('INCONCLUSIVE ordinary_economy_timeout_'..phase);return end
 if phase=='initial'then
  for key,v in pairs(options)do if key:match('^prototype_.*fixture$')and key~='prototype_fighta_paid_landing_fixture'and enabled(v)then finish('FAIL other_fixture_conflict');return end end
  local m,e=resources('INITIAL');if not m or not e or math.abs(m-1000)>5 or math.abs(e-1000)>5 then finish('FAIL ordinary_1000_start_required');return end
  local units=S.GetTeamUnits(team)or{}
  if #units~=1 or not UnitDefNames.ork_big_mek_commander or S.GetUnitDefID(units[1])~=UnitDefNames.ork_big_mek_commander.id or not live(units[1])then finish('FAIL natural_single_Ork_commander_required');return end
  commander=units[1];local fd=UnitDefNames[factoryKey];local pd=UnitDefNames[productKey];local cd=UnitDefs[S.GetUnitDefID(commander)]
  if not fd or not pd or not contains(cd.buildOptions,fd.id)or not contains(UnitDefs[fd.id].buildOptions,pd.id)then finish('FAIL native_paid_build_menu');return end
  local gate=GG.Recoil40KResearch
  if not gate or not gate.CanBuild(team,fd.id,commander,false)then finish('FAIL active_paid_graph_gate');return end
  local f,p=UnitDefs[fd.id],UnitDefs[pd.id];local cp=p.customParams or{}
  if f.canFly or not f.isFactory or (f.customParams or{}).prototype40k_native_donor~='corap' or f.buildSpeed<=0 then finish('FAIL native_air_factory_contract');return end
  if not p.canFly or cp.animsource~=productKey or #p.weapons~=4 or tonumber(cp.prototype40k_ork_aircraft_domain)~=1 or math.abs(p.metalCost-140)>.001 or math.abs(p.energyCost-1400)>.001 or math.abs(p.buildTime-70*f.buildSpeed)>.001 then finish('FAIL genuine_flight_paid_bill');return end
  emit('BILLS','factory_metal='..f.metalCost,'factory_energy='..f.energyCost,'factory_work='..f.buildTime,'factory_power='..f.buildSpeed,'product_metal=140 product_energy=1400','product_work='..p.buildTime,'native_seconds_at_factory=70 four_mounts=true')
  site,stance=chooseSite(fd.id);if not site then finish('INCONCLUSIVE no_clear_reachable_site');return end
  phase='approach';S.GiveOrderToUnit(commander,CMD.MOVE,stance,0)
 elseif phase=='approach'then
  if not live(commander)then finish('FAIL commander_lost');return end
  local x,y,z=S.GetUnitPosition(commander)
  if(x-stance[1])^2+(z-stance[3])^2<=24^2 then
   local d=UnitDefNames[factoryKey];local status,feature=S.TestBuildOrder(d.id,site[1],site[2],site[3],0)
   local range=UnitDefs[S.GetUnitDefID(commander)].buildDistance
   if status~=2 or feature or not clear(d.id,site[1],site[3])or(x-site[1])^2+(y-site[2])^2+(z-site[3])^2>range^2 then finish('FAIL build_site_changed');return end
   phase='build_factory';resources('FACTORY_ORDER');S.GiveOrderToUnit(commander,-d.id,site,0)
  end
 elseif phase=='build_factory'then
  if bornFactory and live(bornFactory)then factory=bornFactory
   if not GG.Recoil40KResearch.CanBuild(team,UnitDefNames[productKey].id,factory,false)then finish('FAIL paid_product_gate');return end
   phase='queue_product';resources('PRODUCT_ORDER');S.GiveOrderToUnit(factory,-UnitDefNames[productKey].id,{},0);emit('QUEUE','exactly_one=true unmodified_native_command=true')end
 elseif phase=='queue_product'then
  if product and release and live(product)then
   local x,y,z=S.GetUnitPosition(product);origin={x,y,z};moveAt=frame
   local tx=x<Game.mapSizeX/2 and math.min(Game.mapSizeX-96,x+640)or math.max(96,x-640)
   local tz=z<Game.mapSizeZ/2 and math.min(Game.mapSizeZ-96,z+640)or math.max(96,z-640)
   if(tx-x)^2+(tz-z)^2<256^2 then finish('INCONCLUSIVE map_too_small');return end
   phase='flight';resources('DELIVERED');S.GiveOrderToUnit(product,CMD.MOVE,{tx,S.GetGroundHeight(tx,tz),tz},0)
   emit('FLIGHT_ORDER',product,x,y,z,'initial_ground='..S.GetGroundHeight(x,z),tx,tz,'native_release='..release)
  end
 elseif phase=='flight'then
  if not live(product)then finish('FAIL aircraft_lost');return end
  local x,y,z=S.GetUnitPosition(product);local ground=S.GetGroundHeight(x,z);local distance=math.sqrt((x-origin[1])^2+(z-origin[3])^2);local altitude=y-ground
  if frame%15==0 then local vx,vy,vz=S.GetUnitVelocity(product);emit('FLIGHT_SAMPLE',frame,x,y,z,'ground='..ground,'altitude='..altitude,'travel='..distance,vx,vy,vz)end
  if frame-moveAt>=90 and distance>=256 and altitude>=40 then
   if not combatEnabled then finish('PASS paid_native_factory paid_genuine_Fighta native_release normal_MOVE_airborne_travel')
   else
    if GG.Recoil40KStompaWeaponWitness then finish('FAIL existing_weapon_witness');return end
    emit('FLIGHT_PASS','paid_native_release=true travel='..distance,'altitude='..altitude,'combat_native_pending=true')
    combat=VFS.Include('40k_configs/ork_paid_air_combat_fixture.lua').New(S,UnitDefs,WeaponDefs,product,team,frame,function(...)emit(...)end)
    if combat.result then finish(combat.result);return end
    Script.SetWatchProjectile(combat.weapon,true)
    GG.Recoil40KStompaWeaponWitness=combat;phase='combat'
   end
  end
 elseif phase=='combat'then
  local result=combat.Step and combat.Step(frame)or combat.result
  if result then
   if result:match('^PASS')then
    emit('PAID_PRIMARY_COMBAT_PASS',result,'landing_native_pending=true remains_entitlement_absent=true')
    combat.Close();if GG.Recoil40KStompaWeaponWitness==combat then GG.Recoil40KStompaWeaponWitness=nil end
    landing=VFS.Include('40k_configs/fighta_native_landing_fixture.lua').New(S,UnitDefs,product,team,frame,emit)
    if landing.result then finish(landing.result);return end
    phase='landing'
   else finish(result)end
  end
 elseif phase=='landing'then
  local result=landing.Step(frame);if result then finish(result)end
 end
end

function gadget:ProjectileCreated(pid,owner,weapon)if combat and combat.Projectile then combat.Projectile(pid,owner,weapon)end end
function gadget:UnitDamaged(id,def,owner,damage,para,weapon,pid,attacker)if combat and combat.Damaged then combat.Damaged(id,damage,para,weapon,pid,attacker)end end
function gadget:Shutdown()if combat and combat.Close then combat.Close()end;if GG.Recoil40KStompaWeaponWitness==combat then GG.Recoil40KStompaWeaponWitness=nil end end

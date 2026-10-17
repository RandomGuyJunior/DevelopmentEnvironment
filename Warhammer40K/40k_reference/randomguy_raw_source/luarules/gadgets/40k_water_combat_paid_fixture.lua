function gadget:GetInfo()
 return{name='40K paid water torpedo and native salvage fixture',desc='Default-off paid shipyard constructor tidal torpedo then funded-enemy native combat/salvage',author='Local project',layer=158,enabled=true}
end
local options=Spring.GetModOptions()or{}
local function enabled(v)return v==true or v==1 or v=='1'end
if not enabled(options.prototype_water_combat_paid_fixture)then return false end
if not gadgetHandler:IsSyncedCode()then
 local closeAt
 local function done(_,reason)Spring.Echo('40K_WATER_COMBAT_PAID owned_fixture_autoclose '..tostring(reason));closeAt=Spring.GetGameFrame()+90 end
 function gadget:Initialize()gadgetHandler:AddSyncAction('fortyk_water_combat_paid_done',done)end
 function gadget:GameFrame(frame)if closeAt and frame>=closeAt then closeAt=nil;Spring.SendCommands('quitforce')end end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction('fortyk_water_combat_paid_done')end
 return
end
local combat;local S=Spring;local phase='initial';local team=0;local start;local commander,factory,boat,tidal,release,outputSince
local site,stance;local keyFactory='fortyk_ork_naval_factory';local keyBoat='fortyk_ork_naval_constructor';local keyTide='fortyk_ork_water_tidal_generator'
local function emit(event,...)local a={...};for i=1,#a do a[i]=tostring(a[i])end;S.Echo('40K_WATER_COMBAT_PAID '..event..' '..table.concat(a,' '))end
local function resources(event)
 local m,_,_,mi,me=S.GetTeamResources(team,'metal');local e,_,_,ei,ee=S.GetTeamResources(team,'energy')
 emit(event,'metal='..tostring(m),'energy='..tostring(e),'metal_income='..tostring(mi),'energy_income='..tostring(ei),'metal_expense='..tostring(me),'energy_expense='..tostring(ee),'net_delta_not_exact_cost=true');return m,e
end
local function finish(reason)if phase=='done'then return end;phase='done';if combat and combat.Close then combat.Close()end;resources('FINAL');emit('COMPLETE',reason,'ordinary_paid_own_production=true funded_enemy_combat_salvage_non_economy=true deepwater_mex_render_pending=true');SendToUnsynced('fortyk_water_combat_paid_done',reason)end
local function live(id)if not id or S.GetUnitIsDead(id)then return false end;local hp,_,_,_,p=S.GetUnitHealth(id);return hp and hp>0 and p and p>=1 end
local function has(d,id)for _,v in ipairs(d.buildOptions or{})do if v==id then return true end end;return false end
local function bill(d,m,e,w)return math.abs(d.metalCost-m)<.001 and math.abs(d.energyCost-e)<.001 and math.abs(d.buildTime-w)<.001 end
local function clear(def,x,z,builder)
 local d=UnitDefs[def];local hx,hz=d.xsize*4,d.zsize*4
 if x-hx<64 or z-hz<64 or x+hx>Game.mapSizeX-64 or z+hz>Game.mapSizeZ-64 then return false end
 for _,id in ipairs(S.GetUnitsInRectangle(x-hx-32,z-hz-32,x+hx+32,z+hz+32)or{})do
  if id~=builder then return false end
  local bx,_,bz=S.GetUnitPosition(id);local bd=UnitDefs[S.GetUnitDefID(id)]
  if math.abs(bx-x)<hx+bd.xsize*4+8 and math.abs(bz-z)<hz+bd.zsize*4+8 then return false end
 end
 return #(S.GetFeaturesInRectangle(x-hx-16,z-hz-16,x+hx+16,z+hz+16)or{})==0
end
local function choose(builder,def)
 local cx,_,cz=S.GetUnitPosition(builder);local cd=UnitDefs[S.GetUnitDefID(builder)];local fd=UnitDefs[def];local range=cd.buildDistance
 for ring=4,24 do for j=0,23 do
  local a=j*math.pi/12;local x,y,z=S.Pos2BuildPos(def,cx+ring*32*math.cos(a),0,cz+ring*32*math.sin(a),0)
  local ground=S.GetGroundHeight(x,z);local status,feature=S.TestBuildOrder(def,x,y,z,0)
  if ground<=-fd.minWaterDepth and status==2 and not feature and clear(def,x,z,builder)then
   for k=0,23 do
    local angle=k*math.pi/12;local sx,sz=x+(range-24)*math.cos(angle),z+(range-24)*math.sin(angle);local sy=S.GetGroundHeight(sx,sz)
    local waterOK=builder==boat and sy<=-cd.minWaterDepth or builder~=boat and sy>=-(cd.maxWaterDepth or 0)
    local outside=math.abs(sx-x)>=fd.xsize*4+cd.xsize*4+8 or math.abs(sz-z)>=fd.zsize*4+cd.zsize*4+8
    if waterOK and outside and sx>32 and sz>32 and sx<Game.mapSizeX-32 and sz<Game.mapSizeZ-32 and S.TestMoveOrder(cd.id,sx,sy,sz,0,0,0,true,true,false)then return{x,y,z,0},{sx,sy,sz}end
   end
  end
 end end
end
local function arrived(builder,def)
 if not live(builder)then finish('FAIL builder_lost');return false end
 local x,y,z=S.GetUnitPosition(builder);if(x-stance[1])^2+(z-stance[3])^2>24^2 then return false end
 local status,feature=S.TestBuildOrder(def,site[1],site[2],site[3],0);local range=UnitDefs[S.GetUnitDefID(builder)].buildDistance
 if status~=2 or feature or not clear(def,site[1],site[3],builder)or(x-site[1])^2+(y-site[2])^2+(z-site[3])^2>range^2 then finish('INCONCLUSIVE legal_site_or_range_changed');return false end
 return true
end
function gadget:UnitCreated(id,def,t,builder)
 if combat then combat.UnitCreated(id,def,t,builder)end
 if t~=team then return end
 if phase=='factory'and def==UnitDefNames[keyFactory].id then if factory or builder~=commander then finish('FAIL factory_paid_owner');return end;factory=id;emit('FACTORY_BIRTH',id,builder)
 elseif phase=='boat'and def==UnitDefNames[keyBoat].id then if boat or builder~=factory then finish('FAIL boat_paid_owner');return end;boat=id;emit('BOAT_BIRTH',id,builder)
 elseif phase=='tidal'and def==UnitDefNames[keyTide].id then if tidal or builder~=boat then finish('FAIL tidal_paid_owner');return end;tidal=id;emit('TIDAL_BIRTH',id,builder)end
end
function gadget:UnitFromFactory(id,def,t,producer)if t==team and id==boat and producer==factory then release=S.GetGameFrame();emit('NATIVE_BOAT_RELEASE',id,producer,release)end end
function gadget:GameFrame(frame)
 if phase=='done'then return end;if not start then start=frame end
 if frame-start>1200*(Game.gameSpeed or 30)then finish('INCONCLUSIVE ordinary_economy_timeout_'..phase);return end
 if phase=='initial'then
  for k,v in pairs(options)do if k:match('^prototype_.*fixture$')and k~='prototype_water_combat_paid_fixture'and enabled(v)then finish('FAIL conflicting_fixture');return end end
  local tide=S.GetTidal();if not tide or tide<=0 then finish('INCONCLUSIVE map_has_no_positive_tidal_income');return end
  local m,e=resources('INITIAL');if not m or not e or math.abs(m-1000)>5 or math.abs(e-1000)>5 then finish('FAIL ordinary_1000_start_required');return end
  local units=S.GetTeamUnits(team)or{};if #units~=1 or not UnitDefNames.corcom or S.GetUnitDefID(units[1])~=UnitDefNames.corcom.id or not live(units[1])then finish('FAIL natural_Ork_commander_required');return end;commander=units[1]
  local fn,bn,tn=UnitDefNames[keyFactory],UnitDefNames[keyBoat],UnitDefNames[keyTide]
  if not fn or not bn or not tn then finish('FAIL missing_active_domain');return end
  local f,b,t=UnitDefs[fn.id],UnitDefs[bn.id],UnitDefs[tn.id];local cd=UnitDefs[S.GetUnitDefID(commander)]
  if not has(cd,fn.id)or not has(f,bn.id)or not has(b,tn.id)or not GG.Recoil40KResearch or not GG.Recoil40KResearch.CanBuild(team,fn.id,commander,false)then finish('FAIL native_route_or_paid_gate');return end
  if (f.customParams or{}).prototype40k_native_donor~='corsy'or(b.customParams or{}).prototype40k_native_donor~='corcs'or(t.customParams or{}).prototype40k_native_donor~='cortide'or(t.customParams or{}).source_resource_role~='energy'or f.buildSpeed~=150 or b.buildSpeed~=125 or not f.isFactory or f.minWaterDepth~=30 or b.canFly or b.minWaterDepth~=15 or b.buildDistance~=200 or t.minWaterDepth~=20 or not bill(f,450,950,5100)or not bill(b,200,2000,3700)or not bill(t,85,250,2100)then finish('FAIL unchanged_native_water_bills_or_placement');return end
  emit('BILLS','factory=450M950E5100work boat=200M2000E3700work tidal=85M250E2100work total=735M3200E','factory_power='..f.buildSpeed,'boat_power='..b.buildSpeed,'map_tidal='..tide)
  site,stance=choose(commander,fn.id);if not site then finish('INCONCLUSIVE no_reachable_clear_coastal_shipyard_site');return end
  phase='approach_factory';S.GiveOrderToUnit(commander,CMD.MOVE,stance,0)
 elseif phase=='approach_factory'then
  if arrived(commander,UnitDefNames[keyFactory].id)then phase='factory';resources('FACTORY_ORDER');S.GiveOrderToUnit(commander,-UnitDefNames[keyFactory].id,site,0)end
 elseif phase=='factory'then
  if factory and live(factory)then
   if not GG.Recoil40KResearch.CanBuild(team,UnitDefNames[keyBoat].id,factory,false)then finish('FAIL paid_boat_gate');return end
   phase='boat';resources('BOAT_ORDER');S.GiveOrderToUnit(factory,-UnitDefNames[keyBoat].id,{},0)
  end
 elseif phase=='boat'then
  if boat and release and live(boat)then
   if not has(UnitDefs[S.GetUnitDefID(boat)],UnitDefNames[keyTide].id)or not GG.Recoil40KResearch.CanBuild(team,UnitDefNames[keyTide].id,boat,false)then finish('FAIL active_tidal_menu_or_gate');return end
   site,stance=choose(boat,UnitDefNames[keyTide].id);if not site then finish('INCONCLUSIVE no_reachable_clear_tidal_site');return end
   phase='approach_tidal';S.GiveOrderToUnit(boat,CMD.MOVE,stance,0);emit('BOAT_DEPARTURE',boat,stance[1],stance[3])
  end
 elseif phase=='approach_tidal'then
  if arrived(boat,UnitDefNames[keyTide].id)then phase='tidal';resources('TIDAL_ORDER');S.GiveOrderToUnit(boat,-UnitDefNames[keyTide].id,site,0)end
 elseif phase=='tidal'then
  if tidal and live(tidal)then phase='output';resources('TIDAL_COMPLETE');emit('TIDAL_POSITION',tidal,site[1],site[2],site[3],'ground='..S.GetGroundHeight(site[1],site[3]))end
 elseif phase=='combat'then
  local result=combat.Step(frame);if result then finish(result)end
 elseif phase=='output'then
  if not live(tidal)then finish('FAIL tidal_lost');return end
  local mm,mu,em,eu=S.GetUnitResources(tidal)
  if em and em>0 then
   if not outputSince then outputSince=frame end
   if frame%30==0 then emit('ACTUAL_UNIT_OUTPUT',frame,tidal,'metal_make='..tostring(mm),'energy_make='..em,'energy_use='..tostring(eu),'native_unit_resources=true')end
   if frame-outputSince>=90 then
    emit('PAID_WATER_ROUTE_PASS','native_shipyard_constructor_tidal_output=true combat_pending=true')
    combat=VFS.Include('40k_configs/water_torpedo_reclaim_fixture.lua').New(S,UnitDefs,WeaponDefs,FeatureDefs,boat,team,frame,
     function(def)site,stance=choose(boat,def);return site,stance end,function(def)return arrived(boat,def)end,emit)
    if combat.result then finish(combat.result);return end
    Script.SetWatchProjectile(combat.weapon,true);phase='combat'
   end
  else outputSince=nil end
 end
end

function gadget:ProjectileCreated(id,owner,weapon)if combat then combat.Projectile(id,owner,weapon)end end
function gadget:UnitDamaged(id,def,team,damage,para,weapon,pid,attacker)if combat then combat.Damaged(id,damage,para,weapon,pid,attacker)end end
function gadget:UnitDestroyed(id,def,team,attacker)if combat then combat.UnitDestroyed(id,attacker)end end
function gadget:FeatureCreated(id)if combat then combat.FeatureCreated(id)end end
function gadget:FeatureDestroyed(id)if combat then combat.FeatureDestroyed(id)end end
function gadget:AllowFeatureBuildStep(id,team,f,def,part)if combat then combat.BuildStep(id,team,f,part)end;return true end
function gadget:Shutdown()if combat and combat.Close then combat.Close()end end

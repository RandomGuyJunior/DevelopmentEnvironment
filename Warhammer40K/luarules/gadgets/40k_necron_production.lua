function gadget:GetInfo()
 return {name='40K genuine Necron paid production',desc='Opt-in native commander/economy/factory provenance and egress proof',author='Local project',layer=108,enabled=true}
end
if not gadgetHandler:IsSyncedCode() then return end
if Spring.GetModOptions().prototype_diagnostic~='expandedproduction' then return end
if VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(Spring.GetModOptions().prototype_source_progression) then return end
local lord,team,base,startFrame
local state='waiting'
local tasks,index,active={},1,nil
local births,finished,structures,factories,products={},{},{},{},{}
local queueNames,queueExpected={},{}
local mexSites,sites={},{}
local initialIncome,initialStorage
local foundationIncomeVerified=false
local completion,lastProgress=0,0
local ECON_MEXES,ECON_GENERATORS=4,8
local TIMEOUT=30*1800 -- Native resource starvation is a failure, never repaired by grants.
local function log(...) Spring.Echo('40K NECRON PRODUCTION',...) end
local function result(ok,why)
 if state=='done' then return end
 state='done';Spring.SetGameRulesParam('40k_necron_production_result',ok and 1 or -1)
 log(ok and 'PASS' or 'FAIL',why,Spring.GetGameFrame(),completion)
end
local function option(def,name)
 for _,id in ipairs(UnitDefs[def].buildOptions or {}) do if UnitDefs[id].name==name then return id end end
end
local function id(name)return UnitDefNames[name] and UnitDefNames[name].id end
local function income()
 local _,_,_,metal=Spring.GetTeamResources(team,'metal')
 local _,_,_,energy=Spring.GetTeamResources(team,'energy')
 return metal or 0,energy or 0
end
local function valid(unit)
 return unit and Spring.ValidUnitID(unit) and not Spring.GetUnitIsDead(unit)
end
local function clearSite(def,x,z,metal)
 local best,bestScore
 for ring=0,24 do
  for step=0,15 do
   local a=step*math.pi/8
   local xx=math.floor((x+ring*32*math.cos(a))/16)*16+8
   local zz=math.floor((z+ring*32*math.sin(a))/16)*16+8
   if xx>96 and zz>96 and xx<Game.mapSizeX-96 and zz<Game.mapSizeZ-96 then
    local y=Spring.GetGroundHeight(xx,zz);local clear=y>=5
    for _,p in ipairs(sites) do if (xx-p[1])^2+(zz-p[3])^2<128^2 then clear=false end end
    for _,p in pairs(factories) do
     if math.abs(xx-p.x)<180 and zz>p.z-100 and zz<p.z+500 then clear=false end
    end
    if clear and Spring.TestBuildOrder(def,xx,y,zz,0)==2 then
     local m=select(3,Spring.GetGroundInfo(xx,zz)) or 0
     if not metal or m>0 then
      local score=(xx-x)^2+(zz-z)^2
      if not bestScore or score<bestScore then best,bestScore={xx,y,zz,0},score end
     end
    end
   end
  end
  if best then return best end
 end
end
local function metalSite(def)
 local candidates={}
 for x=math.max(96,base[1]-1500),math.min(Game.mapSizeX-96,base[1]+1500),32 do
  for z=math.max(96,base[3]-1500),math.min(Game.mapSizeZ-96,base[3]+1500),32 do
   local metal=select(3,Spring.GetGroundInfo(x,z)) or 0
   if metal>0 then candidates[#candidates+1]={x,z,(x-base[1])^2+(z-base[3])^2} end
  end
 end
 table.sort(candidates,function(a,b)if a[3]~=b[3] then return a[3]<b[3] end;if a[1]~=b[1] then return a[1]<b[1] end;return a[2]<b[2] end)
 for _,p in ipairs(candidates) do
  local separated=true
  for _,old in ipairs(mexSites) do if (p[1]-old[1])^2+(p[2]-old[3])^2<180^2 then separated=false end end
  if separated then
   local found=clearSite(def,p[1],p[2],true)
   if found then mexSites[#mexSites+1]=found;return found end
  end
 end
end
local function usableGeothermal()
 if not Spring.GetAllFeatures or not FeatureDefs then return nil end
 local vents={}
 for _,feature in ipairs(Spring.GetAllFeatures() or {}) do
  local fd=FeatureDefs[Spring.GetFeatureDefID(feature)]
  if fd and fd.geoThermal then
   local x,y,z=Spring.GetFeaturePosition(feature)
   vents[#vents+1]={x,Spring.GetGroundHeight(x,z),z,0,distance=(x-base[1])^2+(z-base[3])^2,feature=feature}
  end
 end
 if #vents==0 then return nil end
 local def=id('nec_thermo')
 if not def then return nil,'real_vent_but_thermo_definition_missing' end
 if not UnitDefs[def].needGeo then return nil,'thermo_missing_native_needGeo_flag' end
 table.sort(vents,function(a,b)if a.distance~=b.distance then return a.distance<b.distance end;return a.feature<b.feature end)
 for _,vent in ipairs(vents) do
  if Spring.TestBuildOrder(def,vent[1],vent[2],vent[3],0)==2 then return {vent[1],vent[2],vent[3],0} end
 end
 return nil
end
local function queueFactory(unit,def,name)
 Spring.GiveOrderToUnit(unit,CMD.REPEAT,{0},{})
 if queueExpected[unit] then return end
 local expected={};queueExpected[unit]=expected
 local x,_,z=Spring.GetUnitPosition(unit)
 factories[name]={unit=unit,x=x,z=z}
 for _,product in ipairs(UnitDefs[def].buildOptions or {}) do
  local ud=UnitDefs[product];local cp=ud.customParams or {}
  if (ud.speed or 0)>0 and cp.faction=='Necrons' and tostring(cp.prototype40k)=='1' then
   if not option(def,ud.name) then result(false,'factory_missing_option_'..ud.name);return end
   expected[product]=(expected[product] or 0)+1;queueNames[ud.name]=true
   -- Native factory builds append; SHIFT requests five copies, not queueing.
   Spring.GiveOrderToUnit(unit,-product,{}, {})
   log('PAID_QUEUE',name,ud.name,ud.metalCost,ud.energyCost,ud.buildTime,(ud.buildTime or 0)/math.max(1,UnitDefs[def].buildSpeed or 0))
  end
 end
end
local function builderFor(task)
 if task.scarab then
  for unit in pairs(products) do if valid(unit) and UnitDefs[Spring.GetUnitDefID(unit)].name=='nec_scarab' then return unit end end
  return nil
 end
 return lord
end
local function issue(f)
 local task=tasks[index]
 if not task then return end
 local builder=builderFor(task)
 if not builder then return end
 if not valid(builder) then result(false,'builder_lost_'..task.name);return end
 local def=option(Spring.GetUnitDefID(builder),task.name)
 if not def then result(false,'real_builder_cannot_build_'..task.name);return end
 local site
 if task.site then
  if Spring.TestBuildOrder(def,task.site[1],task.site[2],task.site[3],0)==2 then site=task.site end
 elseif task.name=='nec_mex' then site=metalSite(def)
 else site=clearSite(def,base[1]+task.x,base[3]+task.z,false) end
 if not site then result(false,'no_native_build_site_'..task.name);return end
 sites[#sites+1]=site;active={def=def,builder=builder,site=site,frame=f,name=task.name,created=nil}
 Spring.GiveOrderToUnit(builder,-def,site,{})
 log('PAID_BUILD',task.name,builder,site[1],site[3],f)
end
local function feasibility()
 local metal,energy,seconds=0,0,0
 local lordDef=UnitDefs[Spring.GetUnitDefID(lord)]
 local lordPower=lordDef.buildSpeed or 0
 if lordPower<=0 or (lordDef.speed or 0)<=0 then return false,'native_lord_builder_or_movement_invalid' end
 if not id('nec_scarab') or (UnitDefs[id('nec_scarab')].buildSpeed or 0)<=0 then return false,'native_scarab_buildpower_invalid' end
 for _,task in ipairs(tasks) do
  local def=id(task.name);local ud=def and UnitDefs[def]
  if not ud then return false,'missing_definition_'..task.name end
  if (ud.metalCost or 0)<=0 or (ud.buildTime or 0)<=0 then return false,'invalid_paid_cost_'..task.name end
  local builderDef=task.scarab and id('nec_scarab') or Spring.GetUnitDefID(lord)
  if not option(builderDef,task.name) then return false,'native_constructor_menu_missing_'..task.name end
  metal=metal+ud.metalCost;energy=energy+(ud.energyCost or 0);seconds=seconds+ud.buildTime/(UnitDefs[builderDef].buildSpeed or lordPower)
 end
 local mobile={}
 for _,name in ipairs({'nec_hq','nec_core','nec_greater_core'}) do
  local def=id(name);local ud=def and UnitDefs[def]
  if not ud or (ud.buildSpeed or 0)<=0 then return false,'factory_no_native_buildpower_'..name end
  for _,product in ipairs(ud.buildOptions or {}) do
   local p=UnitDefs[product]
   if (p.speed or 0)>0 then
    if not id(p.name) or (p.metalCost or 0)<=0 or (p.buildTime or 0)<=0 then return false,'invalid_mobile_'..p.name end
    if not mobile[p.name] then mobile[p.name]=true;metal=metal+p.metalCost;energy=energy+(p.energyCost or 0) end
   end
  end
 end
 local count=0;for _ in pairs(mobile) do count=count+1 end
 if count~=10 then return false,'unexpected_reachable_mobile_roster_'..count end
 log('FEASIBILITY',metal,energy,'structure_lower_bound_seconds',seconds,'native_lord_power',UnitDefs[Spring.GetUnitDefID(lord)].buildSpeed,'mobiles',count)
 return true
end
local function start(f)
 for _,unit in ipairs(Spring.GetTeamUnits(0) or {}) do
  local def=UnitDefs[Spring.GetUnitDefID(unit)]
  if def and def.name=='nec_lord' and tostring((def.customParams or {}).prototype40k)=='1' then lord=unit;team=0;break end
 end
 if not lord then return end -- Mode remains harmless for Imperium/Ork starting teams.
 local x,y,z=Spring.GetUnitPosition(lord);base={x,y,z};startFrame=f;state='running'
 local m,e=income();-- First resource statistics can lag a newly started commander. Use its actual
 -- native make rates as a conservative baseline; inactive mexes cannot pass.
 local ld=UnitDefs[Spring.GetUnitDefID(lord)]
 initialIncome={math.max(m,ld.metalMake or 0),math.max(e,ld.energyMake or 0)}
 local _,ms=Spring.GetTeamResources(team,'metal');local _,es=Spring.GetTeamResources(team,'energy');initialStorage={ms or 0,es or 0}
 for _=1,ECON_MEXES do tasks[#tasks+1]={name='nec_mex'} end
 for n=1,ECON_GENERATORS do tasks[#tasks+1]={name='nec_generator',x=((n-1)%4-1.5)*170,z=-260-math.floor((n-1)/4)*170} end
 for _,t in ipairs({{name='nec_hq',x=-420,z=180},{name='nec_core',x=0,z=180},{name='nec_greater_core',x=420,z=180},
  {name='nec_archive',x=-300,z=-650},{name='nec_energy_core',x=0,z=-650,scarab=true},{name='nec_turret',x=300,z=-650}}) do tasks[#tasks+1]=t end
 local vent,geoError=usableGeothermal()
 if geoError then result(false,geoError);return end
 if vent then tasks[#tasks+1]={name='nec_thermo',site=vent};log('REAL_GEOTHERMAL_VENT',vent[1],vent[3])
 else log('GEOTHERMAL_EXCLUDED','No native usable geothermal vent') end
 local good,why=feasibility();if not good then result(false,why);return end
 Spring.GiveOrderToUnit(lord,CMD.FIRE_STATE,{0},{})
 log('INITIAL_NATIVE_LORD',lord,m,e,'storage',initialStorage[1],initialStorage[2],f)
 issue(f)
end
function gadget:UnitCreated(unit,def,unitTeam,builder)
 if state~='running' or unitTeam~=team then return end
 if active and builder==active.builder and def==active.def then
  if active.created then result(false,'duplicate_paid_structure_'..active.name);return end
  active.created=unit;births[unit]={builder=builder,def=def,structure=true,frame=Spring.GetGameFrame()}
 elseif builder and queueExpected[builder] and (queueExpected[builder][def] or 0)>0 then
  queueExpected[builder][def]=queueExpected[builder][def]-1
  births[unit]={builder=builder,def=def,product=true,frame=Spring.GetGameFrame()}
  log('NATIVE_FACTORY_CREATED',UnitDefs[def].name,unit,builder)
 end
end
function gadget:UnitFinished(unit,def,unitTeam)
 if state~='running' or unitTeam~=team then return end
 local birth=births[unit];if not birth then return end
 finished[unit]=true
 if birth.product then
  local x,y,z=Spring.GetUnitPosition(unit);products[unit]={origin={x,y,z},def=def,arrived=false}
  local factoryName=UnitDefs[Spring.GetUnitDefID(birth.builder)].name;local factory=factories[factoryName]
  Spring.GiveOrderToUnit(unit,CMD.FIRE_STATE,{0},{})
  Spring.GiveOrderToUnit(unit,CMD.MOVE,{factory.x,Spring.GetGroundHeight(factory.x,factory.z+450),factory.z+450},{})
  log('PAID_PRODUCT_FINISHED',UnitDefs[def].name,unit,birth.builder)
 elseif active and active.created==unit then
  structures[active.name]=(structures[active.name] or 0)+1
  if active.name=='nec_hq' or active.name=='nec_core' or active.name=='nec_greater_core' then queueFactory(unit,def,active.name) end
  log('PAID_STRUCTURE_FINISHED',active.name,unit,birth.builder)
  active=nil;index=index+1
 end
end
function gadget:GameFrame(f)
 if state=='done' then return end
 if state=='waiting' then if f>=120 and f%30==0 then start(f);if f>=600 and not lord then gadgetHandler:RemoveGadget(self) end end;return end
 if f%30~=0 then return end
 if not valid(lord) then result(false,'initial_lord_lost');return end
 if f-startFrame>TIMEOUT then result(false,'native_30min_timeout_no_grants');return end
 for unit,birth in pairs(births) do
  if finished[unit] and birth.structure and not valid(unit) then result(false,'finished_paid_structure_lost_'..UnitDefs[birth.def].name);return end
 end
 if active and active.created and not valid(active.created) then result(false,'paid_structure_lost_'..active.name);return end
 if active and f-active.frame>30*600 then result(false,'native_structure_timeout_'..active.name);return end
 if not active and index==ECON_MEXES+ECON_GENERATORS+1 and not foundationIncomeVerified then
  local m,e=income()
  if m<=initialIncome[1] or e<=initialIncome[2] then result(false,'native_mex_generator_income_not_increased_before_other_factories');return end
  foundationIncomeVerified=true;log('NATIVE_FOUNDATION_INCOME',initialIncome[1],m,initialIncome[2],e,f)
 end
 if not active then issue(f) end
 completion=0
 for unit,p in pairs(products) do
  if not valid(unit) then result(false,'paid_product_lost_'..UnitDefs[p.def].name);return end
  local x,_,z=Spring.GetUnitPosition(unit)
  if not p.arrived and (x-p.origin[1])^2+(z-p.origin[3])^2>=80^2 then p.arrived=true;log('NATIVE_EGRESS',UnitDefs[p.def].name,unit,f) end
  if p.arrived then completion=completion+1 end
 end
 if f-lastProgress>=300 then
  lastProgress=f;local m,e=income();log('PROGRESS',index,#tasks,completion,'income',m,e,'sim_seconds',(f-startFrame)/30)
 end
 if completion>10 then result(false,'unexpected_paid_product_count');return end
 if index>#tasks and completion==10 then
  local m,e=income()
  if m<=initialIncome[1] or e<=initialIncome[2] then result(false,'native_economy_income_not_increased');return end
  local _,ms=Spring.GetTeamResources(team,'metal');local _,es=Spring.GetTeamResources(team,'energy')
  local expectedMetal,expectedEnergy=initialStorage[1],initialStorage[2]
  for unit,birth in pairs(births) do
   if finished[unit] then local d=UnitDefs[birth.def];expectedMetal=expectedMetal+(d.metalStorage or 0);expectedEnergy=expectedEnergy+(d.energyStorage or 0) end
  end
  if (ms or 0)<expectedMetal-.01 or (es or 0)<expectedEnergy-.01 or (ms or 0)<=initialStorage[1] or (es or 0)<=initialStorage[2] then result(false,'native_storage_not_increased');return end
  log('NATIVE_ECONOMY_VERIFIED',initialIncome[1],m,initialIncome[2],e,'storage',ms,es)
  result(true,'all_paid_structures_ten_native_products_egress80_economy_storage')
 end
end

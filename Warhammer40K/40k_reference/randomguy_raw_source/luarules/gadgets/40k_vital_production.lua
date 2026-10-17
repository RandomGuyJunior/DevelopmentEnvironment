function gadget:GetInfo()
 return {name='40K vital and expanded native production proof',desc='Native economy, all production roles and real paid products',author='Local project',layer=104,enabled=true}
end
if not gadgetHandler:IsSyncedCode() then return end
if Spring.GetModOptions().prototype_diagnostic~='expandedproduction' then return end
if VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(Spring.GetModOptions().prototype_source_progression) then return end
local commander,base,prefix,plan,stage= nil,nil,nil,nil,1
local births,finished,factories,queued,products,mexes={},{},{},{},{},{}
local pending,issued,result,started=false,0,'pending',false
local conversionWait,pendingSite
local function log(...) Spring.Echo('40K VITAL PRODUCTION',...) end
local function fail(reason)
 if result~='pending' then return end
 result='failed';Spring.SetGameRulesParam('40k_vital_production_result',-1);log('FAIL',reason,Spring.GetGameFrame())
end
local function option(builder,name)
 local wanted=UnitDefNames[name];if not wanted then return false end
 for _,id in ipairs(UnitDefs[Spring.GetUnitDefID(builder)].buildOptions or {})do if id==wanted.id then return true end end
 return false
end
-- Diagnostic fixtures reserve real grounded structure footprints plus a builder
-- corridor. TestBuildOrder2 alone also admits reclaimable features in this engine.
local function halfFootprint(ud,facing)
 local x=(ud.xsize or (ud.footprintx or 1)*2)*4
 local z=(ud.zsize or (ud.footprintz or 1)*2)*4
 if facing and facing%2==1 then return z,x end
 return x,z
end
local function unitHalf(id,ud,facing)
 local x,z=halfFootprint(ud,facing)
 if Spring.GetUnitCollisionVolumeData then
  local sx,_,sz,ox,_,oz=Spring.GetUnitCollisionVolumeData(id)
  if type(sx)=='number' and type(sz)=='number' then
   local cx,cz=math.abs(sx)/2+math.abs(ox or 0),math.abs(sz)/2+math.abs(oz or 0)
   if facing and facing%2==1 then cx,cz=cz,cx end
   x,z=math.max(x,cx),math.max(z,cz)
  end
 end
 return x,z
end
local function nearby(x,z)
 if Spring.GetUnitsInRectangle then return Spring.GetUnitsInRectangle(x-1024,z-1024,x+1024,z+1024) or {} end
 if Spring.GetAllUnits then return Spring.GetAllUnits() or {} end
 return Spring.GetTeamUnits(0) or {}
end
local function structureClear(def,x,z)
 local hx,hz=halfFootprint(UnitDefs[def],0)
 local builderDef=UnitDefs[Spring.GetUnitDefID(commander)]
 local bx,bz=unitHalf(commander,builderDef,0);local margin=math.max(32,bx+16,bz+16)
 for _,id in ipairs(nearby(x,z))do
  if id~=commander then
   local ud=UnitDefs[Spring.GetUnitDefID(id)]
   if ud and not ud.canFly and not ud.canfly and (ud.speed or 0)==0 then
    local ux,_,uz=Spring.GetUnitPosition(id)
    local facing=Spring.GetUnitBuildFacing and Spring.GetUnitBuildFacing(id) or 0
    local sx,sz=unitHalf(id,ud,facing)
    if ux and math.abs(x-ux)<hx+sx+margin and math.abs(z-uz)<hz+sz+margin then return false,'structure_builder_clearance_'..id end
   end
  end
 end
 return true
end
local function stance(def,pos)
 if not Spring.TestMoveOrder then return nil,'native_move_test_unavailable' end
 local builderDefID=Spring.GetUnitDefID(commander);local ud=UnitDefs[builderDefID]
 local range=ud.buildDistance or ud.builddistance or 128
 local radius=math.max(1,range-32);local hx,hz=halfFootprint(UnitDefs[def],0)
 local bx,bz=unitHalf(commander,ud,0);local cx,cy,cz=Spring.GetUnitPosition(commander)
 local candidates={}
 for i=0,15 do
  local angle=i*math.pi/8;local x=pos[1]+radius*math.cos(angle);local z=pos[3]+radius*math.sin(angle)
  local y=Spring.GetGroundHeight(x,z)
  local outside=math.abs(x-pos[1])>=hx+bx+8 or math.abs(z-pos[3])>=hz+bz+8
  local inrange=(x-pos[1])^2+(y-pos[2])^2+(z-pos[3])^2<=(range-8)^2
  if outside and inrange and x>32 and z>32 and x<Game.mapSizeX-32 and z<Game.mapSizeZ-32
   and Spring.TestMoveOrder(builderDefID,x,y,z,0,0,0,true,true,false) then
   candidates[#candidates+1]={x,y,z,distance=(x-cx)^2+(z-cz)^2}
  end
 end
 table.sort(candidates,function(a,b)return a.distance<b.distance end)
 if candidates[1] then return candidates[1] end
 return nil,'no_native_passable_build_range_stance'
end
local function site(def,x,z,maxring,angles)
 local rejected='no_dry_clear_site';local visited={};angles=angles or 16
 local stats={candidates=0,duplicates=0,bounds=0,egress=0,water=0,native0=0,native1=0,native2=0,nativeOther=0,features=0,structures=0,stances=0,minHeight=math.huge,maxHeight=-math.huge}
 for ring=0,maxring or 16 do
  for i=0,angles-1 do
   local a=i*2*math.pi/angles
   local xx,yy,zz=Spring.Pos2BuildPos(def,x+32*ring*math.cos(a),Spring.GetGroundHeight(x,z),z+32*ring*math.sin(a),0)
   local key=xx..':'..zz
   if visited[key] then stats.duplicates=stats.duplicates+1
   else
    visited[key]=true;stats.candidates=stats.candidates+1
    stats.minHeight=math.min(stats.minHeight,yy);stats.maxHeight=math.max(stats.maxHeight,yy)
    local clear=xx>64 and zz>64 and xx<Game.mapSizeX-64 and zz<Game.mapSizeZ-64
    if not clear then stats.bounds=stats.bounds+1;rejected='map_bounds' end
    if clear then
     for _,f in pairs(factories)do local fx,_,fz=Spring.GetUnitPosition(f);if fx and math.abs(xx-fx)<200 and zz>fz-80 and zz<fz+320 then clear=false;rejected='factory_egress_corridor' end end
     if not clear then stats.egress=stats.egress+1 end
    end
    if clear then
     local status,feature=Spring.TestBuildOrder(def,xx,yy,zz,0)
     local field=status==0 and 'native0' or status==1 and 'native1' or status==2 and 'native2' or 'nativeOther';stats[field]=stats[field]+1
     if feature then stats.features=stats.features+1 end
     if yy<0 then stats.water=stats.water+1;rejected='underwater_site'
     elseif status==2 and not feature then
      local reserved,reason=structureClear(def,xx,zz)
      if reserved then
       local pos={xx,yy,zz,0};local approach,why=stance(def,pos)
       if approach then return pos,approach,nil,stats end
       stats.stances=stats.stances+1;rejected=why
      else stats.structures=stats.structures+1;rejected=reason end
     elseif feature then rejected='reclaimable_feature_'..feature
     else rejected='native_footprint_blocked_'..tostring(status) end
    end
   end
  end
 end
 return nil,nil,rejected,stats
end
local function reportSiteSearch(name,label,x,z,rings,stats)
 local ud=UnitDefs[UnitDefNames[name].id]
 log('SITE_SEARCH',name,label,'centre_xz',x,z,'radius',rings*32,'unique_duplicates',stats.candidates,stats.duplicates,
  'native_status_0_1_2_other',stats.native0,stats.native1,stats.native2,stats.nativeOther,
  'features_water_structures_egress_stances_bounds',stats.features,stats.water,stats.structures,stats.egress,stats.stances,stats.bounds,
  'sampled_height_min_max',stats.minHeight,stats.maxHeight,'native_maxslope_waterdepth',ud.maxSlope or ud.maxslope or 'unknown',ud.maxWaterDepth or ud.maxwaterdepth or 'unknown')
end
local function plannedSite(name,def,x,z)
 local pos,approach,why,stats=site(def,x,z,16)
 reportSiteSearch(name,'preferred_grid',x,z,16,stats)
 if pos then return pos,approach end
 -- Late fixture rows can leave a starting plateau. Search around the genuine
 -- engine-start base instead of relaxing native slope/footprint/stance gates.
 log('SITE_FALLBACK',name,'original_base',base[1],base[2],base[3],'preferred_last_rejection',why)
 pos,approach,why,stats=site(def,base[1],base[3],32,32)
 reportSiteSearch(name,'original_base_fallback',base[1],base[3],32,stats)
 if pos then log('SITE_FALLBACK_ACCEPTED',name,pos[1],pos[2],pos[3]) end
 return pos,approach,why
end
local function buildReadback(reason)
 if not pendingSite then return end
 local x,y,z=Spring.GetUnitPosition(commander)
 local command,options,tag,p1,p2,p3
 if Spring.GetUnitCurrentCommand then command,options,tag,p1,p2,p3=Spring.GetUnitCurrentCommand(commander) end
 local status,feature=Spring.TestBuildOrder(pendingSite.def,pendingSite.pos[1],pendingSite.pos[2],pendingSite.pos[3],0)
 local metal,mstorage,mpull,mincome=Spring.GetTeamResources(0,'metal')
 local energy,estorage,epull,eincome=Spring.GetTeamResources(0,'energy')
 log('BUILD_READBACK',reason,pendingSite.name,'commander_xyz',x,y,z,'current_command_options_tag_params',command or 'none',options or 'none',tag or 'none',p1 or 'none',p2 or 'none',p3 or 'none',
  'target_xyz',pendingSite.pos[1],pendingSite.pos[2],pendingSite.pos[3],'build_status_feature',status,feature or 'none',
  'stance_xyz',pendingSite.stance[1],pendingSite.stance[2],pendingSite.stance[3],
  'foundation',pendingSite.created or 'none','metal_current_storage_pull_income',metal,mstorage,mpull,mincome,
  'energy_current_storage_pull_income',energy,estorage,epull,eincome)
end
local function mexsite(def)
 local candidates={}
 for x=math.max(64,base[1]-900),math.min(Game.mapSizeX-64,base[1]+900),16 do
  for z=math.max(64,base[3]-900),math.min(Game.mapSizeZ-64,base[3]+900),16 do
   if (select(3,Spring.GetGroundInfo(x,z)) or 0)>0 then candidates[#candidates+1]={x,z,(x-base[1])^2+(z-base[3])^2}end
  end
 end
 table.sort(candidates,function(a,b)if a[3]~=b[3] then return a[3]<b[3]end;if a[1]~=b[1]then return a[1]<b[1]end;return a[2]<b[2]end)
 for _,c in ipairs(candidates)do
  local separate=true;for _,m in ipairs(mexes)do if (c[1]-m[1])^2+(c[2]-m[2])^2<128^2 then separate=false end end
  if separate then local pos,approach=site(def,c[1],c[2],0);if pos then mexes[#mexes+1]={pos[1],pos[3]};return pos,approach end end
 end
end
local function build()
 local name=plan[stage];if not name then return end
 if not option(commander,name)then fail('commander_missing_build_option_'..name);return end
 local def=UnitDefNames[name];local pos,approach,why
 if name==prefix..'mex' then pos,approach=mexsite(def.id)
 else
  local col=(stage-1)%4;local row=math.floor((stage-1)/4)
  pos,approach,why=plannedSite(name,def.id,base[1]+(col-1.5)*240,base[3]+(row-1)*260)
 end
 if not pos then log('SITE_REJECTED',name,why or 'no_metal_site_with_stance');fail('no_dry_clear_site_'..name);return end
 pending=true;issued=Spring.GetGameFrame()
 local ud=UnitDefs[Spring.GetUnitDefID(commander)]
 local travel=math.sqrt(approach.distance or 0)/math.max(1,ud.speed or 1)
 pendingSite={name=name,def=def.id,pos=pos,stance=approach,foundationDeadline=issued+math.max(900,math.ceil(travel*90)+300)}
 -- TestMoveOrder proves the stance footprint is passable. Actual native arrival
 -- below proves route reachability; no teleport, grants or build-speed changes.
 Spring.GiveOrderToUnit(commander,CMD.MOVE,{approach[1],approach[2],approach[3]},{})
 Spring.GiveOrderToUnit(commander,-def.id,pos,{'shift'})
 log('NATIVE_BUILD_APPROACH',name,approach[1],approach[2],approach[3],'foundation_deadline',pendingSite.foundationDeadline)
 log('NATIVE_BUILD_ORDER',name,commander,pos[1],pos[3],issued)
end
local function queue(factory)
 if queued[factory] then return end
 queued[factory]=true
 -- A player's native repeat-off command prevents diagnostic queues from
 -- endlessly rebuilding completed products and starving the remaining roles.
 Spring.GiveOrderToUnit(factory,CMD.REPEAT,{0},{})
 local ud=UnitDefs[Spring.GetUnitDefID(factory)]
 for _,def in ipairs(ud.buildOptions or {})do
  local target=UnitDefs[def];local cp=target.customParams or {}
  if not cp.prototype40k then fail('unconverted_factory_product_'..target.name);return end
  if not Spring.FindUnitCmdDesc(factory,-def) then fail('missing_build_command_'..target.name);return end
  -- Factory build orders append natively; SHIFT would multiply quantity by5.
  Spring.GiveOrderToUnit(factory,-def,{},{})
  log('NATIVE_FACTORY_QUEUE',ud.name,target.name,factory)
 end
end
function gadget:UnitCreated(id,def,team,builder)
 if team==0 then
  births[id]={builder=builder};log('CREATED',UnitDefs[def].name,id,builder or 'engine_initial')
  if pendingSite and builder==commander and UnitDefs[def].name==pendingSite.name then
   pendingSite.created=id
   local x,_,z=Spring.GetUnitPosition(id)
   if x and (x-pendingSite.pos[1])^2+(z-pendingSite.pos[3])^2>16^2 then buildReadback('foundation_outside_checked_site');fail('foundation_outside_checked_site_'..pendingSite.name) end
  end
 end
end
function gadget:UnitFinished(id,def,team)
 if team~=0 or not started then return end
 local name=UnitDefs[def].name;local birth=births[id]
 if not birth or not birth.builder then return end
 log('FINISHED',name,id,birth.builder,Spring.GetGameFrame())
 finished[name]=(finished[name] or 0)+1
 if birth.builder==commander then
  if #(UnitDefs[def].buildOptions or {})>0 and (UnitDefs[def].speed or 0)==0 then factories[name]=id end
  if pending and name==plan[stage] then pending=false;pendingSite=nil;stage=stage+1 end
 else
  local parent=UnitDefs[Spring.GetUnitDefID(birth.builder)]
  if parent and queued[birth.builder] then
   local x,_,z=Spring.GetUnitPosition(id);products[id]={name=name,source=birth.builder,startx=x,startz=z}
   local fx,_,fz=Spring.GetUnitPosition(birth.builder)
   local ex=math.min(Game.mapSizeX-96,math.max(96,fx+220));local ez=math.min(Game.mapSizeZ-96,math.max(96,fz+300))
   Spring.GiveOrderToUnit(id,CMD.MOVE,{ex,Spring.GetGroundHeight(ex,ez),ez},{})
   log('PAID_FACTORY_PROVENANCE',name,id,parent.name,birth.builder)
  end
 end
end
function gadget:UnitDestroyed(id)
 if id==commander then fail('commander_destroyed')end
 if products[id] and not products[id].egress then fail('factory_product_destroyed_'..products[id].name)end
end
function gadget:GameFrame(frame)
 if result~='pending' or frame%30~=0 then return end
 if not started then
  for _,id in ipairs(Spring.GetTeamUnits(0))do
   local ud=UnitDefs[Spring.GetUnitDefID(id)];local cp=ud.customParams or {}
   if ud.name=='nec_lord' then gadgetHandler:RemoveGadget(self);return end
   if ud.name=='armcom' or ud.name=='corcom' then
    if cp.prototype40k_vital~='commander' then fail('commander_actor_not_converted');return end
    commander=id;prefix=ud.name:sub(1,3);base={Spring.GetUnitPosition(id)};started=true
    plan={prefix..'mex',prefix..'mex',prefix..'solar',prefix..'solar',prefix..'lab',prefix..'solar',prefix..'solar',prefix..'vp',
     prefix=='arm' and 'imp_walker_factory' or 'ork_mek_shop',prefix=='arm' and 'imp_hq' or 'ork_settlement',prefix..'rad',prefix..'estor',prefix..'mstor',prefix..'nanotc',prefix..'makr'}
    log('START',prefix,'genuine commander',id,'native income/costs; no grants');break
   end
  end
  if not started and frame>=300 then fail('missing_engine_initial_commander')end
  return
 end
 if not Spring.ValidUnitID(commander)then fail('commander_missing');return end
 if not pending and plan[stage] then build()end
 if pending and pendingSite then
  local x,y,z=Spring.GetUnitPosition(commander)
  local ud=UnitDefs[Spring.GetUnitDefID(commander)];local range=ud.buildDistance or ud.builddistance or 128
  local inrange=x and (x-pendingSite.pos[1])^2+(y-pendingSite.pos[2])^2+(z-pendingSite.pos[3])^2<=(range-8)^2
  if inrange and not pendingSite.arrived and (x-pendingSite.stance[1])^2+(z-pendingSite.stance[3])^2<=32^2 then
   pendingSite.arrived=true;log('NATIVE_BUILD_STANCE_ARRIVAL',pendingSite.name,x,y,z,frame)
  end
  if not pendingSite.created and frame>pendingSite.foundationDeadline then
   buildReadback('no_foundation');fail('native_no_foundation_'..pendingSite.name);return
  end
 end
 if pending and frame-issued>18000 then buildReadback('construction_timeout');fail('native_build_timeout_'..plan[stage])end
 -- Finish native economy construction before expensive all-roster queues.
 if not plan[stage] then
  for _,id in pairs(factories)do queue(id)end
  local all=true;local expected={}
  for _,id in pairs(factories)do
   for _,def in ipairs(UnitDefs[Spring.GetUnitDefID(id)].buildOptions or {})do expected[UnitDefs[def].name]=true end
  end
  for id,p in pairs(products)do
   if not p.egress and Spring.ValidUnitID(id)then
    local x,_,z=Spring.GetUnitPosition(id)
    if x and (x-p.startx)^2+(z-p.startz)^2>=80^2 then p.egress=true;log('NATIVE_FACTORY_EGRESS',p.name,id,frame)end
   end
  end
  for name in pairs(expected)do
   local passed=false;for _,p in pairs(products)do if p.name==name and p.egress then passed=true end end
   if not passed then all=false end
  end
  if all and next(expected)then
   -- Once paid queues finish, native income refills storage above BAR's
   -- default conversion threshold. Require actual converter resource readback.
   if Spring.GetGameRulesParam('40k_converter_observed_active_0')~=1 then
    if not conversionWait then conversionWait=frame;log('WAIT_NATIVE_CONVERSION',frame) end
    if frame>=54000 then fail('native_converter_not_observed_before_timeout') end
    return
   end
   local _,_,_,metalIncome=Spring.GetTeamResources(0,'metal');local _,_,_,energyIncome=Spring.GetTeamResources(0,'energy')
   if not metalIncome or metalIncome<=(UnitDefs[Spring.GetUnitDefID(commander)].metalMake or 0) or not energyIncome or energyIncome<=0 then fail('native_economy_income_not_proven');return end
   result='pass';Spring.SetGameRulesParam('40k_vital_production_result',1)
   local count=0;for _ in pairs(expected)do count=count+1 end
   log('PASS',prefix,count,'paid products all moved80; native income',metalIncome,energyIncome,frame)
  end
 end
 if frame>=54000 then fail('overall_1800_second_timeout')end
end

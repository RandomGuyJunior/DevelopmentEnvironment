function gadget:GetInfo()return{name='40K paid Ork native air factory witness',desc='Default-off ordinary paid production and real geometry egress',author='Local project',layer=153,enabled=true}end
local options=Spring.GetModOptions()or{}
local policy=VFS.Include('40k_configs/development_playtest.lua')
if not policy.OptionEnabled(options.prototype_ork_air_factory_repeat_fixture)then return false end
if not gadgetHandler:IsSyncedCode()then
 local closeAt
 function gadget:Initialize()gadgetHandler:AddSyncAction('fortyk_ork_air_factory_repeat_done',function(_,result)Spring.Echo('40K_ORK_AIR_REPEAT owned_autoclose '..result);closeAt=Spring.GetGameFrame()+90 end)end
 function gadget:GameFrame(n)if closeAt and n>=closeAt then closeAt=nil;Spring.SendCommands('quitforce')end end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction('fortyk_ork_air_factory_repeat_done')end
 return
end
local S=Spring;local geometry=VFS.Include('40k_configs/guard_factory_egress_geometry.lua')
local contract=VFS.Include('40k_configs/ork_air_factory_repeat_contract.lua')
local phase='initial';local route,commander,factory,rally,product,origin,createdAt,finishedAt,releasedAt,idleAt,started
local flightGood,flightFirst,lastFlightSample=0,nil,nil
local count=0;local team=0;local rate=Game.gameSpeed or 30;local used={};local proven={}
local function emit(event,...)local a={...};for i,v in ipairs(a)do a[i]=tostring(v)end;S.Echo('40K_ORK_AIR_REPEAT '..event..' '..table.concat(a,' '))end
local function resources(event)local m,_,_,mi=S.GetTeamResources(team,'metal');local e,_,_,ei=S.GetTeamResources(team,'energy');emit(event,'metal='..tostring(m),'energy='..tostring(e),'metal_income='..tostring(mi),'energy_income='..tostring(ei),'net_delta_is_not_exact_cost=true');return m,e end
local function done(reason)if phase=='done'then return end;phase='done';resources('FINAL');emit('COMPLETE',reason,'native_acceptance=false visual_acceptance=false combat_landing_rendered_mount_acceptance=false ordinary_paid_candidate=true');SendToUnsynced('fortyk_ork_air_factory_repeat_done',reason)end
local function live(id)if not id or S.GetUnitIsDead(id)then return false end;local hp,_,_,_,p=S.GetUnitHealth(id);return hp and hp>0 and p and p>=1 and S.GetUnitTeam(id)==team end
local function queue()local n=0;for _,row in ipairs(S.GetFullBuildQueue(factory)or{})do for def,c in pairs(row)do if def~=route.product then return nil end;n=n+c end end;return n end
local function produce()
 if queue()~=0 or S.GetUnitIsBuilding(factory)then done('FAIL producer_not_idle_before_paid_order');return end
 if not GG.Recoil40KResearch.CanBuild(team,route.product,factory,false)then done('FAIL actual_paid_product_graph_gate');return end
 count=count+1;product=nil;origin=nil;createdAt=nil;finishedAt=nil;releasedAt=nil;flightGood=0;flightFirst=nil;lastFlightSample=nil
 S.GiveOrderToUnit(factory,-route.product,{},0);phase='production';emit('PAID_QUEUE','ordinal='..count,'metal='..UnitDefs[route.product].metalCost,'energy='..UnitDefs[route.product].energyCost,'work='..UnitDefs[route.product].buildTime);resources('QUEUED')
end
local function site()
 local x,_,z=S.GetUnitPosition(commander);local fd=UnitDefs[route.factory]
 for ring=6,12 do for j=0,15 do
  local a=j*math.pi/8;local px,py,pz=S.Pos2BuildPos(route.factory,x+ring*32*math.cos(a),0,z+ring*32*math.sin(a),0);py=S.GetGroundHeight(px,pz)
  local valid,feature=S.TestBuildOrder(route.factory,px,py,pz,0);local clear=true
  if px-fd.xsize*4<64 or pz-fd.zsize*4<64 or px+fd.xsize*4>Game.mapSizeX-64 or pz+fd.zsize*4>Game.mapSizeZ-64 then clear=false end
  for _,id in ipairs(S.GetUnitsInRectangle(px-fd.xsize*4-32,pz-fd.zsize*4-32,px+fd.xsize*4+32,pz+fd.zsize*4+32)or{})do if id~=commander then clear=false end end
  if py>=0 and valid==2 and not feature and clear and #(S.GetFeaturesInRectangle(px-fd.xsize*4-32,pz-fd.zsize*4-32,px+fd.xsize*4+32,pz+fd.zsize*4+32)or{})==0 then
   local rx,rz=px+math.max(fd.xsize,fd.zsize)*4+640,pz;local ry=S.GetGroundHeight(rx,rz)
   if rx<Game.mapSizeX-64 and ry>=0
    and S.TestMoveOrder(route.commander,px,py,pz,0,0,0,true,true,false)then return{px,py,pz,0},{rx,ry,rz}end
  end
 end end
end
function gadget:GameFrame(n)
 if phase=='done'then return end
 if phase=='initial'then
  started=n
  if options.prototype_diagnostic~='normal'or tonumber(options.prototype_test_speed or 1)~=1 or not policy.OptionEnabled(options.prototype_source_progression)then done('FAIL ordinary_normal_source_speed_required');return end
  for key,value in pairs(options)do
   if key~='prototype_ork_air_factory_repeat_fixture'and(type(key)=='string'and(key:match('_fixture$')or key:match('benchmark')or key:match('probe')))and policy.OptionEnabled(value)then done('FAIL conflicting_fixture_'..key);return end
  end
  if not S.GetUnitCollisionVolumeData or not S.GetUnitVectors or not S.GetUnitVelocity then done('FAIL actual_collision_api_required');return end
  local ok,result=pcall(contract.Validate,UnitDefs,UnitDefNames);if not ok then done('FAIL source_contract '..tostring(result));return end;route=result
  local m,e=resources('START');if math.abs(m-1000)>1 or math.abs(e-1000)>1 then done('FAIL not_ordinary_1000_start');return end
  for _,id in ipairs(S.GetTeamUnits(team)or{})do if S.GetUnitDefID(id)==route.commander and live(id)then if commander then done('FAIL duplicate_commander');return end;commander=id end end
  if not commander then done('FAIL genuine_commander_missing');return end
  if not GG.Recoil40KResearch or type(GG.Recoil40KResearch.CanBuild)~='function'or not GG.Recoil40KResearch.CanBuild(team,route.factory,commander,false)then done('FAIL active_paid_factory_graph_gate');return end
  local placement;placement,rally=site();if not placement then done('FAIL no_clear_reachable_native_site');return end
  S.GiveOrderToUnit(commander,-route.factory,placement,0);phase='factory';emit('PAID_FACTORY_ORDER');return
 end
 if n-started>1200*rate then done('INCONCLUSIVE ordinary_economy_or_native_build_timeout');return end
 if not live(commander)then done('FAIL commander_lost_or_captured');return end
 if phase=='factory'then
  if factory and S.GetUnitTeam(factory)~=team then done('FAIL native_factory_captured_before_completion');return end
  if factory and live(factory)then S.GiveOrderToUnit(factory,CMD.MOVE,rally,0);produce()end;return
 end
 if not live(factory)then done('FAIL native_producer_lost_or_captured');return end
 for id in pairs(proven)do if not live(id)then done('FAIL proven_vehicle_lost_during_repeat_route');return end end
 if queue()==nil then done('FAIL unexpected_native_product_queue');return end
 if phase=='idle'then
  if not live(product)then done('FAIL first_proven_vehicle_lost');return end
  if queue()~=0 or S.GetUnitIsBuilding(factory)then done('FAIL completed_idle_queue_changed');return end
  if n-idleAt>=8*rate then produce()end;return
 end
 if product then
  if S.GetUnitIsDead(product)or S.GetUnitTeam(product)~=team then done('FAIL paid_vehicle_lost_or_captured');return end
  local outside,w=geometry.Outside(S,UnitDefs,factory,product);if outside==nil then done('FAIL actual_geometry_'..tostring(w));return end
  local x,_,z=S.GetUnitPosition(product);local traveled=(x-origin[1])^2+(z-origin[3])^2>=256^2;local arrived=(x-rally[1])^2+(z-rally[3])^2<=96^2
  if n%30==0 then emit('ACTUAL_EGRESS','ordinal='..count,'native_release='..tostring(releasedAt),'union_clear='..tostring(outside),'traveled_256='..tostring(traveled),'rally_arrived='..tostring(arrived),'queue='..tostring(queue()))end
  local _,y=S.GetUnitPosition(product);local ground=S.GetGroundHeight(x,z);local vx,vy,vz=S.GetUnitVelocity(product)
  local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
  if not finite(y)or not finite(ground)or not finite(vx)or not finite(vy)or not finite(vz)then done('FAIL actual_flight_geometry_velocity_missing');return end
  local altitude=y-ground;local moving=vx*vx+vy*vy+vz*vz>.01
  if releasedAt and finishedAt and n-releasedAt>=90 and n%15==0 and n~=lastFlightSample then
   if lastFlightSample and n-lastFlightSample~=15 then flightGood=0;flightFirst=nil end
   lastFlightSample=n
   if outside and traveled and arrived and altitude>=40 and moving and live(product)and queue()==0 then
    flightGood=flightGood+1;flightFirst=flightFirst or n
    emit('NATIVE_FLIGHT_SAMPLE','ordinal='..count,'body='..product,'altitude='..altitude,'travel_256='..tostring(traveled),'velocity='..vx..','..vy..','..vz,'sample='..flightGood)
   else flightGood=0;flightFirst=nil end
  end
  if finishedAt and releasedAt and live(product)and outside and traveled and arrived and flightGood>=3 and n-flightFirst>=30 and queue()==0 then
   emit('PROVEN','ordinal='..count,'body='..product)
   proven[product]=true
   if count==2 then done('PASS two_ordinary_paid_genuine_Fightas_real_native_release_horizontal_collision_yard_clear_flight_256_altitude_40_moving_three_samples_idle_reopen')else idleAt=n;phase='idle'end
  elseif n-createdAt>120*rate then done('FAIL paid_native_release_or_geometry_travel_missing')end
 end
end
function gadget:UnitCreated(id,def,unitTeam,builder)
 if phase=='factory'and route and def==route.factory then
  if factory or builder~=commander or unitTeam~=team then done('FAIL foreign_or_duplicate_native_factory_birth');return end;factory=id
 elseif phase=='production'and def==route.product then
  if product or used[id]or builder~=factory or unitTeam~=team then done('FAIL foreign_or_duplicate_paid_product_birth');return end
  product=id;used[id]=true;origin={S.GetUnitPosition(id)};createdAt=S.GetGameFrame();emit('PAID_NATIVE_BIRTH','ordinal='..count,'body='..id)
 end
end
function gadget:UnitFinished(id,def,unitTeam)if id==product then if finishedAt or def~=route.product or unitTeam~=team then done('FAIL duplicate_or_foreign_product_finish');return end;finishedAt=S.GetGameFrame()end end
function gadget:UnitFromFactory(id,def,unitTeam,parent,parentDef,userOrders)
 if id==product then
  if releasedAt or def~=route.product or unitTeam~=team or parent~=factory or parentDef~=route.factory or userOrders then done('FAIL duplicate_or_foreign_native_release');return end
  releasedAt=S.GetGameFrame();emit('NATIVE_RELEASE','ordinal='..count,'body='..id)
 end
end

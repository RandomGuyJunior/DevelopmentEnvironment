-- Reuses existing paid-air-ladder option. Native orders/resources only.
-- Existing advanced-air development flag is TEST AVAILABILITY, not normal unlock.
local M={Version=1,Option='prototype_ork_paid_air_ladder_fixture',TimeoutSeconds=2700}
M.Route={'fortyk_ork_air_factory','ork_mek_kopta','fortyk_ork_advanced_air_factory','ork_big_mek_kopta','fortyk_ork_super_air_factory','ork_gunship'}
local function yes(v)return v==true or v==1 or v=='1'end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function has(t,id)for _,v in ipairs(t or{})do if v==id then return true end end;return false end
function M.Tasks()
 local t={}
 for i=1,4 do t[#t+1]={key='ork_listening_post',owner=0,metal=true};t[#t+1]={key='ork_generator',owner=0}end
 for i=5,12 do t[#t+1]={key='ork_generator',owner=0}end
 for i,key in ipairs(M.Route)do t[#t+1]={key=key,owner=i-1,route=i,product=i%2==0}end
 return t
end
function M.Validate(D,N,o,exclusions)
 assert(yes(o[M.Option])and yes(o.prototype_ork_advanced_air_development),'Explicit existing ladder and advanced-air development flags required')
 assert(yes(o.prototype_development_playtest)and yes(o.prototype_source_progression),'Existing paid source graph required')
 assert(o.prototype_diagnostic=='normal'and tonumber(o.prototype_test_speed or 1)==1,'Normal simulation clock required')
 for _,key in ipairs(exclusions)do assert(key==M.Option or not yes(o[key]),'Conflicting explicit diagnostic '..key)end
 local recipes={'ORK-AIR-1','ORK-BLD-A1','ORK-AIR-2','ORK-BLD-A2','ORK-AIR-3','ORK-AIR-3-GUNSHIP'}
 local ids={};for _,key in ipairs({'corcom','ork_listening_post','ork_generator'})do ids[key]=assert(N[key],'Missing '..key).id end
 for i,key in ipairs(M.Route)do
  local d=D[assert(N[key],'Missing '..key).id];ids[key]=N[key].id
  local c=d.customParams or{}
  assert(c.prototype40k_ork_v13_recipe==recipes[i],'Wrong real recipe '..key)
  for _,k in ipairs({'metalCost','energyCost','buildTime'})do assert(finite(d[k])and d[k]>0,'Invalid real bill '..key..':'..k)end
  if i%2==1 then assert(d.isFactory and not d.canFly and d.buildSpeed>0,'Actual native air factory '..key)
  elseif i<6 then
   assert(d.isBuilder and not d.isFactory and d.canFly and d.canMove and d.buildSpeed>0 and d.buildDistance>0,'Actual native air constructor '..key)
   assert(c.prototype40k_native_donor==(i==2 and'corca'or'coraca')and tonumber(c.prototype40k_temporary_constructor_appearance)==1,'Reviewed native constructor placeholder '..key)
  else
   assert(d.canFly and d.canMove and not d.isBuilder and c.prototype40k_source_asset=='MOW-02','Genuine Gunship required')
   assert(d.metalCost==4600 and d.energyCost==64000 and d.buildTime==60000,'Gunship bill changed')
  end
 end
 assert(D[ids.fortyk_ork_super_air_factory].metalCost==4800 and D[ids.fortyk_ork_super_air_factory].energyCost==50000 and D[ids.fortyk_ork_super_air_factory].buildTime==85000,'AIR3 bill changed')
 assert((D[ids.ork_listening_post].extractsMetal or 0)>0,'Real productive MEX required')
 assert((D[ids.ork_generator].energyMake or 0)>0,'Real energy generator required')
 return ids
end
local function typed(v)
 local t=type(v)
 if t=='number'then return finite(v)and('number~'..string.format('%.17g',v))or'number~nonfinite'end
 if t=='boolean'then return'boolean~'..tostring(v)end
 if t=='string'then return'string~'..#v..'~'..v:gsub('.',function(c)return string.format('%02x',string.byte(c))end)..'~complete'end
 return'nil~unavailable'
end
function M.Observe(D,N,log)
 local keys={'corcom','ork_listening_post','ork_generator'};for _,k in ipairs(M.Route)do keys[#keys+1]=k end
 for _,key in ipairs(keys)do
  local n=N[key];local d=n and D[n.id];local cp=d and d.customParams or{}
  local values={definition=n and n.id,model=d and d.modelname,script=d and d.scriptName,metal=d and d.metalCost,energy=d and d.energyCost,work=d and d.buildTime,labor=d and d.buildSpeed,
   isFactory=d and not not d.isFactory,isBuilder=d and not not d.isBuilder,canFly=d and not not d.canFly,canMove=d and not not d.canMove,
   extractsMetal=d and d.extractsMetal or 0,energyMake=d and d.energyMake or 0,recipe=cp.prototype40k_ork_v13_recipe or'',donor=cp.prototype40k_native_donor or'',temporary=tonumber(cp.prototype40k_temporary_constructor_appearance)or 0}
  for _,field in ipairs({'definition','model','script','metal','energy','work','labor','isFactory','isBuilder','canFly','canMove','extractsMetal','energyMake','recipe','donor','temporary'})do
   log('OBSERVED_FIELD','schema=1','owner='..key,'field='..field,'value='..typed(values[field]))
  end
 end
 local previous='corcom';for _,key in ipairs(M.Route)do
  local p=N[previous];local d=p and D[p.id];local target=N[key]
  log('OBSERVED_MENU','producer='..previous,'producer_def='..tostring(p and p.id),'product='..key,'product_def='..tostring(target and target.id),'present='..tostring(d and target and has(d.buildOptions,target.id)or false));previous=key
 end
end
function M.New(S,D,N,G,Game,CMD,o,geometry,exclusions,emit)
 local C={phase='initial',team=0,actors={},owned={},completed={},tasks=M.Tasks(),index=0}
 local function log(event,...)
  local a={...};for _,v in ipairs({'resource_grants=false','test_availability=true','normal_default_access_accepted=false','combat_accepted=false'})do a[#a+1]=v end
  emit(event,unpack(a))
 end
 local function stop(reason)C.result=C.result or reason;return C.result end
 local function live(id,complete)
  if not id or S.GetUnitIsDead(id)or S.GetUnitTeam(id)~=C.team then return false end
  local hp,_,_,_,p=S.GetUnitHealth(id);return finite(hp)and hp>0 and(not complete or p==1)
 end
 local function budget(event)
  local m,ms,_,mi,me=S.GetTeamResources(0,'metal');local e,es,_,ei,ee=S.GetTeamResources(0,'energy')
  for _,v in ipairs({m,ms,mi,me,e,es,ei,ee})do if not finite(v)then return nil end end
  log(event,'metal='..m,'energy='..e,'metal_income='..mi,'energy_income='..ei,'metal_expense='..me,'energy_expense='..ee,'metal_storage='..ms,'energy_storage='..es,'net_delta_not_exact_cost=true')
  return m,e,mi,ei
 end
 -- Same stock spot-finder admission used by the retained paid extractor test.
 -- No guessed metal pixel, custom extraction owner or free resource injection.
 local function choose(def,builder,metal)
  local cx,_,cz=S.GetUnitPosition(builder);local d=D[def]
  local function valid(x,z,spot)
   local x,y,z=S.Pos2BuildPos(def,x,0,z,0);y=S.GetGroundHeight(x,z)
   local status,feature=S.TestBuildOrder(def,x,y,z,0)
   if y<0 or x<d.xsize*4+64 or z<d.zsize*4+64 or x>Game.mapSizeX-d.xsize*4-64 or z>Game.mapSizeZ-d.zsize*4-64 or status~=2 or feature then return end
   if #(S.GetUnitsInRectangle(x-d.xsize*4-32,z-d.zsize*4-32,x+d.xsize*4+32,z+d.zsize*4+32)or{})>0 or #(S.GetFeaturesInRectangle(x-d.xsize*4-16,z-d.zsize*4-16,x+d.xsize*4+16,z+d.zsize*4+16)or{})>0 then return end
   if metal then
    local api=G.resource_spot_finder
    if not api or(not api.isMetalMap and not api.IsMexPositionValid(spot,x,z))or(api.isMetalMap and(select(3,S.GetGroundInfo(x,z))or 0)<=0)then return end
    for _,id in ipairs(S.GetUnitsInCylinder(x,z,Game.extractorRadius or 96)or{})do if(D[S.GetUnitDefID(id)].extractsMetal or 0)>0 then return end end
   end
   return{x,y,z,0}
  end
  if metal then
   local api=G.resource_spot_finder;if not api then return end
   if not api.isMetalMap then
    if type(api.metalSpotsList)~='table'or type(api.GetBuildingPositions)~='function'or type(api.IsMexPositionValid)~='function'then return end
    local list={};for _,spot in ipairs(api.metalSpotsList)do for _,p in ipairs(api.GetBuildingPositions(spot,def,0,true)or{})do
     local distance=(p.x-cx)^2+(p.z-cz)^2;if distance<=2048^2 then list[#list+1]={x=p.x,z=p.z,spot=spot,distance=distance}end
    end end
    table.sort(list,function(a,b)if a.distance~=b.distance then return a.distance<b.distance end;if a.x~=b.x then return a.x<b.x end;return a.z<b.z end)
    for _,p in ipairs(list)do local s=valid(p.x,p.z,p.spot);if s then return s end end;return
   end
  end
  for ring=6,64 do for j=0,15 do local a=j*math.pi/8;local s=valid(cx+ring*32*math.cos(a),cz+ring*32*math.sin(a));if s then return s end end end
 end
 local function advance(frame)
  C.index=C.index+1;local task=C.tasks[C.index]
  if not task then return stop('FAIL missing_final_flight_transition')end
  local builder=C.actors[task.owner];local def=C.ids[task.key];local bd=builder and D[S.GetUnitDefID(builder)]
  if task.route==1 then
   local m,e,mi,ei=budget('EARNED_INCOME_READY')
   if not m or mi<=0 or ei<=0 then return stop('INCONCLUSIVE actual_ordinary_income_unavailable')end
   local totalM,totalE=0,0;for _,key in ipairs(M.Route)do local d=D[C.ids[key]];totalM=totalM+d.metalCost;totalE=totalE+d.energyCost end
   local lower=math.max(0,(totalM-m)/mi,(totalE-e)/ei)
   log('FEASIBILITY','remaining_route_metal='..totalM,'remaining_route_energy='..totalE,'observed_income_lower_bound_seconds='..lower,'work_travel_stalls_not_included=true','remaining_cap_seconds='..(M.TimeoutSeconds-(frame-C.started)/30))
   if lower>M.TimeoutSeconds-(frame-C.started)/30 then return stop('INCONCLUSIVE earned_income_insufficient_for_bounded_clock')end
  end
  if not live(builder,true)or not bd or not has(bd.buildOptions,def)then return stop('FAIL actual_menu_or_builder_'..C.index)end
  if not G.Recoil40KResearch.CanBuild(0,def,builder,false)then return stop('FAIL sole_paid_gate_'..C.index)end
  if task.product then
   if not bd.isFactory or #(S.GetFactoryCommands(builder,-1)or{})~=0 or S.GetUnitIsBuilding(builder)then return stop('FAIL nonidle_native_factory_'..C.index)end
  elseif bd.isFactory then return stop('FAIL factory_cannot_construct_structure')end
  local site=task.product and{}or choose(def,builder,task.metal)
  if not site then return stop('INCONCLUSIVE no_real_build_site_'..task.key)end
  C.job={task=task,def=def,builder=builder,ordered=frame,site=site};C.phase='building'
  local d=D[def];budget('BUDGET');log('ORDER','step='..C.index,'key='..task.key,'builder='..builder,'def='..def,'metal='..d.metalCost,'energy='..d.energyCost,'work='..d.buildTime,'power='..bd.buildSpeed,'product='..tostring(task.product==true),'site='..(task.product and'native_queue'or table.concat(site,',')))
  S.GiveOrderToUnit(builder,-def,site,0)
 end
 function C.Created(id,def,team,builder)
  if C.result or C.closed or not C.started or team~=0 then return end
  local j=C.job
  if not j or j.def~=def or j.builder~=builder or j.birth then stop('FAIL foreign_duplicate_or_wrong_producer_birth');return end
  local x,y,z=S.GetUnitPosition(id);j.birth=id;C.owned[id]=true;log('BIRTH','step='..C.index,'id='..id,'def='..def,'builder='..builder,'frame='..S.GetGameFrame(),'x='..x,'y='..y,'z='..z)
 end
 function C.Finished(id,def,team)
  if C.result or C.closed or not C.started or team~=0 then return end
  local j=C.job;if not j or j.birth~=id or j.def~=def then stop('FAIL unrelated_finish');return end
  if j.finished then stop('FAIL duplicate_finish');return end
  j.finished=S.GetGameFrame();log('FINISHED','step='..C.index,'id='..id,'frame='..j.finished)
 end
 function C.Released(id,def,team,factory)
  if C.result or C.closed or not C.started or team~=0 then return end
  local j=C.job;if not j or not j.task.product or j.birth~=id or j.def~=def or j.builder~=factory or j.released then stop('FAIL wrong_or_duplicate_native_release');return end
  j.released=S.GetGameFrame();log('NATIVE_RELEASE','step='..C.index,'id='..id,'factory='..factory,'frame='..j.released)
 end
 function C.Step(frame)
  if C.result or C.closed then return C.result end
  if C.phase=='initial'then
   if frame~=1 or Game.gameSpeed~=30 then return stop('FAIL fresh_frame1_clock30_required')end
   M.Observe(D,N,log);local ok,ids=pcall(M.Validate,D,N,o,exclusions);if not ok then return stop('FAIL source_contract '..tostring(ids))end;C.ids=ids
   if not G.Recoil40KResearch or type(G.Recoil40KResearch.CanBuild)~='function'then return stop('FAIL sole_paid_gate_absent')end
   local all=S.GetTeamUnits(0)or{};local m,e=budget('INITIAL')
   if #all~=1 or S.GetUnitDefID(all[1])~=ids.corcom or not live(all[1],true)or not m or math.abs(m-1000)>5 or math.abs(e-1000)>5 then return stop('FAIL ordinary_natural_single_commander_1000_start')end
   C.started=frame;C.actors[0]=all[1];C.initial=all[1];log('INITIAL_COMMANDER','id='..all[1],'def='..ids.corcom,'team=0');log('SCOPE','ordinary_resource_paid_air_ladder=true','test_only_advanced_air_availability=true','timeout_seconds='..M.TimeoutSeconds)
   return advance(frame)
  end
  if frame-C.started>M.TimeoutSeconds*30 then return stop('INCONCLUSIVE bounded_ordinary_income_path_or_queue_timeout_'..C.index)end
  for _,id in pairs(C.actors)do if not live(id,true)then return stop('FAIL ladder_actor_lost_or_transferred')end end
  for _,id in ipairs(C.completed)do if not live(id,true)then return stop('FAIL completed_income_or_factory_lost_or_transferred')end end
  local j=C.job;if j and j.birth and not live(j.birth,false)then return stop('FAIL pending_paid_product_lost_or_transferred')end
  if frame%300==0 then budget('PROGRESS');if j and j.birth then log('BUILD_PROGRESS','step='..C.index,'id='..j.birth,'progress='..tostring(select(5,S.GetUnitHealth(j.birth))))end end
  if C.phase=='building'and j and j.birth and j.finished and live(j.birth,true)and(not j.task.product or j.released)then
   if j.task.product and(#(S.GetFactoryCommands(j.builder,-1)or{})~=0 or S.GetUnitIsBuilding(j.builder))then return stop('FAIL native_release_not_idle')end
   C.completed[#C.completed+1]=j.birth
   if j.task.route then C.actors[j.task.route]=j.birth end
   log('ACCEPTED','step='..C.index,'id='..j.birth,'finished='..j.finished,'released='..tostring(j.released))
   if j.task.route==6 then
    C.origin={S.GetUnitPosition(j.birth)};C.phase='flight';C.flightStart=frame;C.samples=0
    local x,z=C.origin[1],C.origin[3];local tx=x<Game.mapSizeX/2 and math.min(Game.mapSizeX-96,x+640)or math.max(96,x-640);local tz=z<Game.mapSizeZ/2 and math.min(Game.mapSizeZ-96,z+640)or math.max(96,z-640)
    if(tx-x)^2+(tz-z)^2<256^2 then return stop('INCONCLUSIVE map_too_small_for_flight_order')end
    S.GiveOrderToUnit(j.birth,CMD.MOVE,{tx,S.GetGroundHeight(tx,tz),tz},0);log('FLIGHT_ORDER','id='..j.birth,'frame='..frame,'x='..tx,'z='..tz,'origin_x='..C.origin[1],'origin_y='..C.origin[2],'origin_z='..C.origin[3])
   elseif C.index==16 then C.phase='income_settle';C.incomeFinish=frame;log('INCOME_SETTLE','last_finish='..frame,'minimum_frames=60')
   else return advance(frame)end
  elseif C.phase=='income_settle'and frame-C.incomeFinish>=60 then
   for _,id in ipairs(C.completed)do local mm,mu,em,eu=S.GetUnitResources(id);log('INCOME_OUTPUT','id='..id,'def='..S.GetUnitDefID(id),'metal_make='..typed(mm),'metal_use='..typed(mu),'energy_make='..typed(em),'energy_use='..typed(eu))end
   return advance(frame)
  elseif C.phase=='flight'and frame%15==0 and frame-C.job.released>=90 then
   local outside,why=geometry.Outside(S,D,C.job.builder,C.job.birth);if outside==nil then return stop('FAIL actual_native_union_unavailable_'..tostring(why))end
   local x,y,z=S.GetUnitPosition(C.job.birth);local vx,vy,vz=S.GetUnitVelocity(C.job.birth);local ground=S.GetGroundHeight(x,z)
   for _,v in ipairs({x,y,z,vx,vy,vz,ground})do if not finite(v)then return stop('FAIL nonfinite_native_flight')end end
   local travel=math.sqrt((x-C.origin[1])^2+(z-C.origin[3])^2);local good=outside and travel>=256 and y-ground>=40 and vx*vx+vy*vy+vz*vz>.01
   if C.sampleFrame and frame-C.sampleFrame~=15 then C.samples=0 end;C.sampleFrame=frame;C.samples=good and C.samples+1 or 0
   log('NATIVE_FLIGHT','frame='..frame,'union_clear='..tostring(outside),'travel='..travel,'altitude='..(y-ground),'x='..x,'y='..y,'z='..z,'ground='..ground,'vx='..vx,'vy='..vy,'vz='..vz,'consecutive='..C.samples,
    'parent_min_x='..why.parent.minX,'parent_max_x='..why.parent.maxX,'parent_min_z='..why.parent.minZ,'parent_max_z='..why.parent.maxZ,
    'child_min_x='..why.child.minX,'child_max_x='..why.child.maxX,'child_min_z='..why.child.minZ,'child_max_z='..why.child.maxZ)
   if C.samples>=3 then budget('FINAL');log('INITIAL_COMMANDER_PRESERVED','id='..C.initial,'def='..S.GetUnitDefID(C.initial),'team='..S.GetUnitTeam(C.initial),'alive=true');return stop('PASS earned_resource_actual_six_stage_air_ladder_native_Gunship_birth_finish_release_order_union_clear_flight TEST_AVAILABILITY_ONLY')end
   if frame-C.flightStart>900 then return stop('INCONCLUSIVE actual_paid_flight_timeout')end
  end
  return C.result
 end
 function C.Close()C.closed=true end -- Never destroy/refund any paid actor or initial actor.
 return C
end
return M

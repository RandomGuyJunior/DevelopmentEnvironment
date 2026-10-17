-- Default-off ordinary earned construction/production witness; no game setters.
local M={Version=1,Option='prototype_marine_vehicle_factory_paid_fixture'}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function integer(v,min)return finite(v)and v%1==0 and v>=(min or 0)and v<=2147483647 end
local function contains(t,v)for _,x in pairs(t or{})do if x==v then return true end end;return false end
function M.Validate(D,N)
 local keys={'smcom','imp_marine_mex','imp_marine_generator','imp_walker_factory','imp_predator'};local plan={}
 for _,key in ipairs(keys)do
  local n=N[key];assert(n and integer(n.id,1)and D[n.id],'Actual definition required '..key);local d=D[n.id]
  for _,f in ipairs({'metalCost','energyCost','buildTime'})do assert(finite(d[f])and d[f]>=0 and(f~='buildTime'or d[f]>0),'Actual finite bill '..key..':'..f)end
  plan[key]=n.id
 end
 local c,f,p=D[plan.smcom],D[plan.imp_walker_factory],D[plan.imp_predator];local cp=f.customParams or{}
 assert(f.isFactory==true and f.canAttack==false and #(f.weapons or{})==0,'Actual unarmed vehicle factory required')
 assert(tonumber(cp.prototype40k_native_factory_pilot)==1 and cp.prototype40k_native_factory_donor=='armvp'
  and cp.prototype40k_native_factory_domain=='vehicle','Reviewed native ARMVP pilot required')
 assert(f.metalCost==590 and f.energyCost==1550 and f.buildTime==5700 and f.buildSpeed==150,'Current factory bill required')
 assert(type(f.scriptName)=='string'and f.scriptName:lower()=='units/armvp.cob','Existing native production script required')
 assert(p.metalCost==500 and p.energyCost==2500 and p.buildTime==3800,'Current Predator bill required')
 assert(not(p.customParams or{}).prototype40k_squad_product and p.canMove==true,'Individual native ground Predator required')
 for _,d in ipairs({f,p})do assert(finite(d.xsize)and d.xsize>0 and finite(d.zsize)and d.zsize>0,'Native positive footprint required')end
 for _,key in ipairs({'imp_marine_mex','imp_marine_generator','imp_walker_factory'})do assert(contains(c.buildOptions,plan[key]),'Actual commander edge '..key)end
 assert(contains(f.buildOptions,plan.imp_predator),'Actual factory Predator edge required')
 return plan
end
function M.New(S,D,N,G,placement,physical,emit)
 local C={phase='initial',units={},births={},finishes={},releases={},used={},proven={},step=1,team=0};local task,start,idleAt
 local function endWith(label,why)if not C.result then C.result=label..' '..why;emit('COMPLETE',C.result,'native_acceptance=false','exact_debit_accepted=false','rendered_acceptance=false')end;return C.result end
 local function fail(why)return endWith('FAIL',why)end
 local function inconclusive(why)return endWith('INCONCLUSIVE',why)end
 -- Methods exist even for constructor refusal, so wrapper never has a nil call.
 function C.Frame()end;function C.Created()end;function C.Finished()end;function C.Released()end
 assert(type(emit)=='function','Typed diagnostic sink required')
 for _,k in ipairs({'GetGameFrame','GetTeamUnits','GetTeamResources','GetUnitCosts','GetUnitDefID','GetUnitTeam','ValidUnitID','GetUnitIsDead','GetUnitHealth','GetUnitPosition','GetUnitIsBuilding','GetFullBuildQueue','GetUnitBuildFacing','GiveOrderToUnit','TestMoveOrder','GetGroundHeight','GetUnitsInRectangle','GetFeaturesInRectangle','GetUnitCollisionVolumeData','GetUnitVectors'})do
  if type(S[k])~='function'then fail('missing_actual_API_'..k);return C end
 end
 if not placement or placement.Version~=1 or type(placement.Choose)~='function'or not physical or type(physical.Outside)~='function'then inconclusive('reviewed_shared_site_geometry_dependency_required');return C end
 if not G.GG or not G.GG.Recoil40KResearch or type(G.GG.Recoil40KResearch.CanBuild)~='function'then inconclusive('current_paid_graph_dispatch_dependency_required');return C end
 if not finite(G.mapSizeX)or not finite(G.mapSizeZ)or G.mapSizeX<=0 or G.mapSizeZ<=0 then fail('finite_actual_map_bounds_required');return C end
 local ok,plan=pcall(M.Validate,D,N);if not ok then fail('actual_source_contract_'..tostring(plan));return C end;C.plan=plan
 C.tasks={{key='imp_marine_mex',role='mex1',metal=true},{key='imp_marine_generator',role='power1'},
  {key='imp_marine_generator',role='power2'},{key='imp_marine_mex',role='mex2',metal=true},
  {key='imp_walker_factory',role='factory'},
  {key='imp_predator',role='vehicle1',product=true,ordinal=1},{key='imp_predator',role='vehicle2',product=true,ordinal=2}}
 for _,t in ipairs(C.tasks)do t.def=plan[t.key]end
 local function clock()local n=S.GetGameFrame();assert(integer(n),'Typed native frame required');return n end
 local function live(id,def)
  if not integer(id)or S.ValidUnitID(id)~=true or S.GetUnitIsDead(id)~=false or S.GetUnitTeam(id)~=0 or S.GetUnitDefID(id)~=def then return false end
  local hp,_,_,_,built=S.GetUnitHealth(id);return finite(hp)and hp>0 and built==1
 end
 local function resources(event)
  local m,ms,_,mi=S.GetTeamResources(0,'metal');local e,es,_,ei=S.GetTeamResources(0,'energy')
  if not finite(m)or m<0 or not finite(e)or e<0 or not finite(ms)or ms<=0 or not finite(es)or es<=0 or not finite(mi)or mi<0 or not finite(ei)or ei<0 then fail('finite_native_economy_telemetry_required');return end
  emit(event,'metal='..m,'energy='..e,'metal_income='..mi,'energy_income='..ei,'net_income_is_not_exact_cost=true');return m,e
 end
 local function queue()
  local q=S.GetFullBuildQueue(C.units.factory);if type(q)~='table'then return nil end;local total=0;local count=0
  for k,row in pairs(q)do
   if not integer(k,1)or type(row)~='table'then return nil end;count=count+1
   local n=0;for def,amount in pairs(row)do if def~=plan.imp_predator or not integer(amount,1)then return nil end;n=n+1;total=total+amount end
   if n~=1 then return nil end
  end
  if count~=#q or total>1 then return nil end;return total
 end
 local function rally(def,parent)
  local x,_,z=S.GetUnitPosition(parent);if not finite(x)or not finite(z)then return end
  local fd,d=D[plan.imp_walker_factory],D[def]
  for ring=1,4 do for a=0,15 do
   local angle=a*math.pi/8;local radius=math.max(fd.xsize,fd.zsize)*4+224+ring*32
   -- Integer world positions survive native float32 command roundtrip exactly.
   local rx,rz=math.floor(x+radius*math.cos(angle)+.5),math.floor(z+radius*math.sin(angle)+.5);local ry=S.GetGroundHeight(rx,rz)
   local hx,hz=d.xsize*4+16,d.zsize*4+16;local legal=finite(ry)and ry>=0 and rx-hx>64 and rz-hz>64 and rx+hx<G.mapSizeX-64 and rz+hz<G.mapSizeZ-64
   for _,dx in ipairs({-hx,0,hx})do for _,dz in ipairs({-hz,0,hz})do
    local y=S.GetGroundHeight(rx+dx,rz+dz)
    if not finite(y)or y<0 or S.TestMoveOrder(def,rx+dx,y,rz+dz,0,0,0,true,true,false)~=true then legal=false end
   end end
   local units=S.GetUnitsInRectangle(rx-hx,rz-hz,rx+hx,rz+hz);local features=S.GetFeaturesInRectangle(rx-hx,rz-hz,rx+hx,rz+hz)
   if type(units)~='table'or type(features)~='table'or #units~=0 or #features~=0 then legal=false end
   if legal then return{rx,ry,rz}end
  end end
 end
 local function dispatch()
  task=C.tasks[C.step];if not task then return end;task.owner=task.product and C.units.factory or C.units.commander
  if not live(task.owner,task.product and plan.imp_walker_factory or plan.smcom)then return fail('actual_paid_owner_missing')end
  if G.GG.Recoil40KResearch.CanBuild(0,task.def,task.owner,false)~=true then return inconclusive('current_paid_graph_refused_'..task.key)end
  if task.product then
   if queue()~=0 or S.GetUnitIsBuilding(task.owner)~=nil then return fail('native_producer_not_empty_before_paid_queue')end
   task.rally=rally(task.def,task.owner);if not task.rally then return inconclusive('no_actual_full_footprint_rally_site')end
  else task.position=placement.Choose(S,D,G.GG or{},G,task.def,task.owner,task.metal,emit);if not task.position then return inconclusive('stock_admitted_ordinary_site_missing_'..task.key)end end
  -- Set expected task before native dispatch, which may synchronously callback.
  C.phase='building';task.ordered=clock()
  if S.GiveOrderToUnit(task.owner,-task.def,task.position or{},0)~=true then return fail('actual_paid_build_dispatch_refused')end
  local d=D[task.def];emit('PAID_ORDER','step='..C.step,'role='..task.role,'owner='..task.owner,'definition='..task.def,'metal='..d.metalCost,'energy='..d.energyCost,'work='..d.buildTime,'actual_native_dispatch=true','exact_debit_accepted=false');resources('ORDER_RESOURCES')
 end
 function C.Created(id,def,team,builder)
  if C.result or not task or C.phase~='building'or def~=task.def then return end
  if not integer(id)or not integer(def,1)or team~=0 or builder~=task.owner or task.birth~=nil or C.used[id]then return fail('foreign_duplicate_or_reused_paid_birth')end
  local x,y,z=S.GetUnitPosition(id);if not finite(x)or not finite(y)or not finite(z)then return fail('finite_native_birth_position_required')end
  local work,metal,energy=S.GetUnitCosts(id);local d=D[def]
  if work~=d.buildTime or metal~=d.metalCost or energy~=d.energyCost then return fail('actual_native_birth_bill_changed')end
  C.used[id]=true;task.birth=id;task.born=clock();task.origin={x,y,z};C.births[id]={def=def,team=team,builder=builder,frame=task.born}
  emit('NATIVE_BIRTH','body='..id,'definition='..def,'builder='..builder,'frame='..task.born,'step='..C.step,'work='..work,'metal='..metal,'energy='..energy)
 end
 function C.Finished(id,def,team)
  if C.result or not task or id~=task.birth then return end
  if task.finished or def~=task.def or team~=0 or not C.births[id]or not live(id,def)then return fail('duplicate_foreign_or_incomplete_native_finish')end
  task.finished=clock();if task.finished<task.born then return fail('native_finish_before_birth')end;C.finishes[id]={def=def,team=team,frame=task.finished}
  emit('NATIVE_FINISHED','body='..id,'definition='..def,'frame='..task.finished,'step='..C.step,'actual_UnitFinished=true')
 end
 function C.Released(id,def,team,parent,parentDef,userOrders)
  if C.result or not task or not task.product or id~=task.birth then return end
  if task.released or not task.finished or def~=task.def or team~=0 or parent~=task.owner or parentDef~=plan.imp_walker_factory or userOrders~=false then return fail('foreign_duplicate_or_unfinished_native_release')end
  task.released=clock();if task.released<task.finished then return fail('native_release_before_finish')end;C.releases[id]={parent=parent,parentDef=parentDef,frame=task.released}
  if S.GiveOrderToUnit(id,CMD.MOVE,task.rally,0)~=true then return fail('ordinary_rally_order_refused')end
  emit('NATIVE_RELEASED','body='..id,'parent='..parent,'parent_def='..parentDef,'frame='..task.released,'ordinal='..task.ordinal,'actual_UnitFromFactory=true','direct_MOVE=true')
 end
 function C.Frame(n)
  if C.result then return C.result end
  if not integer(n)or n~=clock()then return fail('exact_native_clock_required')end
  if C.phase=='initial'then
   if n==0 then return end;if n~=1 then return inconclusive('fresh_frame1_required_external_launch_provenance_still_required')end
   start=n;local m,e=resources('START');if C.result then return C.result end
   if m~=1000 or e~=1000 then return fail('ordinary_1000_1000_start_required')end
   local units=S.GetTeamUnits(0);if type(units)~='table'or #units~=1 or not live(units[1],plan.smcom)then return fail('one_real_natural_Marine_commander_required')end
   C.units.commander=units[1];emit('LOAD','factory=imp_walker_factory','native_donor=armvp','product=imp_predator','products=2','ordinary_earned_resources=true');dispatch();return
  end
  if n-start>36000 then return inconclusive('ordinary_economy_or_native_build_timeout')end
  for role,id in pairs(C.units)do local def=role=='commander'and plan.smcom or role=='factory'and plan.imp_walker_factory or role:match('vehicle')and plan.imp_predator or C.births[id].def;if not live(id,def)then return fail('prior_paid_unit_lost_or_captured_'..role)end end
  if C.phase=='idle'then
   if queue()~=0 or S.GetUnitIsBuilding(C.units.factory)~=nil then return fail('completed_native_idle_queue_changed')end
   if n-idleAt>=240 then C.step=C.step+1;dispatch()end;return
  end
  if task and task.birth~=nil then
   if S.ValidUnitID(task.birth)~=true or S.GetUnitIsDead(task.birth)~=false or S.GetUnitTeam(task.birth)~=0 or S.GetUnitDefID(task.birth)~=task.def then return fail('paid_birth_lost_or_captured')end
   if task.product then
    local q=queue();if q==nil then return fail('typed_one_product_native_queue_required')end
    if task.finished and task.released then
     for _,id in ipairs({task.owner,task.birth})do
      local face=S.GetUnitBuildFacing(id);local cv={S.GetUnitCollisionVolumeData(id)}
      if not integer(face)or face>3 or #cv~=10 or not integer(cv[7])or cv[7]>3 or not integer(cv[8])or cv[8]>1 or not integer(cv[9])or cv[9]>2 or type(cv[10])~='boolean'then return fail('full_native_collision_metadata_and_facing_required')end
     end
     local outside,w=physical.Outside(S,D,task.owner,task.birth);if outside==nil then return fail('actual_collision_yard_geometry_'..tostring(w))end
     local x,y,z=S.GetUnitPosition(task.birth);if not finite(x)or not finite(y)or not finite(z)then return fail('finite_current_native_position_required')end
     local traveled=(x-task.origin[1])^2+(z-task.origin[3])^2>=32^2;local arrived=(x-task.rally[1])^2+(z-task.rally[3])^2<=96^2
     if outside==true and traveled and arrived and live(task.birth,task.def)then
      if not task.lastClearFrame or n~=task.lastClearFrame+1 then task.clearSince=n end;task.lastClearFrame=n
     else task.clearSince=nil;task.lastClearFrame=nil end
     if task.clearSince and n-task.clearSince>=30 and n-task.released>=30 and q==0 and S.GetUnitIsBuilding(task.owner)==nil then
      C.units[task.role]=task.birth;C.proven[task.birth]=true
      emit('PROVEN','ordinal='..task.ordinal,'body='..task.birth,'native_finished='..task.finished,'native_released='..task.released,'proof_frame='..n,'parent_minX='..w.parent.minX,'parent_maxX='..w.parent.maxX,'parent_minZ='..w.parent.minZ,'parent_maxZ='..w.parent.maxZ,'body_minX='..w.child.minX,'body_maxX='..w.child.maxX,'body_minZ='..w.child.minZ,'body_maxZ='..w.child.maxZ,'native_union_clear=true','traveled_32=true','rally_arrived=true','exact_debit_accepted=false')
      if task.ordinal==2 then return endWith('PASS','two_ordinary_paid_Predators_native_finish_release_geometry30travel_rally_idle_reopen_prior_preserved')end
      idleAt=n;C.phase='idle';emit('IDLE_BEGIN','first='..task.birth,'frames=240');return
     end
    end
   elseif task.finished then C.units[task.role]=task.birth;C.step=C.step+1;dispatch()end
  end
 end
 return C
end
return M

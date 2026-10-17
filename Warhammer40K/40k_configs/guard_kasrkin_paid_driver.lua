-- Ordinary paid leaf. Shared placement adapter and native observer are root-owned.
local M={Version=1,Option='prototype_guard_kasrkin_native_fixture'}
function M.Enabled(o)local v=(o or{})[M.Option];return v==true or v==1 or v=='1'end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function contains(t,v)for _,x in pairs(t or{})do if x==v then return true end end;return false end
function M.Tasks(plan)
 assert(plan and plan.cohorts==2 and plan.actor=='imp_kasrkin','Exact two paid Kasrkin5 recipes required')
 return{{key='imp_mex',owner='commander',role='mex1',metal=true},{key='imp_generator',owner='commander',role='power1'},
 {key='imp_generator',owner='commander',role='power2'},{key='imp_mex',owner='commander',role='mex2',metal=true},
 {key='imp_generator',owner='commander',role='power3'},
 {key='imp_mex',owner='commander',role='mex3',metal=true},
 {key='imp_barracks',owner='commander',role='basicfactory'},
 {key='wh40k_armck',owner='basicfactory',role='builder',product=true,bill=plan.builderBill},
 {key='wh40k_armalab',owner='builder',role='advancedfactory',bill=plan.advancedBill},
 {key='imp_kasrkin',owner='advancedfactory',role='cohort1',product=true,cohort=true,bill=plan.productBill},
 {key='imp_kasrkin',owner='advancedfactory',role='cohort2',product=true,cohort=true,bill=plan.productBill}}
end
function M.New(S,D,N,P,R,physical,placement,plan,emit)
 local C={phase='initial',units={},births={},finishes={},contexts={},step=1};local task;local start
 local function fail(why)C.result=C.result or('FAIL '..why);return C.result end
 local function inconclusive(why)C.result=C.result or('INCONCLUSIVE '..why);return C.result end
 for _,key in ipairs({'GetGameFrame','GetTeamUnits','GetTeamResources','GetUnitCosts','GetUnitHealth','GetUnitTeam','GetUnitDefID','GetUnitIsDead','GetUnitTransporter','GetUnitRulesParam','GetUnitPosition','GetUnitIsBuilding','GetUnitCommands','GiveOrderToUnit'})do
  if type(S[key])~='function'then fail('missing_native_API_'..key);return C end
 end
 if not R or type(R.Get)~='function'or type(R.Members)~='function'or not physical or type(physical.Outside)~='function'
  or not placement or placement.Version~=1 or type(placement.Choose)~='function'or type(placement.Rally)~='function'then
  inconclusive('root_shared_ordinary_placement_adapter_required');return C
 end
 if type(emit)~='function'then fail('typed_event_sink_required');return C end
 if type(plan)~='table'or type(plan.builderBill)~='table'or type(plan.productBill)~='table'or type(plan.advancedBill)~='table'then fail('typed_exact_recipe_required');return C end
 local p=P and P.profiles and P.profiles[plan.profile]
 if not p or p.id~=plan.id or p.capacity~=plan.capacity or p.product~=plan.actor or not N[p.member]or not N[p.product]
  or plan.builder~='wh40k_armck'or plan.builderFactory~='imp_barracks'or not plan.productBill then fail('current_exact_recipe_profile_required');return C end
 if plan.actor~='imp_kasrkin'or plan.profile~='guard_kasrkin'or plan.capacity~=5 or plan.id~=5 or plan.cohorts~=2 or plan.metal~=55 or plan.energy~=280 or plan.work~=520 then fail('actual_Kasrkin5_profile_required');return C end
 for _,bill in ipairs({plan.productBill,plan.builderBill,plan.advancedBill})do for _,key in ipairs({'metal','energy','work'})do if not finite(bill[key])or bill[key]<=0 then fail('finite_positive_actual_bill_required');return C end end end
 local advanced=N.wh40k_armalab and D[N.wh40k_armalab.id]
 if not advanced or not advanced.isFactory or plan.advancedBill.work~=advanced.buildTime or plan.advancedBill.metal~=advanced.metalCost or plan.advancedBill.energy~=advanced.energyCost then fail('actual_current_T2_factory_bill_required');return C end
 local bd=N.wh40k_armck;local bdef=bd and D[bd.id]
 if not bdef or plan.builderBill.work~=bdef.buildTime or plan.builderBill.metal~=bdef.metalCost or plan.builderBill.energy~=bdef.energyCost then fail('actual_current_constructor_bill_required');return C end
 if plan.productBill.metal~=plan.metal*plan.capacity or plan.productBill.energy~=plan.energy*plan.capacity or plan.productBill.work~=plan.work*plan.capacity then fail('exact_full_capacity_product_bill_required');return C end
 C.tasks=M.Tasks(plan);C.team=0
 for _,t in ipairs(C.tasks)do if not N[t.key]or not D[N[t.key].id]then inconclusive('actual_route_definition_absent_'..t.key);return C end;t.def=N[t.key].id end
 local function complete(id)
  if not finite(id)or id<0 or id%1~=0 or id>2147483647 or S.GetUnitIsDead(id)~=false or S.GetUnitTeam(id)~=C.team then return false end
  local hp,max,_,_,built=S.GetUnitHealth(id);return finite(hp)and finite(max)and max>0 and hp>0 and hp<=max and built==1
 end
 function C.Created(id,def,team,builder)
  if C.result then return end
  if not finite(id)or id<0 or id%1~=0 or id>2147483647 or not finite(def)or def<1 or def%1~=0 or not D[def]or team~=C.team then return fail('typed_native_birth_identity_required')end
  local x,y,z=S.GetUnitPosition(id)
  if not finite(x)or not finite(y)or not finite(z)then return fail('finite_actual_birth_position_required')end
  if C.births[id]then return fail('reused_native_unit_birth')end
  C.births[id]={def=def,team=team,frame=S.GetGameFrame(),position={x,y,z}}
  if C.phase~='building'or not task or def~=task.def then return end
  if team~=C.team or builder~=C.units[task.owner]or task.birth then return fail('non_unique_or_wrong_native_paid_birth')end
  local work,metal,energy=S.GetUnitCosts(id)
  if task.bill and(work~=task.bill.work or metal~=task.bill.metal or energy~=task.bill.energy)then return fail('native_created_paid_bill_mismatch')end
  task.birth=id;task.origin={product=id,productDefinition=def,factory=builder,team=team,created=S.GetGameFrame(),createdWork=work,createdMetal=metal,createdEnergy=energy,finished=C.finishes}
  emit('PAID_NATIVE_BIRTH',id,task.key,metal,energy,work)
 end
 -- Cache by native ID before squad linkage: internal births finish recursively.
 function C.Finished(id,def,team)
  if C.result then return end
  if not finite(id)or id<0 or id%1~=0 or id>2147483647 or not C.births[id]or C.births[id].def~=def or C.births[id].team~=team then return fail('actual_native_finish_birth_identity_required')end
  if C.finishes[id]then return fail('duplicate_native_finish')end
  C.finishes[id]={def=def,team=team,frame=S.GetGameFrame()}
  if def==N.wh40k_armck.id or def==N[plan.actor].id or def==N[p.member].id then
   local hp,max,_,_,progress=S.GetUnitHealth(id);local work,metal,energy=S.GetUnitCosts(id)
   emit('PAID_NATIVE_FINISHED',id,def,team,S.GetGameFrame(),hp,max,progress,work,metal,energy,'actual_UnitFinished=true')
  end
  if task and id==task.birth then if def~=task.def or team~=C.team then return fail('native_finish_identity_mismatch')end;task.finished=true end
 end
 function C.Released(id,def,team,factory,factoryDef,userOrders)
  if C.result or not task or not task.product or id~=task.birth then return end
  if task.released or def~=task.def or team~=C.team or factory~=C.units[task.owner]or S.GetUnitDefID(factory)~=factoryDef or userOrders~=false then return fail('native_factory_release_mismatch')end
  task.released=S.GetGameFrame();task.origin.released=task.released
  emit('PAID_NATIVE_RELEASED',id,def,team,factory,factoryDef,task.released,tostring(userOrders),'actual_UnitFromFactory=true')
  if task.product then
   local rally=placement.Rally(def,factory)
   if type(rally)~='table'or not finite(rally[1])or not finite(rally[2])or not finite(rally[3])then return inconclusive('native_full_cohort_rally_site_unavailable')end
   task.rally=rally;task.origin.rally={rally[1],rally[2],rally[3]}
   if S.GiveOrderToUnit(id,CMD.MOVE,rally,0)==false then return inconclusive('native_cohort_rally_rejected')end
  end
 end
 local function cohortReady(frame)
  local state=R.Get(task.birth);local members=R.Members(task.birth)
  if not state or state.profile~=plan.profile or state.leader~=task.birth or state.team~=C.team or type(state.slots)~='table'or type(state.generations)~='table' or #members~=plan.capacity then return false end
  if not finite(state.id)or state.id<1 or state.id%1~=0 or state.id>2147483647 then fail('typed_positive_logical_cohort_identity_required');return false end
  local count=0;for k in pairs(state.slots)do if type(k)~='number'or k%1~=0 or k<1 or k>plan.capacity then fail('extra_or_invalid_paid_slot');return false end;count=count+1 end
  if count~=plan.capacity then return false end
  local observed={};local identities={};local clear=true
  for slot=1,plan.capacity do
   local id=state.slots[slot];local def=id and S.GetUnitDefID(id);local birth=C.births[id];local finished=C.finishes[id]
   if id==nil or observed[id]or not complete(id)or not birth or not finished or birth.team~=C.team or birth.def~=def or finished.team~=C.team or finished.def~=def
    or(slot==1 and(id~=task.birth or def~=N[p.product].id))or(slot~=1 and def~=N[p.member].id)or S.GetUnitTransporter(id)then fail('actual_paid_full_cohort_native_birth_finish_identity_required');return false end
   observed[id]=true
   local work,metal,energy=S.GetUnitCosts(id);local generation=state.generations[slot]
   if work~=plan.work or metal~=plan.metal or energy~=plan.energy or generation~=1
    or S.GetUnitRulesParam(id,'40k_squad_schema')~=2 or S.GetUnitRulesParam(id,'40k_squad_id')~=state.id
    or S.GetUnitRulesParam(id,'40k_squad_slot')~=slot or S.GetUnitRulesParam(id,'40k_squad_generation')~=generation
    or S.GetUnitRulesParam(id,'40k_squad_investment_metal')~=plan.metal or S.GetUnitRulesParam(id,'40k_squad_investment_energy')~=plan.energy
    or S.GetUnitRulesParam(id,'40k_squad_investment_work')~=plan.work then fail('immutable_paid_generation_or_native_body_bill_mismatch');return false end
   identities[slot]={id=id,def=def,generation=generation}
   if task.identity and(task.identity[slot].id~=id or task.identity[slot].def~=def or task.identity[slot].generation~=generation)then fail('paid_cohort_replaced_during_egress');return false end
   local x,y,z=S.GetUnitPosition(id);local bx,bz=birth.position[1],birth.position[3]
   if not finite(x)or not finite(y)or not finite(z)or not finite(bx)or not finite(bz)or physical.Outside(S,D,task.origin.factory,id)~=true
    or(x-bx)^2+(z-bz)^2<32^2 or(x-task.rally[1])^2+(z-task.rally[3])^2>96^2 then clear=false end
  end
  local public={}
  for _,id in ipairs(members)do if not observed[id]or public[id]then fail('foreign_or_duplicate_public_member');return false end;public[id]=true end
  task.identity=task.identity or identities;task.seed=state.id
  if not clear then task.clearSince=nil;task.lastClear=nil;task.clearFrames=0;return false end
  task.clearFrames=task.lastClear==frame-1 and(task.clearFrames or 0)+1 or 1
  if task.clearFrames==1 then task.clearSince=frame end;task.lastClear=frame
  return task.clearFrames>=30
 end
 function C.Step(frame)
  if C.result then return C.result end
  if not finite(frame)or frame<0 or frame%1~=0 or frame>2147483647 or frame~=S.GetGameFrame()then return fail('typed_native_frame_identity_required')end
  if C.phase=='initial'and frame==0 then if S.GetGameFrame()~=0 then return fail('native_frame_zero_mismatch')end;return end
  for role,context in pairs(C.contexts)do
   if not complete(context.product)or S.GetUnitDefID(context.product)~=context.productDefinition then return fail('previous_paid_origin_lost_or_captured')end
   if role=='builder'then local work,metal,energy=S.GetUnitCosts(context.product);if work~=plan.builderBill.work or metal~=plan.builderBill.metal or energy~=plan.builderBill.energy or S.GetUnitTransporter(context.product)then return fail('previous_paid_builder_bill_or_transport_changed')end end
   if context.slots then
    local state=R.Get(context.product)
    if not state or state.profile~=plan.profile or state.id~=context.seed or state.team~=C.team or state.leader~=context.product or type(state.slots)~='table'or type(state.generations)~='table'or #R.Members(context.product)~=plan.capacity then return fail('previous_paid_cohort_changed')end
    local count=0;for slot in pairs(state.slots)do if not finite(slot)or slot%1~=0 or slot<1 or slot>plan.capacity then return fail('previous_paid_slots_changed')end;count=count+1 end
    if count~=plan.capacity then return fail('previous_paid_slots_changed')end
    local public={};local retained=R.Members(context.product)
    for _,id in ipairs(retained)do if public[id]then return fail('previous_paid_public_members_duplicate')end;public[id]=true end
    for slot,row in ipairs(context.slots)do
     if not public[row.id]then return fail('previous_paid_public_members_foreign')end
     local work,metal,energy=S.GetUnitCosts(row.id)
     if work~=plan.work or metal~=plan.metal or energy~=plan.energy
      or S.GetUnitRulesParam(row.id,'40k_squad_schema')~=2 or S.GetUnitRulesParam(row.id,'40k_squad_id')~=context.seed
      or S.GetUnitRulesParam(row.id,'40k_squad_slot')~=slot or S.GetUnitRulesParam(row.id,'40k_squad_generation')~=row.generation
      or S.GetUnitRulesParam(row.id,'40k_squad_investment_metal')~=plan.metal or S.GetUnitRulesParam(row.id,'40k_squad_investment_energy')~=plan.energy
      or S.GetUnitRulesParam(row.id,'40k_squad_investment_work')~=plan.work then return fail('previous_paid_body_bill_or_rules_changed')end
     if state.slots[slot]~=row.id or state.generations[slot]~=row.generation or not complete(row.id)or S.GetUnitDefID(row.id)~=row.def or S.GetUnitTransporter(row.id)then return fail('previous_paid_cohort_changed')end
    end
   end
  end
  start=start or frame;if frame-start>=36000 then return inconclusive('bounded_ordinary_paid_ladder_timeout')end
  if C.phase=='initial'then
   -- Synced native has no saved-game query: root fresh-script/receipt gate excludes SSF/replay.
   if frame~=1 or S.GetGameFrame()~=frame then return fail('fresh_native_frame_one_required')end
   local all=S.GetTeamUnits(C.team);if type(all)~='table'then return fail('typed_native_initial_team_units_required')end;local metal=S.GetTeamResources(C.team,'metal');local energy=S.GetTeamResources(C.team,'energy')
   if #all~=1 or not N.imp_field_commander or S.GetUnitDefID(all[1])~=N.imp_field_commander.id or not complete(all[1])or not finite(metal)or not finite(energy)or math.abs(metal-1000)>5 or math.abs(energy-1000)>5 then return fail('ordinary_natural_commander_1000_start_required')end
   C.units.commander=all[1];C.phase='next'
  elseif C.phase=='next'then
   task=C.tasks[C.step]
   if not task then C.result='PREPARED paid_builder_and_two_released_full_Kasrkin5_cohorts';emit('READY',C.units.builder,C.contexts,'paid_economy_acceptance=false native_weapons_acceptance=false');return C.result end
   local owner=C.units[task.owner];local d=owner and D[S.GetUnitDefID(owner)]
   if not complete(owner)then return fail('native_paid_owner_lost_or_captured')end
   if not d or not contains(d.buildOptions,task.def)or(task.product and not d.isFactory)then return inconclusive('current_native_menu_or_factory_required_'..task.key)end
   local queue=S.GetUnitCommands(owner,-1);if type(queue)~='table'then return inconclusive('native_owner_queue_unreadable')end
   for index,row in pairs(queue)do if type(index)~='number'or index<1 or index%1~=0 or index>#queue or type(row)~='table'or type(row.id)~='number'then return inconclusive('native_owner_queue_malformed')end end
   if S.GetUnitIsBuilding(owner)then return fail('existing_native_orders_refuse_override')end
   if #queue>0 then
    -- The paid Scarab may still be completing this driver's sole rally MOVE.
    local prior=C.contexts[task.owner];local q=queue[1];local params=q and q.params
    if #queue==1 and prior and prior.rally and q.id==CMD.MOVE and type(params)=='table'and params[1]==prior.rally[1]and params[2]==prior.rally[2]and params[3]==prior.rally[3]then return end
    return fail('existing_native_orders_refuse_override')
   end
   local pos=task.product and{}or placement.Choose(task.def,owner,task.metal)
   if not pos then return inconclusive('legal_productive_native_site_unavailable_'..task.key)end
   C.phase='building' -- Native callbacks may occur inside GiveOrderToUnit.
   if S.GiveOrderToUnit(owner,-task.def,pos,0)==false then return inconclusive('native_paid_order_rejected')end
   emit('ORDER',task.key,owner,'ordinary_native_queue_only')
  elseif C.phase=='building'then
   if not complete(C.units[task.owner])then return fail('native_paid_owner_lost_or_captured')end
   if task.birth and not complete(task.birth)then local hp=S.GetUnitHealth(task.birth);if not hp or hp<=0 or S.GetUnitTeam(task.birth)~=C.team then return fail('native_paid_product_lost_or_captured')end end
   if task.birth and task.finished and complete(task.birth)and(not task.product or task.released)then
    if task.cohort and not cohortReady(frame)then return C.result end
    if task.product and not task.cohort then
     local work,metal,energy=S.GetUnitCosts(task.birth)
     if work~=task.bill.work or metal~=task.bill.metal or energy~=task.bill.energy or S.GetUnitTransporter(task.birth)then return fail('paid_native_builder_bill_or_transport_changed')end
     local x,_,z=S.GetUnitPosition(task.birth);local born=C.births[task.birth].position
     if physical.Outside(S,D,task.origin.factory,task.birth)~=true or not finite(x)or not finite(z)or not finite(born[1])or not finite(born[3])
      or(x-born[1])^2+(z-born[3])^2<32^2 or(x-task.rally[1])^2+(z-task.rally[3])^2>96^2 then task.clearSince=nil;task.lastClear=nil;task.clearFrames=0;return end
     task.clearFrames=task.lastClear==frame-1 and(task.clearFrames or 0)+1 or 1
     if task.clearFrames==1 then task.clearSince=frame end;task.lastClear=frame;if task.clearFrames<30 then return end
    end
    if task.product then
    -- Emit the exact physical span already required by the unchanged gates.
    emit('PAID_EGRESS_SPAN',task.role,task.birth,task.origin.factory,task.clearSince,frame,task.seed or 0,task.cohort and plan.capacity or 1,'native_bounds_outside=true min_travel=32 max_arrival=96')
    local bodyRows=task.identity or{{id=task.birth,def=task.def,generation=0}}
    for slot,row in ipairs(bodyRows)do
     local x,y,z=S.GetUnitPosition(row.id);local birth=C.births[row.id];local hp,max,_,_,progress=S.GetUnitHealth(row.id);local work,metal,energy=S.GetUnitCosts(row.id)
     emit('PAID_EGRESS_BODY',task.role,task.seed or 0,slot,row.id,row.def,C.team,row.generation,birth.frame,task.clearSince,frame,
      birth.position[1],birth.position[2],birth.position[3],x,y,z,task.rally[1],task.rally[2],task.rally[3],hp,max,progress,metal,energy,work,'actual_existing_egress_gate=true')
    end
    end
    C.units[task.role]=task.birth;C.contexts[task.role]=task.origin;C.contexts[task.role].slots=task.identity;C.contexts[task.role].seed=task.seed
    C.step=C.step+1;C.phase='next'
   end
  end
  return C.result
 end
 return C
end
return M

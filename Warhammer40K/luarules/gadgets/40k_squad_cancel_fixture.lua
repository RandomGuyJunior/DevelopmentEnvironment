function gadget:GetInfo()return{name='40K ordinary squad cancel retry diagnostic',desc='Default-off native paid Tactical cancellation and retry',author='Local project',layer=41,enabled=true}end
local options=Spring.GetModOptions()or{}
local enabled=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled
if not enabled(options.prototype_squad_cancel_fixture)then return false end
if not gadgetHandler:IsSyncedCode()then return false end
local S=Spring
local C=VFS.Include('40k_configs/squad_cancel_contract.lua')
local phase='initial';local team=0;local commander,factory,bornFactory,site,stance,startFrame
local route={commander='smcom',factory='imp_marine_barracks',product='imp_marine',profile='marine_tactical'}
local profile,capacity,bodyCost,bill,first,retry,cancelled
local rows={};local finished={};local observedBodies={};local timeout=36000
local function emit(event,...)local a={...};for i=1,#a do a[i]=tostring(a[i])end;S.Echo('40K_SQUAD_CANCEL '..event..' '..table.concat(a,' '))end
local function finish(reason)if phase=='done'then return end;phase='done';emit('COMPLETE',reason,'ordinary_earned_resources=true native_acceptance_requires_actual_run=true')end
local function live(id)local hp,_,_,_,p=S.GetUnitHealth(id);return hp and hp>0 and p==1 and not S.GetUnitIsDead(id)end
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

local function owner()return GG.Recoil40KSquads end
local function queue()return S.GetFactoryCommands(factory,-1)or{}end
-- Read-only callback journal: native child callbacks are synchronous within Finish.
-- Pending=nil at the later product finish/release does not mean missing preflight.
local callbackSequence=0;local callbackTruncated=false
local function boundary(event,id,def,t,builder,part)
 if not retry or (id~=retry and not observedBodies[id])then return end
 local R=owner();local p=R and R.pending[retry];local squad=R and R.Get(retry)
 local _,_,_,_,progress=S.GetUnitHealth(id)
 if event=='AllowUnitBuildStep'and not p and type(progress)=='number'and type(part)=='number'and progress==progress and part==part and progress+part<1 then return end
 if callbackSequence>=16 then
  if not callbackTruncated then callbackTruncated=true;emit('CALLBACK_BOUNDARY_TRUNCATED','frame='..S.GetGameFrame(),'retry='..retry,'cap=16')end
  return -- observation cap never changes admission; journal evidence now incomplete
 end
 callbackSequence=callbackSequence+1
 emit('CALLBACK_BOUNDARY','seq='..callbackSequence,'frame='..S.GetGameFrame(),'event='..event,'id='..id,'def='..tostring(def),'team='..tostring(t),
  'builder='..tostring(builder),'part='..tostring(part),'progress='..tostring(progress),'retry='..retry,
  'pending='..tostring(p~=nil),'pending_team='..tostring(p and p.team),'pending_key='..tostring(p and p.key),'pending_factory='..tostring(p and p.factory),
  'plan_count='..tostring(p and type(p.plan)=='table'and #p.plan or 0),'reserved='..tostring(R and R.Reserved(team)),
  'creating='..tostring(R and R.creating),'members='..tostring(squad and #R.Members(retry)or 0),
  'product_finished_observed='..tostring(finished[retry]~=nil),'released='..tostring(rows[retry]and rows[retry].released or false))
end

local function snapshot(id)
 local R=owner();local r=rows[id];local hp,_,_,_,progress=S.GetUnitHealth(id)
 local work,metal,energy=S.GetUnitCosts(id)
 local m,storage=S.GetTeamResources(team,'metal');local e=S.GetTeamResources(team,'energy')
 local q=queue();local head=q[1]or{}
 return{progress=progress,finished=finished[id],released=r and r.released,members=R.Get(id)and #R.Members(id)or 0,pending=R.pending[id],reserved=R.Reserved(team),
 tag=head.tag,queueCount=#q,command=head.id,definition=UnitDefNames[route.product].id,metal=metal,energy=energy,work=work,
 fullMetal=bill.metal,fullEnergy=bill.energy,fullWork=bill.work,beforeMetal=m,beforeEnergy=e,storage=storage}
end
function gadget:UnitCreated(id,def,t,builder)
 if phase=='done'or t~=team then return end
 if def==UnitDefNames[route.factory].id and phase=='build_factory'then
  if builder~=commander or bornFactory then finish('FAIL wrong_factory_birth');return end;bornFactory=id
 elseif def==UnitDefNames[route.product].id then
  if builder~=factory or not(phase=='first'or phase=='retry')then finish('FAIL unexpected_product_birth');return end
  local r={id=id,team=t,definition=def};rows[id]=r
  if phase=='first'then if first then finish('FAIL duplicate_first_birth');return end;first=id
  else if retry or id==cancelled then finish('FAIL duplicate_or_reused_retry_birth');return end;retry=id end
  emit('PRODUCT_BIRTH','id='..id,'phase='..phase,'def='..def,'team='..t,'builder='..tostring(builder))
 elseif profile and def==UnitDefNames[profile.member].id then
  if phase~='retry'then finish('FAIL member_birth_before_paid_retry_finish');return end
  if observedBodies[id]then finish('FAIL duplicate_member_birth');return end;observedBodies[id]=true;emit('MEMBER_BIRTH','id='..id,'def='..def,'team='..t,'builder='..tostring(builder))
 end
 boundary('UnitCreated',id,def,t,builder)
end
function gadget:UnitFinished(id,def,t)
 boundary('UnitFinished',id,def,t)
 if phase=='done'then return end
 if finished[id]then finish('FAIL duplicate_native_finish');return end
 finished[id]={def=def,team=t}
 if rows[id]or observedBodies[id]or id==bornFactory then emit('NATIVE_FINISH','id='..id,'def='..def,'team='..t)end
 if id==first then finish('FAIL first_completed_before_cancel')end
end
function gadget:UnitDestroyed(id)
 local r=rows[id];if r then r.destroyed=true end
 if id==commander or id==factory then finish('FAIL producer_destroyed')end
end
function gadget:UnitTaken(id)if id==commander or id==factory or rows[id]or observedBodies[id]then finish('FAIL ownership_changed')end end
function gadget:UnitGiven(id)gadget:UnitTaken(id)end
function gadget:UnitFromFactory(id,def,t,fac,facdef,userOrders)
 boundary('UnitFromFactory',id,def,t,fac)
 local r=rows[id];if not r then return end
 if id~=retry or fac~=factory or t~=team or def~=UnitDefNames[route.product].id or facdef~=UnitDefNames[route.factory].id or userOrders or r.released then finish('FAIL wrong_or_duplicate_release');return end
 r.released=true;emit('NATIVE_RELEASE','id='..id,'def='..def,'team='..t,'factory='..fac,'factory_def='..facdef,'user_orders='..tostring(userOrders))
end
function gadget:AllowUnitBuildStep(builder,t,id,def,part)
 if phase=='retry'and id==retry then boundary('AllowUnitBuildStep',id,def,t,builder,part)end
 if phase=='retry'and id==retry and not C.Step(part)then finish('FAIL invalid_native_build_step');return true end
 if phase=='retry'and id==retry and part>0 then
  local R=owner();local p=R and R.pending[id]
  if p then
   local _,_,_,_,progress=S.GetUnitHealth(id)
   emit('RESERVATION_NATIVE_CONTEXT','id='..id,'progress='..tostring(progress),'factory='..tostring(factory),'phase='..phase)
   local builderDef=S.GetUnitDefID(builder);local bd=builderDef and UnitDefs[builderDef]
   local builderTeam=S.GetUnitTeam(builder);local builderTarget=S.GetUnitIsBuilding(builder)
   local function nativeBuilderLive(unit)
    local hp,_,_,_,progress=S.GetUnitHealth(unit)
    return type(hp)=='number'and hp==hp and math.abs(hp)<math.huge and hp>0 and progress==1 and S.GetUnitIsDead(unit)==false
   end
   local builderLive=nativeBuilderLive(builder)
   local producerDef=S.GetUnitDefID(factory);local producerTeam=S.GetUnitTeam(factory);local producerTarget=S.GetUnitIsBuilding(factory);local producerLive=nativeBuilderLive(factory)
   local builderValid=C.Builder({id=builder,product=id,factory=factory,commander=commander,definition=builderDef,expectedFactoryDefinition=UnitDefNames[route.factory].id,expectedCommanderDefinition=UnitDefNames[route.commander].id,
    team=builderTeam,callbackTeam=t,expectedTeam=team,live=builderLive,target=builderTarget,isFactory=bd and bd.isFactory,isBuilder=bd and bd.isBuilder,canAssist=bd and bd.canAssist,buildSpeed=bd and bd.buildSpeed,
    producerLive=producerLive,producerTeam=producerTeam,producerDefinition=producerDef,producerTarget=producerTarget})
   local cmd,opts,tag,param=S.GetUnitCurrentCommand(builder)
   emit('NATIVE_BUILDER_WITNESS','id='..tostring(builder),'def='..tostring(builderDef),'team='..tostring(builderTeam),'callback_team='..tostring(t),
    'live='..tostring(builderLive),'target='..tostring(builderTarget),'product='..id,'mapped_factory='..factory,'commander='..commander,'expected_commander_def='..UnitDefNames[route.commander].id,
    'is_factory='..tostring(bd and bd.isFactory),'is_builder='..tostring(bd and bd.isBuilder),'can_assist='..tostring(bd and bd.canAssist),'build_speed='..tostring(bd and bd.buildSpeed),
    'producer_def='..tostring(producerDef),'producer_team='..tostring(producerTeam),'producer_live='..tostring(producerLive),'producer_target='..tostring(producerTarget),
    'command='..tostring(cmd),'command_options='..tostring(opts),'command_tag='..tostring(tag),'command_param1='..tostring(param),'order_origin_unknown=true','valid='..tostring(builderValid))
   local reserved=R.Reserved(team);local count=S.GetTeamUnitCount(team);local maximum=S.GetTeamMaxUnits(team)
   local planCount=type(p.plan)=='table'and #p.plan or -1
   emit('RESERVATION_OBSERVATION','id='..id,'builder='..tostring(builder),'expected_factory='..factory,'team='..tostring(t),'def='..tostring(def),
    'expected_def='..UnitDefNames[route.product].id,'pending_team='..tostring(p.team),'pending_key='..tostring(p.key),'pending_factory='..tostring(p.factory),
    'plan_count='..planCount,'reserved='..tostring(reserved),'unit_count='..tostring(count),'unit_max='..tostring(maximum),'creating='..tostring(R.creating),'part='..tostring(part))
   if not builderValid then finish('FAIL reservation_builder_native_witness')
   elseif t~=team then finish('FAIL reservation_builder_team')
   elseif def~=UnitDefNames[route.product].id then finish('FAIL reservation_product_def')
   elseif p.team~=team then finish('FAIL reservation_pending_team')
   elseif p.key~=route.profile then finish('FAIL reservation_pending_profile')
   elseif p.factory~=factory then finish('FAIL reservation_pending_factory')
   elseif planCount~=3 then finish('FAIL reservation_plan_count')
   elseif reserved~=3 then finish('FAIL reservation_reserved_count')
   elseif not C.Capacity(count,reserved,maximum)then finish('FAIL reservation_capacity')
   else rows[id].sawReservation=true;emit('NATIVE_FINAL_STEP_RESERVATION','id='..id,'reserved='..reserved,'factory='..factory,'def='..def,'team='..t,'plan_count='..planCount)end
  end
 end
 return true -- Observes only: ordinary owner retains all admission/refusal decisions.
end
function gadget:GameFrame(frame)
 if phase=='done'then return end;startFrame=startFrame or frame
 if frame-startFrame>timeout then finish('FAIL timeout phase='..phase);return end
 if phase=='initial'then
  for flag,value in pairs(options)do
   if flag~='prototype_squad_cancel_fixture' and flag:find('fixture',1,true) and enabled(value)then finish('FAIL competing_fixture '..flag);return end
  end
  local profiles=VFS.Include('40k_configs/active_squad_profiles.lua');profile=profiles.profiles[route.profile]
  if not profile or profile.capacity~=4 then finish('FAIL actual_Tactical_fixed4_required');return end;capacity=4
  local R=owner();if not R or next(R.squads)or next(R.pending)or R.Reserved(team)~=0 then finish('FAIL nonempty_squad_owner');return end
  local m=S.GetTeamResources(team,'metal');local e=S.GetTeamResources(team,'energy')
  if not m or math.abs(m-1000)>5 or not e or math.abs(e-1000)>5 then finish('FAIL not_ordinary_1000_start');return end
  local units=S.GetTeamUnits(team)or{};if #units~=1 or S.GetUnitDefID(units[1])~=UnitDefNames[route.commander].id or not live(units[1])then finish('FAIL natural_commander_required');return end;commander=units[1]
  local cd=UnitDefs[S.GetUnitDefID(commander)];local fd=UnitDefNames[route.factory];local pd=UnitDefNames[route.product];local md=UnitDefs[UnitDefNames[profile.member].id]
  bodyCost={metal=md.metalCost,energy=md.energyCost,work=md.buildTime};bill={metal=md.metalCost*4,energy=md.energyCost*4,work=md.buildTime*4}
  if not UnitDefs[fd.id].isFactory or not contains(cd.buildOptions,fd.id)or not contains(UnitDefs[fd.id].buildOptions,pd.id)
   or not costs(UnitDefs[pd.id],bill.metal,bill.energy,bill.work)then finish('FAIL ordinary_native_menu_or_full_bill');return end
  site,stance=chooseSite(fd.id);if not site then finish('FAIL clear_factory_site_missing');return end
  emit('NATIVE_PAID_PARTICIPANTS','commander='..commander,'commander_def='..UnitDefNames[route.commander].id,'team='..team,'factory_def='..fd.id,'product_def='..pd.id,'source_order_origin=fixture_factory_only')
  phase='build_factory';S.GiveOrderToUnit(commander,-fd.id,site,0);emit('ORDINARY_FACTORY_ORDER')
 elseif phase=='build_factory'then
  if bornFactory and live(bornFactory)and finished[bornFactory]then factory=bornFactory;phase='first';S.GiveOrderToUnit(factory,-UnitDefNames[route.product].id,{},0);emit('FIRST_PAID_QUEUE')end
 elseif phase=='first'and first then
  local row=snapshot(first)
  if row.progress and row.progress>=.10 then
   local ok,why=C.Partial(row);if not ok then finish('FAIL '..why);return end
   cancelled=first;phase='cancel';rows[first].paid=row
   emit('PARTIAL_NATIVE_PRICE','id='..first,'progress='..row.progress,'paid_metal='..row.metal*row.progress,'paid_energy='..row.energy*row.progress,'tag='..row.tag)
   -- Factory CONTROL_KEY selects the build queue; zero options selects newUnitCommands.
   emit('QUEUE_REMOVE','id='..first,'tag='..row.tag,'command='..CMD.REMOVE,'options='..CMD.OPT_CTRL,'native_build_command='..row.command,'native_def='..row.definition,
    'full_metal='..row.metal,'full_energy='..row.energy,'full_work='..row.work,'before_metal='..row.beforeMetal,'before_energy='..row.beforeEnergy,'storage='..row.storage)
   S.GiveOrderToUnit(factory,CMD.REMOVE,{row.tag},CMD.OPT_CTRL)
   row.afterMetal=S.GetTeamResources(team,'metal');row.afterEnergy=S.GetTeamResources(team,'energy')
   row.destroyed=rows[first].destroyed;row.alive=(S.GetUnitHealth(first)or 0)>0 and not S.GetUnitIsDead(first);row.finished=finished[first];row.released=rows[first].released
   local R=owner();row.pending=R.pending[first];row.reserved=R.Reserved(team);row.members=R.Get(first)and #R.Members(first)or 0;row.queueCount=#queue()
   ok,why=C.Cancel(row);if not ok then finish('FAIL '..why);return end
   if next(observedBodies)then finish('FAIL cancelled_product_created_members');return end
   emit('NATIVE_CANCEL_REFUND','metal='..(row.afterMetal-row.beforeMetal),'energy='..(row.afterEnergy-row.beforeEnergy),'reservation_cleared=true')
   phase='retry';S.GiveOrderToUnit(factory,-UnitDefNames[route.product].id,{},0);emit('RETRY_PAID_QUEUE')
  end
 elseif phase=='retry'and retry then
  local R=owner();local s=R.Get(retry)
  if S.GetUnitRulesParam(retry,'40k_squad_delivery_failed')==1 then finish('FAIL native_retry_delivery_refused');return end
  if s and rows[retry].released then
   local bodies={};for _,id in ipairs(R.Members(retry))do
    local hp,_,_,_,progress=S.GetUnitHealth(id);local w,m,e=S.GetUnitCosts(id)
    bodies[#bodies+1]={id=id,definition=S.GetUnitDefID(id),nativeFinishDef=finished[id]and finished[id].def,nativeFinishTeam=finished[id]and finished[id].team,alive=hp and hp>0 and not S.GetUnitIsDead(id),finished=finished[id] and finished[id].def==S.GetUnitDefID(id) and finished[id].team==team,progress=progress,team=S.GetUnitTeam(id),transport=S.GetUnitTransporter(id),metal=m,energy=e,work=w}
   end
   local ok,why=C.Delivered({id=retry,cancelled=cancelled,count=#bodies,profile=s.profile,team=s.team,expectedTeam=team,bodies=bodies,
    finished=finished[retry],released=rows[retry].released,sawReservation=rows[retry].sawReservation,pending=R.pending[retry],reserved=R.Reserved(team),fullMetal=bill.metal,fullEnergy=bill.energy,fullWork=bill.work})
   if not ok then finish('FAIL '..why);return end
   if #queue()~=0 or S.GetUnitIsBuilding(factory)then finish('FAIL factory_not_idle_after_release');return end
   for id in pairs(observedBodies)do if not R.Get(id)or R.Get(id).id~=s.id then finish('FAIL foreign_or_orphan_body');return end end
   table.sort(bodies,function(a,b)return a.id<b.id end)
   for _,b in ipairs(bodies)do emit('BODY_PROVEN','id='..b.id,'def='..b.definition,'team='..b.team,'native_finish_def='..tostring(b.nativeFinishDef),'native_finish_team='..tostring(b.nativeFinishTeam),
    'progress='..b.progress,'metal='..b.metal,'energy='..b.energy,'work='..b.work,'leader='..retry,'released='..tostring(rows[retry].released),'reservation_seen='..tostring(rows[retry].sawReservation),'reserved='..R.Reserved(team))end
   finish('PASS native_partial_cancel_metal_refund_energy_spent_distinct_paid_Tactical4_finish_release_reservation')
  end
 end
end

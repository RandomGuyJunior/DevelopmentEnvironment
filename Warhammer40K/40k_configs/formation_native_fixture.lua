-- Explicit controlled scene: unpaid real factory/barriers, one native paid
-- full8 product, stock squad orders. Movement-only, never economy acceptance.
local M={Version=2,Option='prototype_squad_formation_native_fixture'}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function yes(v)return v==true or v==1 or v=='1'end
local function copy(v)if type(v)~='table'then return v end;local o={};for k,x in pairs(v)do o[k]=copy(x)end;return o end
local function same(a,b)if type(a)~='table'or type(b)~='table'or #a~=#b then return false end;for i=1,#a do if a[i]~=b[i]then return false end end;return true end
local function headingDistance(a,b)local v=math.abs(a-b)%65536;return math.min(v,65536-v)end
function M.New(S,D,N,P,R,F,GG,G,options,physical,emit)
 local C={phase='initial',births={},finishes={},walls={},owned={},lastSample=-99,samples=0,headingSamples=0,rawMovingSamples=0,bypassWitness=false,bypassBodies={},corridorBodies={},narrowWitness=false,sceneUnpaid=true}
 local function finish(kind,why)C.result=C.result or(kind..' '..why);return C.result end
 local function fail(why)return finish('FAIL',why)end
 local function unclear(why)return finish('INCONCLUSIVE',why)end
 for _,k in ipairs({'GetGameFrame','GetTeamUnits','GetTeamResources','GetUnitHealth','GetUnitDefID','GetUnitTeam','GetUnitPosition','GetUnitVelocity','GetUnitHeading','GetHeadingFromVector','GetUnitCommands','GetUnitTransporter','GetUnitRulesParam','GetUnitCosts','GetGroundHeight','TestMoveOrder','TestBuildOrder','CreateUnit','DestroyUnit','GiveOrderToUnit','AddUnitDamage','GetUnitIsDead'})do if type(S[k])~='function'then fail('native_API_'..k);return C end end
 if not R or not R.Get or not R.Members or not F or not F.Get or not physical or not physical.Outside then unclear('actual_shared_real_body_and_formation_owner_required');return C end
 if not yes(options[M.Option])or not yes(options.prototype_development_playtest)or not yes(options.prototype_source_progression)or not yes(options.prototype_ork_slugga_squad)or yes(options.prototype_source_paid_match)or options.prototype_diagnostic~='normal' then fail('explicit_isolated_normal_resource_movement_scene_required');return C end
 local exclusions=VFS.Include('40k_configs/formation_native_exclusions.lua')
 if type(exclusions)~='table'or #exclusions<50 then fail('complete_explicit_option_exclusions_required');return C end
 -- Native options can be an __index-only proxy; pairs(options) is not evidence.
 for _,k in ipairs(exclusions)do
  if k=='prototype_generator_native_mode'or k=='prototype_generator_native_key'then
   if options[k]~=nil and options[k]~=''then fail('competing_controller_'..k);return C end
  elseif yes(options[k])then fail('competing_fixture_'..k);return C end
 end
 local p=P and P.profiles and P.profiles.ork_slugga
 if not p or p.id~=19 or p.capacity~=8 or p.product~='ork_slugga'or p.member~='ork_slugga_member'or not N[p.product]or not N[p.member]or not N.ork_boyz_hut or not N.corfort or not N.wh40k_corck then unclear('actual_Slugga8_factory_builder_and_native_blocker_definitions_required');return C end
 C.profile=p;C.product=N[p.product].id;C.member=N[p.member].id;C.factoryDef=N.ork_boyz_hut.id;C.wallDef=N.corfort.id
 local a,b,f,w=D[C.product],D[C.member],D[C.factoryDef],D[C.wallDef]
 if a.metalCost~=96 or a.energyCost~=480 or a.buildTime~=1152 or b.metalCost~=12 or b.energyCost~=60 or b.buildTime~=144 or not f.isFactory or not f.isBuilder or not w.isBuilding or w.canAttack or w.canMove or w.blocking==false then fail('actual_full8_bills_native_factory_static_blocker_required');return C end
 local function point(x,z)return{x,S.GetGroundHeight(x,z),z}end
 local function position(id)local x,y,z=S.GetUnitPosition(id);if finite(x)and finite(y)and finite(z)then return{x,y,z}end end
 local function live(id)return finite(id)and id>=0 and S.GetUnitIsDead(id)==false and S.GetUnitTeam(id)==0 end
 local function give(id,cmd,params,opts)if S.GiveOrderToUnit(id,cmd,params,opts or 0)==false then return unclear('native_order_rejected')end end
 local function move(q,shift)
  give(C.leader,CMD.MOVE,q,shift and{'shift'}or 0)
  if not C.result then
   C.moveFrame=S.GetGameFrame();C.moveOwnerTick=C.moveFrame+6-C.moveFrame%6
   C.awaitMoveTick=true;C.moveWaitNoted=nil
  end
 end
 local function nearAll(q,radius)
  for _,id in ipairs(R.Members(C.leader))do local at=position(id);if not at or(at[1]-q[1])^2+(at[3]-q[3])^2>radius^2 or S.GetUnitTransporter(id)then return false end end;return true
 end
 -- Read-only bounded egress observations. They never move bodies, remove
 -- obstacles or replace the native release/every-body physical exit gates.
 local function token(v)
  if type(v)=='number'then return finite(v)and string.format('%.17g',v)or'nonfinite'end
  if type(v)=='boolean'then return tostring(v)end
  if v==nil then return'none'end
  return tostring(v):gsub('[^%w_%.%-]','_')
 end
 local function diagnosticScalar(v)
  if type(v)=='number'then
   if v~=v then return'number=nan'end
   if v==math.huge then return'number=+inf'end
   if v==-math.huge then return'number=-inf'end
   return'number='..string.format('%.17g',v)
  end
  if v==nil then return'nil'end
  return type(v)..'='..tostring(v):gsub('[^%w_%.%-]','_')
 end
 local function observedQueue(id,frame)
  local q=S.GetUnitCommands(id,-1)
  if type(q)~='table'then emit('EGRESS_API',frame,id,'native_queue_unreadable');return end
  emit('EGRESS_QUEUE_COUNT',frame,id,#q)
  for n=1,math.min(#q,32)do local row=q[n];local params={}
   for i=1,math.min(#(row.params or{}),16)do params[i]=token(row.params[i])end
   emit('EGRESS_QUEUE_ROW',frame,id,n,token(row.id),token(row.tag),token(row.options and row.options.coded),#(row.params or{}),#params>0 and table.concat(params,',')or'none')
  end
  if #q>32 then emit('EGRESS_API',frame,id,'native_queue_rows_truncated_after32')end
 end
 local function observedEnvelope(id,frame)
  if type(physical.Envelope)~='function'then emit('EGRESS_API',frame,id,'native_envelope_api_missing');return end
  local env,why=physical.Envelope(S,D,id)
  if not env then emit('EGRESS_API',frame,id,token(why));return end
  emit('EGRESS_ENVELOPE',frame,id,token(env.minX),token(env.maxX),token(env.minZ),token(env.maxZ),token(env.facing))
  return env
 end
 local function triageOwner(frame,r)
  local a=r and r.regroup;local h=r and r.ownedPace
  emit('TRIAGE_OWNER',frame,token(r and r.frame),token(C.seed),token(C.leader),
   token(r and r.state),token(r and r.reason),token(r and r.columns),
   token(r and r.lateral),token(r and r.longitudinal),token(r and r.maxLag),
   token(r and r.replans),token(r and r.pauseResumes),
   token(a and a.x),token(a and a.y),token(a and a.z),token(a and a.dx),token(a and a.dz),
   token(h and h.id),token(h and h.saved),token(h and h.applied))
 end
 local function projectedOutside(env,parent,at,x,z)
  -- Translate this body's CURRENT yaw envelope to a proposed slot. This is
  -- a labelled conservative projection, not future-yaw/path feasibility.
  if not env or not parent or not at or not finite(x)or not finite(z)then return nil end
  local dx,dz=x-at[1],z-at[3]
  return env.maxX+dx<parent.minX or env.minX+dx>parent.maxX or env.maxZ+dz<parent.minZ or env.minZ+dz>parent.maxZ
 end
 local function triageBody(frame,r,id,at,env,parent)
  local md=type(S.GetUnitMoveTypeData)=='function'and S.GetUnitMoveTypeData(id)or nil
  local radius=type(S.GetUnitRadius)=='function'and S.GetUnitRadius(id)or nil
  emit('TRIAGE_NATIVE',frame,token(C.seed),id,token(md and md.name),token(radius),
   token(md and md.maxSpeed),token(md and md.maxWantedSpeed),token(md and md.progressState),
   token(md and md.goalx),token(md and md.goaly),token(md and md.goalz),
   token(md and md.currwaypointx),token(md and md.currwaypointy),token(md and md.currwaypointz))
  for _,t in ipairs(r and r.targets or{})do if t.id==id then
   local desiredError=at and finite(t.desiredX)and finite(t.desiredZ)and math.sqrt((at[1]-t.desiredX)^2+(at[3]-t.desiredZ)^2)or nil
   local localError=at and finite(t.x)and finite(t.z)and math.sqrt((at[1]-t.x)^2+(at[3]-t.z)^2)or nil
   local nativeMatches
   if md and finite(md.goalx)and finite(md.goalz)and finite(t.x)and finite(t.z)then nativeMatches=math.abs(md.goalx-t.x)<.001 and math.abs(md.goalz-t.z)<.001 end
   emit('TRIAGE_TARGET',frame,token(r and r.frame),token(C.seed),id,token(t.rank),token(t.trailDepth),
    token(t.desiredX),token(t.desiredZ),token(t.x),token(t.y),token(t.z),token(t.stay),token(desiredError),token(localError),token(nativeMatches),
    token(projectedOutside(env,parent,at,t.desiredX,t.desiredZ)),token(projectedOutside(env,parent,at,t.x,t.z)))
  end end
 end
 local function egressObservation(frame,label)
  local ids=C.leader and R.Members(C.leader)or{};local r=C.seed and F.Get(C.seed)
  emit('EGRESS_STATE',frame,label,token(C.seed),token(C.leader),token(C.factory),token(C.released),#ids,
   token(r and r.state),token(r and r.reason),token(r and r.factory),token(r and r.factoryReleased),token(r and r.egressDone),
   token(C.start and nearAll(C.start,100)),token(C.start and C.start[1]),token(C.start and C.start[2]),token(C.start and C.start[3]))
  local factoryEnvelope=observedEnvelope(C.factory,frame);observedQueue(C.factory,frame)
  triageOwner(frame,r)
  for _,id in ipairs(ids)do
   local at=position(id);local vx,vy,vz=S.GetUnitVelocity(id);local outside,detail=physical.Outside(S,D,C.factory,id)
   emit('EGRESS_BODY',frame,token(C.seed),id,token(S.GetUnitDefID(id)),id==C.leader and'leader'or'body',token(at and at[1]),token(at and at[2]),token(at and at[3]),
    token(vx),token(vy),token(vz),token(outside),type(detail)=='string'and token(detail)or'geometry_available',
    token(S.GetUnitRulesParam(id,'40k_squad_movement_factory')),token(S.GetUnitRulesParam(id,'40k_squad_movement_factory_released')),token(S.GetUnitTransporter(id)),
    token(C.finishes[id]==true))
   local childEnvelope=observedEnvelope(id,frame);observedQueue(id,frame)
   triageBody(frame,r,id,at,childEnvelope,factoryEnvelope)
  end
 end
 local function queue(id)
  local q=S.GetUnitCommands(id,-1);if type(q)~='table'then return end;local out={}
  for _,row in ipairs(q)do if row.id==CMD.MOVE then out[#out+1]={id=row.id,params=copy(row.params),tag=row.tag}end end;return out
 end
 local function sample(frame)
  -- Raw goals update every6frames. Observe real native heading between ticks,
  -- where ground physics could otherwise turn followers back to local offsets.
  if frame%6==0 or frame-C.lastSample<6 then return true end;C.lastSample=frame
  local state=R.Get(C.leader);local rows=R.Members(C.leader);local record=F.Get(C.seed)
  if not state or state.id~=C.seed or state.team~=0 or state.leader~=C.leader or #rows~=(C.killed and not C.repaired and 7 or 8)then return fail('actual_surviving_membership_or_leader_changed')end
  if not record then return true end -- admission/STOP may have no formation record.
  if record.mode~='one_native_leader_route_native_raw_followers'or record.engineRigidGroup~=false or record.nativePathRequestsCounted~=false or record.leader~=C.leader or not finite(record.frame)or record.frame>frame or frame-record.frame>30 then return fail('actual_recent_single_route_formation_telemetry_required')end
  -- Native rally remains authoritative until all bodies physically clear.
  -- Our preceding egress gate checks every body; allow only one bounded owner
  -- update interval before requiring active leader-route/raw-follower evidence.
  if record.state=='factory_egress'and C.phase=='open'and frame-C.stageAt<=12 then return true end
  local active=record.state=='moving'or record.state=='waiting_members'or record.state=='arriving'
  if active and(not finite(record.columns)or record.columns<1 or record.columns>3)then return fail('bounded_actual_formation_columns')end
  if not active and record.state~='blocked'and record.state~='arrived'and record.state~='idle'then return unclear('unexpected_native_formation_state_'..tostring(record.state))end
  if not same(record.members,rows)then return fail('formation_telemetry_not_exact_actual_survivors')end
  local lp=position(C.leader);if not lp then return fail('actual_native_leader_position')end
  local moving=0;local aligned=0;local movingFollowers=0;local observed={}
  for _,id in ipairs(rows)do
   if observed[id]or not live(id)or S.GetUnitDefID(id)~=(id==C.original and not C.killed and C.product or C.member)then return fail('real_unique_body_definition_changed')end;observed[id]=true
   local x,y,z=S.GetUnitPosition(id);local at=finite(x)and finite(y)and finite(z)and{x,y,z}or nil
   local vx,vy,vz=S.GetUnitVelocity(id);local h=S.GetUnitHeading(id);local work,m,e=S.GetUnitCosts(id);local hp,maxhp,paralyze,capture,built=S.GetUnitHealth(id)
   local squadID=S.GetUnitRulesParam(id,'40k_squad_id')
   if not at or not finite(vx)or not finite(vy)or not finite(vz)or not finite(h)or not finite(hp)or hp<=0 or built~=1 or work~=144 or m~=12 or e~=60 or squadID~=C.seed then
    -- Explain the unchanged exact guard using the SAME API values, including
    -- raw invalid coordinates and full float32 cost precision. No retry/grant.
    emit('TRIAGE_BODY_GUARD',frame,C.phase,diagnosticScalar(C.seed),diagnosticScalar(C.leader),id,diagnosticScalar(S.GetUnitDefID(id)),
     diagnosticScalar(x),diagnosticScalar(y),diagnosticScalar(z),diagnosticScalar(vx),diagnosticScalar(vy),diagnosticScalar(vz),diagnosticScalar(h),diagnosticScalar(hp),diagnosticScalar(maxhp),diagnosticScalar(paralyze),diagnosticScalar(capture),diagnosticScalar(built),diagnosticScalar(work),diagnosticScalar(m),diagnosticScalar(e),diagnosticScalar(squadID),
     'position_bad='..tostring(not at),'velocity_bad='..tostring(not finite(vx)or not finite(vy)or not finite(vz)),
     'heading_bad='..tostring(not finite(h)),'health_bad='..tostring(not finite(hp)or hp<=0),'build_bad='..tostring(built~=1),
     'work_bad='..tostring(work~=144),'metal_bad='..tostring(m~=12),'energy_bad='..tostring(e~=60),'squad_id_bad='..tostring(squadID~=C.seed))
    return fail('real_native_body_bills_or_coordinates_changed')
   end
   if S.GetUnitTransporter(id)then return unclear('unexpected_transport_in_core_geometry_case')end
   local q=queue(id);if not q then return unclear('native_queue_unreadable')end
   if id~=C.leader and #q>0 then return fail('follower_has_independent_destination_MOVE_queue')end
   if vx*vx+vz*vz>.04 then moving=moving+1;if headingDistance(h,S.GetUnitHeading(C.leader))<=8192 then aligned=aligned+1 end;if id~=C.leader then movingFollowers=movingFollowers+1 end end
   emit('BODY_SAMPLE',frame,C.phase,C.seed,id,id==C.leader and'leader'or'raw_follower',at[1],at[2],at[3],vx,vy,vz,h,#q,record.columns)
   if C.phase=='bypass'and at[3]>=C.base[3]+100 and at[3]<=C.base[3]+200 and math.abs(at[1]-C.base[1])>145 and not C.bypassBodies[id]then C.bypassBodies[id]=true;emit('BYPASS_BODY_PASS',frame,C.seed,id,at[1],at[2],at[3])end
   if C.phase=='corridor'and at[3]>=C.base[3]+80 and at[3]<=C.base[3]+160 and math.abs(at[1]-C.base[1])<=24 and not C.corridorBodies[id]then C.corridorBodies[id]=true;emit('CORRIDOR_BODY_PASS',frame,C.seed,id,at[1],at[2],at[3])end
  end
  local targetCount=0
  for _,t in ipairs(record.targets or{})do
   if not observed[t.id]or t.id==C.leader or not finite(t.x)or not finite(t.y)or not finite(t.z)or(t.x-lp[1])^2+(t.z-lp[3])^2>240^2 then return fail('raw_follower_goal_not_bounded_near_actual_leader')end
   targetCount=targetCount+1;emit('LOCAL_GOAL',frame,C.seed,t.id,t.x,t.y,t.z)
  end
  local lvx,_,lvz=S.GetUnitVelocity(C.leader);local travelHeading=S.GetHeadingFromVector(lvx,lvz)
  if moving>=5 and targetCount>=4 then C.rawMovingSamples=C.rawMovingSamples+1
   if finite(travelHeading)and lvx*lvx+lvz*lvz>.04 and aligned==moving and headingDistance(S.GetUnitHeading(C.leader),travelHeading)<=8192 then C.headingSamples=C.headingSamples+1 end
  end
  C.samples=C.samples+1
  if C.phase=='bypass'and lp[3]>=C.base[3]+100 and lp[3]<=C.base[3]+200 and math.abs(lp[1]-C.base[1])>145 then C.bypassWitness=true end
  if C.phase=='corridor'and active and lp[3]>=C.base[3]-32 and lp[3]<=C.base[3]+160 and record.columns<3 then C.narrowWitness=true end
  emit('FORMATION_SAMPLE',frame,C.seed,C.leader,record.state or'unknown',record.columns,record.heading or'unknown',moving,movingFollowers,targetCount,'native_path_requests_counted=false')
  return true
 end
 local function scene()
  -- Bounded actual terrain/build probes; this scene uses artificial walls.
  for _,fraction in ipairs({{.35,.35},{.6,.35},{.35,.6},{.6,.6},{.5,.5}})do
   local x,z=math.floor(G.mapSizeX*fraction[1]/16)*16,math.floor(G.mapSizeZ*fraction[2]/16)*16
   if x>700 and z>700 and x<G.mapSizeX-700 and z<G.mapSizeZ-700 then
    local legal=true;local min,max=math.huge,-math.huge
    for dx=-320,320,80 do for dz=-520,480,80 do local y=S.GetGroundHeight(x+dx,z+dz);min=math.min(min,y);max=math.max(max,y)
     if y<0 or S.TestMoveOrder(C.member,x+dx,y,z+dz,0,0,0,true,true,false)~=true then legal=false end
    end end
    local fp=point(x-240,z-480)
    if legal and max-min<=24 and S.TestBuildOrder(C.factoryDef,fp[1],fp[2],fp[3],0)>0 then C.base=point(x,z);return fp end
   end
  end
 end
 local function clearWalls()
  for _,id in ipairs(C.walls)do if live(id)then S.DestroyUnit(id,false,true)end end;C.walls={}
 end
 local function wall(x,z)
  local q=point(x,z);if S.TestBuildOrder(C.wallDef,q[1],q[2],q[3],0)<=0 then return unclear('actual_static_wall_placement_unavailable')end
  local id=S.CreateUnit('corfort',q[1],q[2],q[3],0,0);if not live(id)or S.GetUnitDefID(id)~=C.wallDef then return fail('actual_native_blocker_birth_refused')end
  C.walls[#C.walls+1]=id;emit('CONTROLLED_UNPAID_WALL',id,q[1],q[2],q[3]);return id
 end
 local function corridorAdmission(frame)
  local record=F.Get(C.seed);local spacing=record and record.lateral
  if not finite(spacing)or spacing<=0 then return unclear('actual_corridor_body_spacing_unavailable')end
  -- Probe after actual native walls exist, before issuing either route goal.
  -- Both real body definitions need a usable full-footprint centerline; a
  -- clear point alone or the earlier wall-free scene probes are insufficient.
  for _,def in ipairs({C.product,C.member})do
   for dz=-64,224,16 do
    local q=point(C.base[1],C.base[3]+dz)
    local okay=S.TestMoveOrder(def,q[1],q[2],q[3],0,0,0,true,true,false)
    emit('TRIAGE_CORRIDOR_ADMISSION',frame,def,'center',q[1],q[2],q[3],token(okay),'full_native_footprint=true path_proof=false')
    if okay~=true then return unclear('actual_native_corridor_centerline_unavailable')end
   end
   for _,side in ipairs({-1,1})do
    local q=point(C.base[1]+spacing*side,C.base[3]+112)
    local okay=S.TestMoveOrder(def,q[1],q[2],q[3],0,0,0,true,true,false)
    emit('TRIAGE_CORRIDOR_ADMISSION',frame,def,side<0 and'left_slot'or'right_slot',q[1],q[2],q[3],token(okay),'full_native_footprint=true path_proof=false')
    if okay~=false then return unclear('actual_native_corridor_wide_slots_not_denied')end
   end
  end
  return true
 end
 function C.Created(id,def,team,builder)
  if team~=0 or(def~=C.product and def~=C.member)then return end
  local reused=C.births[id]~=nil
  if reused and not(C.phase=='paid_repair_promotion'and C.killed and C.deathCallback and id==C.original and def==C.member and not C.restored)then return fail('duplicate_real_body_birth')end
  if C.killed then
   if C.phase~='paid_repair_promotion'or def~=C.member or C.restored then return fail('unexplained_new_body_after_controlled_casualty')end
   C.restored=id
   local job=R.repair and R.repair[C.seed]
   local builderDef=C.repairBuilder and D[S.GetUnitDefID(C.repairBuilder)]
   emit('TRIAGE_REPAIR_BIRTH_JOB',S.GetGameFrame(),diagnosticScalar(C.seed),id,diagnosticScalar(job and job.slot),diagnosticScalar(job and job.def),
    diagnosticScalar(job and job.work),diagnosticScalar(job and job.metal),diagnosticScalar(job and job.energy),diagnosticScalar(C.repairBuilder),diagnosticScalar(builderDef and builderDef.buildSpeed),diagnosticScalar(G.gameSpeed),'before_body_investment_apply=true')
  end
  local work,m,e=S.GetUnitCosts(id);local full=def==C.product
  if work~=(full and 1152 or 144)or m~=(full and 96 or 12)or e~=(full and 480 or 60)then return fail('actual_native_queued_product_or_member_birth_bill_mismatch')end
  if reused then C.retiredOriginalBirth=copy(C.births[id]);C.finishes[id]=nil end
  C.totalBirths=(C.totalBirths or 0)+1
  C.births[id]={definition=def,builder=builder,frame=S.GetGameFrame(),work=work,metal=m,energy=e,serial=C.totalBirths};emit('NATIVE_BODY_BIRTH',id,def,team,builder or'none',work,m,e,C.totalBirths,reused and'reused_retired_native_id'or'new_native_id')
  if def==C.product then if C.original or builder~=C.factory then return fail('native_factory_product_owner_mismatch')end;C.original=id end
 end
 function C.Finished(id,def,team)
  if not C.births[id]then return end
  if team~=0 or C.finishes[id]or C.births[id].definition~=def then return fail('actual_body_finish_owner_mismatch')end
  C.finishes[id]=true;emit('NATIVE_BODY_FINISH',id,def,team)
 end
 function C.Released(id,def,team,factory,factoryDef,userOrders)
  if def~=C.product then return end
  if id~=C.original or team~=0 or factory~=C.factory or factoryDef~=C.factoryDef or userOrders~=false or C.released then return fail('actual_factory_release_owner_mismatch')end
  C.released=S.GetGameFrame();emit('NATIVE_PAID_PRODUCT_RELEASE',id,def,team,factory)
  emit('FACTORY_RELEASE_DETAIL',C.released,id,def,team,factory,factoryDef,tostring(userOrders),'actual_UnitFromFactory=true')
  observedQueue(id,C.released)
 end
 function C.Destroyed(id)
  if id==C.original and C.killed then C.deathCallback=true;emit('SCRIPTED_LEADER_DEATH',id,S.GetGameFrame(),'no_free_successor_birth=true')end
 end
 function C.Step(frame)
  if C.result then return C.result end
  C.started=C.started or frame
  if frame-C.started>10*60*(G.gameSpeed or 30)then return unclear('bounded_ten_minute_movement_scene_timeout_'..C.phase)end
  if C.awaitMoveTick then
   if frame-C.moveFrame>12 then return unclear('post_command_owner_tick_not_observed')end
   local record=C.seed and F.Get(C.seed)
   if record and finite(record.frame)and record.frame>frame then return fail('actual_recent_single_route_formation_telemetry_required')end
   -- Fixture layer180 issues orders after owner layer40. Even an owner
   -- tick on the command frame is pre-command; only the next tick can
   -- substantiate the resulting movement state. This never counts starting.
   -- Release only on an eligible off-tick sample, so sample() cannot skip
   -- state validation while a nearAll gate immediately advances the phase.
   if record and record.leader==C.leader and finite(record.frame)and record.frame>=C.moveOwnerTick and record.frame>C.moveFrame and frame%6~=0 and frame-C.lastSample>=6 then
    C.awaitMoveTick=nil
    emit('TRIAGE_CLOCK_READY',frame,C.moveFrame,record.frame,token(record.state),token(C.seed),token(C.leader))
   else
    if not C.moveWaitNoted then C.moveWaitNoted=true;emit('TRIAGE_CLOCK_WAIT',frame,C.moveFrame,token(record and record.frame),token(record and record.state),token(C.seed),token(C.leader))end
    return
   end
  end
  if C.phase=='initial'then
   local m=S.GetTeamResources(0,'metal');local e=S.GetTeamResources(0,'energy');if not finite(m)or not finite(e)or math.abs(m-1000)>5 or math.abs(e-1000)>5 then return fail('ordinary1000_start_no_resource_grants_required')end
   local q=scene();if not q then return unclear('bounded_clear_actual_scene_unavailable')end
   emit('SCENE',C.base[1],C.base[2],C.base[3],G.mapSizeX,G.mapSizeZ,'artificial_native_barriers=true natural_terrain_acceptance=false')
   C.factory=S.CreateUnit('ork_boyz_hut',q[1],q[2],q[3],0,0);if not live(C.factory)then return fail('controlled_native_factory_birth_refused')end
   if not GG.Recoil40KResearch or not GG.Recoil40KResearch.CanBuild(0,C.product,C.factory,false)then return fail('genuine_INF1_product_graph_refused')end
   emit('SCOPE','movement_only=true unpaid_real_factory=true unpaid_real_repair_builder=true artificial_native_wall_scene=true one_native_paid_queue_entry=true one_native_paid_casualty_restore_required=true paid_economy_accepted=false natural_narrow_terrain_accepted=false transport_pause_accepted=false')
   give(C.factory,-C.product,{});C.phase='production';C.stageAt=frame
  elseif C.phase=='production'then
   if C.original and C.released then
    local s=R.Get(C.original);local ids=R.Members(C.original)
    if s and s.profile=='ork_slugga'and s.leader==C.original and #ids==8 then
     for _,id in ipairs(ids)do if not C.births[id]or not C.finishes[id]or not live(id)then return fail('eight_real_native_completed_bodies_required')end end
     C.seed=s.id;C.leader=s.leader;C.originalMembers=copy(ids);C.birthCount=C.totalBirths
     if C.birthCount~=8 then return fail('exactly_eight_real_bodies_one_product_required')end
     C.start=point(C.base[1],C.base[3]-220)
     -- Same target, actual native admission for each real body; never infer
     -- terrain/path legality from a clear scene grid or a factory callback.
     for _,id in ipairs(ids)do
      local legal=S.TestMoveOrder(S.GetUnitDefID(id),C.start[1],C.start[2],C.start[3],0,0,0,true,true,false)
      emit('EGRESS_TARGET_ADMISSION',frame,id,S.GetUnitDefID(id),C.start[1],C.start[2],C.start[3],tostring(legal),'native_path_proof=false')
      if legal~=true then egressObservation(frame,'target_refused');return unclear('actual_native_egress_target_unavailable')end
     end
     egressObservation(frame,'before_stock_move')
     give(C.leader,CMD.FIRE_STATE,{0});give(C.leader,CMD.MOVE_STATE,{0});move(C.start);C.phase='egress';C.stageAt=frame;C.lastEgressObservation=frame
     egressObservation(frame,'after_stock_move')
    end
   end
   if frame-C.stageAt>1800 then return unclear('native_paid_full8_factory_release_timeout')end
  elseif C.phase=='egress'then
   if frame-C.stageAt<=1800 and frame-(C.lastEgressObservation or-999)>=90 then egressObservation(frame,'bounded_wait');C.lastEgressObservation=frame end
   if nearAll(C.start,100)then
    egressObservation(frame,'near_target_gate_check')
    for _,id in ipairs(R.Members(C.leader))do if physical.Outside(S,D,C.factory,id)~=true then return fail('every_body_must_exit_real_factory')end end
    egressObservation(frame,'all8_near_and_physical_outside')
    C.goal=point(C.base[1]+260,C.base[3]-120);move(C.goal);C.phase='open';C.stageAt=frame
   elseif frame-C.stageAt>1800 then egressObservation(frame,'timeout');return unclear('full_squad_egress_timeout')end
  elseif C.phase=='open'then
   sample(frame);if C.result then return C.result end
   if nearAll(C.goal,100)and C.rawMovingSamples>=3 and C.headingSamples>=2 then
    C.goal=C.start;move(C.goal);C.phase='before_bypass';C.stageAt=frame
   elseif frame-C.stageAt>1800 then return unclear('common_heading_raw_travel_not_observed')end
  elseif C.phase=='before_bypass'then
   sample(frame);if C.result then return C.result end
   if nearAll(C.start,90)then
    for dx=-128,128,32 do if not wall(C.base[1]+dx,C.base[3]+144)then return C.result end end
    C.goal=point(C.base[1],C.base[3]+400);move(C.goal);C.phase='bypass';C.stageAt=frame
   elseif frame-C.stageAt>1800 then return unclear('bypass_staging_timeout')end
  elseif C.phase=='bypass'then
   sample(frame);if C.result then return C.result end
   local passed=0;for _ in pairs(C.bypassBodies)do passed=passed+1 end
   if nearAll(C.goal,100)and C.bypassWitness and passed==8 then
    clearWalls();C.goal=C.start;move(C.goal);C.phase='before_corridor';C.stageAt=frame
   elseif frame-C.stageAt>2400 then return unclear('actual_barrier_bypass_not_observed')end
  elseif C.phase=='before_corridor'then
   sample(frame);if C.result then return C.result end
   if nearAll(C.start,90)then
    for dz=-64,224,32 do for _,dx in ipairs({-32,32})do if not wall(C.base[1]+dx,C.base[3]+dz)then return C.result end end end
    if corridorAdmission(frame)~=true then return C.result end
    -- A direct exit goal permits the leader's native route to bypass both
    -- wall rows, as observed in r73. Require an actual central waypoint then
    -- the exit on the SAME real leader queue; followers retain raw movement.
    C.corridorEntry=point(C.base[1],C.base[3]+112)
    C.goal=point(C.base[1],C.base[3]+400);move(C.corridorEntry);move(C.goal,true);C.phase='corridor';C.stageAt=frame
   elseif frame-C.stageAt>1800 then return unclear('narrow_corridor_staging_timeout')end
  elseif C.phase=='corridor'then
   sample(frame);if C.result then return C.result end
   local passed=0;for _ in pairs(C.corridorBodies)do passed=passed+1 end
   if nearAll(C.goal,100)and C.narrowWitness and passed==8 then
    clearWalls();C.q1=point(C.base[1]+300,C.base[3]);C.q2=point(C.base[1]-300,C.base[3]-120);move(C.q1);move(C.q2,true);C.phase='queued';C.stageAt=frame
   elseif frame-C.stageAt>2400 then return unclear('actual_narrowing_and_corridor_exit_not_observed')end
  elseif C.phase=='queued'then
   sample(frame);if C.result then return C.result end
   if frame-C.stageAt>=12 then
    local q=queue(C.leader);if not q or #q~=2 or not same(q[1].params,C.q1)or not same(q[2].params,C.q2)then return fail('stock_queued_MOVE_order_not_preserved')end
    C.savedQueue=copy(q);C.killed=true;local hp=S.GetUnitHealth(C.leader);emit('CONTROLLED_LETHAL',C.leader,'native_damage_not_enemy_combat=true');S.AddUnitDamage(C.leader,hp*2,0,nil,-1);C.phase='succession';C.stageAt=frame
   end
  elseif C.phase=='succession'then
   if frame-C.stageAt>=12 then
    local survivor=C.originalMembers[2];local state=R.Get(survivor);if not C.deathCallback or not state or state.id~=C.seed or state.leader~=survivor or #R.Members(survivor)~=7 then return fail('real_survivor_successor_required')end
    C.leader=survivor;local count=C.totalBirths;if count~=8 then return fail('leader_death_created_free_body')end
    local q=queue(C.leader);if not q or #q~=2 or not same(q[1].params,C.q1)or not same(q[2].params,C.q2)then return fail('successor_did_not_inherit_exact_stock_queued_MOVEs')end
    emit('SUCCESSION_QUEUE',C.seed,C.original,C.leader,#q,'native_tag_numbers_not_compared_across_units=true')
    local at=position(C.leader);local site
    for _,offset in ipairs({{80,0},{-80,0},{0,80},{0,-80}})do local s=point(at[1]+offset[1],at[3]+offset[2]);if S.TestMoveOrder(N.wh40k_corck.id,s[1],s[2],s[3],0,0,0,true,true,false)==true then site=s;break end end
    local bd=D[N.wh40k_corck.id];if not site or not bd.isBuilder or bd.isFactory or bd.canFly or not finite(bd.buildSpeed)or bd.buildSpeed<=0 then return unclear('real_ground_builder_paid_repair_interface_unavailable')end
    C.previousLiveLeader=C.leader;C.repairBuilder=S.CreateUnit('wh40k_corck',site[1],site[2],site[3],0,0)
    if not live(C.repairBuilder)or S.GetUnitDefID(C.repairBuilder)~=N.wh40k_corck.id then return fail('controlled_ground_repair_builder_refused')end
    emit('CONTROLLED_UNPAID_REPAIR_BUILDER',C.repairBuilder,site[1],site[2],site[3]);C.phase='paid_repair_promotion';C.stageAt=frame;give(C.repairBuilder,CMD.REPAIR,{C.leader})
   end
  elseif C.phase=='paid_repair_promotion'then
   local state=R.Get(C.previousLiveLeader)
   if C.restored and C.finishes[C.restored]and state and state.leader==C.restored then
    if not live(C.previousLiveLeader)or not live(C.restored)or state.slots[1]~=C.restored or state.generations[1]~=2 or #R.Members(C.restored)~=8 then return fail('paid_slot1_restore_must_promote_real_new_generation_without_retiring_live_survivor')end
    local count=C.totalBirths;if count~=9 then return fail('exactly_one_paid_casualty_restore_required')end
    C.repaired=true;C.leader=C.restored;C.promotedAt=C.promotedAt or frame
    if frame-C.promotedAt>=12 then
     local q=queue(C.leader);local old=queue(C.previousLiveLeader)
     if not q or #q~=2 or not same(q[1].params,C.q1)or not same(q[2].params,C.q2)or not old or #old~=0 then return fail('slot1_promotion_must_leave_exactly_one_native_leader_route')end
     emit('PAID_REPAIR_PROMOTION',C.seed,C.previousLiveLeader,C.leader,count,state.generations[1],'exact_gross_debit_not_claimed=true');C.phase='queue_travel';C.stageAt=frame
    end
   elseif frame-C.stageAt>900 then return unclear('native_resource_paid_slot1_repair_not_observed')end
  elseif C.phase=='queue_travel'then
   sample(frame);if C.result then return C.result end
   local q=queue(C.leader);if not q then return unclear('successor_native_queue_unreadable')end
   if #q==1 and same(q[1].params,C.q2)then C.firstQueueConsumed=true end
   if C.firstQueueConsumed and nearAll(C.q2,100)then
    C.stopOrigin={};give(C.leader,CMD.STOP,{});C.phase='stop';C.stageAt=frame
   elseif frame-C.stageAt>2400 then return unclear('queued_MOVE_sequence_not_completed')end
  elseif C.phase=='stop'then
   if frame-C.stageAt==30 then for _,id in ipairs(R.Members(C.leader))do C.stopOrigin[id]=position(id)end end
   if frame-C.stageAt>=30 then
    local record=F.Get(C.seed)
    if record and(#(record.targets or{})>0 or record.state~='idle'and record.state~='arrived'and record.state~='paused_command')then return fail('STOP_left_stale_arrival_or_raw_follower_goals')end
    for _,id in ipairs(R.Members(C.leader))do local at=position(id);local old=C.stopOrigin[id];local vx,_,vz=S.GetUnitVelocity(id);local q=queue(id)
     if not old or not at or not q or #q~=0 or(at[1]-old[1])^2+(at[3]-old[3])^2>8^2 or vx*vx+vz*vz>.04 then return fail('STOP_did_not_clear_route_and_quiet_real_followers')end
     if(frame-C.stageAt)%6==0 then emit('STOP_BODY_SAMPLE',frame,C.seed,id,at[1],at[2],at[3],vx,vz,#q)end
    end
   end
   if frame-C.stageAt>=120 then
    emit('COMPLETE_OBSERVATIONS',C.samples,C.rawMovingSamples,C.headingSamples,C.bypassWitness,C.narrowWitness,C.firstQueueConsumed,C.repaired,'actual_path_request_count_unknown=true');return finish('PASS','controlled_scene_native_paid_full8_leader_route_raw_followers_common_heading_barrier_bypass_artificial_corridor_queued_MOVE_successor_paid_slot1_promotion_single_route_STOP transport_pause_natural_narrow_terrain_economy_combat_render_pending=true')
   end
  end
 end
 return C
end
return M

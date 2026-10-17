function gadget:GetInfo()return{name='40K ordinary paid Guard Flamer specialist research fixture',desc='Default-off native economy, research and preserved real slot roles',author='Local project',layer=151,enabled=true}end
local options=Spring.GetModOptions()or{}
local development=VFS.Include('40k_configs/development_playtest.lua')
local enabled=development.OptionEnabled
if not enabled(options.prototype_guard_squad_paid_research_fixture)or not development.Enabled(options)or not enabled(options.prototype_source_progression)then return false end
if not gadgetHandler:IsSyncedCode()then
 local closeAt
 local function done(_,result)Spring.Echo('40K_GUARD_SQUAD_PAID_RESEARCH owned_fixture_autoclose '..tostring(result));closeAt=Spring.GetGameFrame()+90 end
 function gadget:Initialize()gadgetHandler:AddSyncAction('fortyk_guard_squad_paid_research_done',done)end
 function gadget:GameFrame(frame)if closeAt and frame>=closeAt then closeAt=nil;Spring.SendCommands('quitforce')end end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction('fortyk_guard_squad_paid_research_done')end
 return
end
local combatEnabled=enabled(options.prototype_guard_paid_flamer_combat)
local combat
local S=Spring;local team=0;local phase='initial';local start;local mark;local timeout=1800*Game.gameSpeed
local commander,factory,armoury,firstProduct,futureProduct,seed,profile,record
local oldSpecial,missingOrdinary,heavyKilled,saved,missingInvestment,specialInvestment,replacementSpecialCost
local departure,departureAt,specialGeneration
local factoryDeliveryFrame
local egress={helper=VFS.Include('40k_configs/squad_fixture_egress.lua')}
local repairWitness={saveEnabled=enabled(options.prototype_squad_save_checkpoint_fixture),pendingResearch=enabled(options.prototype_squad_save_pending_research_fixture),originalSaveMembers={}}
repairWitness.birthProof={}
repairWitness.birthHelper=VFS.Include('40k_configs/paid_restore_birth_witness.lua')
local born={};local finished={};local jobObserved=false;local paid={steps=0,metal=0,energy=0};local healObserved=false;local lateProbe=false
local function emit(event,...)
 local a={...};for i=1,#a do a[i]=tostring(a[i])end;S.Echo('40K_GUARD_SQUAD_PAID_RESEARCH '..event..' '..table.concat(a,' '))
end
local function resources(event)
 local m,_,_,mi,me=S.GetTeamResources(team,'metal');local e,_,_,ei,ee=S.GetTeamResources(team,'energy')
 emit(event,'metal='..tostring(m),'energy='..tostring(e),'metal_income='..tostring(mi),'energy_income='..tostring(ei),
  'metal_expense='..tostring(me),'energy_expense='..tostring(ee),'net_delta_is_not_exact_bill=true');return m,e
end
function gadget:Initialize()
 if not repairWitness.saveEnabled then return end
 assert(not GG.Recoil40KGuardSquadSaveFixture,'Guard checkpoint context already owned')
 GG.Recoil40KGuardSquadSaveFixture={CheckpointContext=function()
  local originals={};for id,value in pairs(repairWitness.originalSaveMembers)do originals[id]=value end
  return{pendingResearch=repairWitness.pendingResearch,pendingReady=lateProbe,phase=phase=='heavy_restore'and'repair'or phase,seed=seed,commander=commander,missingSlot=8,team=team,
   originalMembers=originals,proof={paid_factory=not not(factory and born.imp_barracks==factory and finished[factory]),
    paid_full_squad=not not(seed and firstProduct),ordinary_start=repairWitness.initialPaid,paid_research=repairWitness.researchVerified},
   research={key=profile and profile.research,producer=armoury,lastSteps=paid.steps,lastMetal=paid.metal,lastEnergy=paid.energy}}
 end}
end
local function finish(reason)
 if reason:match('^PASS ')and repairWitness.saveEnabled then
  local observer=GG.Recoil40KSquadSaveCheckpoint;local status=observer and observer.Status()
  if status=='failed'then reason='FAIL native_research_save_observer_failed'
  elseif status~='complete'then repairWitness.pendingFinish=reason;repairWitness.pendingSince=repairWitness.pendingSince or S.GetGameFrame();return end
 end
 if phase=='done'then return end;phase='done';if combat and combat.Close then combat.Close()end;if GG.Recoil40KStompaWeaponWitness==combat then GG.Recoil40KStompaWeaponWitness=nil end;resources('FINAL_RESOURCES')
 emit('COMPLETE',reason,combatEnabled and'ordinary_paid_own_resources=true scripted_research_state_probe=true unpaid_hostile_target=true genuine_flamer_combat_scope_only=true visual_acceptance=false hud_click_acceptance=false'or'ordinary_resources=true scripted_state_probe_only=true weapon_combat_acceptance=false hud_click_acceptance=false')
 SendToUnsynced('fortyk_guard_squad_paid_research_done',reason)
end
local function fail(reason)finish('FAIL '..reason)end
local function live(id)
 if not id or S.GetUnitIsDead(id)then return false end
 local h,_,_,_,p=S.GetUnitHealth(id);return h and h>0 and p and p>=1 and S.GetUnitTeam(id)==team
end
local function contains(a,id)for _,v in ipairs(a or{})do if v==id then return true end end;return false end
local function near(a,b)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<.001 end
local function copyCost(c)return{metal=c.metal,energy=c.energy,work=c.work}end
local function bill(id,c)
 local work,m,e=S.GetUnitCosts(id)
 return near(work,c.work)and near(m,c.metal)and near(e,c.energy)
end
local function receipt(a,b)return a and near(a.metal,b.metal)and near(a.energy,b.energy)and near(a.work,b.work)end
local function sameOrders(a,b)
 if #a~=#b then return false end
 for i,c in ipairs(a)do local d=b[i];if c.id~=d.id or #(c.params or{})~=#(d.params or{})then return false end;for j,v in ipairs(c.params or{})do if v~=d.params[j]then return false end end
  local ca,da=c.options and c.options.coded or 0,d.options and d.options.coded or 0
  -- Native replay adds SHIFT to append the already queued command; this is not
  -- an order intent change. Preserve all other coded option bits exactly.
  if math.floor(ca/CMD.OPT_SHIFT)%2==1 then ca=ca-CMD.OPT_SHIFT end
  if math.floor(da/CMD.OPT_SHIFT)%2==1 then da=da-CMD.OPT_SHIFT end
  if ca~=da then return false end
 end;return true
end
local function stateFailureTrace(s,new,h,m,states)
 local work,metal,energy=S.GetUnitCosts(new)
 local orders=S.GetUnitCommands(new,-1)or{}
 local investment=s.investments[8]or{}
 local function field(name,pass,actual,expected)
  emit('SPECIALIST_STATE_FIELD','field='..name,'pass='..tostring(not not pass),'actual='..tostring(actual),'expected='..tostring(expected))
 end
 field('new_identity',new~=oldSpecial,new,'different_from_'..oldSpecial)
 field('old_dead',not live(oldSpecial),live(oldSpecial),false)
 field('fraction',math.abs(h/m-saved.fraction)<=.003,h/m,saved.fraction)
 field('xp',math.abs(S.GetUnitExperience(new)-saved.xp)<=.003,S.GetUnitExperience(new),saved.xp)
 field('heading',math.abs((S.GetUnitHeading(new)-saved.heading+32768)%65536-32768)<=1,S.GetUnitHeading(new),saved.heading)
 field('firestate',states.firestate==saved.fire,states.firestate,saved.fire)
 field('movestate',states.movestate==saved.move,states.movestate,saved.move)
 field('generation',s.generations[8]==specialGeneration,s.generations[8],specialGeneration)
 field('saved_wait',saved.orders[1]and saved.orders[1].id==CMD.WAIT,saved.orders[1]and saved.orders[1].id,CMD.WAIT)
 field('orders',sameOrders(saved.orders,orders),#orders,#saved.orders)
 for _,pair in ipairs({{'actual',orders},{'saved',saved.orders}})do
  for i,c in ipairs(pair[2])do local params={};for _,v in ipairs(c.params or{})do params[#params+1]=tostring(v)end
   emit('SPECIALIST_STATE_ORDER','side='..pair[1],'index='..i,'id='..tostring(c.id),'coded='..tostring(c.options and c.options.coded),'params='..table.concat(params,','))
  end
 end
 for _,key in ipairs({'metal','energy','work'})do field('investment_'..key,near(investment[key],specialInvestment[key]),investment[key],specialInvestment[key])end
 field('native_work',near(work,specialInvestment.work),work,specialInvestment.work)
 field('native_metal',near(metal,specialInvestment.metal),metal,specialInvestment.metal)
 field('native_energy',near(energy,specialInvestment.energy),energy,specialInvestment.energy)
end
local function count(s)local n=0;for _ in pairs(s.slots)do n=n+1 end;return n end
local function observeRepair(slot,c,label)
 local job=GG.Recoil40KSquads.repair[seed]
 if not job then return true end
 if job.slot~=slot or job.def~=(slot==8 and profile.special or profile.member)or job.work<0 or job.work>c.work
  or not near(job.metal,c.metal*job.work/c.work)or not near(job.energy,c.energy*job.work/c.work)then fail('invalid_native_'..label..'_partial_bill');return false end
 local old=repairWitness[label]
 if old and(job.work<old.work or job.metal<old.metal or job.energy<old.energy)then fail('regressed_native_'..label..'_partial_bill');return false end
 if job.work>0 and job.work<c.work then repairWitness[label]=copyCost(job);emit('PARTIAL_RESTORE_BILL','role='..label,'slot='..slot,'work='..job.work,'metal='..job.metal,'energy='..job.energy)end
 return true
end
local function current()return GG.Recoil40KSquads and GG.Recoil40KSquads.squads[seed]end
local function role(id,name)return live(id)and S.GetUnitDefID(id)==UnitDefNames[name].id end
local function probeTrace(event,frame)
 local s=current();local active=s and s.slots[8];local function body(prefix,id)
  local def=id and S.GetUnitDefID(id);local d=def and UnitDefs[def];local h,m
  if id then h,m=S.GetUnitHealth(id)end
  return prefix..'_id='..tostring(id)..' '..prefix..'_def='..tostring(def)..' '..prefix..'_hp='..tostring(h)..' '..prefix..'_max='..tostring(m)
   ..' '..prefix..'_xp='..tostring(id and S.GetUnitExperience(id))..' '..prefix..'_autoHeal='..tostring(d and d.autoHeal)
   ..' '..prefix..'_idleAutoHeal='..tostring(d and d.idleAutoHeal)..' '..prefix..'_idleTime='..tostring(d and d.idleTime)
 end
 local q=S.GetUnitCommands(commander,3)or{};local head=q[1];local args={}
 local building=S.GetUnitIsBuilding(commander)
 for _,v in ipairs(head and head.params or{})do args[#args+1]=tostring(v)end
 local cx,_,cz=S.GetUnitPosition(commander);local x,z
 if active then local px,py,pz=S.GetUnitPosition(active);x,z=px,pz end
 local distance=cx and cz and x and z and math.sqrt((cx-x)^2+(cz-z)^2)
 local commanderDef=S.GetUnitDefID(commander);local cd=commanderDef and UnitDefs[commanderDef]
 emit(event,'frame='..frame,'paid_steps='..paid.steps,body('old',oldSpecial),body('slot8',active),
  'saved_fraction='..tostring(saved and saved.fraction),'commander='..tostring(commander),'commander_def='..tostring(commanderDef),
  'commander_building='..tostring(building),'commander_queue_sample_count='..#q,
  'commander_head='..tostring(head and head.id),'commander_tag='..tostring(head and head.tag),'commander_params='..table.concat(args,','),
  'commander_distance='..tostring(distance),'commander_buildDistance='..tostring(cd and cd.buildDistance),'native_healing_and_builder_mechanics_unchanged=true')
end
local function healthy(s)for _,id in pairs(s.slots)do local h,m=S.GetUnitHealth(id);if not h or h<m-.01 then return false end end;return true end
-- Read-only stall witness: never changes order, resources, body or repair state.

-- Read-only diagnostics only; caller and local throttle require a 300-frame sample.
local function placementTrace(frame,defID,x,z)
 if frame%300~=0 then return end
 local function read(name,...)
  local f=S[name];if type(f)~='function'then return nil end
  local okay,a,b,c,d,e,f,g=pcall(f,...);if okay then return a,b,c,d,e,f,g end
 end
 local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
 local d=UnitDefs[defID];if not d then return end
 local rawY=read('GetGroundHeight',x,z)
 local sx,sy,sz=read('Pos2BuildPos',defID,x,rawY or 0,z,0)
 if not finite(sx)or not finite(sy)or not finite(sz)then
  emit('REPAIR_SITE_NATIVE','frame='..frame,'unavailable=snapped_position','raw_x='..x,'raw_z='..z);return
 end
 local nx,nz=tonumber(d.xsize),tonumber(d.zsize)
 if not nx or not nz or nx<1 or nz<1 or nx~=math.floor(nx)or nz~=math.floor(nz)or nx*nz>64 then
  emit('REPAIR_SITE_NATIVE','frame='..frame,'unavailable=bounded_footprint','xsize='..tostring(nx),'zsize='..tostring(nz));return
 end
 local x1,z1=math.floor(sx/8)-math.floor(nx/2),math.floor(sz/8)-math.floor(nz/2)
 local x2,z2=x1+nx-1,z1+nz-1
 local terrain=read('TestMoveOrder',defID,sx,sy,sz,0,0,0,true,false,false)
 local objects=read('TestMoveOrder',defID,sx,sy,sz,0,0,0,false,true,false)
 local both=read('TestMoveOrder',defID,sx,sy,sz,0,0,0,true,true,false)
 local blockedType,blockedID=read('GetGroundBlocked',x1*8,z1*8,x2*8,z2*8)
 local md=type(d.moveDef)=='table'and d.moveDef or{}
 emit('REPAIR_SITE_NATIVE','frame='..frame,'def='..defID,'name='..tostring(d.name),
  'raw='..table.concat({x,rawY or'nil',z},','),'snapped='..table.concat({sx,sy,sz},','),
  'xsize='..nx,'zsize='..nz,'pathType='..tostring(d.pathType),'buildMask='..tostring(d.buildMask),
  'move_maxSlope='..tostring(md.maxSlope),'move_depth='..tostring(md.depth),'move_class='..tostring(md.speedModClass),
  'terrain_only='..tostring(terrain),'objects_only='..tostring(objects),'both='..tostring(both),
  'blocked_type='..tostring(blockedType),'blocked_id='..tostring(blockedID),
  'move_read_requires_native_mobile_path_and_visibility=true yard_mask_not_exposed=true')
 local cells={}
 for gz=z1,z2 do for gx=x1,x2 do
  local cx,cz=gx*8,gz*8;local h=read('GetGroundHeight',cx,cz)
  local _,_,_,slope=read('GetGroundNormal',cx,cz,false)
  local kind,id=read('GetGroundBlocked',cx,cz)
  cells[#cells+1]=table.concat({cx,cz,tostring(h),tostring(slope),tostring(kind),tostring(id)},',')
 end end
 emit('REPAIR_SITE_CELLS','frame='..frame,'snapped_x='..sx,'snapped_z='..sz,'cells='..table.concat(cells,';'),'max_cells=64')
 local us=read('GetUnitsInRectangle',x1*8-256,z1*8-256,(x2+1)*8+256,(z2+1)*8+256)or{}
 local fs=read('GetFeaturesInRectangle',x1*8-64,z1*8-64,(x2+1)*8+64,(z2+1)*8+64)or{}
 local units,features={},{}
 for i,id in ipairs(us)do if i>16 then break end
  local udID=read('GetUnitDefID',id);local ud=udID and UnitDefs[udID]or{}
  local ux,uy,uz=read('GetUnitPosition',id);local blocked=read('GetUnitBlocking',id)
  units[#units+1]=table.concat({id,tostring(udID),tostring(ux),tostring(uy),tostring(uz),
   tostring(ud.xsize),tostring(ud.zsize),tostring(blocked)},',')
 end
 for i,id in ipairs(fs)do if i>16 then break end
  local fdID=read('GetFeatureDefID',id);local fd=fdID and FeatureDefs and FeatureDefs[fdID]or{}
  local fx,fy,fz=read('GetFeaturePosition',id);local blocked=read('GetFeatureBlocking',id)
  features[#features+1]=table.concat({id,tostring(fdID),tostring(fx),tostring(fy),tostring(fz),
   tostring(fd.reclaimable),tostring(blocked)},',')
 end
 emit('REPAIR_SITE_OBJECTS','frame='..frame,'snapped_x='..sx,'snapped_z='..sz,
  'units='..table.concat(units,';'),'features='..table.concat(features,';'),
  'unit_count='..#us,'feature_count='..#fs,'unit_truncated='..tostring(#us>16),'feature_truncated='..tostring(#fs>16),'each_cap=16')
end

local function repairTrace(event,frame)
 local s=current();if not s or not live(commander)then return end
 local cd=UnitDefs[S.GetUnitDefID(commander)]
 local cx,cy,cz=S.GetUnitPosition(commander);local lx,ly,lz=S.GetUnitPosition(s.leader)
 local move=S.GetUnitMoveTypeData(commander)or{}
 local q=S.GetUnitCommands(commander,-1)or{};local job=GG.Recoil40KSquads.repair[seed]
 emit(event,'frame='..frame,'phase='..phase,'seed='..seed,'leader='..s.leader,'living='..count(s),
  'healthy='..tostring(healthy(s)),'needs_repair='..tostring(GG.Recoil40KSquads.NeedsRepair(s.leader)),
  'commander='..commander,'isBuilder='..tostring(cd.isBuilder),'isFactory='..tostring(cd.isFactory),
  'buildSpeed='..tostring(cd.buildSpeed),'buildDistance='..tostring(cd.buildDistance),
  'commander_pos='..table.concat({cx,cy,cz},','),'leader_pos='..table.concat({lx,ly,lz},','),
  'leader_distance='..math.sqrt((cx-lx)^2+(cz-lz)^2),'queue_count='..#q,'fallback_calls='..tostring(GG.Recoil40KGuardRepairWitness and GG.Recoil40KGuardRepairWitness[commander]and GG.Recoil40KGuardRepairWitness[commander].fallback or 0),
  'native_building='..tostring((S.GetUnitIsBuilding(commander))),
  'move_progress='..tostring(move.progressState),'move_goal='..table.concat({tostring(move.goalx),tostring(move.goaly),tostring(move.goalz)},','),
  'move_radius='..tostring(move.goalRadius),'move_speed='..tostring(move.currentSpeed),
  'job_slot='..tostring(job and job.slot),'job_work='..tostring(job and job.work),
  'job_metal='..tostring(job and job.metal),'job_energy='..tostring(job and job.energy))
 for i,c in ipairs(q)do local p={};for _,v in ipairs(c.params or{})do p[#p+1]=tostring(v)end
  emit('REPAIR_QUEUE','frame='..frame,'index='..i,'id='..c.id,'tag='..tostring(c.tag),'coded='..tostring(c.options and c.options.coded),'params='..table.concat(p,','))
 end
 for slot,id in pairs(s.slots)do local h,m=S.GetUnitHealth(id)
  emit('REPAIR_SURVIVOR','frame='..frame,'slot='..slot,'id='..id,'health='..tostring(h),'max='..tostring(m),'transport='..tostring((S.GetUnitTransporter(id))))
 end
 if job and job.work>=UnitDefNames[job.def].buildTime-1e-7 then
  for _,off in ipairs({{24,0},{0,24},{-24,0},{0,-24},{24,24},{-24,24},{24,-24},{-24,-24},{40,0},{0,40},{-40,0},{0,-40}})do
   local x,z=lx+off[1],lz+off[2];local y=S.GetGroundHeight(x,z)
   local state,feature=S.TestBuildOrder(UnitDefNames[job.def].id,x,y,z,0)
   local ids=S.GetUnitsInCylinder(x,z,16)or{}
   emit('REPAIR_SITE','frame='..frame,'x='..x,'z='..z,'state='..tostring(state),'feature='..tostring(feature),'near_units='..table.concat(ids,','))
   placementTrace(frame,UnitDefNames[job.def].id,x,z)
  end
 end
end
local function clear(def,x,z)
 local d=UnitDefs[def];local hx,hz=d.xsize*4,d.zsize*4
 if x-hx<64 or z-hz<64 or x+hx>Game.mapSizeX-64 or z+hz>Game.mapSizeZ-64 then return false end
 for _,id in ipairs(S.GetUnitsInRectangle(x-hx-32,z-hz-32,x+hx+32,z+hz+32)or{})do
  if id~=commander then return false end
  local cx,_,cz=S.GetUnitPosition(id);local cd=UnitDefs[S.GetUnitDefID(id)]
  if math.abs(cx-x)<hx+cd.xsize*4+8 and math.abs(cz-z)<hz+cd.zsize*4+8 then return false end
 end
 return #(S.GetFeaturesInRectangle(x-hx-16,z-hz-16,x+hx+16,z+hz+16)or{})==0
end
local function exits(def,x,z)
 local fd=UnitDefs[def];local pd=UnitDefs[UnitDefNames.imp_guardsman.id]
 local radius=math.max(fd.xsize,fd.zsize)*4+math.max(pd.xsize,pd.zsize)*4+32;local n=0
 for j=0,15 do local a=j*math.pi/8;local ex,ez=x+radius*math.cos(a),z+radius*math.sin(a);local ey=S.GetGroundHeight(ex,ez)
  if ex>32 and ez>32 and ex<Game.mapSizeX-32 and ez<Game.mapSizeZ-32 and ey>=0
   and S.TestMoveOrder(pd.id,ex,ey,ez,0,0,0,true,true,false)then n=n+1 end
 end;return n>=4
end
local function site(def,isFactory)
 local cx,_,cz=S.GetUnitPosition(commander)
 for ring=6,30 do for j=0,15 do local a=j*math.pi/8
  local x,y,z=S.Pos2BuildPos(def,cx+ring*32*math.cos(a),0,cz+ring*32*math.sin(a),0);y=S.GetGroundHeight(x,z)
  local status,feature=S.TestBuildOrder(def,x,y,z,0)
  if y>=0 and status==2 and not feature and clear(def,x,z)and(not isFactory or exits(def,x,z))then return{x,y,z,0}end
 end end
end
local function outsideSquadRepair(s,x,z)
 local d=UnitDefs[S.GetUnitDefID(commander)];local range=d and d.buildDistance
 if type(range)~='number'or range<=0 then return false end
 for _,id in pairs(s.slots)do
  local px,_,pz=S.GetUnitPosition(id);local body=UnitDefs[S.GetUnitDefID(id)]
  local margin=range+math.max(body.xsize,body.zsize)*4+128
  if not px or (px-x)^2+(pz-z)^2<=margin^2 then return false end
 end
 return true
end
-- Departure must be outside whole object footprints, including factory EXITONLY
-- yards whose centers are beyond the old commander-sized rectangle query.
local departureGate=VFS.Include('40k_configs/paid_ground_site_gate.lua')
local function departureClear(def,x,y,z)
 local d=UnitDefs[def];local half=math.max(d.xsize,d.zsize)*4
 if x-half<64 or z-half<64 or x+half>Game.mapSizeX-64 or z+half>Game.mapSizeZ-64 then return false end
 if type(S.GetAllUnits)~='function'then return false end
 local ids=S.GetAllUnits();if type(ids)~='table'then return false end
 for _,id in ipairs(ids)do if id~=commander then
  local ud=UnitDefs[S.GetUnitDefID(id)];local ux,_,uz=S.GetUnitPosition(id)
  if not ud or type(ud.xsize)~='number'or type(ud.zsize)~='number'or not ux or not uz then return false end
  -- A square enclosing any facing also excludes the complete factory yard.
  local otherHalf=math.max(ud.xsize,ud.zsize)*4
  if math.abs(ux-x)<=half+otherHalf+8 and math.abs(uz-z)<=half+otherHalf+8 then return false end
 end end
 -- Existing exact native volume inventories also cover model offsets/features.
 return departureGate.Clearance(S,commander,factory,{x,y,z})
end
local function depart(frame)
 local s=current();local def=S.GetUnitDefID(commander);local cx,_,cz=S.GetUnitPosition(commander)
 local stopped=S.GiveOrderToUnit(commander,CMD.STOP,{},0)
 if stopped==false then finish('INCONCLUSIVE native_builder_departure_stop_rejected');return end
 for ring=6,40 do for j=0,15 do local a=j*math.pi/8;local x,z=cx+ring*32*math.cos(a),cz+ring*32*math.sin(a);local y=S.GetGroundHeight(x,z)
  if x>64 and z>64 and x<Game.mapSizeX-64 and z<Game.mapSizeZ-64 and y>=0 and outsideSquadRepair(s,x,z)
   and departureClear(def,x,y,z)and S.TestMoveOrder(def,x,y,z,0,0,0,true,true,false)then
   departure={x,y,z};departureAt=frame;phase='builder_departure'
   local accepted=S.GiveOrderToUnit(commander,CMD.MOVE,departure,0)
   emit('BUILDER_DEPARTURE','native_move=true no_teleport=true','x='..x,'z='..z,'return='..tostring(accepted))
   if accepted==false then finish('INCONCLUSIVE native_builder_departure_order_rejected')end
   return
  end
 end end
 finish('INCONCLUSIVE no_legal_builder_departure_site')
end
local function construct(name,nextPhase)
 local d=UnitDefNames[name];local c=GG.Recoil40KResearch
 if not contains(UnitDefs[S.GetUnitDefID(commander)].buildOptions,d.id)or not c.CanBuild(team,d.id,commander,false)then fail('unreachable_paid_build '..name);return end
 local p=site(d.id,UnitDefs[d.id].isFactory);if not p then finish('INCONCLUSIVE no_native_clear_site '..name);return end
 phase=nextPhase;resources('BUILD_ORDER_RESOURCES')
 local ok=S.GiveOrderToUnit(commander,-d.id,p,0)
 emit('BUILD_ORDER','name='..name,'native_command=true native_approach=true','return='..tostring(ok))
 if ok==false then finish('INCONCLUSIVE native_build_order_rejected '..name)end
end
local function queue(future)
 local d=UnitDefNames.imp_guardsman;local c=GG.Recoil40KResearch
 if not c.CanBuild(team,d.id,factory,false)then finish('INCONCLUSIVE paid_product_gate');return end
 phase=future and'future_product'or'first_product';resources('PRODUCT_ORDER_RESOURCES')
 local ok=S.GiveOrderToUnit(factory,-d.id,{},0)
 emit('PRODUCT_ORDER','cohort='..(future and'future'or'current'),'full_metal='..UnitDefs[d.id].metalCost,'full_energy='..UnitDefs[d.id].energyCost,'full_work='..UnitDefs[d.id].buildTime)
 if ok==false then finish('INCONCLUSIVE native_product_order_rejected')end
end
function gadget:UnitCreated(id,def,owner,builder)
 if phase=='heal_restore'or phase=='heavy_restore'then
  local label=phase=='heal_restore'and'ordinary'or'special'
  local slot=label=='ordinary'and 2 or 8
  local name=label=='ordinary'and profile.member or profile.special
  local cost=label=='ordinary'and missingInvestment or replacementSpecialCost
  local proof,checks=repairWitness.birthHelper.Observe(S,GG.Recoil40KSquads,UnitDefs,UnitDefNames,34591,commander,seed,slot,name,cost,id,def,owner,builder)
  for field,pass in pairs(checks)do emit('RESTORE_BIRTH_FIELD','role='..label,'new='..id,'field='..field,'pass='..tostring(pass))end
  if proof then repairWitness.birthProof[label]=proof;emit('PAID_RESTORE_BIRTH_JOB','role='..label,'id='..id,'slot='..slot,'frame='..proof.frame,'work='..proof.work,'metal='..proof.metal,'energy='..proof.energy,'native_builder_nil=true readonly_full_job_before_bind=true')end
 end
 if owner~=team then return end
 local name=UnitDefs[def].name
 if phase=='build_factory'and name=='imp_barracks'or phase=='build_armoury'and name=='imp_research'then
  if builder~=commander or born[name]then fail('not_single_native_commander_build '..name);return end
  local _,_,_,_,p=S.GetUnitHealth(id);if not p or p>=1 then fail('structure_not_native_incomplete '..name);return end
  born[name]=id;emit('STRUCTURE_BIRTH','name='..name,'builder='..builder,'progress='..p)
 elseif name=='imp_guardsman'and(phase=='first_product'or phase=='future_product')then
  if builder~=factory or(phase=='first_product'and firstProduct)or(phase=='future_product'and futureProduct)then fail('not_single_native_factory_product');return end
  if phase=='first_product'then firstProduct=id else futureProduct=id end
  emit('PRODUCT_BIRTH','id='..id,'builder='..builder,'cohort_phase='..phase)
 end
end
function gadget:UnitFinished(id)finished[id]=true end
function gadget:UnitFromFactory(id,def,owner,producer)
 if id~=firstProduct then return end
 if def~=UnitDefNames.imp_guardsman.id or owner~=team or producer~=factory then fail('wrong_native_factory_delivery_callback');return end
 factoryDeliveryFrame=S.GetGameFrame();emit('FACTORY_DELIVERY_CALLBACK','id='..id,'producer='..producer,'frame='..factoryDeliveryFrame)
end
function gadget:GameFrame(frame)
 if phase=='done'then return end
 if repairWitness.saveEnabled and GG.Recoil40KSquadSaveCheckpoint and GG.Recoil40KSquadSaveCheckpoint.Status()=='failed'then fail('native_research_save_observer_failed');return end
 if repairWitness.pendingFinish then
  local observer=GG.Recoil40KSquadSaveCheckpoint;local status=observer and observer.Status()
  if status=='failed'then repairWitness.pendingFinish=nil;fail('native_research_save_observer_failed');return end
  if status=='complete'then local result=repairWitness.pendingFinish;repairWitness.pendingFinish=nil;finish(result);return end
  if frame-repairWitness.pendingSince>=300 then repairWitness.pendingFinish=nil;fail('native_research_save_terminal_timeout')end;return
 end
 if not start then start=frame end
 if frame-start>timeout then finish('INCONCLUSIVE timeout ordinary_economic_or_native_gate phase='..phase);return end
 if phase=='initial'then
  if repairWitness.pendingResearch and(not repairWitness.saveEnabled or combatEnabled or (enabled(options.prototype_squad_save_first_tick_fixture)~=enabled(options.prototype_squad_save_pending_first_tick_fixture)))then fail('pending_research_route_unsupported');return end
  if repairWitness.saveEnabled and combatEnabled then fail('save_combat_route_unsupported');return end
  if not enabled(options.prototype_guard_squad_flamer)then fail('genuine_guard_flamer_profile_not_enabled');return end
  if enabled(options.prototype_scale085_pilot)then fail('unpaired_guard_flamer_scale085');return end
  for _,key in ipairs({'prototype_squad_fixture','prototype_squad_paid_fixture','prototype_squad_egress_fixture','prototype_corpse_blast_fixture','prototype_squad_paid_research_fixture','prototype_ork_squad_paid_research_fixture'})do if enabled(options[key])then fail('conflicting_fixture '..key);return end end
  for _,key in ipairs({'armcom','imp_barracks','imp_research','imp_guardsman','imp_guardsman_member','imp_guardsman_flamer_member'})do if not UnitDefNames[key]then fail('missing_definition '..key);return end end
  local R,C=GG.Recoil40KSquads,GG.Recoil40KResearch
  if not R or not C or next(R.squads)then fail('missing_or_preexisting_controller_squads');return end
  profile=VFS.Include('40k_configs/active_squad_profiles.lua').profiles.guard_line
  local special=UnitDefs[UnitDefNames[profile.special].id]
  replacementSpecialCost={metal=special.metalCost,energy=special.energyCost,work=special.buildTime}
  record=C.records[profile.research]
  if profile.capacity~=8 or profile.specialSlot~=8 or not record or record.producer~='imp_research'
   or record.row.cost.metal~=200 or record.row.cost.energy~=1000 or record.row.time~=35 or record.frames~=35*Game.gameSpeed then fail('wrong_genuine_research_contract');return end
  local units=S.GetTeamUnits(team)or{};if #units~=1 or not role(units[1],'armcom')then fail('need_natural_single_armcom');return end;commander=units[1]
  local m,e=resources('INITIAL_RESOURCES');if not near(m,1000)and math.abs((m or 0)-1000)>5 or not near(e,1000)and math.abs((e or 0)-1000)>5 then fail('not_ordinary_start');return end
  repairWitness.initialPaid=true
  local pd,md=UnitDefs[UnitDefNames.imp_guardsman.id],UnitDefs[UnitDefNames[profile.member].id]
  if not UnitDefs[UnitDefNames.imp_barracks.id].isFactory
   or not contains(UnitDefs[UnitDefNames.imp_barracks.id].buildOptions,pd.id)
   or not near(pd.metalCost,md.metalCost*8)or not near(pd.energyCost,md.energyCost*8)or not near(pd.buildTime,md.buildTime*8)then fail('wrong_native_full_price_product');return end
  if C.HasResearch(team,profile.research)then fail('research_pregranted');return end
  emit('CONTRACT','ordinary_start=1000/1000 cohorts=2 no_spawns_or_grants=true','scale_pilot='..tostring(options.prototype_scale085_pilot))
  construct('imp_barracks','build_factory')
 elseif phase=='build_factory'then
  local id=born.imp_barracks;if id and live(id)and finished[id]then factory=id;queue(false)end
 elseif phase=='first_product'then
  local s=firstProduct and GG.Recoil40KSquads.Get(firstProduct)
  if s then
   if s.profile~='guard_line'or count(s)~=8 then fail('not_full_current_cohort');return end
   seed=s.id;oldSpecial=s.slots[8];missingOrdinary=s.slots[2]
   if not role(oldSpecial,profile.member)then fail('unresearched_special_not_ordinary');return end
   missingInvestment=copyCost(s.investments[2]);specialInvestment=copyCost(s.investments[8]);specialGeneration=s.generations[8]
   for slot,id in pairs(s.slots)do if not bill(id,s.investments[slot])then fail('current_native_body_bill');return end end
   S.GiveOrderToUnit(s.leader,CMD.STOP,{},0);S.GiveOrderToUnit(s.leader,CMD.FIRE_STATE,{0},0);S.GiveOrderToUnit(s.leader,CMD.MOVE_STATE,{0},0)
   S.GiveOrderToUnit(s.leader,CMD.WAIT,{},0);mark=frame;phase='delivery_checkpoint';emit('DELIVERY','cohort=current members=8 native_product=true native_capture_grace=30')
  end
 elseif phase=='delivery_checkpoint'and frame-mark>=30 then
  if not factoryDeliveryFrame then fail('native_factory_delivery_not_observed_before_late_wait');return end
  local s=current();local why
  egress.goal,why=egress.helper.Plan(S,UnitDefs,Game,factory,s)
  if not egress.goal then finish('INCONCLUSIVE cohort_egress_'..tostring(why));return end
  if S.GiveOrderToUnit(s.leader,CMD.MOVE,{egress.goal[1],egress.goal[2],egress.goal[3]},0)==false then finish('INCONCLUSIVE cohort_egress_order_rejected');return end
  egress.at=frame;phase='cohort_egress'
  emit('COHORT_EGRESS_ORDER','ordinary_leader_move=true','planned_bodies=8','target='..egress.goal[1]..','..egress.goal[3])
 elseif phase=='cohort_egress'then
  if frame-egress.at>120*Game.gameSpeed then finish('INCONCLUSIVE cohort_egress_path_timeout');return end
  if frame%15==0 then
   local s=current();if not s or count(s)~=8 then finish('INCONCLUSIVE cohort_egress_members_missing');return end
   for i=1,8 do if not live(s.slots[i])then finish('INCONCLUSIVE cohort_egress_members_not_live');return end end
   local outside,n=egress.helper.Outside(S,UnitDefs,factory,s)
   if outside then
    S.GiveOrderToUnit(s.leader,CMD.STOP,{},0);S.GiveOrderToUnit(s.leader,CMD.WAIT,{},0)
    emit('COHORT_EGRESS_COMPLETE','outside_bodies='..n,'factory_footprint_margin=16','ordinary_movement=true')
    construct('imp_research','build_armoury')
   elseif frame%300==0 then emit('COHORT_EGRESS_WAIT','outside_bodies='..n,'required=8')end
  end
 elseif phase=='build_armoury'then
  local id=born.imp_research;if id and live(id)and finished[id]then
   armoury=id;local s=current();if not s or count(s)~=8 or not live(oldSpecial)then fail('current_cohort_lost');return end
   depart(frame)
  end
 elseif phase=='builder_departure'then
  local s=current();local x,_,z=S.GetUnitPosition(commander);local queue=S.GetUnitCommands(commander,1)or{};local building=S.GetUnitIsBuilding(commander)
  if frame-departureAt>120*Game.gameSpeed then finish('INCONCLUSIVE native_builder_departure_stalled');return end
  if not s or not x then fail('builder_departure_cohort_lost');return end
  if queue[1]and queue[1].id~=CMD.MOVE then finish('INCONCLUSIVE native_builder_departure_interrupted');return end
  if not queue[1]and not building and (x-departure[1])^2+(z-departure[3])^2<=32^2 and outsideSquadRepair(s,x,z)then
   S.GiveOrderToUnit(commander,CMD.STOP,{},0)
   emit('BUILDER_DEPARTURE_COMPLETE','native_arrival=true all_survivors_outside_repair_range_plus128=true','x='..x,'z='..z)
   if not factoryDeliveryFrame then fail('native_factory_delivery_not_observed_before_late_wait');return end
   local stop=S.GiveOrderToUnit(s.leader,CMD.STOP,{},0)
   local wait=S.GiveOrderToUnit(s.leader,CMD.WAIT,{},0)
   mark=frame;phase='late_wait_settle'
   emit('LATE_LEADER_WAIT_ORDER','leader='..s.leader,'slot8='..oldSpecial,'factory_delivery_frame='..factoryDeliveryFrame,
    'frame='..frame,'stop_return='..tostring(stop),'wait_return='..tostring(wait),'native_returns_not_admission_proof=true once_only=true')
  end
 elseif phase=='late_wait_settle'and frame>mark then
  local s=current();if not s or s.slots[8]~=oldSpecial or not role(oldSpecial,profile.member)then fail('late_wait_probe_cohort_changed');return end
  local q=S.GetUnitCommands(oldSpecial,-1)or{}
  if q[1]and q[1].id==CMD.WAIT then
   emit('LATE_LEADER_WAIT_READBACK','frame='..frame,'slot8='..oldSpecial,'native_head='..q[1].id,'native_queue_count='..#q,'nonempty_wait_required=true')
   S.SetUnitExperience(oldSpecial,.7);mark=frame;phase='experience_settle'
   emit('STATE_PROBE','fixture_only_XP=.7 weapon_combat_acceptance=false')
  elseif frame-mark>=30 then
   local leader=S.GetUnitCommands(s.leader,-1)or{}
   emit('LATE_LEADER_WAIT_REFUSAL','frame='..frame,'leader='..s.leader,'slot8='..oldSpecial,'leader_head='..tostring(leader[1]and leader[1].id),
    'slot8_head='..tostring(q[1]and q[1].id),'slot8_queue_count='..#q,'bounded_frames=30 no_reissue=true')
   fail('native_leader_wait_not_delivered_before_state_probe')
  end
 elseif phase=='experience_settle'and frame-mark>=15 then
  local _,max=S.GetUnitHealth(oldSpecial);local hp=S.GetUnitHealth(oldSpecial);S.AddUnitDamage(oldSpecial,math.max(1,hp-max*.62),0,nil,-1);mark=frame;phase='wound_settle'
  emit('STATE_PROBE','fixture_only_scripted_damage_target_fraction=.62 no_builder_repair=true native_idle_healing_unchanged=true')
 elseif phase=='wound_settle'and frame-mark>=15 then
  local h,m=S.GetUnitHealth(oldSpecial);local states=S.GetUnitStates(oldSpecial)
  saved={fraction=h/m,xp=S.GetUnitExperience(oldSpecial),heading=S.GetUnitHeading(oldSpecial),fire=states.firestate,move=states.movestate,orders=S.GetUnitCommands(oldSpecial,-1)or{}}
  if repairWitness.pendingResearch then phase='casualty_before_research'
  else local hp=S.GetUnitHealth(missingOrdinary);phase='casualty_before_research';S.AddUnitDamage(missingOrdinary,hp*4+10000,0,nil,-1)end
  if repairWitness.pendingResearch then emit('CURRENT_FULL8_PENDING_RESEARCH','slot2_preserved=true no_casualty_probe=true')
  else emit('MISSING_SLOT_PROBE','slot=2 scripted_native_damage=true no_free_research_reinforcement_expected=true')end
 elseif phase=='casualty_before_research'then
  local s=current();if not s or(repairWitness.pendingResearch and(count(s)~=8 or not s.slots[2])or not repairWitness.pendingResearch and(count(s)~=7 or s.slots[2]or live(missingOrdinary)))then fail('scripted_missing_slot_not_seven_survivors');return end
  local found=false;for _,d in ipairs(S.GetUnitCmdDescs(armoury)or{})do if d.id==record.cmd and not d.disabled then found=true end end
  if not found then finish('INCONCLUSIVE actual_research_descriptor_unavailable');return end
  phase='research';resources('RESEARCH_ORDER_RESOURCES')
  local ok=S.GiveOrderToUnit(armoury,record.cmd,{},0)
  emit('RESEARCH_ORDER','native_cmd='..record.cmd,'metal=200 energy=1000 native_seconds=35','return='..tostring(ok))
  if ok==false then finish('INCONCLUSIVE native_research_order_rejected')end
 elseif phase=='research'then
  local C=GG.Recoil40KResearch;local s=current();if not s or(repairWitness.pendingResearch and(count(s)~=8 or not s.slots[2])or not repairWitness.pendingResearch and(s.slots[2]or count(s)~=7))then fail('research_free_missing_slot_birth');return end
  local job=C.jobs[armoury]and C.jobs[armoury][profile.research]
  if job then
   if job.team~=team or job.cmd~=record.cmd or job.steps<paid.steps or job.metal<paid.metal or job.energy<paid.energy
    or not near(job.metal,200*job.steps/record.frames)or not near(job.energy,1000*job.steps/record.frames)then fail('actual_research_payment_receipt');return end
   jobObserved=jobObserved or job.steps>0;paid={steps=job.steps,metal=job.metal,energy=job.energy}
   if job.steps>=record.frames-30 and not lateProbe and role(oldSpecial,profile.member)then
    probeTrace('PROBE_BEFORE_REFRESH',frame)
    lateProbe=true -- Disclosed scripted native damage resets the idle-heal timer below.
    local _,max=S.GetUnitHealth(oldSpecial);local hp=S.GetUnitHealth(oldSpecial);S.AddUnitDamage(oldSpecial,math.max(1,hp-max*.62),0,nil,-1)
    probeTrace('PROBE_AFTER_REFRESH',frame)
    emit('STATE_PROBE','final30_paid_steps=true bounded_fixture_native_damage_refresh=.62 native_damage_idle_timer_reset=true weapon_combat_acceptance=false')
   end
  end
  if lateProbe and role(oldSpecial,profile.member)then
   local h,m=S.GetUnitHealth(oldSpecial);local states=S.GetUnitStates(oldSpecial)
   saved={fraction=h/m,xp=S.GetUnitExperience(oldSpecial),heading=S.GetUnitHeading(oldSpecial),fire=states.firestate,move=states.movestate,orders=S.GetUnitCommands(oldSpecial,-1)or{}}
  end
  if lateProbe and frame%15==0 then probeTrace('PROBE_NATIVE_STATE',frame)end
  if C.HasResearch(team,profile.research)then
   probeTrace('PROBE_RESEARCH_COMPLETE',frame)
   if not jobObserved or paid.steps<record.frames-2 or S.GetTeamRulesParam(team,'40k_research_'..profile.research)~=1 then fail('completion_without_observed_native_paid_job');return end
   local new=s.slots[8]
   if role(new,profile.special)then
    if not lateProbe or saved.fraction>=.999 then finish('INCONCLUSIVE state_probe_healed_during_ordinary_research_stall');return end
    local h,m=S.GetUnitHealth(new);local states=S.GetUnitStates(new)
    if new==oldSpecial or live(oldSpecial)or math.abs(h/m-saved.fraction)>.003 or math.abs(S.GetUnitExperience(new)-saved.xp)>.003
     or math.abs((S.GetUnitHeading(new)-saved.heading+32768)%65536-32768)>1 or states.firestate~=saved.fire or states.movestate~=saved.move
     or s.generations[8]~=specialGeneration or not saved.orders[1]or saved.orders[1].id~=CMD.WAIT or not sameOrders(saved.orders,S.GetUnitCommands(new,-1)or{})
     or not receipt(s.investments[8],specialInvestment)or not bill(new,specialInvestment)then stateFailureTrace(s,new,h,m,states);fail('live_specialist_state_or_slot_bill_not_preserved');return end
    emit('RESEARCH_COMPLETE','actual_job_last_steps='..paid.steps,'actual_job_last_metal='..paid.metal,'actual_job_last_energy='..paid.energy,
     'registered_full_bill=200/1000 observed_native_completion=true '..(repairWitness.pendingResearch and'current8_preserved=true'or'missing_slot_still_empty=true'),'new_special='..new,'wound_fraction='..h/m,'xp='..S.GetUnitExperience(new))
    repairWitness.researchVerified=true
    if repairWitness.pendingResearch then finish('PASS ordinary_pending_paid_guard_research full8_preserved_permanent_transform');return end
    S.GiveOrderToUnit(s.leader,CMD.STOP,{},0);resources('HEAL_THEN_RESTORE_ORDER_RESOURCES');phase='heal_restore';S.GiveOrderToUnit(commander,CMD.REPAIR,{s.leader},0);repairTrace('REPAIR_ORDER_READBACK',frame)
   end
  end
 elseif phase=='heal_restore'then
  if frame%300==0 then repairTrace('REPAIR_STALL_STATE',frame)end
  local s=current();if not s then fail('heal_repair_cohort_lost');return end
  if not observeRepair(2,missingInvestment,'ordinary')then return end
  if healthy(s)and not healObserved then healObserved=true;emit('HEAL_CHECKPOINT','survivors_healthy=true healing_energy_separate_from_missing_slot_bill=true')end
  if s.slots[2]then
   local id=s.slots[2]
   if(not repairWitness.ordinary and not repairWitness.birthHelper.Bound(repairWitness.birthProof.ordinary,S,s,2,profile.member,UnitDefNames,missingInvestment))or not healObserved or count(s)~=8 or id==missingOrdinary or not role(id,profile.member)
    or s.generations[2]~=2 or not receipt(s.investments[2],missingInvestment)or not bill(id,missingInvestment)then
    local proof=repairWitness.birthProof.ordinary
    local checks={partial_witness=repairWitness.ordinary~=nil,heal_observed=healObserved==true,living8=count(s)==8,new_identity=id~=missingOrdinary,role=role(id,profile.member),generation=s.generations[2]==2,investment=receipt(s.investments[2],missingInvestment),native_bill=bill(id,missingInvestment),bound_full_birth_job=repairWitness.birthHelper.Bound(proof,S,s,2,profile.member,UnitDefNames,missingInvestment)==true}
    for field,pass in pairs(checks)do emit('ORDINARY_RESTORE_FIELD','field='..field,'pass='..tostring(pass),'id='..id,'generation='..tostring(s.generations[2]))end
    fail('paid_ordinary_restoration_receipt_or_heal_order');return end
   emit('ORDINARY_RESTORE','generation=2','metal='..s.investments[2].metal,'energy='..s.investments[2].energy,'work='..s.investments[2].work)
   S.GiveOrderToUnit(commander,CMD.STOP,{},0);for _,member in pairs(s.slots)do repairWitness.originalSaveMembers[member]=true end;heavyKilled=s.slots[8];local hp=S.GetUnitHealth(heavyKilled)
   phase='heavy_casualty';S.AddUnitDamage(heavyKilled,hp*4+10000,0,nil,-1)
  end
 elseif phase=='heavy_casualty'then
  local s=current();if not s or count(s)~=7 or s.slots[8]or live(heavyKilled)then fail('specialist_casualty_not_empty');return end
  phase='heavy_restore';resources('HEAVY_RESTORE_ORDER_RESOURCES');S.GiveOrderToUnit(commander,CMD.REPAIR,{s.leader},0);repairTrace('REPAIR_ORDER_READBACK',frame)
 elseif phase=='heavy_restore'then
  if frame%300==0 then repairTrace('REPAIR_STALL_STATE',frame)end
  local s=current();if not s then fail('specialist_repair_cohort_lost');return end
  if not observeRepair(8,replacementSpecialCost,'special')then return end
  if s.slots[8]then local id=s.slots[8]
   if(not repairWitness.special and not repairWitness.birthHelper.Bound(repairWitness.birthProof.special,S,s,8,profile.special,UnitDefNames,replacementSpecialCost))or count(s)~=8 or id==heavyKilled or not role(id,profile.special)or s.generations[8]~=2
    or not receipt(s.investments[8],replacementSpecialCost)or not bill(id,replacementSpecialCost)or math.abs(S.GetUnitExperience(id))>.003 then fail('paid_specialist_restoration_role_job_bill');return end
   emit('SPECIALIST_RESTORE','native_special_definition=true generation=2 fresh_XP=0 role_template_bill_at_job_start=true',
    'metal='..replacementSpecialCost.metal,'energy='..replacementSpecialCost.energy,'work='..replacementSpecialCost.work,
    'historical_live_research_investment_metal='..specialInvestment.metal)
   S.GiveOrderToUnit(commander,CMD.STOP,{},0);queue(true)
  end
 elseif phase=='future_product'then
  local s=futureProduct and GG.Recoil40KSquads.Get(futureProduct)
  if s then
   if s.id==seed or s.profile~='guard_line'or count(s)~=8 or not role(s.slots[8],profile.special)then fail('future_specialist_full_delivery');return end
   for slot,id in pairs(s.slots)do
    if not role(id,slot==8 and profile.special or(slot==1 and'imp_guardsman'or profile.member))then fail('future_slot_role');return end
    if s.generations[slot]~=1 or not receipt(s.investments[slot],specialInvestment)or not bill(id,s.investments[slot])then fail('future_full_price_slot_receipt');return end
   end
   emit('FUTURE_DELIVERY','members=8 exactly_one_specialist=true full_native_factory_price=true')
   if not combatEnabled then finish('PASS ordinary_paid_research current_state_preserved no_free_missing_birth paid_normal_and_special_restore future_specialist')
   else
    if GG.Recoil40KStompaWeaponWitness then fail('existing_weapon_witness');return end
    combat=VFS.Include('40k_configs/guard_paid_flamer_combat_fixture.lua').New(S,UnitDefs,WeaponDefs,s.slots[8],s.leader,team,frame,function(...)emit(...)end)
    if combat.result then finish(combat.result);return end
    Script.SetWatchProjectile(combat.weapon,true);GG.Recoil40KStompaWeaponWitness=combat;phase='combat'
   end
  end
 elseif phase=='combat'then
  local result=combat.Step and combat.Step(frame)or combat.result;if result then finish(result)end
 end
 if frame%300==0 then emit('STATE','phase='..phase,'frame='..frame,'research_steps='..paid.steps,'research_metal='..paid.metal,'research_energy='..paid.energy);resources('PERIODIC_RESOURCES')end
end

function gadget:ProjectileCreated(pid,owner,weapon)if combat and combat.Projectile then combat.Projectile(pid,owner,weapon)end end
function gadget:UnitDamaged(id,def,owner,damage,para,weapon,pid,attacker)if combat and combat.Damaged then combat.Damaged(id,damage,para,weapon,pid,attacker)end end
function gadget:Shutdown()if repairWitness.saveEnabled then GG.Recoil40KGuardSquadSaveFixture=nil end;if combat and combat.Close then combat.Close()end;if GG.Recoil40KStompaWeaponWitness==combat then GG.Recoil40KStompaWeaponWitness=nil end end

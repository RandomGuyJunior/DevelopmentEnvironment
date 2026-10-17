function gadget:GetInfo()
 return {name='40K paid Ork source progression review',desc='Native paid Ork graph; mandatory unresolved mechanisms block acceptance',author='Local project',layer=109,enabled=true}
end
if not gadgetHandler:IsSyncedCode()then return false end
local opts=Spring.GetModOptions()or{}
if opts.prototype_diagnostic~='expandedproduction' or not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(opts.prototype_source_progression) or opts.prototype_source_acceptance~='orks'then return false end
if VFS.Include('40k_configs/ork_primary_paid_review.lua').Enabled(opts)then return false end
local commander,base,team,active,started,done=nil,nil,0,nil,false,false
local factories,births,products,mexes,shots,initialBirths={},{},{},{},{},{}
local tasks={
 {'build','ork_resource_factory'},{'build','ork_resource_factory'},
 {'build','ork_generator'},{'build','ork_generator'},
 {'build','ork_settlement'},{'build','ork_boyz_hut'},
 {'product','ork_grot','ork_settlement'},{'product','ork_boy','ork_boyz_hut'},
 {'product','ork_slugga','ork_boyz_hut'},{'product','ork_burna','ork_boyz_hut'},
 {'build','ork_mek_lab'},{'research','ork_mek_technology','ork_mek_lab'},
 {'build','ork_mek_shop'},{'build','ork_generator'},{'build','ork_generator'},
 {'product','ork_tankbusta','ork_boyz_hut'},{'product','ork_wartrak','ork_mek_shop'},
 {'product','ork_killa_kan','ork_mek_shop'},
 {'research','ork_ard_technology','ork_mek_lab'},
 {'product','ork_nob','ork_boyz_hut'},{'product','ork_meganob','ork_boyz_hut'},
 {'product','ork_loota','ork_boyz_hut'},{'product','ork_deff_dread','ork_mek_shop'},
 {'product','ork_trukk','ork_mek_shop'},
 {'build','ork_waaagh_banner'},{'build','ork_generator'},{'build','ork_generator'},
 {'research','ork_big_waaagh','ork_waaagh_banner'},
 {'product','ork_squiggoth','ork_mek_shop'},
 {'build','ork_generator'},{'build','ork_generator'},
 {'research','ork_apocalypse','ork_mek_lab'},
 {'build','ork_hq_super'}, -- Hammer actor intentionally removed from current acceptance.
 {'product','ork_dakka_stompa','ork_hq_super'},{'product','ork_gargant','ork_hq_super'},
}
local index,buildingIndex=1,0
local mandatory='Dakka Lifta requested lifting semantics unrecovered from source; Kustim hammer source contact; Trukk cargo overlap/source transport not verified'
local function log(...)Spring.Echo('40K SOURCE ORKS',...)end
local function outcome(value,reason)
 if done then return end;done=true
 Spring.SetGameRulesParam('40k_source_orks_result',value)
 log(value==2 and 'LIMITED_BLOCKED' or 'FAIL',reason,Spring.GetGameFrame(),'steps',index-1,'mandatory',mandatory)
end
local function fail(reason)outcome(-1,reason)end
local function option(builder,name)
 local def=UnitDefNames[name];if not def then return false end
 for _,id in ipairs(UnitDefs[Spring.GetUnitDefID(builder)].buildOptions or{})do if id==def.id then return true end end
 return false
end
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

local function findMetal(def)
 local candidates={}
 for x=math.max(64,base[1]-1200),math.min(Game.mapSizeX-64,base[1]+1200),16 do
  for z=math.max(64,base[3]-1200),math.min(Game.mapSizeZ-64,base[3]+1200),16 do
   if (select(3,Spring.GetGroundInfo(x,z))or 0)>0 then candidates[#candidates+1]={x,z,(x-base[1])^2+(z-base[3])^2}end
  end
 end
 table.sort(candidates,function(a,b)if a[3]~=b[3]then return a[3]<b[3]end;if a[1]~=b[1]then return a[1]<b[1]end;return a[2]<b[2]end)
 for _,p in ipairs(candidates)do
  local separate=true;for _,m in ipairs(mexes)do if (p[1]-m[1])^2+(p[2]-m[2])^2<128^2 then separate=false end end
  if separate then local pos,approach=site(def,p[1],p[2],0);if pos then mexes[#mexes+1]={pos[1],pos[3]};return pos,approach end end
 end
end

local function nativeReady(name)
 local def=UnitDefNames[name];local d=def and UnitDefs[def.id]
 return d and tostring((d.customParams or{}).prototype40k_source_progression)=='1'
end
local function advance(reason)
 log('STEP_PASS',index,tasks[index][1],tasks[index][2],reason)
 active=nil;index=index+1
end
local function issue(task,frame)
 local kind,name,parent=task[1],task[2],task[3]
 if kind=='build'then
  if not nativeReady(name)or not option(commander,name)then fail('unmarked_or_unoffered_structure_'..name);return end
  local def=UnitDefNames[name].id;local pos,approach,reason
  buildingIndex=buildingIndex+1
  if name=='ork_resource_factory'then pos,approach=findMetal(def)
  else pos,approach,reason=site(def,base[1]+(((buildingIndex-1)%4)-1.5)*360,base[3]+(math.floor((buildingIndex-1)/4)-1)*400,20)end
  if not pos then fail('no_native_clear_stance_'..name..'_'..tostring(reason));return end
  active={kind=kind,name=name,producer=commander,issued=frame,position=pos}
  Spring.GiveOrderToUnit(commander,CMD.MOVE,{approach[1],approach[2],approach[3]},{})
  Spring.GiveOrderToUnit(commander,-def,pos,{'shift'})
 elseif kind=='product'then
  local producer=factories[parent]
  if not producer or not nativeReady(name)or not option(producer,name)then fail('native_product_unavailable_'..name);return end
  active={kind=kind,name=name,producer=producer,issued=frame}
  Spring.GiveOrderToUnit(producer,CMD.REPEAT,{0},{})
  Spring.GiveOrderToUnit(producer,-UnitDefNames[name].id,{},{})
 elseif kind=='research'then
  local r=GG.Recoil40KResearch;local producer=factories[parent];local record=r and r.records[name]
  if not producer or not record or not Spring.FindUnitCmdDesc(producer,record.cmd)then fail('native_research_unavailable_'..name);return end
  if r.HasResearch(team,name)then fail('research_already_complete_without_fixture_payment_'..name);return end
  active={kind=kind,name=name,producer=producer,issued=frame,record=record,observations=0,maxSteps=0}
  Spring.GiveOrderToUnit(producer,record.cmd,{},{})
 end
 if active then log('PAID_NATIVE_ORDER',index,kind,name,active.producer,frame)end
end
local function rangedMounts(id)
 local result={};local d=UnitDefs[Spring.GetUnitDefID(id)]
 for n,m in ipairs(d.weapons or{})do
  local w=WeaponDefs[m.weaponDef or m.weaponDefID];local p=w and w.customParams or{}
  if w and w.type~='Melee'and w.type~='Shield'and tostring(p.source_passive)~='1'then result[#result+1]={n=n,weapon=m.weaponDef or m.weaponDefID,def=w}end
 end
 return result
end
local function gunsComplete(id)
 for _,m in ipairs(rangedMounts(id))do if not(shots[id]and shots[id][m.n])then return false end end
 return true
end
local function fire(id,angle)
 local range=math.huge
 for _,m in ipairs(rangedMounts(id))do range=math.min(range,m.def.range or 120)end
 if range==math.huge then return end
 local x,_,z=Spring.GetUnitPosition(id);local radius=math.min(200,range*.65)
 local xx=math.max(32,math.min(Game.mapSizeX-32,x+radius*math.cos(angle)));local zz=math.max(32,math.min(Game.mapSizeZ-32,z+radius*math.sin(angle)))
 Spring.GiveOrderToUnit(id,CMD.ATTACK,{xx,Spring.GetGroundHeight(xx,zz),zz},{})
end
function gadget:Initialize()
 if not Script.SetWatchProjectile then fail('native_projectile_watch_unavailable');return end
 for _,d in pairs(UnitDefs)do if (d.customParams or{}).faction=='Orks'then
  for _,m in ipairs(d.weapons or{})do Script.SetWatchProjectile(m.weaponDef or m.weaponDefID,true)end
 end end
 if Spring.GetGameFrame()==0 then for _,id in ipairs(Spring.GetTeamUnits(team))do initialBirths[id]=true end end
 Spring.SetGameRulesParam('40k_source_orks_result',0)
 log('LIMITED_BLOCKED_SOURCE_MECHANISMS',mandatory,'no spawning/grants/heals/teleports/speed changes/markers')
end
function gadget:UnitCreated(id,def,unitTeam,builder)
 if unitTeam==team and builder==nil and Spring.GetGameFrame()==0 then initialBirths[id]=true end
 if unitTeam~=team or not started or not active or active.kind=='research'then return end
 if UnitDefs[def].name~=active.name then return end
 if builder~=active.producer then fail('free_or_unrelated_birth_'..active.name);return end
 local progress=select(5,Spring.GetUnitHealth(id))
 if progress==nil or progress>=1 then fail('instant_completed_birth_'..active.name);return end
 births[id]={builder=builder,name=active.name,task=index};active.created=id
 log('PAID_BIRTH',active.name,id,builder,index)
end
function gadget:UnitFinished(id,def,unitTeam)
 if unitTeam~=team or not active or UnitDefs[def].name~=active.name then return end
 local b=births[id]
 if not b or b.task~=index or b.builder~=active.producer or not active.buildWitness then fail('paid_build_progress_and_resource_use_unobserved_'..active.name);return end
 if active.kind=='build'then
  factories[active.name]=id
  if active.name=='ork_resource_factory'or active.name=='ork_generator'then active.unit=id;active.phase='income';active.finished=Spring.GetGameFrame();active.incomeSamples=0
  else advance('paid_native_foundation_with_progress_and_use')end
 elseif active.kind=='product'then
  products[active.name]=id;active.unit=id;active.finished=Spring.GetGameFrame();active.phase='egress';active.start={Spring.GetUnitPosition(id)}
  local fx,_,fz=Spring.GetUnitPosition(active.producer)
  local target={math.max(96,math.min(Game.mapSizeX-96,fx+220)),0,math.max(96,math.min(Game.mapSizeZ-96,fz+300))};target[2]=Spring.GetGroundHeight(target[1],target[3])
  if not Spring.TestMoveOrder(def,target[1],target[2],target[3],0,0,0,true,true,false)then fail('native_factory_exit_unpassable_'..active.name);return end
  Spring.GiveOrderToUnit(id,CMD.MOVE,target,{})
  log('PAID_PRODUCT_FINISHED',active.name,id,'native_egress_order',target[1],target[3])
 end
end
function gadget:UnitDestroyed(id)
 if started and(id==commander or active and(id==active.producer or id==active.unit or id==active.created))then fail('required_actor_destroyed_'..id)end
end
function gadget:UnitTaken(id)self:UnitDestroyed(id)end
function gadget:ProjectileCreated(projectile,owner,weapon)
 if not active or active.kind~='product'or active.unit~=owner or active.phase~='guns'then return end
 if not weapon or weapon<0 then weapon=Spring.GetProjectileDefID and Spring.GetProjectileDefID(projectile)end
 local mount,count=nil,0
 for _,m in ipairs(rangedMounts(owner))do if m.weapon==weapon then mount=m.n;count=count+1 end end
 if count~=1 then log('SHOT_UNKNOWN','ambiguous_native_mount',owner,weapon);return end
 local f=Spring.GetGameFrame();local shot=Spring.GetUnitRulesParam(owner,'40k_last_shot_'..mount)
 local x,y,z=Spring.GetProjectilePosition(projectile)
 local fx=Spring.GetUnitRulesParam(owner,'40k_last_flash_x_'..mount);local fy=Spring.GetUnitRulesParam(owner,'40k_last_flash_y_'..mount);local fz=Spring.GetUnitRulesParam(owner,'40k_last_flash_z_'..mount)
 local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
 if shot~=f or not finite(x)or not finite(y)or not finite(z)or not finite(fx)or not finite(fy)or not finite(fz)then log('SHOT_UNKNOWN','missing_same_frame_origin',active.name,mount);return end
 local delta=math.sqrt((x-fx)^2+(y-fy)^2+(z-fz)^2)
 if delta>.01 then fail('native_projectile_flash_origin_mismatch_'..active.name..'_'..mount);return end
 shots[owner]=shots[owner]or{};shots[owner][mount]=true
 log('NATIVE_SOURCE_SHOT',active.name,owner,weapon,mount,f,'origin_distance',delta)
end
function gadget:GameFrame(frame)
 if done then return end
 if not started then
  if frame%30~=0 then return end
  for _,id in ipairs(Spring.GetTeamUnits(team))do local d=UnitDefs[Spring.GetUnitDefID(id)];local cp=d.customParams or{}
   if initialBirths[id] and d.name=='corcom'and cp.prototype40k_vital=='commander'and tostring(cp.prototype40k_source_progression)=='1'then commander=id;base={Spring.GetUnitPosition(id)};started=true;log('START','engine_initial_commander',id);break end
  end
  if not started and frame>=300 then fail('marked_engine_initial_ork_commander_missing')end
  return
 end
 if not Spring.ValidUnitID(commander)then fail('initial_commander_missing');return end
 -- Observe native build progress and producer use on every native frame.
 if active and active.created and not active.phase then
  local progress=select(5,Spring.GetUnitHealth(active.created))
  local _,metalUse,_,energyUse=Spring.GetUnitResources(active.producer)
  local command=Spring.GetUnitCurrentCommand and Spring.GetUnitCurrentCommand(active.producer)
  if progress and progress>0 and progress<1 and command==-UnitDefNames[active.name].id and ((metalUse or 0)>0 or(energyUse or 0)>0)then active.buildWitness=true end
 end
 if active and active.kind=='research'then
  local r=GG.Recoil40KResearch;local job=r and r.jobs[active.producer]and r.jobs[active.producer][active.name]
  if job and job.active and job.team==team and job.steps>active.maxSteps and job.metal>0 and job.energy>0 then
   active.maxSteps=job.steps;active.observations=active.observations+1;active.paidMetal=job.metal;active.paidEnergy=job.energy
  end
  if r and r.HasResearch(team,active.name)then
   local record=active.record;local cost=record.row.cost or{};local previous=math.max(0,record.frames-1)/record.frames
   if active.observations<2 or active.maxSteps<record.frames-1 or (active.paidMetal or 0)+1e-6<(cost.metal or 0)*previous or(active.paidEnergy or 0)+1e-6<(cost.energy or 0)*previous then fail('research_completion_without_observed_paid_job_'..active.name);return end
   log('NATIVE_PAID_RESEARCH_RECEIPT',active.name,active.maxSteps,record.frames,active.paidMetal,active.paidEnergy,'completion_from_controller_after_final_native_payment')
   advance('observed_paid_controller_job_and_completion');return
  end
 end
 if frame%30~=0 then return end
 if not active then
  if tasks[index]then issue(tasks[index],frame)
  else outcome(2,'selected native paid sequence complete; mandatory source mechanisms and broad roster remain blocked')end
  return
 end
 if frame-active.issued>108000 then fail('paid_native_stage_timeout_'..active.kind..'_'..active.name);return end
 if active.kind=='build'and active.phase=='income'then
  local metal,_,energy=Spring.GetUnitResources(active.unit)
  local income=active.name=='ork_resource_factory'and metal or energy
  if income and income>0 then active.incomeSamples=active.incomeSamples+1;log('NATIVE_SOURCE_INCOME',active.name,active.unit,metal or 0,energy or 0,active.incomeSamples)
   if active.incomeSamples>=2 then advance('paid_structure_two_native_income_samples')end
  else active.incomeSamples=0;if frame-active.finished>3600 then fail('completed_source_income_inactive_'..active.name)end end
 elseif active.kind=='product'and active.unit then
  local x,_,z=Spring.GetUnitPosition(active.unit)
  if active.phase=='egress'and frame-active.finished>3600 then fail('native_factory_egress_timeout_'..active.name);return end
  if active.phase=='egress'and x and(x-active.start[1])^2+(z-active.start[3])^2>=160^2 then
   active.phase='guns';active.gunsFrame=frame;fire(active.unit,0);log('NATIVE_EGRESS',active.name,active.unit,x,z)
   if done then return end
   if gunsComplete(active.unit)then advance('paid_native_egress_no_ranged_mounts')end
  elseif active.phase=='guns'then
   if gunsComplete(active.unit)then advance('selected_ranged_mounts_actual_native_shot_origins')
   elseif frame-active.gunsFrame>3600 then outcome(2,'native_mount_origin_evidence_unavailable_'..active.name..'; beam-only/missing Shot telemetry is not acceptance')
   elseif(frame-active.gunsFrame)%300==0 then fire(active.unit,((frame-active.gunsFrame)/300)%8*math.pi/4)end
  end
 end
end
-- Result0 pending; -1 failed;2 LIMITED_BLOCKED. No broad PASS result exists.
-- Birth/progress/use witness is native production evidence, not reconstructed
-- per-unit invoices. Research final tick relies on strict controller payment.

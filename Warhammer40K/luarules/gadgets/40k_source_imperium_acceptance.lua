function gadget:GetInfo()
 return {name='40K paid Imperium source progression review',desc='Ordinary commander, economy, research and production; never grants',author='Local project',layer=109,enabled=true}
end
if not gadgetHandler:IsSyncedCode()then return false end
local opts=Spring.GetModOptions()or{}
if tostring(opts.prototype_bike_cohort_review)=='1'then return false end
if opts.prototype_diagnostic~='expandedproduction' or not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(opts.prototype_source_progression) or opts.prototype_source_acceptance~='imperium'then return false end
local aimReview=VFS.Include('40k_configs/source_infantry_aim_review.lua')
local groundSiteGate=VFS.Include('40k_configs/paid_ground_site_gate.lua')
local commander,base,team,active,started,done=nil,nil,0,nil,false,false
local factories,births,products,mexes,shots={},{},{},{},{}
local tasks={
 {'build','imp_mex'},{'build','imp_mex'},{'build','imp_generator'},{'build','imp_generator'},
 {'build','imp_hq'},{'build','imp_barracks'},{'build','imp_research'},
 {'build','imp_generator'},{'build','imp_generator'},{'build','imp_tank_factory'},
 {'product','imp_enginseer','imp_hq'},{'product','imp_guardsman','imp_barracks'},
 {'product','imp_marine','imp_barracks'},
 {'research','imperial_logistics','imp_research'},
 {'build','imp_walker_factory'},{'product','imp_kasrkin','imp_barracks'},
 {'product','imp_devastator','imp_barracks'},{'product','imp_assault_marine','imp_barracks'},
 {'jump','imp_assault_marine'},{'product','imp_russ','imp_tank_factory'},
 {'product','imp_basilisk','imp_tank_factory'},{'product','imp_predator','imp_tank_factory'},
 {'product','imp_sentinel','imp_walker_factory'},{'product','imp_dreadnought','imp_walker_factory'},
 {'build','imp_generator'},{'build','imp_generator'},
 {'research','imperial_full_scale_war','imp_research'},
 {'product','imp_terminator','imp_barracks'},
 {'build','imp_superheavy_factory'},{'product','imp_baneblade','imp_superheavy_factory'},
 {'warhound_gate','imp_warhound'},
 {'build','imp_titan_factory'},{'research','imperial_titan_writ','imp_titan_factory'},
 {'product','imp_warhound','imp_titan_factory'},
}
local marineReview=tostring(opts.prototype_factory_pose_review)=='1'
if marineReview then
 tasks={
  {'build','imp_mex'},{'build','imp_mex'},{'build','imp_generator'},{'build','imp_generator'},
  {'build','imp_hq'},{'build','imp_marine_hq'},{'build','imp_marine_barracks'},
  {'build','imp_marine_armoury'},
  {'product','imp_scout','imp_marine_hq'},{'product','imp_scout','imp_marine_hq'},
  {'product','imp_marine','imp_marine_barracks'},{'product','imp_marine','imp_marine_barracks'},
 }
end
local index,buildingIndex=1,0
local groundPending=false
local unitTargetReview=VFS.Include('40k_configs/source_marine_unit_target_review.lua').New(Spring,UnitDefs,WeaponDefs,CMD,Game,opts,team,function()return GG.Recoil40KInfantryAimReview end,function(...)Spring.Echo('40K SOURCE IMPERIUM',...)end)
local function log(...)Spring.Echo('40K SOURCE IMPERIUM',...)end
local function outcome(value,reason)
 if done then return end;done=true
 Spring.SetGameRulesParam('40k_source_imperium_result',value)
 log(value==1 and 'PASS' or value==2 and 'LIMITED_BLOCKED' or 'FAIL',reason,Spring.GetGameFrame(),'steps',index-1)
end
local function fail(reason)outcome(-1,reason)end
local function canonical(def)return (def.customParams or{}).prototype40k_tech_requires or (def.customParams or{}).prototype40k_donor or def.name end
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
local function park(id)
 local x,_,z=Spring.GetUnitPosition(id);local def=Spring.GetUnitDefID(id)
 for i=0,23 do local angle=(i+index)*math.pi/12;local xx=x+500*math.cos(angle);local zz=z+500*math.sin(angle);local y=Spring.GetGroundHeight(xx,zz)
  if xx>64 and zz>64 and xx<Game.mapSizeX-64 and zz<Game.mapSizeZ-64 and Spring.TestMoveOrder(def,xx,y,zz,0,0,0,true,true,false)then
   Spring.GiveOrderToUnit(id,CMD.MOVE,{xx,y,zz},{})
   log('NATIVE_PRODUCT_PARK_ORDER',id,xx,zz);return
  end
 end
 log('PARK_UNKNOWN','no_native_legal_site',id)
end
local function advance(reason)
 if active and active.kind=='product'and active.unit then
  if unitTargetReview and unitTargetReview.state and unitTargetReview.state.actor==active.unit then unitTargetReview.Clear()end
  park(active.unit)
 end
 log('STEP_PASS',index,tasks[index][1],tasks[index][2],reason or '')
 active=nil;index=index+1
end
local function nativeReady(name)
 local def=UnitDefNames[name];local d=def and UnitDefs[def.id]
 if marineReview and d then
  local cp=d.customParams or{}
  if cp.source_native_pieces and (name=='imp_marine_hq'or name=='imp_marine_barracks'or name=='imp_marine_armoury')then return true end
  -- Existing ordinary Scout is a paid native product; this review certifies
  -- factory lifecycle only, not full source Scout balance or faction acceptance.
  if name=='imp_scout' and cp.animsource then return true end
 end
 return d and tostring((d.customParams or{}).prototype40k_source_progression)=='1'
end
local function build(name,frame)
 if not nativeReady(name)or not option(commander,name)then fail('unmarked_or_unoffered_structure_'..name);return end
 local def=UnitDefNames[name].id;local pos,approach,reason
 buildingIndex=buildingIndex+1
 if name=='imp_mex'then pos,approach=findMetal(def)
 else
  local column=(buildingIndex-1)%4;local row=math.floor((buildingIndex-1)/4)
  pos,approach,reason=site(def,base[1]+(column-1.5)*360,base[3]+(row-1)*400,20)
 end
 if not pos then fail('no_measured_clear_build_stance_'..name..'_'..tostring(reason));return end
 active={kind='build',name=name,producer=commander,issued=frame,position=pos}
 Spring.GiveOrderToUnit(commander,CMD.MOVE,{approach[1],approach[2],approach[3]},{})
 Spring.GiveOrderToUnit(commander,-def,pos,{'shift'})
 log('PAID_NATIVE_BUILD',name,commander,pos[1],pos[3],frame)
end
local function firingOrder(id,angle)
 local d=UnitDefs[Spring.GetUnitDefID(id)];local range=math.huge
 for _,mount in ipairs(d.weapons or{})do
  local wd=WeaponDefs[mount.weaponDef or mount.weaponDefID];local cp=wd and wd.customParams or{}
  if wd and wd.type~='Melee'and wd.type~='Shield'and tostring(cp.source_passive)~='1'then range=math.min(range,wd.range or 120)end
 end
 if range==math.huge then return end
 local x,_,z=Spring.GetUnitPosition(id);local radius=math.min(200,range*.65)
 local xx=math.max(32,math.min(Game.mapSizeX-32,x+radius*math.cos(angle)));local zz=math.max(32,math.min(Game.mapSizeZ-32,z+radius*math.sin(angle)))
 local target={xx,Spring.GetGroundHeight(xx,zz),zz}
 if marineReview then
  local okay,why,mount,piece,mx,my,mz=groundSiteGate.Ground(Spring,UnitDefs,WeaponDefs,id,target)
  log('NATIVE_GROUND_CANDIDATE',id,'ordered',okay,'reason',why,'target',xx,target[2],zz,'mount',mount,'piece',piece,'marker',mx,my,mz)
  if not okay then return false end
 end
 if active and active.unit==id and active.phase=='guns'then active.groundTarget=target end
 Spring.GiveOrderToUnit(id,CMD.ATTACK,target,{})
end
local function gunsComplete(id)
 local d=UnitDefs[Spring.GetUnitDefID(id)]
 for n,mount in ipairs(d.weapons or{})do
  local wd=WeaponDefs[mount.weaponDef or mount.weaponDefID];local cp=wd and wd.customParams or{}
  if wd and wd.type~='Melee'and wd.type~='Shield'and tostring(cp.source_passive)~='1'and not(shots[id]and shots[id][n])then return false end
 end
 return true
end
local function issue(task,frame)
 local kind,name,parent=task[1],task[2],task[3]
 if kind=='build'then build(name,frame)
 elseif kind=='research'then
  local r=GG.Recoil40KResearch;local producer=factories[parent];local record=r and r.records[name]
  if not producer or not record or not Spring.FindUnitCmdDesc(producer,record.cmd)then fail('native_research_unavailable_'..name);return end
  active={kind=kind,name=name,producer=producer,issued=frame}
  Spring.GiveOrderToUnit(producer,record.cmd,{},{})
  log('PAID_NATIVE_RESEARCH',name,producer,record.cmd,frame)
 elseif kind=='product'then
  local producer=factories[parent]
  if not producer or not nativeReady(name)or not option(producer,name)then fail('native_product_unavailable_'..name);return end
  active={kind=kind,name=name,producer=producer,issued=frame}
  Spring.GiveOrderToUnit(producer,CMD.REPEAT,{0},{})
  Spring.GiveOrderToUnit(producer,-UnitDefNames[name].id,{},{})
  log('PAID_NATIVE_PRODUCT',name,parent,producer,frame)
 elseif kind=='jump'then
  local id=products[name];local jump=GG.Recoil40KJump
  if not id or not jump or not Spring.FindUnitCmdDesc(id,jump.command)then fail('native_jump_unavailable');return end
  local x,_,z=Spring.GetUnitPosition(id);local def=UnitDefs[Spring.GetUnitDefID(id)];local distance=math.min(180,tonumber((def.customParams or{}).jump_range)or 180)
  local target
  for i=0,15 do local angle=i*math.pi/8;local xx=x+distance*math.cos(angle);local zz=z+distance*math.sin(angle);local y=Spring.GetGroundHeight(xx,zz)
   if xx>64 and zz>64 and xx<Game.mapSizeX-64 and zz<Game.mapSizeZ-64 and Spring.TestMoveOrder(Spring.GetUnitDefID(id),xx,y,zz,0,0,0,true,true,false)then target={xx,y,zz};break end
  end
  if not target then fail('native_jump_landing_site_unavailable');return end
  active={kind=kind,name=name,producer=id,issued=frame,target=target,charge=Spring.GetUnitRulesParam(id,'40k_jump_charge')}
  Spring.GiveOrderToUnit(id,jump.command,target,{})
  log('NATIVE_JUMP_ORDER',id,target[1],target[3],active.charge or 'missing')
 elseif kind=='warhound_gate'then
  local def=UnitDefNames[name];local cp=def and UnitDefs[def.id].customParams or{}
  if not nativeReady(name)or tonumber(cp.source_voidshield_profile_verified)~=1 or not cp.source_voidshield_profile or not GG.Recoil40KVoidShield then
   outcome(2,'Warhound source void shield/morale semantics unverified; required late phase blocked, no full acceptance')
  else advance('explicit_source_shield_handler_present_not_yet_native_proven')end
 end
end
function gadget:Initialize()
 if not Script.SetWatchProjectile then fail('native_projectile_watch_unavailable');return end
 for _,d in pairs(UnitDefs)do
  local cp=d.customParams or{}
  if cp.faction=='Imperium'and tostring(cp.prototype40k_source_progression)=='1'then
   for _,mount in ipairs(d.weapons or{})do local id=mount.weaponDef or mount.weaponDefID;if id then Script.SetWatchProjectile(id,true)end end
  end
 end
 Spring.SetGameRulesParam('40k_source_imperium_result',0)
end
function gadget:UnitCreated(id,def,unitTeam,builder)
 if unitTeam~=team or not started then return end
 if active and active.kind~='research'and builder==active.producer and UnitDefs[def].name==active.name then births[id]={builder=builder,name=active.name,task=index};active.created=id;log('PAID_BIRTH',active.name,id,builder,index)end
end
function gadget:UnitFinished(id,def,unitTeam)
 local birth=births[id]
 if unitTeam~=team or not active or not birth or birth.task~=index or birth.builder~=active.producer then return end
 if active.kind=='build'then
  factories[active.name]=id
  if active.name=='imp_mex'or active.name=='imp_generator'then active.unit=id;active.phase='income';active.finished=Spring.GetGameFrame()
  else advance('completed_native_foundation')end
 elseif active.kind=='product'then
  if active.name=='imp_warhound'then
   local shield=GG.Recoil40KVoidShield and GG.Recoil40KVoidShield.states[id]
   if not shield or not shield.profile or not shield.charge or shield.charge<=0 then fail('paid_warhound_actual_source_shield_state_missing');return end
   log('NATIVE_SOURCE_SHIELD_STATE',id,shield.charge,shield.profile.maximum or 'missing')
  end
  products[active.name]=id;active.unit=id;active.finished=Spring.GetGameFrame();active.phase='egress'
  local fx,_,fz=Spring.GetUnitPosition(active.producer);active.exit={math.max(96,math.min(Game.mapSizeX-96,fx+220)),0,math.max(96,math.min(Game.mapSizeZ-96,fz+300))};active.exit[2]=Spring.GetGroundHeight(active.exit[1],active.exit[3])
  active.start={Spring.GetUnitPosition(id)}
  Spring.GiveOrderToUnit(id,CMD.MOVE,active.exit,{})
  log('PAID_FINISHED_PRODUCT',active.name,id,birth.builder,'native_egress_order',active.exit[1],active.exit[3])
 end
end
function gadget:UnitDestroyed(id)
 if started and (id==commander or active and (id==active.producer or id==active.unit))then fail('required_actor_destroyed_'..id)end
end
function gadget:UnitTaken(id)if started and (id==commander or active and(id==active.producer or id==active.unit))then fail('required_actor_changed_owner_'..id)end end
local function groundShotProof(owner,mount)
 local expected=active and active.groundTarget
 if not expected or not Spring.GetUnitWeaponTarget then return false,'ground_order_not_observed'end
 local targetType,user,target=Spring.GetUnitWeaponTarget(owner,mount)
 local cmd,_,tag,x,y,z=Spring.GetUnitCurrentCommand(owner)
 if targetType~=2 or user~=true or type(target)~='table'or cmd~=CMD.ATTACK then return false,'native_target_not_ordinary_ground_attack'end
 -- Both APIs expose native float32 positions; tolerate only the same configured
 -- point's round-trip, not a different aim target or an incidental unit shot.
 local function same(a,b)return type(a)=='number'and a==a and type(b)=='number'and b==b and math.abs(a-b)<=.01 end
 if not same(x,expected[1])or not same(y,expected[2])or not same(z,expected[3])
  or not same(target[1],expected[1])or not same(target[2],expected[2])or not same(target[3],expected[3])then return false,'native_ground_target_or_command_changed'end
 return true,tag
end
function gadget:ProjectileCreated(projectile,owner,weapon)
 if not active or active.kind~='product'or active.unit~=owner or (active.phase~='guns'and active.phase~='unit_guns')then return end
 if not weapon or weapon<0 then weapon=Spring.GetProjectileDefID and Spring.GetProjectileDefID(projectile)end
 local d=UnitDefs[Spring.GetUnitDefID(owner)];local frame=Spring.GetGameFrame();local mount,count=nil,0
 for n,w in ipairs(d.weapons or{})do if (w.weaponDef or w.weaponDefID)==weapon then mount=n;count=count+1 end end
 if count~=1 then log('SHOT_UNKNOWN','ambiguous_native_mount',owner,weapon);return end
 local shot=Spring.GetUnitRulesParam(owner,'40k_last_shot_'..mount)
 local x,y,z=Spring.GetProjectilePosition(projectile)
 local fx=Spring.GetUnitRulesParam(owner,'40k_last_flash_x_'..mount);local fy=Spring.GetUnitRulesParam(owner,'40k_last_flash_y_'..mount);local fz=Spring.GetUnitRulesParam(owner,'40k_last_flash_z_'..mount)
 local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
 if shot~=frame or not finite(x)or not finite(y)or not finite(z)or not finite(fx)or not finite(fy)or not finite(fz)then log('SHOT_UNKNOWN','missing_same_frame_native_origin',active.name,mount,shot or -1,frame);return end
 local delta=math.sqrt((x-fx)^2+(y-fy)^2+(z-fz)^2)
 if delta>.01 then fail('native_projectile_flash_origin_mismatch_'..active.name..'_'..mount);return end
 if marineReview and active.phase=='guns'then
  local okay,why=groundShotProof(owner,mount)
  if not okay then log('SHOT_UNKNOWN',why,active.name,mount,frame);return end
  log('NATIVE_ORDINARY_GROUND_SHOT_PROOF',active.name,owner,mount,frame,'command_tag',why)
 end
 shots[owner]=shots[owner]or{};shots[owner][mount]=true
 log('NATIVE_SOURCE_SHOT',active.name,owner,weapon,mount,frame,'projectile_flash_distance',delta)
 if active.phase=='unit_guns'then unitTargetReview.NoteShot(owner,mount,frame)end
end
function gadget:UnitDamaged(...)
 if unitTargetReview and active and active.phase=='unit_guns'then unitTargetReview.UnitDamaged(...)end
end
function gadget:GameFrame(frame)
 if done then return end
 if not started then
  if frame%30~=0 then return end
  for _,id in ipairs(Spring.GetTeamUnits(team))do local d=UnitDefs[Spring.GetUnitDefID(id)];local cp=d.customParams or{}
   if d.name=='imp_field_commander'and cp.prototype40k_vital=='commander'and tostring(cp.prototype40k_source_progression)=='1'then commander=id;base={Spring.GetUnitPosition(id)};started=true;unitTargetReview.CaptureInitial();log('START','engine_initial_commander',id,'no units/resources/health/speed grants');break end
  end
  if not started and frame>=300 then fail('marked_engine_initial_imperium_commander_missing')end
  return
 end
 if not Spring.ValidUnitID(commander)then fail('initial_commander_missing');return end
 if active and active.kind=='jump'then
  if frame-active.issued>900 then fail('native_jump_state_timeout');return end
  local jump=GG.Recoil40KJump;local state=jump and jump.states[active.producer]
  if state then active.airborne=true end
  if active.airborne and not state and Spring.GetUnitRulesParam(active.producer,'40k_jump_active')==0 then
   local x,_,z=Spring.GetUnitPosition(active.producer);local charge=Spring.GetUnitRulesParam(active.producer,'40k_jump_charge')
   if not x or (x-active.target[1])^2+(z-active.target[3])^2>48^2 or not charge or not active.charge or charge>=active.charge then fail('native_jump_landing_or_charge_mismatch');return end
   advance('native_jump_state_charge_and_landing_readback')
  end
 end
 if active and active.kind=='product'and active.phase=='unit_guns'then
  local result,why=unitTargetReview.Frame(frame)
  if result==true and gunsComplete(active.unit)then advance('paid_native_unit_target_projectile_and_damage_GROUND_FIRING_UNACCEPTED')
  elseif result==false then fail('paid_unit_target_fallback_'..tostring(why));return end
 end
 if frame%30~=0 then return end
 if not active then if tasks[index]then issue(tasks[index],frame)else outcome(groundPending and 2 or 1,groundPending and 'paid products may prove real unit-target hits; GROUND FIRING UNACCEPTED; visuals/save/network separate' or marineReview and 'selected paid Marine native factory products and egress only; model visibility/platform/upgrade parity unaccepted' or 'selected paid source economy/research/products, egress, jump and all ranged mounts; visual/morale/save/network acceptance separate')end;return end
 if frame-active.issued>108000 then fail('paid_native_stage_timeout_'..active.kind..'_'..active.name);return end
 if active.kind=='build'and active.phase=='income'then
  if not Spring.GetUnitResources then fail('native_source_income_readback_unavailable');return end
  local metal,_,energy=Spring.GetUnitResources(active.unit)
  local income=active.name=='imp_mex'and metal or energy
  if income and income>0 then log('NATIVE_SOURCE_INCOME',active.name,active.unit,metal or 0,energy or 0);advance('completed_paid_source_structure_with_native_income')
  elseif frame-active.finished>3600 then fail('completed_source_income_inactive_'..active.name)end
 elseif active.kind=='research'then
  if GG.Recoil40KResearch and GG.Recoil40KResearch.HasResearch(team,active.name)then advance('completed_native_paid_research')end
 elseif active.kind=='product'and active.unit then
  local x,_,z=Spring.GetUnitPosition(active.unit)
  if active.phase=='egress'and frame-active.finished>3600 then fail('native_factory_egress_timeout_'..active.name);return end
  local exitOkay,exitWhy,remaining,blockKind,blockID,gap
  if active.phase=='egress'and marineReview then
   exitOkay,exitWhy,remaining,blockKind,blockID,gap=groundSiteGate.Exit(Spring,active.unit,active.producer,active.exit)
   if frame%300==0 then log('NATIVE_EXIT_CLEARANCE',active.unit,'clear',exitOkay,'reason',exitWhy,'remaining',remaining,'blockKind',blockKind,'blockID',blockID,'conservativeGap',gap,'orderedExit',active.exit[1],active.exit[3])end
   if frame%300==0 then
    local row=groundSiteGate.Movement(Spring,active.unit,active.producer,active.exit);local m=row.move or{};local p=row.position or{};local v=row.velocity or{};local c=row.commandPosition or{}
    log('NATIVE_EXIT_MOVEMENT',active.unit,'position',p[1],p[2],p[3],'velocity',v[1],v[2],v[3],'speed',row.speed,'command',row.command,'tag',row.tag,'commandXYZ',c[1],c[2],c[3],
     'progress',m.progressState,'nativeGoal',m.goalx,m.goaly,m.goalz,'goalRadius',m.goalRadius,'currentSpeed',m.currentSpeed,'wantedSpeed',m.wantedSpeed,
     'waypoint',m.currwaypointx,m.currwaypointy,m.currwaypointz,'fullClear',row.fullClear,'clearReason',row.clearReason,'blockKind',row.blockKind,'blockID',row.blocker,'gap',row.gap,'error',row.error)
    local witness=groundSiteGate.Witness(row,active.exit,frame,CMD.MOVE)
    if witness and not active.exitWitness then active.exitWitness=witness;log('NATIVE_EXIT_OWNED_HEAD_WITNESS',active.unit,active.producer,witness.tag,witness.frame,witness.target[1],witness.target[2],witness.target[3])end
    if row.speed and row.speed<.001 then active.stationarySince=active.stationarySince or frame else active.stationarySince=nil end
    if (active.exitRetries or 0)<2 and groundSiteGate.RetryReady(row,active.exit,frame-active.finished,active.stationarySince and frame-active.stationarySince or 0,CMD.MOVE,active.exitWitness,frame)then
     active.failedExits=active.failedExits or{};local oldExit={active.exit[1],active.exit[2],active.exit[3]};active.failedExits[#active.failedExits+1]=oldExit
     active.usedExits=active.usedExits or{};active.usedExits[math.floor(oldExit[1]/8)..':'..math.floor(oldExit[3]/8)]=true
     local alternate,why=groundSiteGate.Alternate(Spring,Game,active.unit,active.producer,oldExit,active.usedExits)
     log('NATIVE_EXIT_ORIGINAL_SITE_UNREACHED',active.unit,oldExit[1],oldExit[2],oldExit[3],row.remaining,m.progressState,row.command,frame)
     active.exitRetries=(active.exitRetries or 0)+1;active.stationarySince=nil
     if alternate then
      active.exit={alternate[1],alternate[2],alternate[3]};active.exitWitness=nil;active.usedExits[alternate.key]=true
      Spring.GiveOrderToUnit(active.unit,CMD.MOVE,active.exit,{})
      log('NATIVE_EXIT_ALTERNATE_ORDINARY_MOVE',active.unit,active.exitRetries,why,active.exit[1],active.exit[2],active.exit[3],frame)
     else log('NATIVE_EXIT_ALTERNATE_REFUSED',active.unit,why,frame)end
    end
   end
  end
  if active.phase=='egress'and x and (marineReview and exitOkay or not marineReview and (x-active.start[1])^2+(z-active.start[3])^2>=160^2)then
   active.phase='settle_guns';active.gunsFrame=frame;Spring.GiveOrderToUnit(active.unit,CMD.STOP,{},{});log('NATIVE_EGRESS',active.name,active.unit,x,z)
   if done then return end
   if gunsComplete(active.unit)then advance('native_egress_and_required_ranged_mounts')end
  elseif active.phase=='settle_guns'then
   local _,_,_,speed=Spring.GetUnitVelocity(active.unit)
   if speed and speed<.001 and frame-active.gunsFrame>=30 then active.phase='guns';active.gunsFrame=frame;firingOrder(active.unit,0);log('NATIVE_STOPPED_FOR_GUNS',active.name,active.unit,frame,speed)end
   if frame-active.gunsFrame>600 then fail('native_product_did_not_stop_'..active.name)end
  elseif active.phase=='guns'then
   if gunsComplete(active.unit)then advance('all_selected_ranged_mounts_native_projectile_shot_origin')
   elseif frame-active.gunsFrame>3600 then
    if active.name=='imp_marine'and unitTargetReview then
     groundPending=true;Spring.SetGameRulesParam('40k_source_imperium_ground_pending',1)
     log('GROUND_GUNS_UNACCEPTED',active.name,active.unit,'ranged_mount_native_shot_missing',frame)
     active.phase='unit_guns';local okay,why=unitTargetReview.Begin(active.unit,frame,true)
     if not okay then fail('paid_unit_target_fallback_'..tostring(why))end
    else fail('ranged_mount_native_shot_missing_'..active.name)end
   elseif(frame-active.gunsFrame)%300==0 then
    log('NATIVE_GUN_WAIT',active.name,active.unit,'command',Spring.GetUnitCurrentCommand(active.unit),'velocity',Spring.GetUnitVelocity(active.unit))
    aimReview.Observe(Spring,active.unit,GG.Recoil40KInfantryAimReview)
    firingOrder(active.unit,((frame-active.gunsFrame)/300)%8*math.pi/4)
   end
  end
 end
end
-- Result0=pending, -1=failed, 2=selected sequence limited by a mandatory source
-- mechanism, 1=selected paid sequence only (never whole-faction acceptance).
-- Fixture requires ordinary engine-initial team0 Imperium start and positive
-- nearby native metal. Research/production costs and native command waits remain
-- untouched; each paid stage may wait up to one simulated hour for real income.
-- Warhound adds actual profile-state witness but incoming morale/shield damage,
-- source melee contacts, savegame/network/visual quality remain separate tests.
-- No spawning, grants, resource edits, heals, speed changes or readiness markers.

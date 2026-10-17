function gadget:GetInfo()
 return {name='40K genuine paid Ork primary review',desc='Paid Grot structures, four Storm founding actors, jump and native power research',author='Local project',layer=109,enabled=true}
end
if not gadgetHandler:IsSyncedCode()then return false end
local opts=Spring.GetModOptions()or{}
if opts.prototype_diagnostic~='expandedproduction' or not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(opts.prototype_source_progression) or opts.prototype_source_acceptance~='orks'then return false end
if not VFS.Include('40k_configs/ork_primary_paid_review.lua').Enabled(opts)then return false end
local commander,base,team,active,started,done=nil,nil,0,nil,false,false
local factories,births,products,mexes,shots,initialBirths={},{},{},{},{},{}
local stormIDs,generators={},{}
local tasks={
 {'build','ork_resource_factory'},{'build','ork_resource_factory'},
 {'build','ork_generator'},{'build','ork_generator'},
 {'build','ork_settlement'},{'build','ork_boyz_hut'},
 {'product','ork_grot','ork_settlement'},{'grot','paid_constructor'},
 {'build','ork_pile_o_guns'},
 {'build','ork_waaagh_banner'},{'build','ork_waaagh_banner'},{'build','ork_waaagh_banner'},
 {'population',50},
 {'product','ork_stormboy','ork_boyz_hut'},{'product','ork_stormboy','ork_boyz_hut'},
 {'product','ork_stormboy','ork_boyz_hut'},{'product','ork_stormboy','ork_boyz_hut'},
 {'jump','four_paid_storm_cohort'},
 {'build','ork_waaagh_banner'},{'population',60},
 {'build','ork_bigger_generator'},
 {'research','ork_bigger_generator__ua_ork_power_research_1','ork_bigger_generator'},
 {'power','actual_native_upgrade_readback'},
 {'build','ork_waaagh_banner'},{'population',70},
 {'addon','ork_source_hq_addon','ork_settlement'},
 {'build','ork_giant_waagh_banner_sp_dxp3'},
 {'product','ork_fighta_bomba','ork_giant_waagh_banner_sp_dxp3'},
}
-- Source adapted capacity20+10/banner+20/paidHQaddon: thirteen banners reach170.
for _=1,8 do tasks[#tasks+1]={'build','ork_waaagh_banner'}end
tasks[#tasks+1]={'population',170};tasks[#tasks+1]={'build','ork_boomy_platform'}
-- Source290 tech begins only after all original thirteen paid banners exist.
tasks[#tasks+1]={'nuke','exact_source_tech_boundary'}
local index,buildingIndex=1,0
local mandatory='Nukklear exact technology/bombard conditional; distinct FlyTower airstrike optional; broad research/roster/capture/save not accepted by this fixture'
local function log(...)Spring.Echo('40K PAID PRIMARY ORKS',...)end
local function outcome(value,reason)
 if done then return end;done=true
 Spring.SetGameRulesParam('40k_paid_primary_orks_result',value)
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
 local distance=ud.buildDistance or ud.builddistance
 local target=UnitDefs[def];local targetRadius=target.buildeeBuildRadius
 if type(targetRadius)=='number'and targetRadius<0 then targetRadius=target.radius end
 if type(distance)~='number'or type(targetRadius)~='number'or targetRadius<0 then return nil,'actual_native_build_range_unreadable'end
 -- Exact pinned BuilderCAI GetBuildRange(distance + real buildee/model radius).
 local range=distance+targetRadius
 local radius=math.max(1,range*.9-8);local hx,hz=halfFootprint(UnitDefs[def],0)
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
local specialIssue,specialFrame,activePowerBefore
local function issue(task,frame)
 local kind,name,parent=task[1],task[2],task[3]
 if specialIssue and specialIssue(task,frame)then return end
 if kind=='build'then
  if name~='ork_resource_factory'and name~='ork_generator'and name~='ork_settlement'and name~='ork_boyz_hut'then
   local C=GG.Recoil40KResearch;local d=UnitDefs[Spring.GetUnitDefID(commander)];local receipt=C and C.sourceOrkProducerCosts and C.sourceOrkProducerCosts.receipts[commander]
   if not products.ork_grot or commander~=products.ork_grot or d.name~='ork_grot'or not receipt then fail('genuine_paid_grot_required_'..name);return end
  end
  if not nativeReady(name)or not option(commander,name)then fail('unmarked_or_unoffered_structure_'..name);return end
  local def=UnitDefNames[name].id;local pos,approach,reason
  buildingIndex=buildingIndex+1
  if name=='ork_resource_factory'then pos,approach=findMetal(def)
  else
   local sx=base[1]<Game.mapSizeX/2 and 1 or -1;local sz=base[3]<Game.mapSizeZ/2 and 1 or -1
   local x=math.max(160,math.min(Game.mapSizeX-160,base[1]+sx*(160+((buildingIndex-1)%4)*360)))
   local z=math.max(160,math.min(Game.mapSizeZ-160,base[3]+sz*(160+math.floor((buildingIndex-1)/4)*360)))
   pos,approach,reason=site(def,x,z,32)
  end
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
 elseif kind=='research'or kind=='addon'then
  local r=GG.Recoil40KResearch;local producer=factories[parent];local record=r and r.records[name]
  if not producer or not record or not Spring.FindUnitCmdDesc(producer,record.cmd)then fail('native_research_unavailable_'..name);return end
  if name=='ork_bigger_generator__ua_ork_power_research_1'then
   if not Spring.GetUnitResourcing then fail('actual_native_resourcing_getter_missing');return end
   activePowerBefore={}
   for _,id in ipairs(generators)do local d=UnitDefs[Spring.GetUnitDefID(id)];activePowerBefore[id]={fixed=d.energyMake,ume=Spring.GetUnitResourcing(id,'ume'),cme=Spring.GetUnitResourcing(id,'cme')}end
  end
  if kind=='addon'and r.sourceVariantAdapter.LocalAddon(producer,team,name)or kind=='research'and r.HasResearch(team,name)then fail('research_already_complete_without_fixture_payment_'..name);return end
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
 local d=UnitDefs[Spring.GetUnitDefID(id)]
 if d.canFly then
  local air=VFS.Include('40k_configs/paid_air_endpoint_review.lua');local C=GG.Recoil40KResearch
  local target,distance=air.Target(Spring,UnitDefs,C,id)
  if not target then fail('genuine_existing_surface_enemy_for_all_air_mounts_unavailable');return end
  local x,_,z=Spring.GetUnitPosition(id);local tx,_,tz=Spring.GetUnitPosition(target)
  local dx,dz=x-tx,z-tz;local len=math.sqrt(distance);if len==0 then dx,dz,len=1,0,1 end
  local px,pz=tx+range*.5*dx/len,tz+range*.5*dz/len
  local goal,witness,why=air.Check(Spring,UnitDefs,id,px,pz,Game.mapSizeX,Game.mapSizeZ)
  if not goal then log('ACTUAL_AIR_TARGET_STANDOFF_REFUSED',id,target,px,pz,why);fail('native_air_target_standoff_fullvolume_refused');return end
  log('ACTUAL_GENUINE_SURFACE_AIR_MOUNT_TARGET',id,target,'sourceMasks','SURFACE_bombs_ALL_others','sourceWantedHeight',witness.sourceWantedHeight)
  if distance>(range*.7)^2 then Spring.GiveOrderToUnit(id,CMD.MOVE,goal,{});Spring.GiveOrderToUnit(id,CMD.ATTACK,{target},{'shift'})
  else Spring.GiveOrderToUnit(id,CMD.ATTACK,{target},{})end
  return
 end
 local x,_,z=Spring.GetUnitPosition(id);local radius=math.min(200,range*.65)
 local xx=math.max(32,math.min(Game.mapSizeX-32,x+radius*math.cos(angle)));local zz=math.max(32,math.min(Game.mapSizeZ-32,z+radius*math.sin(angle)))
 Spring.GiveOrderToUnit(id,CMD.ATTACK,{xx,Spring.GetGroundHeight(xx,zz),zz},{})
end
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
specialIssue=function(task,frame)
 local kind,name=task[1],task[2];local C=GG.Recoil40KResearch
 if kind=='grot'then
  local id=products.ork_grot;local r=C and C.sourceOrkProducerCosts and C.sourceOrkProducerCosts.receipts[id]
  if not id or not r or r.builder~=factories.ork_settlement or r.metal~=90 or r.energy~=0 or r.work~=270 then fail('genuine_paid_HQ_grot_receipt_missing');return true end
  commander=id;advance('paid_HQ_Grot_becomes_only_structure_builder');return true
 elseif kind=='population'then active={kind=kind,name=name,issued=frame};return true
 elseif kind=='power'then
  if not activePowerBefore or not C.HasResearch(team,'ork_bigger_generator__ua_ork_power_research_1')or not C.sourceVariantModifiers.IsApplied(team,'ork_bigger_generator__ua_ork_power_research_1')then fail('whole_paid_power_receipt_missing');return true end
  for id,b in pairs(activePowerBefore)do
   local ume,cme=Spring.GetUnitResourcing(id,'ume'),Spring.GetUnitResourcing(id,'cme');local expected=(b.fixed+b.ume)*1.25-b.fixed
   if not finite(ume)or not finite(cme)or math.abs(ume-expected)>.001 or math.abs(cme-b.cme*1.25)>.001 then fail('native_generator_paid_upgrade_readback_'..id);return true end
   log('NATIVE_PAID_POWER_READBACK',id,b.fixed,b.ume,b.cme,ume,cme,expected)
  end;advance('source_1_25_actual_native_resourcing_readbacks');return true
 elseif kind=='jump'then
  local life=C and C.sourceOrkLifecycle;local seed=stormIDs[1]and Spring.GetUnitRulesParam(stormIDs[1],'40k_ork_cohort_seed');local row=life and life.ledger.Snapshot().cohorts[seed]
  if #stormIDs~=4 or not row or #row.ids~=4 or not GG.Recoil40KJump then fail('genuine_four_paid_Storm_cohort_missing');return true end
  local member={};for _,id in ipairs(stormIDs)do member[id]=true;if Spring.GetUnitRulesParam(id,'40k_ork_cohort_seed')~=seed then fail('mixed_paid_Storm_cohort');return true end end
  for _,id in ipairs(row.ids)do if not member[id]then fail('unpaid_or_extra_Storm_member');return true end end
  local leader=row.ids[1];local x,_,z=Spring.GetUnitPosition(leader);local target
  for i=0,15 do local a=i*math.pi/8;local tx,tz=x+400*math.cos(a),z+400*math.sin(a);local y=Spring.GetGroundHeight(tx,tz)
   if tx>96 and tz>96 and tx<Game.mapSizeX-96 and tz<Game.mapSizeZ-96 then
    local clear=true
    for _,id in ipairs(row.ids)do local mx,_,mz=Spring.GetUnitPosition(id);local px,pz=tx+mx-x,tz+mz-z;local py=Spring.GetGroundHeight(px,pz)
     if px<96 or pz<96 or px>Game.mapSizeX-96 or pz>Game.mapSizeZ-96 or not Spring.TestMoveOrder(Spring.GetUnitDefID(id),px,py,pz,0,0,0,true,true,false)then clear=false;break end
    end
    if clear then target={tx,y,tz};break end
   end
  end
  if not target then fail('native_Storm_jump_target_unavailable');return true end
  active={kind=kind,name=name,issued=frame,seed=seed,ids=row.ids,seen={},target=target,start={},leader=leader,phase='settle'}
  for _,id in ipairs(row.ids)do Spring.GiveOrderToUnit(id,CMD.STOP,{},{})end
  -- Ordinary STOP settles prior egress queues before recording stable cohort heads.
  return true
 elseif kind=='nuke'then
  local key=C.sourceNukklearTechReview and C.sourceNukklearTechReview.key
  if not key then local F=VFS.Include('40k_configs/ork_primary_research_facts.lua');for k,p in pairs(F.profiles)do if p.source:lower():gsub('\\','/')=='attrib/research/races/orks/ua_ork_research_tech_nukklear_bomma.lua'then key=k end end end
  local producer=factories.ork_giant_waagh_banner_sp_dxp3;local def=UnitDefNames.ork_nuke_bomba.id
  if not key or not C.records[key]or C.suppressed[key]then
   if C.CanBuild(team,def,producer,false)then fail('Nukklear_missing_exact_source_tech_not_closed');return true end
   log('EXACT_NUKKLEAR_SOURCE_TECH_CLOSED',key or'missing','no paid aircraft/ability acceptance');advance('actual_common_admission_refuses_missing_or_suppressed_exact_tech');return true
  end
  local record=C.records[key]
  if C.sourceNukklearTechReview then
   if C.CanBuild(team,def,producer,false)then fail('exact_Nukklear_paid_tech_gate_open_before_research');return true end
   local nextTasks={}
   if not factories[record.producer]then nextTasks[#nextTasks+1]={'build',record.producer}end
   for i=1,5 do nextTasks[#nextTasks+1]={'build','ork_waaagh_banner'}end
   nextTasks[#nextTasks+1]={'population',220};nextTasks[#nextTasks+1]={'research','ork_source_waaagh','ork_settlement'}
   nextTasks[#nextTasks+1]={'waaagh_readback','whole_paid_capacity60'}
   nextTasks[#nextTasks+1]={'build','ork_waaagh_banner'};nextTasks[#nextTasks+1]={'population',290}
   nextTasks[#nextTasks+1]={'research',key,record.producer};nextTasks[#nextTasks+1]={'product','ork_nuke_bomba','ork_giant_waagh_banner_sp_dxp3'}
   nextTasks[#nextTasks+1]={'bombard','actual_paid_nukklear_damage'}
   for i=#nextTasks,1,-1 do table.insert(tasks,index+1,nextTasks[i])end
   log('GENUINE_NUKKLEAR_SOURCE_CHAIN_INSERTED',key,record.producer,'six_additional_paid_banners_total19','Waaagh220_then_actual_applied_capacity280_then_growth290')
  else
   if not factories[record.producer]then log('NUKKLEAR_EXACT_TECH_PRODUCER_UNAVAILABLE',key,record.producer);advance('explicit_remaining_genuine_tech_producer_gap');return true end
   table.insert(tasks,index+1,{'research',key,record.producer});table.insert(tasks,index+2,{'product','ork_nuke_bomba','ork_giant_waagh_banner_sp_dxp3'});table.insert(tasks,index+3,{'bombard','actual_paid_nukklear_damage'})
  end
  advance('exact_whole_Nukklear_tech_available_native_paid_branch_inserted');return true
 elseif kind=='waaagh_readback'then
  local manager=C.sourceVariantModifiers;local pop=C.sourceVariantPopulation
  local applied=manager and manager.IsApplied(team,'ork_source_waaagh')==true
  local capacity=pop and pop.Capacity(team)
  if not applied or capacity~=280 then fail('whole_paid_Waaagh_application_or_actual_capacity60_unproved');return true end
  log('ACTUAL_WHOLE_PAID_WAAAGH_CAPACITY_READBACK',220,capacity,capacity-220,'manager_applied_receipt',applied)
  advance('whole_paid_Waaagh_committed_plus60_source_capacity_readback');return true
 elseif kind=='bombard'then
  local id=products.ork_nuke_bomba;local ability=GG.Recoil40KNukklearBombard
  if not id or not ability then fail('whole_paid_Nukklear_actor_or_runtime_missing');return true end
  local enemy=VFS.Include('40k_configs/paid_air_endpoint_review.lua').Target(Spring,UnitDefs,C,id)
  if not enemy then log('NUKKLEAR_NATIVE_DAMAGE_TARGET_UNAVAILABLE','no target actors created');advance('explicit_remaining_actual_enemy_target_gap');return true end
  local x,_,z=Spring.GetUnitPosition(id);local tx,_,tz=Spring.GetUnitPosition(enemy);local dx,dz=x-tx,z-tz;local len=math.sqrt(dx*dx+dz*dz);if len==0 then dx,dz,len=1,0,1 end
  local p={math.max(96,math.min(Game.mapSizeX-96,tx+600*dx/len)),0,math.max(96,math.min(Game.mapSizeZ-96,tz+600*dz/len))};p[2]=Spring.GetGroundHeight(p[1],p[3])
  local airGoal,airWitness,airReason=VFS.Include('40k_configs/paid_air_endpoint_review.lua').Check(Spring,UnitDefs,id,p[1],p[3],Game.mapSizeX,Game.mapSizeZ)
  log('NUKKLEAR_AIR_STANDOFF_ENDPOINT',id,p[1],p[3],airGoal~=nil,airReason or 'full_air_volume_clear',airWitness.sourceWantedHeight)
  if not airGoal then fail('Nukklear_native_standoff_unpassable');return true end;p=airGoal
  active={kind=kind,name=name,unit=id,target=enemy,issued=frame,phase='approach'};Spring.GiveOrderToUnit(id,CMD.MOVE,p,{});return true
 end
 return false
end
specialFrame=function(frame)
 if not active then return false end
 if active.kind=='population'then
  local C=GG.Recoil40KResearch;local p=C and C.sourceVariantPopulation and C.sourceVariantPopulation.Get(team)
  if not finite(p)then fail('actual_source_population_unreadable')elseif p>=active.name then log('ACTUAL_SOURCE_POPULATION',p,active.name,frame);advance('actual_source_growth_reaches_prerequisite')elseif frame-active.issued>18000 then fail('source_population_wait_timeout_'..active.name)end;return true
 elseif active.kind=='bombard'then
  local ability=GG.Recoil40KNukklearBombard;local id=active.unit
  if not Spring.ValidUnitID(active.target)then fail('actual_Nukklear_enemy_target_lost');return true end
  local state=ability and ability.State(id)
  if state and state.paid and state.phase=='fired'then active.projectile=state.projectile end
  if active.damageObserved and active.projectile then log('ACTUAL_PAID_NUKKLEAR_DAMAGE',id,active.target,active.projectile,active.damageObserved);advance('genuine_paid_ability_receipt_and_positive_native_damage');return true end
  if frame%30==0 and active.phase=='approach'then
   local x,_,z=Spring.GetUnitPosition(id);local tx,_,tz=Spring.GetUnitPosition(active.target)
   if x and tx and(x-tx)^2+(z-tz)^2<=750^2 then
    local metal=Spring.GetTeamResources(team,'metal');local energy=Spring.GetTeamResources(team,'energy')
    if metal>=1750 and energy>=8750 then
     Spring.GiveOrderToUnit(id,34991,{tx,Spring.GetGroundHeight(tx,tz),tz},{});active.phase='pending';active.requested=frame;log('ACTUAL_NUKKLEAR_PAID_NATIVE_COMMAND',id,frame,metal,energy)
    end
   end
  end
  if active.phase=='pending'and frame-active.requested>300 and not state then fail('actual_Nukklear_command_missing_paid_receipt')end
  if frame-active.issued>18000 then fail('actual_Nukklear_damage_trial_timeout')end;return true
 elseif active.kind=='jump'then
  if active.phase=='settle'then
   if frame-active.issued>=30 then
    for _,id in ipairs(active.ids)do active.start[id]={Spring.GetUnitPosition(id)}end
    Spring.GiveOrderToUnit(active.leader,GG.Recoil40KJump.command,active.target,{});active.phase='jump';active.jumpIssued=frame;log('ACTUAL_PAID_COHORT_JUMP_ORDER',active.leader,active.seed,active.target[1],active.target[3])
   end;return true
  end
  local all=true
  for _,id in ipairs(active.ids)do
   local state=GG.Recoil40KJump.states[id];if state and state.sourceGroup==active.seed then active.seen[id]=true end
   if state or not active.seen[id]or Spring.GetUnitRulesParam(id,'40k_jump_active')~=0 then all=false end
  end
  if all then
   for _,id in ipairs(active.ids)do local x,y,z=Spring.GetUnitPosition(id);local p=active.start[id];local charge=Spring.GetUnitRulesParam(id,'40k_jump_charge');local stunned=Spring.GetUnitIsStunned(id)
    if not x or(x-p[1])^2+(z-p[3])^2<300^2 or not finite(charge)or charge>=90 or stunned or Spring.MoveCtrl.IsEnabled(id)then fail('actual_Storm_jump_completion_or_charge_missing_'..id);return true end
    log('ACTUAL_STORM_JUMP_FINISHED',id,active.seed,x,y,z,charge)
   end;advance('all_four_actual_native_jump_states_movement_and_charge');return true
  end
  if frame-active.issued>1800 then fail('actual_four_Storm_jump_timeout')end;return true
 end
 return false
end
function gadget:Initialize()
 if not Script.SetWatchProjectile then fail('native_projectile_watch_unavailable');return end
 for _,d in pairs(UnitDefs)do if (d.customParams or{}).faction=='Orks'then
  for _,m in ipairs(d.weapons or{})do Script.SetWatchProjectile(m.weaponDef or m.weaponDefID,true)end
 end end
 if Spring.GetGameFrame()==0 then for _,id in ipairs(Spring.GetTeamUnits(team))do initialBirths[id]=true end end
 local metal,ms,_,mi=Spring.GetTeamResources(team,'metal');local energy,es,_,ei=Spring.GetTeamResources(team,'energy')
 log('NATIVE_INITIAL_ECONOMY',metal,ms,mi,energy,es,ei,'ordinary launcher1000start; no grants')
 if WeaponDefNames.ork_nuke_bomba_bombard then Script.SetWatchProjectile(WeaponDefNames.ork_nuke_bomba_bombard.id,true)end
 Spring.SetGameRulesParam('40k_paid_primary_orks_result',0)
 log('LIMITED_BLOCKED_SOURCE_MECHANISMS',mandatory,'no spawning/grants/heals/teleports/speed changes/markers')
end
function gadget:UnitCreated(id,def,unitTeam,builder)
 if unitTeam==team and builder==nil and Spring.GetGameFrame()==0 then initialBirths[id]=true end
 if unitTeam~=team or not started or not active or (active.kind=='research'or active.kind=='addon')then return end
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
  if active.name=='ork_generator'or active.name=='ork_bigger_generator'then generators[#generators+1]=id end
  if active.name=='ork_resource_factory'or active.name=='ork_generator'or active.name=='ork_bigger_generator'then active.unit=id;active.phase='income';active.finished=Spring.GetGameFrame();active.incomeSamples=0
  else advance('paid_native_foundation_with_progress_and_use')end
 elseif active.kind=='product'then
  products[active.name]=id;if active.name=='ork_stormboy'then
   local C=GG.Recoil40KResearch;local r=C and C.sourceOrkProducerCosts and C.sourceOrkProducerCosts.receipts[id]
   if not r or r.builder~=active.producer or r.work~=1050 or r.metal~=50 or r.energy~=0 then fail('ordinary_paid_storm_birth_cost_receipt_missing');return end
   stormIDs[#stormIDs+1]=id
  end;active.unit=id;active.finished=Spring.GetGameFrame();active.phase='egress';active.start={Spring.GetUnitPosition(id)}
  local target,witness,reason=VFS.Include('40k_configs/paid_factory_egress_review.lua').Plan(Spring,UnitDefs,id,active.producer,Game.mapSizeX,Game.mapSizeZ)
  log('NATIVE_FACTORY_EGRESS_ENDPOINT_WITNESS',active.name,id,active.producer,'reason',reason or 'native_endpoint_allowed','tries',#witness.tries,'childDefinition',witness.childDefinition,'producerDefinition',witness.producerDefinition)
  for n,row in ipairs(witness.tries)do log('NATIVE_FACTORY_EGRESS_ENDPOINT',n,row.x,row.y,row.z,row.label,row.inBounds,row.outsideParent,row.childDisplacement,row.nativeMoveLegal,row.airEndpointLegal,row.airReason)end
  if witness.parentVolume then log('NATIVE_FACTORY_PARENT_VOLUME',unpack(witness.parentVolume))end
  if not target then fail('native_factory_exit_unpassable_'..active.name);return end
  Spring.GiveOrderToUnit(id,CMD.MOVE,target,{})
  log('PAID_PRODUCT_FINISHED',active.name,id,'native_egress_order',target[1],target[3])
 end
end
function gadget:UnitDestroyed(id)
 if started and(id==commander or active and(id==active.producer or id==active.unit or id==active.created))then fail('required_actor_destroyed_'..id)end
end
function gadget:UnitTaken(id)self:UnitDestroyed(id)end
function gadget:UnitDamaged(id,def,unitTeam,damage,paralyzer,weapon,projectile)
 if not active or active.kind~='bombard'or paralyzer or not finite(damage)or damage<=0 then return end
 local expected=WeaponDefNames.ork_nuke_bomba_bombard;local ability=GG.Recoil40KNukklearBombard;local state=ability and ability.State(active.unit)
 if expected and state and state.paid and state.projectile==projectile and expected.id==weapon then active.damageObserved=damage;active.projectile=projectile;log('ACTUAL_NUKKLEAR_NATIVE_COLLISION_DAMAGE',id,damage,weapon,projectile,Spring.GetGameFrame())end
end
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
 if GG.Recoil40KPrimaryPaidOpponentFailure then fail('paid_opponent_'..GG.Recoil40KPrimaryPaidOpponentFailure);return end
 if not started then
  if frame%30~=0 then return end
  for _,id in ipairs(Spring.GetTeamUnits(team))do local d=UnitDefs[Spring.GetUnitDefID(id)];local cp=d.customParams or{}
   if initialBirths[id] and d.name=='ork_big_mek_commander'and cp.prototype40k_vital=='commander'and tostring(cp.prototype40k_source_progression)=='1'then commander=id;base={Spring.GetUnitPosition(id)};started=true;log('START','engine_initial_commander',id);break end
  end
  if not started and frame>=300 then fail('marked_engine_initial_ork_commander_missing')end
  return
 end
 if not Spring.ValidUnitID(commander)then fail('initial_commander_missing');return end
 -- Observe native build progress and producer use on every native frame.
 if active and active.created and not active.phase then
  local progress=select(5,Spring.GetUnitHealth(active.created))
  local _,metalUse,_,energyUse=Spring.GetUnitResources(active.producer)
  local command,building,queueAPI
  if active.kind=='product'then
   -- Exact native GetUnitCurrentCommand(factory) reads newUnitCommands,
   -- not factory production commandQue. Require both production head and child.
   local queue=Spring.GetFactoryCommands and Spring.GetFactoryCommands(active.producer,1)
   command=queue and queue[1] and queue[1].id
   building=Spring.GetUnitIsBuilding and Spring.GetUnitIsBuilding(active.producer)
   queueAPI='GetFactoryCommands'
  else
   command=Spring.GetUnitCurrentCommand and Spring.GetUnitCurrentCommand(active.producer)
   queueAPI='GetUnitCurrentCommand'
  end
  local childMatches=active.kind~='product'or building==active.created
  local observed=progress and progress>0 and progress<1 and command==-UnitDefNames[active.name].id and childMatches and ((metalUse or 0)>0 or(energyUse or 0)>0)
  if not active.buildWitness and (observed or frame%30==0)then
   local C=GG.Recoil40KResearch;local costs=C and C.sourceOrkProducerCosts and C.sourceOrkProducerCosts.receipts[active.created]
   log('NATIVE_BUILD_PROGRESS_USE_WITNESS',active.name,active.producer,active.created,frame,'progress',progress,'metalUse',metalUse,'energyUse',energyUse,'queueAPI',queueAPI,'command',command,'factoryBuilding',building,'matched',observed==true,'sourceCostBuilder',costs and costs.builder,'sourceCostMetal',costs and costs.metal,'sourceCostEnergy',costs and costs.energy,'sourceCostWork',costs and costs.work)
  end
  if observed then active.buildWitness=true end
 end
 if active and(active.kind=='research'or active.kind=='addon')then
  local r=GG.Recoil40KResearch
  local jobs=r and(active.kind=='addon'and r.sourceVariantAddonJobs and r.sourceVariantAddonJobs.jobs or r.jobs)
  local job=jobs and jobs[active.producer]and jobs[active.producer][active.name]
  local cost=active.record.row.cost or{};local cm,ce=cost.metal or 0,cost.energy or 0
  local paidFields=job and (cm>0 or ce>0)and (cm==0 and job.metal==0 or cm>0 and job.metal>0)and (ce==0 and job.energy==0 or ce>0 and job.energy>0)
  if job and job.active and job.team==team and job.steps>active.maxSteps and paidFields then
   active.maxSteps=job.steps;active.observations=active.observations+1;active.paidMetal=job.metal;active.paidEnergy=job.energy
   -- Retain read-only reference to this actual controller job. The native paid
   -- controller updates its final fields before retirement (including1.1clock).
   active.observedJob=job
  end
  if r and(active.kind=='addon'and r.sourceVariantAdapter.LocalAddon(active.producer,team,active.name)or active.kind=='research'and r.HasResearch(team,active.name))then
   local record=active.record;local cost=record.row.cost or{};local final=active.observedJob
   if active.observations<2 or not final or final.team~=team or final.steps~=record.frames or math.abs((final.metal or 0)-(cost.metal or 0))>1e-6*math.max(1,cost.metal or 0)or math.abs((final.energy or 0)-(cost.energy or 0))>1e-6*math.max(1,cost.energy or 0)then fail('research_completion_without_observed_paid_job_'..active.name);return end
   active.maxSteps=final.steps;active.paidMetal=final.metal;active.paidEnergy=final.energy
   log(active.kind=='addon'and'NATIVE_PAID_ENTITY_ADDON_RECEIPT'or'NATIVE_PAID_RESEARCH_RECEIPT',active.name,active.maxSteps,record.frames,active.paidMetal,active.paidEnergy,'completion_from_controller_after_final_native_payment')
   advance('observed_paid_controller_job_and_completion');return
  end
 end
 if specialFrame and specialFrame(frame)then return end
 if frame%30~=0 then return end
 if not active then
  if tasks[index]then issue(tasks[index],frame)
  else outcome(2,'PAID_PRIMARY_SELECTED_SEQUENCE_COMPLETE; five genuine source roles/four paid Storm cohort+actual jump/source power/HQ addon/Fighta; explicit remaining gaps')end
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
  local d=UnitDefs[Spring.GetUnitDefID(active.unit)]
  local airborne=not d.canFly or VFS.Include('40k_configs/paid_air_endpoint_review.lua').FlightObserved(Spring,UnitDefs,active.unit)
  if active.phase=='egress'and airborne and x and(x-active.start[1])^2+(z-active.start[3])^2>=160^2 then
   if active.name=='ork_stormboy'then advance('genuine_paid_storm_factory_egress');return end
   active.phase='guns';active.gunsFrame=frame;fire(active.unit,0);log('NATIVE_EGRESS',active.name,active.unit,x,z)
   if done then return end
   if gunsComplete(active.unit)then advance('paid_native_egress_no_ranged_mounts')end
  elseif active.phase=='guns'then
   if gunsComplete(active.unit)then advance('selected_ranged_mounts_actual_native_shot_origins')
   elseif frame-active.gunsFrame>3600 then fail('native_mount_origin_evidence_unavailable_'..active.name)
   elseif(frame-active.gunsFrame)%300==0 then fire(active.unit,((frame-active.gunsFrame)/300)%8*math.pi/4)end
  end
 end
end
-- Result0 pending; -1 failed;2 SELECTED_PAID_REVIEW_COMPLETE_WITH_EXPLICIT_GAPS. No broad PASS result exists.
-- Birth/progress/use witness is native production evidence, not reconstructed
-- per-unit invoices. Research final tick relies on strict controller payment.

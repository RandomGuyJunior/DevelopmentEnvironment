function gadget:GetInfo()
 return {name='40K mixed performance v2',desc='Three-faction diagnostic seeds; separate native workload windows',author='Local project',layer=108,enabled=true}
end
local options=Spring.GetModOptions()
if options.prototype_diagnostic~='mixedperf2' or tostring(options.prototype_mixed_v2)~='1' then return end
local cfg=VFS.Include('40k_configs/mixed_v2.lua')
local function json(v)
 if type(v)=='string'then return '"'..v:gsub('[%z\1-\31\\"]',function(c)return string.format('\\u%04x',c:byte())end)..'"'end
 if type(v)=='number'then return v==v and math.abs(v)<math.huge and tostring(v) or 'null'end
 if type(v)=='boolean'then return v and 'true' or 'false'end
 if type(v)~='table'then return 'null'end
 local out={};for k,x in pairs(v)do out[#out+1]=json(tostring(k))..':'..json(x)end;table.sort(out)
 return '{'..table.concat(out,',')..'}'
end
local function emit(v) Spring.Echo('40K_MIXED_V2 '..json(v)) end
if not gadgetHandler:IsSyncedCode() then
 local serial,start,last,lastFrame,samples,low=0,nil,nil,nil,0,0
 local fpsSum,simSum,ended=0,0,false
 function gadget:Update()
  if Spring.GetMyPlayerID()~=0 then return end
  local current=Spring.GetGameRulesParam('40k_mixed_v2_serial') or 0
  if current==0 or Spring.GetGameRulesParam('40k_mixed_v2_done')==1 then return end
  local now,frame=Spring.GetTimer(),Spring.GetGameFrame()
  if current~=serial then
   serial,start,last,lastFrame,samples,low=current,now,now,frame,0,0;fpsSum,simSum,ended=0,0,false
   local sound={};for _,key in ipairs({'snd_volmaster','snd_volbattle','snd_volunitreply','snd_volmusic','MaxSounds','Sound','VSync','VSyncGame','VSyncFraction','IdleFpsDivider','LimitIdleFps'})do sound[key]=Spring.GetConfigInt(key,-1)end
   local w,h,x,y=Spring.GetViewGeometry()
   emit({event='runtime',serial=serial,engine=Engine and Engine.version,engineFull=Engine and Engine.versionFull,
    game=Game.gameName,gameVersion=Game.gameVersion,map=Game.mapName,mapChecksum=Game.mapChecksum,modChecksum=Game.modChecksum,
    options=options,sound=sound,view={width=w,height=h,x=x,y=y},camera=Spring.GetCameraState(),
    audioPolicy=options.prototype_mixed_v2_audio,stockHUD='external native review required; fixture does not modify UI',
    seedsArePaidAcceptance=false,externalFrozenSHA256Required=true})
   return
  end
  if ended then return end
  local dt=Spring.DiffTimers(now,last);if dt<1 then return end
  local wall=Spring.DiffTimers(now,start);local ratio=(frame-lastFrame)/((Game.gameSpeed or 30)*dt)
  last,lastFrame=now,frame
  local desired,achieved,paused=Spring.GetGameSpeed()
  local master,music=Spring.GetConfigInt('snd_volmaster',-1),Spring.GetConfigInt('snd_volmusic',-1)
  local audio=options.prototype_mixed_v2_audio
  local audioOK=(audio=='quiet' and master==0 and music==0) or (audio=='audible' and master>0 and music==0)
  audioOK=audioOK and Spring.GetConfigInt('Sound',1)~=0
  if wall<cfg.settleWall and desired==1 and not paused and audioOK then return end
  local fps=Spring.GetFPS();samples=samples+1;fpsSum=fpsSum+fps;simSum=simSum+ratio
  low=(fps<cfg.minFPS or ratio<cfg.minSim) and low+1 or 0
  local seedIds,visible,includingIcons={},0,0
  local modelSet={};for _,id in ipairs(Spring.GetVisibleUnits(-1,nil,false) or {})do modelSet[id]=true end
  for _,id in ipairs(Spring.GetVisibleUnits(-1,nil,true) or {})do
   if Spring.GetUnitRulesParam(id,'40k_mixed_v2_seed')==serial then includingIcons=includingIcons+1 end
  end
  for _,id in ipairs(Spring.GetAllUnits())do
   if Spring.GetUnitRulesParam(id,'40k_mixed_v2_seed')==serial then
    seedIds[#seedIds+1]=id;if modelSet[id]then visible=visible+1 end
   end
  end
  table.sort(seedIds)
  emit({event='render',serial=serial,frame=frame,wall=wall,fps=fps,simRatio=ratio,configuredSpeed=desired,
   achievedSpeed=achieved,paused=paused,audioPolicyOK=audioOK,frameBudgetMs=1000/(Game.gameSpeed or 30),
   camera=Spring.GetCameraState(),view={Spring.GetViewGeometry()},visibleSeedModels=visible,
   visibleSeedIncludingIcons=includingIcons,readableAliveSeeds=#seedIds,seedIds=seedIds,
   visibilityAPI='native frustum/LOS/noDraw query; not GPU draw proof'})
  Spring.SendLuaRulesMsg(string.format('40K_MIXED_V2_SAMPLE %d %d',serial,frame))
  local unsafe=low>=5 or paused or desired~=1 or not audioOK
  if unsafe or wall>=cfg.settleWall+cfg.measureWall then
   ended=true
   Spring.SendLuaRulesMsg(string.format('40K_MIXED_V2_END %d %.6f %.6f %d %d %.6f',serial,fpsSum/samples,simSum/samples,samples,unsafe and 1 or 0,wall))
  end
 end
 return
end

local stage,phase,serial,started,stopped=0,0,0,0,false
local owned,seeds,origins,infra,paid,births={},{},{},{},{},{}
local routePolicy=VFS.Include('40k_configs/mixed_v2_cardinal_waypoints.lua')
local movementGoals={}
local backgroundPolicy=VFS.Include('40k_configs/mixed_background_firestate_review.lua').New(Spring,CMD,UnitDefNames,options,emit)
local cleaning=false
local pendingFrame,lastSampleFrame=nil,-1
local counters={projectiles=0,hits=0,damage=0,deaths=0,movingSamples=0,renderSamples=0,shotChanges=0,hitsByFaction={}}
local lastShots={};local production={};local seededInfrastructure=false
local seedBirth,lastNativeDamage={},{}
local deathRecords,deathLimit,deathTruncated=0,64,false
local function alive(id)return Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id)end
local function own(id,kind)
 if id then owned[id]=kind;Spring.SetUnitRulesParam(id,'40k_mixed_v2_owned',1,{public=true})end
 return id
end
local function cleanSeeds()
 cleaning=true;for _,id in ipairs(seeds)do if alive(id)then Spring.DestroyUnit(id,false,true)end end
 for _,id in ipairs(seeds)do owned[id]=nil end;seeds,origins,lastShots={},{},{};movementGoals={};seedBirth,lastNativeDamage={},{};cleaning=false
end
local function finish(reason)
 if stopped then return end;stopped=true
 local restored,restoreWhy=backgroundPolicy.Restore(reason)
 if not restored then emit({event='background_restore_failure',reason=restoreWhy,serial=serial,performanceAccepted=false})end
 emit({event='complete',serial=serial,stage=stage,reason=reason,performanceAccepted=false,paidRosterAccepted=false})
 Spring.SetGameRulesParam('40k_mixed_v2_done',1)
 -- Keep native results visible; coordinator closes the owned test normally.
end
local function site(name,x,z,mobile,metal)
 local def=UnitDefNames[name].id
 for ring=0,6 do for angle=0,15 do
  local xx,zz=x+ring*32*math.cos(angle*math.pi/8),z+ring*32*math.sin(angle*math.pi/8)
  local yy=Spring.GetGroundHeight(xx,zz)
  if xx>128 and zz>128 and xx<Game.mapSizeX-128 and zz<Game.mapSizeZ-128 and yy>0 then
   if mobile and Spring.TestMoveOrder(def,xx,yy,zz,0,0,0,true,true,false)then return {xx,yy,zz,0}end
   if not mobile then
    local bx,by,bz=Spring.Pos2BuildPos(def,xx,yy,zz,0)
    if Spring.TestBuildOrder(def,bx,by,bz,0)==2 and #(Spring.GetFeaturesInRectangle(bx-48,bz-48,bx+48,bz+48)or {})==0
     and (not metal or (select(3,Spring.GetGroundInfo(bx,bz))or 0)>0)then return {bx,by,bz,0}end
   end
  end
 end end
end
local function spawn(name,x,z,t,kind,metal)
 if stopped then return end
 local p=site(name,x,z,kind=='seed' or kind=='builder',metal);if not p then return end
 local controller=GG and GG.Recoil40KResearch
 if not controller or type(controller.WithDiagnosticSeedPermit)~='function'then finish('diagnostic_seed_capability_missing');return end
 local attemptedID
 local permitted,made=controller.WithDiagnosticSeedPermit(t,UnitDefNames[name].id,'40k_mixed_v2',function()
  -- Pinned native manual CreateUnit goes straight to LoadUnit/PostInit, not
  -- AllowUnitCreation. Consume this exact scoped capability before that birth;
  -- synchronous actual Register/identity checks still decide permit success.
  if type(controller.CanBuild)~='function' or not controller.CanBuild(t,UnitDefNames[name].id,nil,false)then return nil end
  attemptedID=Spring.CreateUnit(name,p[1],p[2],p[3],0,t)
  return attemptedID
 end)
 if not permitted then
  -- Cleanup only this fixture's actual synchronous returned birth, never an
  -- unexpected ID/team/definition. Runtime refusal is not itself cleanup proof.
  local rolledBack=false
  if type(attemptedID)=='number' and Spring.ValidUnitID(attemptedID)
   and Spring.GetUnitDefID(attemptedID)==UnitDefNames[name].id and Spring.GetUnitTeam(attemptedID)==t then
   Spring.DestroyUnit(attemptedID,false,true);rolledBack=true
  end
  emit({event='seed_refusal',serial=serial,name=name,team=t,definition=UnitDefNames[name].id,kind=kind,reason=tostring(made),attemptedID=attemptedID,fixtureRollback=rolledBack,paid=false})
  finish('diagnostic_seed_refused_'..name);return
 end
 local id=own(made,kind)
 if id then
  Spring.GiveOrderToUnit(id,CMD.FIRE_STATE,{0},{})
  emit({event='seed',serial=serial,id=id,name=name,team=t,kind=kind,x=p[1],z=p[3],paid=false})
 end
 return id,p
end
local function canBuild(id,name)
 if not alive(id) then return false end
 for _,def in ipairs(UnitDefs[Spring.GetUnitDefID(id)].buildOptions or {})do
  if def==UnitDefNames[name].id then return Spring.FindUnitCmdDesc(id,-def)~=nil end
 end
 return false
end
local function queue(side)
 local t,b=cfg.teams[side],infra[side]
 if not canBuild(b.factory,t.product)then finish('native_factory_product_unavailable_'..t.product);return end
 Spring.GiveOrderToUnit(b.factory,-UnitDefNames[t.product].id,{},{})
 emit({event='paid_order',serial=serial,producer=b.factory,name=t.product,team=t.id,seededProducer=true})
end
local function setupInfrastructure()
 for side,t in ipairs(cfg.teams)do
  local b={};infra[side]=b;production[side]=0
  b.hq=spawn(t.hq,t.baseX,t.baseZ,t.id,'infrastructure')
  b.factory=t.factory==t.hq and b.hq or spawn(t.factory,t.baseX+144,t.baseZ,t.id,'infrastructure')
  local g1=spawn(t.generator,t.baseX-144,t.baseZ,t.id,'infrastructure')
  local g2=spawn(t.generator,t.baseX,t.baseZ+144,t.id,'infrastructure')
  b.mex=spawn(t.mex,t.mexX,t.mexZ,t.id,'infrastructure',true)
  b.builder=spawn(t.builder,t.baseX,t.baseZ-128,t.id,'builder')
  if not b.hq or not b.factory or not g1 or not g2 or not b.mex or not b.builder then finish('infrastructure_site_failed_'..t.faction);return false end
  local p=site(t.generator,t.baseX+144,t.baseZ+144,false,false)
  if not p or not canBuild(b.builder,t.generator)then finish('native_builder_option_or_site_failed_'..t.generator);return false end
  Spring.GiveOrderToUnit(b.builder,-UnitDefNames[t.generator].id,p,{})
  emit({event='paid_build_order',serial=serial,builder=b.builder,name=t.generator,team=t.id,site=p,seededBuilder=true})
  queue(side);if stopped then return false end
 end
 seededInfrastructure=true;return true
end
local function begin(frame)
 if not GG or not GG.Recoil40KResearch then finish('actual_paid_source_controller_required');return end
 cleanSeeds();serial=serial+1
 local mapped=cfg.Window(serial)
 if not mapped then finish('requested_windows_complete');return end
 local policyOK,policyWhy=backgroundPolicy.Window(mapped.phase)
 if not policyOK then finish(policyWhy);return end
 stage=mapped.stage;phase=mapped.phase=='movement' and 1 or 2;started=frame
 lastSampleFrame=-1
 counters={projectiles=0,hits=0,damage=0,deaths=0,movingSamples=0,renderSamples=0,shotChanges=0,hitsByFaction={}}
 if not seededInfrastructure and not setupInfrastructure()then return end
 local lists={};for side,t in ipairs(cfg.teams)do
  lists[side]={};local composition=cfg.Composition(cfg.stages[stage],side)
  for role,count in ipairs(composition)do for i=1,count do lists[side][#lists[side]+1]=t.units[role]end end
 end
 local slot=0
 for index=1,math.ceil(cfg.stages[stage]/3)do for side,t in ipairs(cfg.teams)do
  local name=lists[side][index]
  if name then
   local x=cfg.startX+(slot%cfg.columns)*cfg.spacing
   local z=cfg.startZ+math.floor(slot/cfg.columns)*cfg.spacing;slot=slot+1
   local id,p=spawn(name,x,z,t.id,'seed')
   if not id then finish('native_seed_site_failed_'..name);return end
   local hp=Spring.GetUnitHealth and Spring.GetUnitHealth(id)
   seedBirth[id]={id=id,definition=UnitDefNames[name].id,name=name,team=t.id,x=p[1],z=p[3],startingHealth=hp,startingHealthObserved=hp~=nil}
   seeds[#seeds+1]=id;origins[id]={p[1],p[3]};Spring.SetUnitRulesParam(id,'40k_mixed_v2_seed',serial,{public=true})
   Spring.GiveOrderToUnit(id,CMD.FIRE_STATE,{0},{})
  end
 end end
 if #seeds~=cfg.stages[stage]then finish('exact_population_not_achieved');return end
 if phase==1 then
  for _,id in ipairs(seeds)do
   local goal,witness,why=routePolicy.Plan(Spring,UnitDefs,id,origins[id],Game.mapSizeX,Game.mapSizeZ)
   if not goal or witness.originalRefused then emit({event='movement_waypoint_route',serial=serial,frame=frame,witness=witness,reason=why or 'alternate_native_destination',newBaselineRequired=true})end
   if not goal then finish('movement_waypoint_unreachable');return end
   movementGoals[id]=goal
   Spring.GiveOrderToUnit(id,CMD.MOVE,{goal.x,goal.y,goal.z},{})
  end
 else
  for i,id in ipairs(seeds)do
   local team=Spring.GetUnitTeam(id);local target
   for offset=1,#seeds-1 do local other=seeds[(i+offset-1)%#seeds+1]
    if Spring.GetUnitTeam(other)~=team then target=other;break end
   end
   Spring.GiveOrderToUnit(id,CMD.FIRE_STATE,{2},{})
   Spring.GiveOrderToUnit(id,CMD.ATTACK,{target},{})
  end
 end
 Spring.SetGameRulesParam('40k_mixed_v2_serial',serial)
 emit({event='phase_start',routePolicy=routePolicy.Name,routeBaselineRequired=true,windowOrder=cfg.windowOrder,populationScope=phase==1 and 'fixed_population' or 'battle_population_history',serial=serial,stage=stage,phase=phase==1 and 'movement' or 'combat',frame=frame,target=cfg.stages[stage],
  seedIds=seeds,normalHealth=true,normalWeapons=true,normalExperience=true,resources='configured initial baseline and native economy only',
  seedTechnology='diagnostic actor exposure only; no paid unlock proof',audioPolicy=options.prototype_mixed_v2_audio,
  infrastructure='source diagnostic seeds; products/buildings from native orders are separately tracked'})
end
function gadget:Initialize()
 if Game.mapName~=cfg.mapName or Game.mapSizeX~=cfg.mapSize or Game.mapSizeZ~=cfg.mapSize then finish('fixture_map_mismatch');return end
 if options.prototype_mixed_v2_audio~='quiet' and options.prototype_mixed_v2_audio~='audible'then finish('explicit_audio_policy_required');return end
 if not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(options.prototype_source_progression) then finish('actual_source_progression_required');return end
 local existing={};for _,t in ipairs(Spring.GetTeamList())do existing[t]=true end
 for _,t in ipairs(cfg.teams)do
  if not existing[t.id]then finish('missing_team_'..t.id);return end
  for _,other in ipairs(cfg.teams)do if t.id~=other.id and Spring.AreTeamsAllied(t.id,other.id)then finish('teams_must_be_opposed');return end end
 end
 for name in pairs(cfg.Selected(options))do
  local d=UnitDefNames[name];local u=d and UnitDefs[d.id]
  if not u or not u.customParams or not u.customParams.animsource then finish('missing_genuine_definition_'..name);return end
  if tostring(u.customParams.prototype40k_source_progression)~='1' then finish('actual_source_graph_definition_required_'..name);return end
  emit({event='definition',name=name,id=d.id,source=u.customParams.animsource,health=u.health or u.maxHealth,speed=u.speed,
   metal=u.metalCost,energy=u.energyCost,buildTime=u.buildTime,weapons=u.weapons})
  for _,w in ipairs(u.weapons or {})do Script.SetWatchProjectile(w.weaponDef,true)end
 end
 emit({event='fixture',version=3,windowOrder=cfg.windowOrder,factions=3,stages=cfg.stages,normalSpeedRequired=1,noHealthOrResourceGrants=true,
  stockHUDRequired=true,sourceSteppedDefault=true,paidAcceptance=false})
end
function gadget:UnitCreated(id,def,team,builder)
 backgroundPolicy.Birth(id,def,team,builder,Spring.GetGameFrame())
 if builder and owned[builder] and owned[builder]~='seed'then
  own(id,'paid');paid[id]=true;births[id]={builder=builder,serial=serial}
  Spring.GiveOrderToUnit(id,CMD.FIRE_STATE,{0},{})
  emit({event='paid_created',serial=serial,id=id,name=UnitDefs[def].name,builder=builder,team=team})
 end
end
function gadget:UnitFinished(id,def,team)
 if not paid[id]then return end
 local b=births[id]
 emit({event='paid_finished',serial=serial,birthSerial=b.serial,id=id,name=UnitDefs[def].name,builder=b.builder,team=team})
 for side,t in ipairs(cfg.teams)do if infra[side] and b.builder==infra[side].factory then
  production[side]=production[side]+1
  if not stopped then
   if production[side]<cfg.maxPaidPerTeam then queue(side)
   else finish('INSUFFICIENT_production_safety_cap')end
  end
 end end
end
function gadget:UnitDestroyed(id,def,team,attacker,attackerDef,attackerTeam,weapon)
 if owned[id]~='seed' or cleaning then return end
 counters.deaths=counters.deaths+1
 if deathRecords>=deathLimit then
  if not deathTruncated then deathTruncated=true;emit({event='seed_death_journal_truncated',serial=serial,limit=deathLimit,frame=Spring.GetGameFrame()})end
  return
 end
 deathRecords=deathRecords+1
 emit({event='seed_death',serial=serial,stage=stage,phase=phase==1 and 'movement' or 'combat',frame=Spring.GetGameFrame(),
  id=id,definition=def,team=team,attacker=attacker,attackerDefinition=attackerDef,attackerTeam=attackerTeam,weapon=weapon,
  birth=seedBirth[id],lastNativeDamage=lastNativeDamage[id],lastDamageObserved=lastNativeDamage[id]~=nil,
  destroyAttackerObserved=attacker~=nil,destroyWeaponObserved=weapon~=nil,
  cause='unclassified native callbacks; last damage is not inferred killing damage',fixtureStopped=stopped,limit=deathLimit})
end
function gadget:ProjectileCreated(id,owner,weapon)
 if owned[owner]=='seed'then counters.projectiles=counters.projectiles+1
 elseif serial>0 and owner and not cleaning and not stopped then finish('INSUFFICIENT_outside_seed_projectile')end
end
local function refusedDamage(reason,id,def,team,damage,paralyzer,weapon,projectile,attacker,attackerDef,attackerTeam)
 -- Observe the actual triggering callback before finish; never alter native damage.
 local x,y,z=Spring.GetUnitPosition(id)
 local ax,ay,az
 if attacker then ax,ay,az=Spring.GetUnitPosition(attacker)end
 local commands=Spring.GetUnitCommands and Spring.GetUnitCommands(id,1)
 local attackCommands=attacker and Spring.GetUnitCommands and Spring.GetUnitCommands(attacker,1)
 emit({event='damage_refusal',reason=reason,serial=serial,stage=stage,phase=phase==1 and 'movement' or 'combat',frame=Spring.GetGameFrame(),
  target={id=id,definition=def,team=team,kind=owned[id] or 'background',x=x,y=y,z=z,command=commands and commands[1]},
  attacker={id=attacker,definition=attackerDef,team=attackerTeam,kind=owned[attacker] or 'background_or_unobserved',x=ax,y=ay,z=az,command=attackCommands and attackCommands[1]},
  damage=damage,paralyzer=paralyzer,weapon=weapon,projectile=projectile,lastNativeDamage=lastNativeDamage[id],
  classification='actual callback; no inferred cause or suppressed damage',performanceAccepted=false})
 finish(reason)
end
function gadget:UnitDamaged(id,def,team,damage,paralyzer,weapon,projectile,attacker,attackerDef,attackerTeam)
 if owned[id]=='seed' and not cleaning and damage>0 then
  local hp=Spring.GetUnitHealth and Spring.GetUnitHealth(id)
  local x,y,z=Spring.GetUnitPosition(id)
  local commands=Spring.GetUnitCommands and Spring.GetUnitCommands(id,1)
  lastNativeDamage[id]={frame=Spring.GetGameFrame(),definition=def,team=team,damage=damage,paralyzer=paralyzer,
   weapon=weapon,projectile=projectile,attacker=attacker,attackerDefinition=attackerDef,attackerTeam=attackerTeam,
   observedHealth=hp,healthObserved=hp~=nil,x=x,y=y,z=z,command=commands and commands[1]}
 end
 if serial>0 and not stopped and not cleaning and damage>0 and owned[id]~='seed'then
  refusedDamage('INSUFFICIENT_outside_seed_target_damage',id,def,team,damage,paralyzer,weapon,projectile,attacker,attackerDef,attackerTeam);return
 end
 if owned[id]=='seed' and damage>0 and (phase==1 or not attacker or owned[attacker]~='seed') then
  refusedDamage('INSUFFICIENT_combat_outside_measured_seed_window',id,def,team,damage,paralyzer,weapon,projectile,attacker,attackerDef,attackerTeam);return
 end
 if owned[id]=='seed' and attacker and owned[attacker]=='seed' and not paralyzer and damage>0 then
  counters.damage=counters.damage+damage
  if Spring.GetUnitTeam(id)~=Spring.GetUnitTeam(attacker)then
   counters.hits=counters.hits+1
   for _,t in ipairs(cfg.teams)do if Spring.GetUnitTeam(attacker)==t.id then
    counters.hitsByFaction[t.faction]=(counters.hitsByFaction[t.faction] or 0)+1
   end end
  end
 end
end
function gadget:RecvLuaMsg(msg,player)
 if player~=0 or stopped or not select(2,Spring.GetPlayerInfo(player,false))then return end
 local s,f=msg:match('^40K_MIXED_V2_SAMPLE (%d+) (%d+)$')
 if s and tonumber(s)==serial and tonumber(f)>lastSampleFrame and math.abs(tonumber(f)-Spring.GetGameFrame())<90 then
  lastSampleFrame=tonumber(f);counters.renderSamples=counters.renderSamples+1
 end
 local ss,fps,sim,count,unsafe,wall=msg:match('^40K_MIXED_V2_END (%d+) ([%d.]+) ([%d.]+) (%d+) (%d+) ([%d.]+)$')
 if not ss or tonumber(ss)~=serial then return end
 local aliveCount=0;for _,id in ipairs(seeds)do if alive(id)then aliveCount=aliveCount+1 end end
 local allFactionsHit=true;for _,t in ipairs(cfg.teams)do if not counters.hitsByFaction[t.faction]then allFactionsHit=false end end
 emit({event='phase_end',windowOrder=cfg.windowOrder,populationScope=phase==1 and 'fixed_population' or 'battle_population_history',serial=serial,stage=stage,phase=phase==1 and 'movement' or 'combat',target=cfg.stages[stage],alive=aliveCount,
  frame=Spring.GetGameFrame(),fps=tonumber(fps),simRatio=tonumber(sim),samples=tonumber(count),wall=tonumber(wall),
  counters=counters,exactPopulation=aliveCount==cfg.stages[stage],unsafe=tonumber(unsafe)==1,production=production})
 if tonumber(unsafe)==1 then finish('native_speed_audio_or_performance_guard')
 elseif tonumber(fps)<cfg.minFPS or tonumber(sim)<cfg.minSim then finish('native_phase_mean_performance_guard')
 elseif phase==1 and aliveCount~=cfg.stages[stage]then finish('INSUFFICIENT_population_loss')
 elseif phase==2 and aliveCount==0 then finish('INSUFFICIENT_battle_population_exhausted')
 elseif tonumber(wall)<cfg.settleWall+cfg.measureWall or tonumber(count)<20 then finish('INSUFFICIENT_window')
 elseif counters.renderSamples<20 then finish('INSUFFICIENT_native_render_receipts')
 elseif phase==1 and counters.movingSamples==0 then finish('INSUFFICIENT_motion')
 elseif phase==2 and counters.hits==0 then finish('INSUFFICIENT_native_combat')
 elseif phase==2 and not allFactionsHit then finish('INSUFFICIENT_three_faction_combat')
 elseif stage==#cfg.stages and phase==2 then finish('requested_windows_complete')
 else
  cleanSeeds();pendingFrame=Spring.GetGameFrame()+150
  emit({event='transition',serial=serial,projectileDrainFrames=150,productionContinues=true})
 end
end
function gadget:GameFrame(frame)
 if stopped then return end
 local policyOK,policyWhy=backgroundPolicy.Check()
 if not policyOK then finish(policyWhy);return end
 if pendingFrame then
  if frame>=pendingFrame then pendingFrame=nil;begin(frame)end
  return
 end
 if serial==0 then if frame>=90 then begin(frame)end;return end
 if frame-started>5400 then finish('native_safety_timeout');return end
 if frame%30~=0 then return end
 local count,moving,byFaction,movingByFaction,paidAlive,fixedAlive=0,0,{},{},0,0
 for _,t in ipairs(cfg.teams)do byFaction[t.faction]=0;movingByFaction[t.faction]=0 end
 for _,id in ipairs(seeds)do if alive(id)then
  count=count+1;local vx,_,vz=Spring.GetUnitVelocity(id);if vx*vx+vz*vz>.0025 then moving=moving+1 end
  for _,t in ipairs(cfg.teams)do if Spring.GetUnitTeam(id)==t.id then
   byFaction[t.faction]=byFaction[t.faction]+1
   if vx*vx+vz*vz>.0025 then movingByFaction[t.faction]=movingByFaction[t.faction]+1 end
  end end
  local shot=Spring.GetUnitRulesParam(id,'40k_last_shot')
  if shot and shot~=lastShots[id]then if lastShots[id]then counters.shotChanges=counters.shotChanges+1 end;lastShots[id]=shot end
  if phase==1 then
   local x,_,z=Spring.GetUnitPosition(id);local p=origins[id]
   if (x-p[1])^2+(z-p[2])^2>300^2 then
    Spring.GiveOrderToUnit(id,CMD.MOVE,{p[1],Spring.GetGroundHeight(p[1],p[2]),p[2]},{})
   elseif (x-p[1])^2+(z-p[2])^2<20^2 and frame-started>300 then
    local goal=movementGoals[id];if not goal then finish('movement_waypoint_unrecorded');return end
    Spring.GiveOrderToUnit(id,CMD.MOVE,{goal.x,Spring.GetGroundHeight(goal.x,goal.z),goal.z},{})
   end
  end
 end end
 counters.movingSamples=counters.movingSamples+moving
 for id,kind in pairs(owned)do if alive(id)then
  if kind=='paid'then paidAlive=paidAlive+1 elseif kind~='seed'then fixedAlive=fixedAlive+1 end
 end end
 local resources,queues={},{};for side,t in ipairs(cfg.teams)do resources[t.faction]={}
  local factory=infra[side] and infra[side].factory
  if factory and alive(factory)then
   local commands=Spring.GetFactoryCommands(factory,1) or {}
   queues[t.faction]={producer=factory,head=commands[1],building=Spring.GetUnitIsBuilding(factory)}
  else queues[t.faction]={missingProducer=true}end
  for _,r in ipairs({'metal','energy'})do local current,storage,pull,income,expense=Spring.GetTeamResources(t.id,r)
   resources[t.faction][r]={current=current,storage=storage,pull=pull,income=income,expense=expense}end
 end
 local totalNativeAlive,background
 if Spring.GetAllUnits then
  totalNativeAlive=0;background={}
  for _,id in ipairs(Spring.GetAllUnits()or{})do if alive(id)then
   totalNativeAlive=totalNativeAlive+1
   if not owned[id]then local def=Spring.GetUnitDefID(id)
    background[#background+1]={id=id,def=def,name=UnitDefs[def]and UnitDefs[def].name,team=Spring.GetUnitTeam(id)}
   end
  end end
 end
 emit({event='workload',serial=serial,stage=stage,phase=phase==1 and 'movement' or 'combat',frame=frame,alive=count,
  nativePopulationCovered=Spring.GetAllUnits~=nil,totalNativeAlive=totalNativeAlive,backgroundActors=background,
  backgroundPolicy='retained uncontrolled starting/background actors; not seed target or paid acceptance',
  moving=moving,byFaction=byFaction,movingByFaction=movingByFaction,counters=counters,resources=resources,paidAlive=paidAlive,
  fixedAlive=fixedAlive,totalOwnedAlive=count+paidAlive+fixedAlive,completedProducts=production,productionQueue=queues})
 -- Fixed movement loss still ends escalation. Real battle losses are recorded, never replenished.
 if phase==1 and count~=cfg.stages[stage]then finish('INSUFFICIENT_population_loss')
 elseif phase==2 and count==0 then finish('INSUFFICIENT_battle_population_exhausted')end
end

function gadget:Shutdown()backgroundPolicy.Restore("shutdown")end
function gadget:Save()local ok,why=backgroundPolicy.SaveAbort();if not ok then finish(why)end end
function gadget:Load()local ok,why=backgroundPolicy.SaveAbort();if not ok then finish(why)end end

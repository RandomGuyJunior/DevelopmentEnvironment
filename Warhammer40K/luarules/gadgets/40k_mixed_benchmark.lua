function gadget:GetInfo()
 return {name='40K mixed force benchmark',desc='Explicit owned mixed movement/combat plus native paid queues',author='Local project',layer=106,enabled=true}
end
local options=Spring.GetModOptions()
if options.prototype_diagnostic~='benchmark' or tostring(options.prototype_mixed_force)~='1' then return end
local config=VFS.Include('40k_configs/mixed_benchmark.lua')
local function json(v)
 if type(v)=='string' then return '"'..v:gsub('[%z\1-\31\\"]',function(c)return string.format('\\u%04x',c:byte())end)..'"' end
 if type(v)=='number' then return v==v and math.abs(v)<math.huge and tostring(v) or 'null' end
 if type(v)=='boolean' then return v and 'true' or 'false' end
 if type(v)~='table' then return 'null' end
 local out={};for k,value in pairs(v)do out[#out+1]=json(tostring(k))..':'..json(value)end;table.sort(out)
 return '{'..table.concat(out,',')..'}'
end
local function emit(v)Spring.Echo('40K_MIXED_BENCH '..json(v))end
if not gadgetHandler:IsSyncedCode() then
 local stage=0;local timer,lastTimer,lastFrame;local samples,fpsSum,simSum=0,0,0;local low=0;local ended=false;local combatSent=false
 function gadget:Update()
  local current=Spring.GetGameRulesParam('40k_mixed_stage') or 0
  if Spring.GetGameRulesParam('40k_mixed_done')==1 or current==0 then return end
  local now,f=Spring.GetTimer(),Spring.GetGameFrame()
  if stage~=current then
   stage=current;timer,lastTimer,lastFrame=now,now,f;samples,fpsSum,simSum,low=0,0,0,0;ended=false;combatSent=false
   local sound={device=Spring.GetConfigString and Spring.GetConfigString('snd_device','unknown')};for _,key in ipairs({'snd_volmaster','snd_volbattle','snd_volunitreply','snd_volui','snd_volmusic','MaxSounds','Sound'})do sound[key]=Spring.GetConfigInt(key,-1)end
   local w,h,x,y=Spring.GetViewGeometry()
   emit({event='runtime',stage=stage,camera=Spring.GetCameraState(),view={x=x,y=y,width=w,height=h},sound=sound,
    engine=Engine and Engine.version,game=Game.gameVersion,gameName=Game.gameName,archiveHashPolicy='Game checksum native; external archive SHA256 required in launch evidence',map=Game.mapName,mapChecksum=Game.mapChecksum,modChecksum=Game.modChecksum,
    options=options,requestedSpeed=1,profiling=tostring(options.prototype_profile)=='1',hudPolicy='stock BAR; fixture changes no UI/audio/camera'})
   return
  end
  local dt=Spring.DiffTimers(now,lastTimer);if dt<1 or ended then return end
  local wall=Spring.DiffTimers(now,timer);local ratio=(f-lastFrame)/(30*dt);local fps=Spring.GetFPS()
  lastTimer,lastFrame=now,f
  if wall<config.settleWall then return end
  if wall>=config.settleWall+config.measureWall-8 and not combatSent then combatSent=true;Spring.SendLuaRulesMsg('40K_MIXED_COMBAT '..stage)end
  samples=samples+1;fpsSum=fpsSum+fps;simSum=simSum+ratio
  low=(fps<config.minFPS or ratio<config.minSim) and low+1 or 0
  local desired,achieved,paused=Spring.GetGameSpeed()
  emit({event='render',stage=stage,frame=f,wall=wall,fps=fps,simRatio=ratio,configuredSpeed=desired,achievedSpeed=achieved,paused=paused,frameBudgetMs=1000/30})
  Spring.SendLuaRulesMsg(string.format('40K_MIXED_SAMPLE %d %.6f %.6f',stage,fps,ratio))
  if wall>=config.settleWall+config.measureWall or low>=5 or paused or desired~=1 then
   ended=true
   Spring.SendLuaRulesMsg(string.format('40K_MIXED_END %d %.6f %.6f %d %d %.6f',stage,fpsSum/samples,simSum/samples,samples,(low>=5 or paused or desired~=1) and 1 or 0,wall))
  end
 end
 return
end
local stage,started,stopped=0,0,false
local owned,units,bases,paid,births={}, {}, {}, {}, {}
local aliveCount,projectiles,hits,damage,deaths,products,buildings=0,0,0,0,0,0,0
local large=tostring(options.prototype_mixed_large)=='1'
local cleaning=false;local combat=false;local origins={};local motionSamples=0;local lastFPS,lastSim,renderSamples=0,0,0
local function alive(id)return Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id)end
local function own(id,kind)
 if not id then return nil end;owned[id]=kind;Spring.SetUnitRulesParam(id,'40k_mixed_owned',1,{public=true});return id
end
local function clean()
 cleaning=true;for id in pairs(owned)do if alive(id)then Spring.DestroyUnit(id,false,true)end end
 owned,units,bases,paid,births={},{},{},{},{};cleaning=false
end
local function finish(reason)
 if stopped then return end;stopped=true;emit({event='complete',stage=stage,reason=reason});Spring.SetGameRulesParam('40k_mixed_done',1);clean()
end
local function has(def,name)
 for _,id in ipairs(UnitDefs[def].buildOptions or {})do if id==UnitDefNames[name].id then return true end end;return false
end
local function site(name,x,z,metal)
 local def=UnitDefNames[name].id
 for ring=0,8 do for i=0,15 do
  local a=i*math.pi/8;local xx,yy,zz=Spring.Pos2BuildPos(def,x+ring*32*math.cos(a),0,z+ring*32*math.sin(a),0)
  yy=Spring.GetGroundHeight(xx,zz)
  if xx>64 and zz>64 and xx<Game.mapSizeX-64 and zz<Game.mapSizeZ-64 and yy>0 and Spring.TestBuildOrder(def,xx,yy,zz,0)==2
   and #(Spring.GetFeaturesInRectangle(xx-48,zz-48,xx+48,zz+48) or {})==0
   and (not metal or (select(3,Spring.GetGroundInfo(xx,zz)) or 0)>0) then return {xx,yy,zz,0} end
 end end
end
local function spawn(name,x,z,team,kind)
 local ud=UnitDefNames[name];local y=Spring.GetGroundHeight(x,z)
 if x<64 or z<64 or x>Game.mapSizeX-64 or z>Game.mapSizeZ-64 or y<=0 then return nil end
 if kind=='combat' or kind=='builder' then
  if not Spring.TestMoveOrder(ud.id,x,y,z,0,0,0,true,true,false)then return nil end
 end
 local id=own(Spring.CreateUnit(name,x,y,z,0,team),kind)
 if id then emit({event='seed',stage=stage,id=id,name=name,team=team,kind=kind,x=x,y=y,z=z,paid=false})end;return id
end
local function queue(factory,name)
 local def=UnitDefNames[name]
 if not alive(factory) or not has(Spring.GetUnitDefID(factory),name) or not Spring.FindUnitCmdDesc(factory,-def.id) then return false end
 Spring.GiveOrderToUnit(factory,-def.id,{},{});emit({event='paid_order',factory=factory,name=name,stage=stage});return true
end
local function begin(f)
 clean();stage=stage+1;started=f;projectiles,hits,damage,deaths,products,buildings=0,0,0,0,0,0
 combat=false;origins={};motionSamples=0;lastFPS,lastSim,renderSamples=0,0,0
 if not config.stages[stage]then finish('requested_stages_complete');return end
 local composition=config.composition(config.stages[stage],large)
 for side,t in ipairs(config.teams)do
  units[side]={};local n=0
  for role,count in ipairs(composition)do for i=1,count do
   n=n+1;local x=config.startX+((n-1)%config.columns)*config.spacingX
   local z=config.startZ+math.floor((n-1)/config.columns)*config.spacingZ+(side-1)*52
   local name=role==4 and t.large or t.units[role]
   local id=spawn(name,x,z,t.id,'combat');if not id then finish('native_mobile_site_or_spawn_failed');return end
   units[side][n]=id;origins[id]={x,z};Spring.GiveOrderToUnit(id,CMD.FIRE_STATE,{0},{})
   Spring.GiveOrderToUnit(id,CMD.MOVE,{x+64,Spring.GetGroundHeight(x+64,z),z},{})
  end end
  local bx,bz=t.baseX,t.baseZ
  bases[side]={}
  for i,name in ipairs({t.hq,t.factory,t.generator,t.generator,t.mex})do
   local sx=bx+((i-1)%2)*176-88;local sz=bz+math.floor((i-1)/2)*176-176
   local p=site(name,name==t.mex and t.mexX or sx,name==t.mex and t.mexZ or sz,name==t.mex)
   if not p then finish('native_building_or_metal_site_failed_'..name);return end
   local id=spawn(name,p[1],p[3],t.id,'base');if not id then finish('source_building_spawn_failed');return end
   bases[side][i]=id
  end
  local builder=spawn(t.builder,bx+96,bz+64,t.id,'builder');if not builder then finish('source_builder_spawn_failed');return end
  local p=site(t.generator,bx+96,bz+128,false)
  if not p or not has(Spring.GetUnitDefID(builder),t.generator)then finish('native_builder_option_or_site_failed');return end
  Spring.GiveOrderToUnit(builder,-UnitDefNames[t.generator].id,p,{})
  emit({event='paid_build_order',builder=builder,name=t.generator,site=p,stage=stage})
  if not queue(bases[side][2],t.product)then finish('native_factory_option_failed');return end
 end
 Spring.SetGameRulesParam('40k_mixed_stage',stage);Spring.SetGameRulesParam('40k_mixed_started',f)
 emit({event='stage_start',stage=stage,targetMobile=config.stages[stage],compositionPerSide=composition,fixedStructures=10,fixedBuilders=2,
  large=large,frame=f,normalHealth=true,resources='initial configured resources + native economy only; no refill',seededEntitiesNotProductionProof=true})
end
function gadget:Initialize()
 if Game.mapName~=config.mapName or Game.mapSizeX~=4096 or Game.mapSizeZ~=4096 then finish('fixture_map_mismatch');return end
 if not Spring.AreTeamsAllied or Spring.AreTeamsAllied(0,1)then finish('requires_opposed_existing_teams_0_1');return end
 for _,t in ipairs(config.teams)do
  for _,name in ipairs({t.units[1],t.units[2],t.units[3],t.hq,t.factory,t.builder,t.generator,t.mex,large and t.large or t.units[1]})do
   local ud=UnitDefNames[name]
   if not ud or not UnitDefs[ud.id].customParams.animsource then finish('missing_genuine_definition_'..name);return end
   emit({event='definition',name=name,id=ud.id,source=UnitDefs[ud.id].customParams.animsource,health=UnitDefs[ud.id].health or UnitDefs[ud.id].maxHealth,speed=UnitDefs[ud.id].speed,metal=UnitDefs[ud.id].metalCost,energy=UnitDefs[ud.id].energyCost,buildTime=UnitDefs[ud.id].buildTime})
   for _,w in ipairs(UnitDefs[ud.id].weapons or {})do Script.SetWatchProjectile(w.weaponDef,true)end
  end
 end
 emit({event='fixture',workload='two-faction six-core; optional exact large actors',map=Game.mapName,mapSizeX=Game.mapSizeX,mapSizeZ=Game.mapSizeZ,options=options})
end
function gadget:UnitCreated(id,def,team,builder)
 if builder and owned[builder]then own(id,'paid');births[id]=builder;paid[id]=true;emit({event='paid_created',id=id,name=UnitDefs[def].name,builder=builder,stage=stage})end
end
function gadget:UnitFinished(id,def,team)
 if not paid[id]then return end
 local ud=UnitDefs[def];if ud.speed and ud.speed>0 then products=products+1 else buildings=buildings+1 end
 emit({event='paid_finished',id=id,name=ud.name,builder=births[id],products=products,buildings=buildings,stage=stage})
 for side,t in ipairs(config.teams)do if bases[side] and births[id]==bases[side][2] and products<8 then queue(births[id],t.product)end end
end
function gadget:UnitDestroyed(id)
 if owned[id] and not cleaning then deaths=deaths+1;emit({event='death',id=id,kind=owned[id],stage=stage})end
end
function gadget:ProjectileCreated(id,owner,weapon)if owned[owner]then projectiles=projectiles+1 end end
function gadget:UnitDamaged(id,def,team,d,paralyzer,weapon,projectile,attacker)
 if owned[id] and attacker and owned[attacker] and not paralyzer and d>0 then hits=hits+1;damage=damage+d end
end
function gadget:RecvLuaMsg(msg,player)
 local active=select(2,Spring.GetPlayerInfo(player,false));if not active then return end
 local c=msg:match('^40K_MIXED_COMBAT (%d+)$')
 if c and tonumber(c)==stage then combat=true end
 local rs,rf,rr=msg:match('^40K_MIXED_SAMPLE (%d+) ([%d.]+) ([%d.]+)$')
 if rs and tonumber(rs)==stage then lastFPS,lastSim=tonumber(rf),tonumber(rr);renderSamples=renderSamples+1 end
 local s,fps,sim,count,unsafe,wall=msg:match('^40K_MIXED_END (%d+) ([%d.]+) ([%d.]+) (%d+) (%d+) ([%d.]+)$')
 if not s or tonumber(s)~=stage or stopped then return end
 emit({event='stage_end',stage=stage,fps=tonumber(fps),sim=tonumber(sim),samples=tonumber(count),projectiles=projectiles,hits=hits,damage=damage,deaths=deaths,paidProducts=products,paidBuildings=buildings,aliveMobile=aliveCount,movingUnitSamples=motionSamples,renderSamples=renderSamples,wall=tonumber(wall),unsafe=tonumber(unsafe)==1})
 if tonumber(unsafe)==1 then finish('persistent_runtime_safety_gate')
 elseif tonumber(wall)<config.settleWall+config.measureWall then finish('measurement_window_incomplete')
 elseif tonumber(count)<10 or tonumber(fps)<config.minFPS or tonumber(sim)<config.minSim then finish('performance_or_sampler_gate')
 elseif aliveCount<config.stages[stage]*(1-config.maxLossFraction)then finish('population_loss_invalidates_target_load')
 elseif products==0 or buildings==0 or projectiles==0 or hits==0 or motionSamples==0 then finish('production_or_combat_not_achieved')
 elseif stage==#config.stages then finish('requested_stages_complete')else begin(Spring.GetGameFrame())end
end
function gadget:GameFrame(f)
 if stopped then return end
 if stage==0 then if f>=90 then begin(f)end;return end
 if combat==true then
  combat="started"
  for side,list in ipairs(units)do local other=units[3-side]
   for i,id in ipairs(list)do if alive(id)then Spring.GiveOrderToUnit(id,CMD.FIRE_STATE,{2},{})
    if alive(other[i])then Spring.GiveOrderToUnit(id,CMD.ATTACK,{other[i]},{})end
   end end
  end
 end
 if not combat and (f-started)%180==0 then
  for _,list in ipairs(units)do for _,id in ipairs(list)do if alive(id)then
   local p=origins[id];local x=p[1]+(math.floor((f-started)/180)%2==0 and 64 or -64)
   Spring.GiveOrderToUnit(id,CMD.MOVE,{x,Spring.GetGroundHeight(x,p[2]),p[2]},{})
  end end end
 end
 if f%30~=0 then return end
 local moving,baseAlive,paidAlive=0,0,0;aliveCount=0
 for id,kind in pairs(owned)do if alive(id)then
  if kind=='combat'then aliveCount=aliveCount+1;local vx,_,vz=Spring.GetUnitVelocity(id);if vx*vx+vz*vz>.0025 then moving=moving+1 end
  elseif kind=='paid'then paidAlive=paidAlive+1 else baseAlive=baseAlive+1 end
 end end
 motionSamples=motionSamples+moving
 local resources={};for _,t in ipairs(config.teams)do
  resources[t.faction]={};for _,r in ipairs({'metal','energy'})do local current,storage,pull,income,expense=Spring.GetTeamResources(t.id,r)
   resources[t.faction][r]={current=current,storage=storage,pull=pull,income=income,expense=expense}end
 end
 emit({event='workload',stage=stage,frame=f,aliveMobile=aliveCount,moving=moving,fixedAlive=baseAlive,paidAlive=paidAlive,combatPhase=not not combat,projectiles=projectiles,hits=hits,damage=damage,resources=resources})
 if f-started>5400 then finish('synced_safety_timeout')end
end

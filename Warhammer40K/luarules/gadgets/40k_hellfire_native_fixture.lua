function gadget:GetInfo()return{name='40K Hellfire and Basilisk native fixture',desc='Exact opt-in unpaid real projectile and hull review',author='Local Recoil Project',layer=110,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return end
local M=VFS.Include('40k_configs/hellfire_native_fixture.lua')
local options=Spring.GetModOptions()or{}
if not M.Enabled(options)then return end
local json=VFS.Include('40k_configs/wraith_paid_native_json.lua')
local function emit(event,row)row=row or{};row.event=event;Spring.Echo('40K_HELLFIRE_NATIVE '..json.Encode(row))end
local owned,targets,ownership={},{},{};local actor,basilisk,ledger,team,enemy,ax,az
local basiliskObserver
local projectileOwners={} -- Native IDs can be reused between the two observed actors.
local index,stage,start,done=0,'setup',0,false
local function alive(id)return id and Spring.ValidUnitID(id)and not Spring.GetUnitIsDead(id)end
local function clear(ids)
 for _,id in ipairs(ids)do local o=ownership[id]
  if o and alive(id)and Spring.GetUnitTeam(id)==o.team and Spring.GetUnitDefID(id)==o.def then Spring.DestroyUnit(id,false,true)end
 end
end
local function order(id,cmd,args)Spring.GiveOrderToUnit(id,cmd,args,0)end
local function hold(id)
 if not alive(id)then return false end
 -- Hold fire before STOP drops the explicit target: avoid an opportunity-target gap.
 order(id,CMD.FIRE_STATE,{0});order(id,CMD.STOP,{});order(id,CMD.MOVE_STATE,{0})
 local state=Spring.GetUnitStates(id);local okay=state and state.firestate==0 and state.movestate==0
 emit('hold_state',{id=id,frame=Spring.GetGameFrame(),firestate=state and state.firestate,movestate=state and state.movestate,accepted=okay==true})
 return okay
end
local function finish(reason)
 if done then return end;done=true
 if basiliskObserver then basiliskObserver.Close(reason)end
 if ledger then ledger.Close();if GG.Recoil40KStompaWeaponWitness==ledger then GG.Recoil40KStompaWeaponWitness=nil end end
 clear(owned);emit('complete',{reason=reason,cases=index,frame=Spring.GetGameFrame(),paidAcceptance=false,visualAcceptance=false})
end
local function legal(name,x,z)
 local d=UnitDefNames[name]
 return d and x>128 and z>128 and x<Game.mapSizeX-128 and z<Game.mapSizeZ-128
  and Spring.GetGroundHeight(x,z)>0 and Spring.TestMoveOrder(d.id,x,Spring.GetGroundHeight(x,z),z,0,0,0,true,true,false)
end
local function spawn(name,x,z,t)
 if not legal(name,x,z)then emit('site_refused',{name=name,x=x,z=z});return end
 local id=Spring.CreateUnit(name,x,Spring.GetGroundHeight(x,z),z,0,t)
 if id then owned[#owned+1]=id;ownership[id]={team=t,def=UnitDefNames[name].id};if not hold(id)then emit('hold_refused',{id=id});return end;emit('birth',{name=name,id=id,team=t,x=x,z=z,unpaid=true})end
 return id
end
local function lane()
 for x=768,Game.mapSizeX-768,128 do for z=768,Game.mapSizeZ-768,128 do
  local h=Spring.GetGroundHeight(x,z);local okay=h>0
  for _,site in ipairs(M.Sites(x,z))do
   if math.abs(h-Spring.GetGroundHeight(site.x,site.z))>3 or not legal(site.name,site.x,site.z)then okay=false;break end
  end
  -- Called after starter births, never while the engine still has an empty world.
  if Spring.GetFeaturesInRectangle and #Spring.GetFeaturesInRectangle(x-650,z-650,x+650,z+650)>0 then okay=false end
  if Spring.GetUnitsInRectangle and #Spring.GetUnitsInRectangle(x-650,z-650,x+650,z+650)>0 then okay=false end
  if okay then emit('lane_selected',{x=x,z=z,frame=Spring.GetGameFrame(),testedSites=#M.Sites(x,z)});return x,z end
 end end
end
local function fireCase(f)
 local case=M.Cases[index];local x,_,z=Spring.GetUnitPosition(actor)
 local tx,tz,sx,sz=M.TargetSites(case,ax,az)
 local target=spawn('imp_russ',tx,tz,enemy);if not target then finish('primary_birth_refused');return end;targets={target}
 local secondary=spawn('imp_guardsman',sx,sz,enemy)
 if not secondary then finish('secondary_birth_refused');return end;targets[#targets+1]=secondary
 ledger.Begin(case,target,secondary);stage='fire';start=f
 local permit=Spring.GetUnitRulesParam(actor,'40k_validation_mount')
 if permit~=nil then finish('foreign_mount_selection_detected');return end
 if not hold(actor)then finish('actor_hold_refused');return end
 -- A player-issued attack works in native hold-fire and prevents auto-acquisition.
 order(actor,CMD.ATTACK,{target})
 emit('case_begin',{case=case.name,frame=f,actor=actor,target=target,secondary=secondary,distance=case.distance,actualDistance=math.sqrt((tx-x)^2+(tz-z)^2),heading=Spring.GetUnitHeading(actor),actorPosition={x,z},targetPosition={tx,tz},secondaryPosition={sx,sz},bothNativeMounts=true,normalAimBranch=true})
end
local function nextCase(f)
 clear(targets);targets={};index=index+1
 if index>#M.Cases then index=#M.Cases;stage='basilisk';start=f;if basiliskObserver then basiliskObserver.Begin(f)end;emit('basilisk_view',{id=basilisk,frame=f,seconds=40,actions='idle_move_stop_ground_fire_return',visualAcceptance=false});return end
 if M.Cases[index].move then
  stage='move';start=f;order(actor,CMD.MOVE,{ax+96,Spring.GetGroundHeight(ax+96,az),az})
  emit('move_begin',{id=actor,frame=f,goal={ax+96,az}})
 else fireCase(f)end
end
local function setupScene(f)
 if GG.Recoil40KStompaWeaponWitness then finish('observer_already_owned');return end
 if GG.Recoil40KResearch then finish('paid_controller_must_be_disabled');return end
 local ud=UnitDefs[UnitDefNames.imp_dreadnought_hellfire.id]
 ax,az=lane();if not ax then finish('clear_flat_lane_missing');return end
 actor=spawn('imp_dreadnought_hellfire',ax,az,team);basilisk=spawn('imp_basilisk',ax-220,az-120,team)
 if not actor or not basilisk then finish('actor_birth_refused');return end
 local map=Spring.GetUnitPieceMap(actor);local mounts={}
 for slot=1,2 do
  local entry=ud.weapons[slot];local wid=entry.weaponDef or entry.weaponDefID;local w=WeaponDefs[wid];local p=w.customParams or{};local pieces={};local count=0
  if tostring(p.source_aimfrom_muzzle)~='1'then finish('normal_muzzle_property_missing');return end
  for name in (p.source_muzzle_pair or p.source_muzzle or ''):gmatch('[^,;]+')do
   if not map[name]then finish('source_muzzle_missing');return end;pieces[map[name]]=true;count=count+1
  end
  if slot==2 and(count~=4 or(w.salvoSize or w.salvosize)~=4 or math.abs(w.reload-2)>.001)then finish('native_salvo_recipe_mismatch');return end
  mounts[slot]={weapon=wid,pieces=pieces};Script.SetWatchProjectile(wid,true);Script.SetWatchExplosion(wid,true)
  emit('mount',{slot=slot,weapon=wid,type=w.type,range=w.range,reload=w.reload,salvoSize=w.salvoSize or w.salvosize,salvoDelay=w.salvoDelay,sourceMuzzles=p.source_muzzle_pair or p.source_muzzle})
 end
 local B=VFS.Include('40k_configs/hellfire_basilisk_observer.lua')
 basiliskObserver=B.New(Spring,basilisk,UnitDefs[UnitDefNames.imp_basilisk.id],WeaponDefs,Game,
  VFS.Include('40k_configs/40k_ground_lof_observer.lua'),CMD.ATTACK,emit)
 for _,wid in ipairs(basiliskObserver.Weapons)do Script.SetWatchProjectile(wid,true);Script.SetWatchExplosion(wid,true)end
 ledger=M.Ledger(Spring,actor,mounts,emit);GG.Recoil40KStompaWeaponWitness=ledger
 emit('begin',{fixtureRevision='owned_targets_v2',actor=actor,basilisk=basilisk,frame=Spring.GetGameFrame(),sourceProgression=false,paidAcceptance=false,healthOverrides=false,scriptedProjectiles=false,scriptedDamage=false})
 stage='settle';start=Spring.GetGameFrame()
end
function gadget:Initialize()
 if Spring.GetGameFrame()>0 then finish('fresh_start_required');return end
 if GG.Recoil40KStompaWeaponWitness then finish('observer_already_owned');return end
 if GG.Recoil40KResearch then finish('paid_controller_must_be_disabled');return end
 for name in pairs(M.Roster)do if not UnitDefNames[name]then finish('definition_missing_'..name);return end end
 local ud=UnitDefs[UnitDefNames.imp_dreadnought_hellfire.id];local cp=ud.customParams or{}
 if cp.hellfire_weapon_repair~='native_pod_salvo_v1'or #ud.weapons~=2 then finish('normal_recipe_missing');return end
 local teams=Spring.GetTeamList()
 for _,a in ipairs(teams)do if a~=Spring.GetGaiaTeamID()then for _,b in ipairs(teams)do if b~=Spring.GetGaiaTeamID()and not Spring.AreTeamsAllied(a,b)then team,enemy=a,b;break end end;if team then break end end end
 if not team then finish('enemy_teams_missing');return end
 stage='await_start';start=0
end
function gadget:GameFrame(f)
 if done then return end
 if stage=='await_start'and f>=90 then setupScene(f);return end
 if not ledger then return end
 if ledger.failed then finish(ledger.failed);return end
 if not alive(actor)or not alive(basilisk)or Spring.GetUnitTeam(actor)~=team or Spring.GetUnitTeam(basilisk)~=team then finish('actor_lifecycle_changed');return end
 ledger.Tick(f);if basiliskObserver then basiliskObserver.Tick(f)end;local age=f-start
 if (stage=='fire'or stage=='drain')and f%15==0 then
  for slot=1,2 do
   local kind,_,target=Spring.GetUnitWeaponTarget(actor,slot)
   if kind==1 and target and target~=targets[1]and target~=targets[2]then
    ledger.ForeignTarget(slot,target,f);hold(actor)
    if stage=='fire'then ledger.EndFire(f);stage='drain';start=f end
   end
  end
 end
 age=f-start
 if stage=='settle'and age>=90 then nextCase(f)
 elseif stage=='move'then
  local x,_,z=Spring.GetUnitPosition(actor);local vx,_,vz=Spring.GetUnitVelocity(actor)
  if (x-(ax+96))^2+(z-az)^2<64 then if not hold(actor)then finish('move_hold_refused');return end;stage='move_settle';start=f;emit('move_arrived',{id=actor,frame=f,position={x,z},velocity={vx,vz}})
  elseif age>600 then finish('ordinary_move_timeout')end
 elseif stage=='move_settle'and age>=60 then fireCase(f)
 elseif stage=='fire'then
  if age%120==0 then for slot=1,2 do
   local px,py,pz=Spring.GetUnitWeaponVectors(actor,slot)
   local targetType,_,targetId=Spring.GetUnitWeaponTarget(actor,slot)
   emit('native_gate',{case=M.Cases[index].name,frame=f,slot=slot,canFire=Spring.GetUnitWeaponCanFire(actor,slot),muzzle={px,py,pz},ground=px and Spring.GetGroundHeight(px,pz),targetType=targetType,targetId=targetId})
  end end
  if age>=300 then
   ledger.EndFire(f);if not hold(actor)then finish('drain_hold_refused');return end
   stage='drain';start=f;emit('drain_begin',{case=M.Cases[index].name,frame=f})
  end
 elseif stage=='drain'and age>=120 then ledger.Summary();nextCase(f)
 elseif stage=='basilisk'then
  if age==180 then order(basilisk,CMD.MOVE,{ax-140,Spring.GetGroundHeight(ax-140,az-120),az-120})
  elseif age==450 then if not hold(basilisk)then finish('basilisk_hold_refused');return end;order(basilisk,CMD.ATTACK,{ax-140,Spring.GetGroundHeight(ax-140,az+280),az+280})
  elseif age==780 then if not hold(basilisk)then finish('basilisk_hold_refused');return end;order(basilisk,CMD.MOVE,{ax-220,Spring.GetGroundHeight(ax-220,az-120),az-120})
  elseif age>=1200 then finish('bounded_cases_and_visual_window_complete')end
 end
end
function gadget:ProjectileCreated(pid,owner,weapon)
 if not ledger or done then return end
 projectileOwners[pid]=(owner==actor or owner==basilisk)and owner or nil
 ledger.Projectile(pid,owner,weapon);if basiliskObserver then basiliskObserver.Projectile(pid,owner,weapon)end
end
function gadget:ProjectileDestroyed(pid)
 if not ledger or done then return end
 local owner=projectileOwners[pid];projectileOwners[pid]=nil
 if owner==actor then ledger.Deleted(pid)elseif owner==basilisk and basiliskObserver then basiliskObserver.Deleted(pid)end
end
function gadget:Explosion(weapon,x,y,z,owner,pid)if ledger and not done then ledger.Explosion(weapon,x,y,z,owner,pid);if basiliskObserver then basiliskObserver.Explosion(weapon,x,y,z,owner,pid)end end;return false end
function gadget:UnitPreDamaged(id,def,t,damage,paralyzer,weapon,pid,attacker)if ledger and not done then ledger.Pre(id,damage,paralyzer,weapon,pid,attacker)end;return damage end
function gadget:UnitDamaged(id,def,t,damage,paralyzer,weapon,pid,attacker)if ledger and not done then ledger.Damaged(id,damage,paralyzer,weapon,pid,attacker)end end
function gadget:Shutdown()finish('shutdown')end

function gadget:GetInfo()return{name='40K four ranged walkers unpaid weapons diagnostic',desc='Exact native mounts and collision, not paid production acceptance',author='Local project',layer=160,enabled=true}end
local M=VFS.Include('40k_configs/ork_ranged_weapon_fixture.lua')
if not M.Enabled(Spring.GetModOptions()or{})then return false end
if not gadgetHandler:IsSyncedCode()then
 local closeAt
 local function done(_,why)Spring.Echo('40K_ORK_RANGED_WEAPONS owned_autoclose '..tostring(why));closeAt=Spring.GetGameFrame()+90 end
 function gadget:Initialize()gadgetHandler:AddSyncAction('fortyk_ork_ranged_weapons_done',done)end
 function gadget:GameFrame(f)if closeAt and f>=closeAt then closeAt=nil;Spring.SendCommands('quitforce')end end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction('fortyk_ork_ranged_weapons_done')end
 return
end
local S=Spring;local owned={};local actor,target,ledger,mounts,team,enemy,ax,az;local variant=0;local slot=0;local terrain=false
local phase='initial';local stageStart,started,pending,lastDeathDamage
local flatScene
local direct,movingStage,moveRoute,moveLeg=nil,false,nil,0
local directMovingPassed,pairedKanMovingPassed=0,0
local flatRequested=(Spring.GetModOptions()or{}).prototype_ork_ranged_flat_scene
flatRequested=flatRequested==true or flatRequested==1 or flatRequested=='1'
local function emit(s)S.Echo('40K_ORK_RANGED_WEAPONS '..s)end
local function remove(id)if id and S.ValidUnitID(id)and not S.GetUnitIsDead(id)then S.DestroyUnit(id,false,true)end end
local function finish(reason)
 if phase=='done'then return end;phase='done';if ledger then ledger.Close()end;if GG.Recoil40KStompaWeaponWitness==ledger then GG.Recoil40KStompaWeaponWitness=nil end
 for _,id in ipairs(owned)do remove(id)end
 emit('COMPLETE '..reason..' unpaid=true paid_acceptance=false visual_animation_acceptance=false');SendToUnsynced('fortyk_ork_ranged_weapons_done',reason)
end
local function legal(d,x,z,ignore)
 if flatScene then return flatScene.Legal(d,x,z,ignore)end
 return x>160 and z>160 and x<Game.mapSizeX-160 and z<Game.mapSizeZ-160 and S.GetGroundHeight(x,z)>=0 and S.TestMoveOrder(d,x,S.GetGroundHeight(x,z),z,0,0,0,true,true,false)
end
local function spawn(key,x,z,t)
 local n=UnitDefNames[key];if not n or not legal(n.id,x,z)then return end
 local id=S.CreateUnit(key,x,S.GetGroundHeight(x,z),z,0,t)
 if id then owned[#owned+1]=id;S.GiveOrderToUnit(id,CMD.FIRE_STATE,{0},0);S.GiveOrderToUnit(id,CMD.MOVE_STATE,{0},0)end
 return id
end
local function quiet()S.SetUnitRulesParam(actor,'40k_validation_mount',0);S.GiveOrderToUnit(actor,CMD.STOP,{},0);S.GiveOrderToUnit(actor,CMD.FIRE_STATE,{0},0)end
-- Native visibility is observed, never granted. A post-spawn frame is required.
local pendingAttack,commandProbeFrame,groundAttack
local terrainCursor,terrainSearchStart,terrainAnchor,terrainPose,terrainStable=0,nil,nil,nil,0
local targetCursor,targetSearchStart,targetAnchor,targetPose,targetStable=0,nil,nil,nil,0
local function categoryWords(t)
 local keys={};for k,v in pairs(t or{})do if v then keys[#keys+1]=k end end;table.sort(keys);return table.concat(keys,',')
end
local function targetState()
 if not target or not S.ValidUnitID(target)or S.GetUnitIsDead(target)then return nil end
 local at=S.GetUnitTeam(actor);local tt=S.GetUnitTeam(target);local aa=S.GetUnitAllyTeam(actor)
 local los=S.GetUnitLosState(target,aa,false)or{}
 local td=UnitDefs[S.GetUnitDefID(target)];local ad=UnitDefs[S.GetUnitDefID(actor)]
 local hp,_,_,_,progress=S.GetUnitHealth(target)
 local transporter=S.GetUnitTransporter(target) -- Native absence returns ZERO values; bind before tostring.
 local x,y,z=S.GetUnitPosition(target);local ux,uy,uz=S.GetUnitPosition(actor)
 return{actorTeam=at,targetTeam=tt,actorAllyTeam=aa,targetAllyTeam=S.GetUnitAllyTeam(target),
  allied=S.AreTeamsAllied(at,tt),los=los.los==true,radar=los.radar==true,typed=los.typed==true,
  losBits=S.GetUnitLosState(target,aa,true),targetHP=hp,targetConstruction=progress,
  targetNeutral=S.GetUnitNeutral(target),targetCloaked=S.GetUnitIsCloaked(target),targetTransporter=tostring(transporter),
  targetX=x,targetY=y,targetZ=z,targetGround=y and S.GetGroundHeight(x,z),
  actorX=ux,actorY=uy,actorZ=uz,actorGround=uy and S.GetGroundHeight(ux,uz),
  targetCategories=categoryWords(td.modCategories),mountOnlyTargets=categoryWords(ad.weapons[slot].onlyTargets),
  actorCanAttack=ad.canAttack,targetSurface=td.modCategories and td.modCategories.surface or false,
  mountSurface=ad.weapons[slot].onlyTargets and ad.weapons[slot].onlyTargets.surface or false}
end
local function commandReceipt(label,f,returned)
 local cmd,opts,tag,param=S.GetUnitCurrentCommand(actor)
 emit('ATTACK_COMMAND '..label..' frame='..f..' actor='..actor..' target='..tostring(target)..' returned='..tostring(returned)..' command='..tostring(cmd)..' options='..tostring(opts)..' tag='..tostring(tag)..' param1='..tostring(param))
end
local function movementRoute()
 if not flatScene then return nil,'direct_movement_requires_funded_flat_scene' end
 local x,y,z=S.GetUnitPosition(actor);local tx,ty,tz=S.GetUnitPosition(target)
 local length=x and tx and math.sqrt((tx-x)^2+(tz-z)^2)
 if not length or length<1 then return nil,'direct_movement_target_coordinates' end
 local dx,dz=(tz-z)/length*80,-(tx-x)/length*80
 local route={{x+dx,S.GetGroundHeight(x+dx,z+dz),z+dz},{x-dx,S.GetGroundHeight(x-dx,z-dz),z-dz}}
 for _,p in ipairs(route)do
  if not legal(S.GetUnitDefID(actor),p[1],p[3],actor)then return nil,'direct_movement_endpoint_not_legal' end
  if (p[1]-tx)^2+(p[2]-ty)^2+(p[3]-tz)^2>=(mounts[slot].range*.8)^2 then return nil,'direct_movement_endpoint_outside_range' end
 end
 return route
end
local function moveOrder(f)
 moveLeg=moveLeg+1
 local p=moveRoute[(moveLeg-1)%2+1]
 local returned=S.GiveOrderToUnit(actor,CMD.MOVE,p,0)
 emit((direct.kind=='paired_kan'and'PAIRED_KAN_MOVE_ORDER'or'DIRECT_MOVE_ORDER')..' frame='..f..' slot='..slot..' leg='..moveLeg..' xyz='..table.concat(p,',')..' returned='..tostring(returned)..' native_auto_target=true')
end
local function issueAttack(f)
 local p=pendingAttack;if terrain then groundAttack={unpack(p)}end;pendingAttack=nil
 S.GiveOrderToUnit(actor,CMD.FIRE_STATE,{2},0)
 if movingStage then
  local why;moveRoute,why=movementRoute();moveLeg=0
  if not moveRoute then finish('INCONCLUSIVE '..why);return end
  moveOrder(f)
 else
  local returned=S.GiveOrderToUnit(actor,CMD.ATTACK,p,0)
  commandReceipt('immediate',f,returned);commandProbeFrame=f+1
 end
 stageStart=f;phase='fire'
end
-- Read existing native terrain LOS; never change sight or target state.
local function visibleTargetSite(m)
 local ad=UnitDefs[S.GetUnitDefID(actor)];local td=UnitDefNames.imp_russ
 local x,y,z=unpack(targetAnchor or{S.GetUnitPosition(actor)});local ally=S.GetUnitAllyTeam(actor)
 local sight=ad.sightDistance or ad.losRadius
 if not x or type(sight)~='number'or sight<=0 then return end
 local clearance=(math.max(ad.xsize,ad.zsize)+math.max(td.xsize,td.zsize))*4+16
 local radius=math.min(m.range*.55,sight*.75);local scales={1,.85,.7}
 -- Each of the 48 fixed candidates is consumed once per mount, including
 -- failed post-birth native preflights. Never reselect the first blocked site.
 while targetCursor<48 do
  local index=targetCursor;targetCursor=targetCursor+1
  local r=radius*scales[math.floor(index/16)+1];local direction=index%16
  if r>=clearance then
   local a=direction*math.pi/8;local tx,tz=x+r*math.sin(a),z+r*math.cos(a);local ty=S.GetGroundHeight(tx,tz)
   if legal(td.id,tx,tz)and(tx-x)^2+(ty-y)^2+(tz-z)^2<(m.range*.8)^2 and S.IsPosInLos(tx,ty,tz,ally)then return tx,tz end
  end
 end
end
-- Select an ordinary collision-tested, visible ground point for this actual mount.
-- Native TestRange owns height-dependent range; authored artillery minima remain intact.
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
-- TryTarget uses the true native default AimFrom. Five-argument LOF instead
-- means supplied SOURCE to zero target; only eight-argument positional LOF is used.
local function groundPreflight(p)
 if type(p)~='table'or not finite(p[1])or not finite(p[2])or not finite(p[3])then return false,'ground_coordinates_missing' end
 local x,y,z=unpack(p);local td=UnitDefNames.imp_russ
 if not td or not legal(td.id,x,z)or math.abs(y-S.GetGroundHeight(x,z))>.5 then return false,'ground_pose_not_legal' end
 local probes={
  {'ground_pos_los',S.IsPosInLos(x,y,z,S.GetUnitAllyTeam(actor))},
  {'ground_native_target',S.GetUnitWeaponTestTarget(actor,slot,x,y,z)},
  {'ground_native_range',S.GetUnitWeaponTestRange(actor,slot,x,y,z)},
  {'ground_native_default_TryTarget',S.GetUnitWeaponTryTarget(actor,slot,x,y,z)},
 }
 for _,p in ipairs(probes)do if p[2]~=true then return false,p[1]..'_not_true_'..type(p[2])..'_'..tostring(p[2])end end
 local mx,my,mz=S.GetUnitWeaponVectors(actor,slot)
 if not finite(mx)or not finite(my)or not finite(mz)then return false,'ground_native_muzzle_missing' end
 local lof=S.GetUnitWeaponHaveFreeLineOfFire(actor,slot,mx,my,mz,x,y,z)
 if lof~=true then return false,'ground_native_muzzle_lof_not_true_'..type(lof)..'_'..tostring(lof)end
 return true,'native_ground_target_range_default_TryTarget_muzzle_lof'
end
-- Read-only refusal witness. No new admission gate or command is issued.
local function groundRefusalReadback(p,why)
 if why~='ground_native_default_TryTarget_not_true_boolean_false' then return end
 local ok,mx,my,mz=pcall(S.GetUnitWeaponVectors,actor,slot)
 if not ok or not finite(mx)or not finite(my)or not finite(mz)then
  emit('TERRAIN_REFUSAL_READBACK candidate='..terrainCursor..' native_muzzle=UNAVAILABLE unchanged_gates=true');return
 end
 local good,lof=pcall(S.GetUnitWeaponHaveFreeLineOfFire,actor,slot,mx,my,mz,p[1],p[2],p[3])
 local goodHeight,height=pcall(S.GetGroundHeight,mx,mz)
 local clearance=goodHeight and finite(height)and tostring(my-height)or'UNAVAILABLE'
 local result=good and type(lof)=='boolean'and tostring(lof)or'UNAVAILABLE'
 emit('TERRAIN_REFUSAL_READBACK candidate='..terrainCursor..' actor='..actor..' slot='..slot..' xyz='..table.concat(p,',')..' native_muzzle='..mx..','..my..','..mz..' muzzle_ground_clearance='..clearance..' explicit_8arg_muzzle_lof='..result..' default_TryTarget=false unchanged_gates=true diagnostic_only=true')
end
local function visibleTerrainSite(m)
 local ad=UnitDefs[S.GetUnitDefID(actor)];local td=UnitDefNames.imp_russ
 local x,y,z=unpack(terrainAnchor or{S.GetUnitPosition(actor)});local ally=S.GetUnitAllyTeam(actor)
 local sight=ad and(ad.sightDistance or ad.losRadius)
 if not x or not td or type(sight)~='number'or sight<=0 then return end
 local w=WeaponDefs[m.weapon];local cp=w and w.customParams or{}
 local minimum=tonumber(cp.source_minrange)or 0
 local clearance=(math.max(ad.xsize,ad.zsize)+math.max(td.xsize,td.zsize))*4+16
 local radius=math.min(m.range*.55,sight*.75);local scales={.7,.85,1}
 while terrainCursor<48 do
  local index=terrainCursor;terrainCursor=terrainCursor+1
  local r=radius*scales[math.floor(index/16)+1];local direction=index%16
  if r>=clearance and r>=minimum+16 then
   local a=direction*math.pi/8;local tx,tz=x+r*math.sin(a),z+r*math.cos(a);local ty=S.GetGroundHeight(tx,tz)
   local ok,why=groundPreflight({tx,ty,tz})
   if ok then return tx,tz end
   groundRefusalReadback({tx,ty,tz},why)
   emit('TERRAIN_PREFLIGHT_REFUSAL candidate='..terrainCursor..' actor='..actor..' slot='..slot..' xyz='..tx..','..ty..','..tz..' reason='..why)
  else emit('TERRAIN_PREFLIGHT_REFUSAL candidate='..terrainCursor..' actor='..actor..' slot='..slot..' reason=ground_clearance_or_authored_minrange')end
 end
end
local function beginStage(f,tx,tz)
 ledger.Begin(slot,target,terrain,movingStage);S.SetUnitRulesParam(actor,'40k_validation_mount',slot)
 pendingAttack=terrain and{tx,S.GetGroundHeight(tx,tz),tz}or{target}
 stageStart=f;phase='settle';emit('STAGE actor='..actor..' slot='..slot..' terrain='..tostring(terrain)..' family='..mounts[slot].family..' moving='..tostring(movingStage)..' unpaid=true natural_visibility_settle=true')
end
local function nextStage(f)
 remove(target);target=nil
 if slot>=#mounts and terrain then
  quiet();ledger.Close();if GG.Recoil40KStompaWeaponWitness==ledger then GG.Recoil40KStompaWeaponWitness=nil end;phase='death';stageStart=f;lastDeathDamage=nil
  target=spawn('imp_russ',ax+160,az+180,enemy);if not target then finish('INCONCLUSIVE native_enemy_site');return end
  S.GiveOrderToUnit(target,CMD.FIRE_STATE,{2},0);S.GiveOrderToUnit(target,CMD.ATTACK,{actor},0);emit('ENEMY_NATIVE_DEATH_TEST actor='..actor..' enemy='..target..' scripted_damage=false');return
 end
 if direct and not terrain and not movingStage then movingStage=true
 else movingStage=false;if terrain then slot=slot+1;terrain=false else terrain=true end end
 moveRoute=nil;moveLeg=0
 if not terrain then
  stageStart=f;targetSearchStart=f;targetCursor=0;targetAnchor={S.GetUnitPosition(actor)};targetPose=nil;targetStable=0;phase='target_site';emit('TARGET_SITE_WAIT actor='..actor..' slot='..slot..' native_pos_los_required=true');return
 end
 terrainCursor=0;terrainSearchStart=f;terrainAnchor={S.GetUnitPosition(actor)};terrainPose=nil;terrainStable=0;groundAttack=nil;phase='terrain_site'

end
-- Observe actual settled native target pose/range/type/LOF; no aim/weapon gate
-- is overridden. AngleGood remains the real Shot admission requirement.
local function targetPreflight(state)
 local x,y,z=state.targetX,state.targetY,state.targetZ
 if type(x)~='number'or type(y)~='number'or type(z)~='number'or x~=x or y~=y or z~=z then return false,'target_position_missing' end
 if not legal(S.GetUnitDefID(target),x,z,target)or math.abs(y-S.GetGroundHeight(x,z))>.5 then return false,'target_pose_not_legal_ground' end
 if not(state.los or state.radar)then return false,'native_visibility' end
 if S.GetUnitWeaponTestRange(actor,slot,target)~=true then return false,'native_range' end
 if S.GetUnitWeaponTestTarget(actor,slot,target)~=true then return false,'native_target' end
 if S.GetUnitWeaponHaveFreeLineOfFire(actor,slot,target)~=true then return false,'native_default_lof' end
 local mx,my,mz=S.GetUnitWeaponVectors(actor,slot)
 if type(mx)~='number'or type(my)~='number'or type(mz)~='number'or mx~=mx or my~=my or mz~=mz then return false,'native_muzzle_missing' end
 if S.GetUnitWeaponHaveFreeLineOfFire(actor,slot,mx,my,mz,target)~=true then return false,'native_muzzle_lof' end
 return true,'native_target_range_and_lof'
end
local function rejectTarget(f,reason)
 emit('TARGET_PREFLIGHT_REFUSAL candidate='..targetCursor..' actor='..actor..' slot='..slot..' reason='..reason..' unchanged_weapon_gates=true')
 remove(target);target=nil;pendingAttack=nil;targetPose=nil;targetStable=0;quiet()
 if targetCursor>=48 or f-targetSearchStart>=1800 then finish('INCONCLUSIVE no_settled_native_target_preflight');return end
 stageStart=f;phase='target_site'
end
local function nextActor(f)
 remove(actor);remove(target);target=nil;variant=variant+1
 if variant>#M.Keys and(directMovingPassed~=4 or pairedKanMovingPassed~=6)then finish('FAIL incomplete_actual_moving_mounts');return end
 if variant>#M.Keys then finish('PASS four_exact_variants_independent_mounts_native_hits_terrain_selfsplash_readback_native_death direct_v2_moving_slots='..directMovingPassed..' paired_kan_moving_slots='..pairedKanMovingPassed);return end
 local key=M.Keys[variant];local n=UnitDefNames[key];local d=n and UnitDefs[n.id];local cp=d and d.customParams or{}
 if not d or cp.animsource~=key or tostring(cp.prototype40k_ranged_variant)~='1'or cp.diagnostic~='roster'then finish('FAIL exact_scoped_runtime');return end
 if flatScene then
  local why;ax,az,why=flatScene.Choose(n.id);if not ax then finish('INCONCLUSIVE '..tostring(why));return end
 end
 actor=spawn(key,ax,az,team);if not actor then finish('INCONCLUSIVE exact_actor_birth');return end
 local collision={S.GetUnitCollisionVolumeData(actor)};for i,v in ipairs(collision)do collision[i]=tostring(v)end;emit('ACTOR '..key..' id='..actor..' collision='..table.concat(collision,','))
 local pieces=S.GetUnitPieceMap(actor);mounts={};direct=nil;movingStage=false
 local pairedKan=key~='ork_dread_ranged_fourarm'
 if pairedKan and(cp.source_variant_recipe~='project_kan_paired_torso_v2'or cp.source_torso_aimpiece~='project_kan_hip_yaw')then finish('FAIL paired_kan_torso_interface_missing');return end
 if pairedKan or(key=='ork_dread_ranged_fourarm'and cp.source_variant_recipe=='project_dread_direct_torso_v2')then
  local hip,body=pieces[cp.source_torso_aimpiece],pieces[cp.source_torso_bodypiece]
  if not hip or not body or cp.source_torso_aim_mode~='shared_heading_local_residual'then finish('FAIL direct_torso_interface_missing');return end
  direct={hip=hip,body=body,pivots={},moveCommand=CMD.MOVE,kind=pairedKan and'paired_kan'or'direct_dread'}
  local x,y,z,mx,my,mz=S.GetUnitPosition(actor,true)
  emit((pairedKan and'PAIRED_KAN_BODY'or'DIRECT_BODY')..' actor='..actor..' model_sha='..tostring(cp.source_ranged_model_sha256)..' origin='..tostring(x)..','..tostring(y)..','..tostring(z)..' midpoint='..tostring(mx)..','..tostring(my)..','..tostring(mz)..' selection_readback=not_exposed_by_pinned_API')
 end
 for n,entry in ipairs(d.weapons)do
  local w=WeaponDefs[entry.weaponDef];local c=w and w.customParams or{};local allowed={};local list=c.source_muzzle_pair or c.source_muzzle
  if not w or not list or not c.source_variant_assembly or not pieces[c.source_aimpiece]or not pieces[c.source_pitchpiece]or(w.type~='Cannon'and w.type~='LaserCannon'and w.type~='MissileLauncher')then finish('FAIL exact_visible_mount');return end
  for name in list:gmatch('[^,]+')do if not pieces[name]then finish('FAIL actual_muzzle_piece');return end;allowed[pieces[name]]=true end
  mounts[n]={weapon=entry.weaponDef,pieces=allowed,range=w.range,reload=w.reload,salvo=w.salvoSize or 1,speed=S.GetUnitWeaponState(actor,n,'projectileSpeed')or w.projectilespeed or 20,family=c.source_fx_family}
  if direct then direct.pivots[n]=pieces[c.source_aimpiece]end
  Script.SetWatchProjectile(entry.weaponDef,true);Script.SetWatchExplosion(entry.weaponDef,true)
 end
 if #mounts~=(variant==4 and 4 or 2)then finish('FAIL phantom_or_missing_weapon');return end
 ledger=M.New(S,actor,team,mounts,emit,direct);GG.Recoil40KStompaWeaponWitness=ledger;slot=0;terrain=true;nextStage(f)
end

-- Read-only bounded firing gates; native callbacks/controllers remain untouched.
local fireProbeCounts={}
local function fireProbe(f)
 local key=tostring(actor)..':'..slot..':'..tostring(terrain)..':'..tostring(movingStage)
 if f%90~=0 or(fireProbeCounts[key]or 0)>=20 then return end
 fireProbeCounts[key]=(fireProbeCounts[key]or 0)+1
 local function value(v)
  if type(v)=='table'then return tostring(v[1])..','..tostring(v[2])..','..tostring(v[3])end
  return tostring(v)
 end
 local a={};local function add(k,v)a[#a+1]=k..'='..value(v)end
 add('frame',f);add('actor',actor);add('slot',slot);add('terrain',terrain)
 add('phase',phase)
 local state=targetState();if state then local keys={};for k in pairs(state)do keys[#keys+1]=k end;table.sort(keys);for _,k in ipairs(keys)do add(k,state[k])end end
 local ag,ready,rf,salvo,stock=S.GetUnitWeaponState(actor,slot)
 add('angleGood',ag);add('reloadReady',ready);add('reloadFrame',rf);add('salvoLeft',salvo);add('stockpile',stock)
 add('canFire',S.GetUnitWeaponCanFire(actor,slot,false,false,false))
 add('canIgnoreAngle',S.GetUnitWeaponCanFire(actor,slot,true,false,false))
 add('canIgnoreAngleTargetDirection',S.GetUnitWeaponCanFire(actor,slot,true,true,true))
 local kind,user,payload=S.GetUnitWeaponTarget(actor,slot);add('targetType',kind);add('userTarget',user);add('targetPayload',payload)
 local cmd,opts,tag,param=S.GetUnitCurrentCommand(actor);add('command',cmd);add('commandOptions',opts);add('commandTag',tag);add('commandParam1',param)
 add('mountPermit',S.GetUnitRulesParam(actor,'40k_validation_mount'));add('construction',select(5,S.GetUnitHealth(actor)))
 local mx,my,mz,dx,dy,dz=S.GetUnitWeaponVectors(actor,slot)
 add('muzzle',{mx,my,mz});add('nativeDirection',{dx,dy,dz})
 local pieceID=ledger and ledger.query and ledger.query.piece
 if pieceID then
  local px,py,pz,pdx,pdy,pdz=S.GetUnitPiecePosDir(actor,pieceID)
  add('queriedPiece',pieceID);add('currentPieceEmissionPos',{px,py,pz});add('currentPieceEmissionDir',{pdx,pdy,pdz})
 end
 if type(mx)=='number'and type(my)=='number'and type(mz)=='number'then add('muzzleGroundClearance',my-S.GetGroundHeight(mx,mz))end
 if target and S.ValidUnitID(target)and not S.GetUnitIsDead(target)then
  add('expectedTarget',target);add('testTarget',S.GetUnitWeaponTestTarget(actor,slot,target));add('testRange',S.GetUnitWeaponTestRange(actor,slot,target))
  add('freeLOFDefault',S.GetUnitWeaponHaveFreeLineOfFire(actor,slot,target))
  if type(mx)=='number'and type(my)=='number'and type(mz)=='number'then add('freeLOFMuzzle',S.GetUnitWeaponHaveFreeLineOfFire(actor,slot,mx,my,mz,target))end
 elseif terrain and type(groundAttack or pendingAttack)=='table'then
  local p=groundAttack or pendingAttack;add('pendingGround',p)
  add('groundPosLos',S.IsPosInLos(p[1],p[2],p[3],S.GetUnitAllyTeam(actor)))
  add('testTarget',S.GetUnitWeaponTestTarget(actor,slot,p[1],p[2],p[3]));add('testRange',S.GetUnitWeaponTestRange(actor,slot,p[1],p[2],p[3]))
  add('defaultTryTarget',S.GetUnitWeaponTryTarget(actor,slot,p[1],p[2],p[3]))
  if finite(mx)and finite(my)and finite(mz)then add('freeLOFMuzzle',S.GetUnitWeaponHaveFreeLineOfFire(actor,slot,mx,my,mz,p[1],p[2],p[3]))end
 end
 local w=mounts[slot]and WeaponDefs[mounts[slot].weapon];local owner=S.GetUnitTeam(actor)
 add('teamMetal',S.GetTeamResources(owner,'metal'));add('teamEnergy',S.GetTeamResources(owner,'energy'))
 add('weaponMetalCost',w and w.metalCost);add('weaponEnergyCost',w and w.energyCost)
 emit('FIRE_GATES '..table.concat(a,' '))
end

function gadget:GameFrame(f)
 if phase=='done'then return end
 if commandProbeFrame and f>=commandProbeFrame then commandProbeFrame=nil;commandReceipt('next_frame',f)end
 if not started then
  started=f;local opts=S.GetModOptions()or{}
  for k,v in pairs(opts)do if k:match('^prototype_.*fixture$')and k~='prototype_ork_ranged_weapon_fixture'and(v==true or v==1 or v=='1')then finish('FAIL conflicting_fixture');return end end
  if GG.Recoil40KStompaWeaponWitness then finish('FAIL existing_weapon_witness');return end
  for _,a in ipairs(S.GetTeamList())do if a~=S.GetGaiaTeamID()then for _,b in ipairs(S.GetTeamList())do if b~=S.GetGaiaTeamID()and not S.AreTeamsAllied(a,b)then team,enemy=a,b;break end end;if team then break end end end
  if not team then finish('INCONCLUSIVE enemy_teams_required');return end
  local n=UnitDefNames[M.Keys[1]];local t=UnitDefNames.imp_russ;if not n or not t then finish('FAIL actual_definitions');return end
  if flatRequested then
   local why;flatScene,why=VFS.Include('40k_configs/ranged_flat_native_scene.lua').New(S,UnitDefs,WeaponDefs,UnitDefNames,Game,M.Keys,emit)
   if not flatScene then finish('INCONCLUSIVE '..tostring(why));return end
   emit('SCENE_POLICY exclusive_flat_map=true funded=true economy_acceptance=false unchanged_native_weapon_gates=true')
  else
   for x=math.floor(Game.mapSizeX*.25),math.floor(Game.mapSizeX*.75),256 do for z=math.floor(Game.mapSizeZ*.25),math.floor(Game.mapSizeZ*.60),256 do if legal(n.id,x,z)and legal(t.id,x+160,z+256)then ax,az=x,z;break end end;if ax then break end end
   if not ax then finish('INCONCLUSIVE finite_native_scene');return end
  end
  nextActor(f);return
 end
 if f-started>900*30 then finish('INCONCLUSIVE overall_native_timeout');return end
 if phase=='death'then
  if S.GetUnitIsDead(actor)then
   if not lastDeathDamage or lastDeathDamage.attacker~=target or lastDeathDamage.damage<=0 then finish('FAIL native_enemy_death_receipt');return end
   emit('NATIVE_DEATH actor='..actor..' weapon='..lastDeathDamage.weapon..' enemy='..target);pending=f+30;phase='nextactor'
  elseif f-stageStart>1800 then finish('INCONCLUSIVE native_death_timeout')end
 elseif phase=='nextactor'then if f>=pending then pending=nil;nextActor(f)end
 elseif phase=='target_site'then
  -- A new actor must first contribute its ordinary LOS during native updates.
  if f>stageStart and f%15==0 then
   local tx,tz=visibleTargetSite(mounts[slot])
   if tx then
    target=spawn('imp_russ',tx,tz,enemy);if not target then finish('FAIL exact_target_birth');return end
    targetPose=nil;targetStable=0
    emit('TARGET_SITE_SELECTED candidate='..targetCursor..' x='..tx..' ground='..S.GetGroundHeight(tx,tz)..' z='..tz..' native_pos_los=true sight='..tostring(UnitDefs[S.GetUnitDefID(actor)].sightDistance))
    beginStage(f,tx,tz)
   end
  end
  if phase=='target_site'and(targetCursor>=48 or f-targetSearchStart>=1800)then finish('INCONCLUSIVE no_settled_native_target_preflight')end
 elseif phase=='terrain_site'then
  if terrainCursor>=48 or f-terrainSearchStart>=1800 then finish('INCONCLUSIVE no_admitted_native_ground_site');return end
  local tx,tz=visibleTerrainSite(mounts[slot])
  if not tx then finish('INCONCLUSIVE no_admitted_native_ground_site');return end
  terrainPose=nil;terrainStable=0
  emit('TERRAIN_SITE_SELECTED x='..tx..' ground='..S.GetGroundHeight(tx,tz)..' z='..tz..' native_collision=true native_pos_los=true native_mount_range=true native_target=true native_default_TryTarget=true native_muzzle_lof=true candidate='..terrainCursor)
  beginStage(f,tx,tz)
 elseif phase=='settle'then
  fireProbe(f)
  if terrain then
   local x,y,z=S.GetUnitPosition(actor)
   if terrainPose and finite(x)and finite(y)and finite(z)and math.abs(x-terrainPose[1])<=.125 and math.abs(y-terrainPose[2])<=.125 and math.abs(z-terrainPose[3])<=.125 then terrainStable=terrainStable+1 else terrainStable=0 end
   terrainPose=finite(x)and finite(y)and finite(z)and{x,y,z}or nil
   if terrainStable>=2 then
    local ok,why=groundPreflight(pendingAttack)
    if ok then emit('TERRAIN_PREFLIGHT_ACCEPT candidate='..terrainCursor..' settled_frames='..terrainStable..' native_default_TryTarget=true native_muzzle_lof=true');issueAttack(f)
    else emit('TERRAIN_PREFLIGHT_REFUSAL candidate='..terrainCursor..' actor='..actor..' slot='..slot..' reason='..why);pendingAttack=nil;phase='terrain_site' end
   elseif f-stageStart>=30 then emit('TERRAIN_PREFLIGHT_REFUSAL candidate='..terrainCursor..' actor='..actor..' slot='..slot..' reason=ground_actor_pose_unsettled');pendingAttack=nil;phase='terrain_site'end
   if f-terrainSearchStart>=1800 then finish('INCONCLUSIVE no_admitted_native_ground_site')end
   return
  end
  local state=targetState()
  if not state then finish('FAIL settled_target_missing');return end
  if state.allied or state.targetTeam~=enemy then finish('FAIL settled_enemy_team');return end
  if f>stageStart then
   local x,y,z=state.targetX,state.targetY,state.targetZ
   if targetPose and x and y and z and math.abs(x-targetPose[1])<=.125 and math.abs(y-targetPose[2])<=.125 and math.abs(z-targetPose[3])<=.125 then targetStable=targetStable+1 else targetStable=0 end
   targetPose=x and y and z and{x,y,z}or nil
   if targetStable>=2 and state.targetConstruction==1 then
    local accepted,reason=targetPreflight(state)
    if accepted then
     emit('TARGET_PREFLIGHT_ACCEPT candidate='..targetCursor..' actor='..actor..' slot='..slot..' target='..target..' xyz='..x..','..y..','..z..' native_range=true native_target=true native_default_lof=true native_muzzle_lof=true settled_frames='..targetStable)
     issueAttack(f)
    else rejectTarget(f,reason)end
   elseif f-stageStart>=30 or f-targetSearchStart>=1800 then rejectTarget(f,'target_pose_or_construction_unsettled')end
  end
 elseif phase=='fire'then
  fireProbe(f)
  if movingStage and f%15==0 then
   local p=moveRoute[(moveLeg-1)%2+1];local x,y,z=S.GetUnitPosition(actor)
   if x and(x-p[1])^2+(z-p[3])^2<16^2 and moveLeg<20 then moveOrder(f)end
  end
  if S.GetUnitIsDead(actor)then finish('FAIL actor_died_during_mount_test');return end
  if ledger.failed then finish('FAIL '..ledger.failed);return end
  if not terrain and not S.GetUnitIsDead(target)then
   local state=targetState()
   if state and not(state.los or state.radar)then
    emit('TARGET_VISIBILITY_LOST actor='..actor..' slot='..slot..' target='..target..' frame='..f..' shots='..ledger.row.shots..' unchanged_weapon_gates=true')
    finish('INCONCLUSIVE native_target_visibility_lost');return
   end
  end
  if ledger.Ready()and f-stageStart>=60 then
   local actorHP=S.GetUnitHealth(actor)
   if movingStage then
    if direct.kind=='paired_kan'then pairedKanMovingPassed=pairedKanMovingPassed+1 else directMovingPassed=directMovingPassed+1 end
    emit((direct.kind=='paired_kan'and'PAIRED_KAN_MOVING_STAGE_PASS'or'DIRECT_MOVING_STAGE_PASS')..' actor='..actor..' slot='..slot..' moving=true two_moving_damage_cycles=true')
   end
   emit('READBACK actorHP='..tostring(actorHP)..' selfDamage='..ledger.row.selfDamage..' ground='..tostring(terrain)..' zero_not_immunity_claim=true')
   quiet();pending=f+150;phase='drain'
  elseif f-stageStart>1800 then finish('INCONCLUSIVE mount_timeout_'..variant..'_'..slot..'_'..tostring(terrain))end
 elseif phase=='drain'then if ledger.failed then finish('FAIL '..ledger.failed);return end;if f>=pending then pending=nil;nextStage(f)end end
end
function gadget:ProjectileCreated(pid,owner,wd)if ledger and phase~='death'and phase~='nextactor'then ledger.Projectile(pid,owner,wd)end end
function gadget:UnitDamaged(id,def,t,damage,para,wd,pid,attacker)
 if phase=='death'and id==actor then lastDeathDamage={attacker=attacker,weapon=wd,damage=damage};return end
 if ledger then ledger.Damaged(id,damage,para,wd,pid,attacker)end
end
function gadget:Explosion(wd,x,y,z,owner,pid)if ledger then ledger.Explosion(wd,x,y,z,owner,pid)end;return false end
function gadget:Shutdown()finish('shutdown_not_acceptance')end

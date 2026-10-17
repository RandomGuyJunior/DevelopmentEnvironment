-- Default-off, directly spawned model/weapon diagnostic. Never ordinary production.
local M={Option='prototype_ork_goh_native_fixture'}
local actors={
 warbike={key='ork_warbike_crewed',label='EVZ_Ork_warbike',script='40k_ork_warbike_crewed.lua',count=2,metal=45,
  motion={'bike006_wheelfront','bike011_wheelback'},fixed='bike032_driver',
  muzzles={{'bike023_barrel_l00'},{'bike030_barrel_r00'}}},
 morkanaut={key='ork_morkanaut',label='evz_morkanaut',script='40k_morkanaut.lua',count=3,metal=750,
  motion={'mork031_foot_l','mork036_foot_r'},fixed='mork026_pelvis',
  muzzles={{'mork084_fxlightmegablasta3'},{'mork112_fxlightmegablasta1'},
   {'mork_rocket_muzzle_1','mork_rocket_muzzle_2','mork_rocket_muzzle_3','mork_rocket_muzzle_4'}}},
}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function enabled(v)return v==true or v==1 or v=='1'end
local function path(v,prefix)return tostring(v or''):gsub('\\','/'):gsub('^'..prefix..'/','')end
function M.Registration(key,options)
 options=options or{}
 if not enabled(options[M.Option])then return false end
 assert(options.prototype_diagnostic=='normal'and(options.prototype_source_acceptance==nil or options.prototype_source_acceptance=='')
  and enabled(options.prototype_source_progression)and enabled(options.prototype_development_playtest),
  'Owned GOH registration requires normal source pipeline')
 for k,value in pairs(options)do
  if enabled(value)and k~=M.Option and(k:match('_fixture$')or k:match('benchmark')or k:match('probe')or k=='prototype_burna_flame_combat')then error('Conflicting diagnostic '..k)end
 end
 if enabled(options.prototype_source_bounds_capture)then
  assert(options.prototype_ork_goh_native_actor=='','Bounds-only GOH registration requires empty actor; no actor fixture')
  return key=='ork_warbike_crewed'or key=='ork_morkanaut'
 end
 local actor=actors[options.prototype_ork_goh_native_actor]
 assert(actor,'Exact selected owned GOH native actor required')
 return actor.key==key
end
function M.Selected(options)
 options=options or{}
 return enabled(options[M.Option])and actors[options.prototype_ork_goh_native_actor]or nil
end
function M.Validate(D,N,W,options)
 local a=M.Selected(options);assert(a,'Explicit one-actor GOH fixture required')
 assert(options.prototype_diagnostic=='normal'and not enabled(options.prototype_source_bounds_capture)and options.prototype_source_acceptance==''
  and enabled(options.prototype_source_progression)and enabled(options.prototype_development_playtest)
  and tonumber(options.prototype_test_speed or 1)==1,'Isolated normal-source normal-clock diagnostic required')
 for key,value in pairs(options)do
  if enabled(value)and key~=M.Option and(key:match('_fixture$')or key:match('benchmark')or key:match('probe')or key=='prototype_burna_flame_combat')then error('Conflicting diagnostic '..key)end
 end
 local n=N[a.key];local target=N.ork_deff_dread;assert(n and target,'Exact actor and genuine native Dread target required')
 local d,t=D[n.id],D[target.id];local cp=d and d.customParams or{}
 assert(d and cp.source_entity==a.label and cp.animsource==a.key and path(d.modelname,'objects3d')==a.key..'.glb'
  and path(d.scriptName,'scripts')==a.script and d.canMove==true and d.canAttack==true and not d.canFly and not d.isBuilder,'Exact genuine GOH native actor required')
 assert(t and finite(t.health)and t.health>1360 and(t.customParams or{}).animsource=='ork_deff_dread','Real unmodified hostile Dread required')
 assert(#(d.weapons or{})==(a.count==2 and 2 or 5),'Exact visible native weapon count required')
 if a.key=='ork_morkanaut'then
  local field=W[d.weapons[5].weaponDef]
  assert(cp.source_native_kff=='native_plasma_shield_v1'and field and field.type=='Shield'
   and(field.customParams or{}).source_field_device=='mork027_kustom_force_field','Actual passive native KFF required')
 end
 local out={actor=n.id,target=target.id,spec=a,weapons={}}
 for slot=1,a.count do
  local wid=d.weapons[slot].weaponDef;local w=W[wid]
  assert(w and(w.type=='Cannon'or w.type=='MissileLauncher')and finite(w.range)and w.range>100,'Actual native ranged mount required')
  assert((w.customParams or{}).source_actor==a.label,'Exact GOH weapon owner required')
  out.weapons[wid]=slot
 end
 return out
end
function M.New(S,D,N,W,F,G,Script,Game,CMD,options,emit)
 local C={phase='initial',owned={},initial={},projectiles={},hits={},movingShots={},motionChanged={},combatMotion={},previousMatrix={}}
 local function log(event,...)
  local a={...};a[#a+1]='direct_spawn_diagnostic=true';a[#a+1]='ordinary_accepted=false'
  local hasFrame=false;for _,v in ipairs(a)do if tostring(v):match('^frame=')then hasFrame=true end end
  if not hasFrame then a[#a+1]='frame='..S.GetGameFrame()end
  a[#a+1]='visual_accepted=false';a[#a+1]='reclaim_accepted=false';emit(event,unpack(a))
 end
 local function live(id,def,team)
  if not id or not S.ValidUnitID(id)or S.GetUnitIsDead(id)or S.GetUnitDefID(id)~=def or S.GetUnitTeam(id)~=team then return false end
  local hp,_,_,_,built=S.GetUnitHealth(id);return finite(hp)and hp>0 and built==1
 end
 local function finish(result)
  if C.result then return C.result end
  for id,row in pairs(C.initial)do
   if not live(id,row.def,row.team)then result='FAIL original_actor_lost_or_transferred'end
   log('INITIAL_PRESERVED','actor='..id,'def='..row.def,'team='..row.team,'alive='..tostring(live(id,row.def,row.team)))
  end
  C.result=result;C.phase='done';log('COMPLETE',result,'frame='..S.GetGameFrame());return result
 end
 local function fail(reason)return finish('FAIL '..reason)end
 local function sample(frame)
  local vx,_,vz=S.GetUnitVelocity(C.actor);if not finite(vx)or not finite(vz)then return fail('native_velocity_absent')end
  local speed=math.sqrt(vx*vx+vz*vz)*30
  if speed<1 then return end
  for _,name in ipairs(C.route.spec.motion)do
   local m={S.GetUnitPieceMatrix(C.actor,C.pieces[name])};if #m~=16 then return fail('native_motion_matrix_absent')end
   local old=C.previousMatrix[name];local diff=0
   for i,v in ipairs(m)do if not finite(v)then return fail('native_motion_nonfinite')end;if old then diff=math.max(diff,math.abs(v-old[i]))end end
   if old and diff>.001 then
    C.motionChanged[name]=true
    if C.phase=='combat'and C.firstMovingShot then C.combatMotion[name]=true end
   end
   C.previousMatrix[name]=m
   log('MOTION','frame='..frame,'phase='..C.phase,'piece='..name,'speed='..speed,'matrix_delta='..diff,'after_moving_shot='..tostring(C.firstMovingShot~=nil))
  end
  return speed
 end
 local function site()
  -- Nine candidates, two short stock MOVE legs and one forward firing corridor.
  for _,xf in ipairs({.25,.5,.7})do for _,zf in ipairs({.25,.5,.7})do
   local x,z=Game.mapSizeX*xf,Game.mapSizeZ*zf
   if x+448<Game.mapSizeX-128 and z+704<Game.mapSizeZ-128 then
    local good=#(S.GetUnitsInRectangle(x-128,z-128,x+448,z+704)or{})==0
     and #(S.GetFeaturesInRectangle(x-128,z-128,x+448,z+704)or{})==0
    for _,r in ipairs({{x,z},{x+192,z},{x+192,z+192},{x+192,z+512},{x+192,z+368}})do
     local y=S.GetGroundHeight(r[1],r[2]);if not finite(y)or y<0 or not S.TestMoveOrder(C.route.actor,r[1],y,r[2],0,0,0,true,true,false)then good=false end
    end
    local ty=S.GetGroundHeight(x+192,z+512)
    if good and S.TestMoveOrder(C.route.target,x+192,ty,z+512,0,0,0,true,true,false)then return{x,S.GetGroundHeight(x,z),z}end
   end
  end end
 end
 function C.Step(frame)
  if C.result or C.closed then return C.result end
  if C.phase=='initial'then
   if frame==0 then return end
   if frame~=1 or Game.gameSpeed~=30 then return fail('fresh_frame1_clock30_required')end
   local ok,r=pcall(M.Validate,D,N,W,options);if not ok then return fail('contract '..tostring(r))end;C.route=r;C.started=frame
   for _,name in ipairs({'GetUnitPieceMatrix','GetUnitPieceMap','GetUnitPiecePosDir','GetUnitWeaponVectors','GetUnitWeaponState','GetProjectilePosition','GetUnitVelocity','SetUnitTarget','GetFeatureResources'})do if type(S[name])~='function'then return fail('missing_API_'..name)end end
   if not Script or type(Script.SetWatchProjectile)~='function'then return fail('missing_projectile_watch_API')end
   if S.GetGaiaTeamID()==1 or S.AreTeamsAllied(0,1)then return fail('genuine_hostile_team1_required')end
   if not G.Recoil40KResearch or not G.Recoil40KResearch.CanBuild(0,r.actor,nil,false)or not G.Recoil40KResearch.CanBuild(1,r.target,nil,false)then return fail('native_creation_gate_refused')end
   for _,id in ipairs(S.GetAllUnits()or{})do C.initial[id]={def=S.GetUnitDefID(id),team=S.GetUnitTeam(id)}end
   C.origin=site();if not C.origin then return finish('INCONCLUSIVE isolated_native_site_absent')end
   local p=C.origin;C.actor=S.CreateUnit(r.spec.key,p[1],p[2],p[3],0,0)
   if not live(C.actor,r.actor,0)or C.initial[C.actor]then return fail('exact_owned_actor_birth')end;C.owned[C.actor]={def=r.actor,team=0}
   C.pieces=S.GetUnitPieceMap(C.actor)or{}
   for _,name in ipairs(r.spec.motion)do if not C.pieces[name]then return fail('motion_piece_'..name)end end
   if not C.pieces[r.spec.fixed]then return fail('attached_body_piece')end
   for _,names in ipairs(r.spec.muzzles)do for _,name in ipairs(names)do if not C.pieces[name]then return fail('muzzle_piece_'..name)end end end
   for wid in pairs(r.weapons)do Script.SetWatchProjectile(wid,true)end;C.watching=true
   C.initialHeading=S.GetUnitHeading(C.actor);C.phase='leg1';C.stage=frame
   S.GiveOrderToUnit(C.actor,CMD.FIRE_STATE,{0},0);S.GiveOrderToUnit(C.actor,CMD.MOVE,{p[1]+192,p[2],p[3]},0)
   local count=0;for _ in pairs(C.initial)do count=count+1 end
   log('BEGIN','actor='..C.actor,'key='..r.spec.key,'def='..r.actor,'source='..r.spec.label,'initial_count='..count);return
  end
  if frame-C.started>2400 then return finish('INCONCLUSIVE bounded_timeout_'..C.phase)end
  if C.phase~='salvage'and not live(C.actor,C.route.actor,0)then return fail('actor_lost_or_transferred')end
  if C.phase=='leg1'or C.phase=='leg2'or C.phase=='combat'then
   if frame%10==0 then sample(frame);if C.result then return C.result end end
   local x,_,z=S.GetUnitPosition(C.actor);local p=C.origin
   if C.phase=='leg1'and(x-p[1]-192)^2+(z-p[3])^2<48^2 then
    local h=S.GetUnitHeading(C.actor);local delta=math.abs((h-C.initialHeading+32768)%65536-32768)
    if delta<8192 then return fail('native_turn_less_than45deg')end
    C.turn=delta;C.phase='leg2';S.GiveOrderToUnit(C.actor,CMD.MOVE,{p[1]+192,S.GetGroundHeight(p[1]+192,p[3]+192),p[3]+192},0)
    log('TURN','delta='..delta,'frame='..frame)
   elseif C.phase=='leg2'and(x-p[1]-192)^2+(z-p[3]-192)^2<48^2 then
    for _,name in ipairs(C.route.spec.motion)do if not C.motionChanged[name]then return finish('INCONCLUSIVE no_native_motion_'..name)end end
    local tx,tz=p[1]+192,p[3]+512;C.target=S.CreateUnit('ork_deff_dread',tx,S.GetGroundHeight(tx,tz),tz,0,1)
    if not live(C.target,C.route.target,1)or C.initial[C.target]then return fail('owned_target_birth')end;C.owned[C.target]={def=C.route.target,team=1}
    S.GiveOrderToUnit(C.target,CMD.FIRE_STATE,{0},0);S.GiveOrderToUnit(C.target,CMD.MOVE_STATE,{0},0)
    C.lastHP=S.GetUnitHealth(C.target);C.phase='combat';C.stage=frame
    S.GiveOrderToUnit(C.actor,CMD.FIRE_STATE,{2},0)
    S.GiveOrderToUnit(C.actor,CMD.MOVE,{tx,S.GetGroundHeight(tx,p[3]+368),p[3]+368},0)
    if S.SetUnitTarget(C.actor,C.target,false,true)~=true then return finish('INCONCLUSIVE native_target_order_refused')end
    log('COMBAT','actor='..C.actor,'target='..C.target,'initial_hp='..C.lastHP)
   elseif C.phase=='combat'then
    local complete=true;for slot=1,C.route.spec.count do if not C.hits[slot]or not C.movingShots[slot]then complete=false end end
    for _,name in ipairs(C.route.spec.motion)do if not C.combatMotion[name]then complete=false end end
    if complete then
     -- Native death callback owns the one wreck. No synthetic corpse or refund.
     C.phase='salvage';C.stage=frame;C.death={S.GetUnitPosition(C.actor)};C.beforeFeatures={}
     for _,fid in ipairs(S.GetAllFeatures()or{})do C.beforeFeatures[fid]=true end
     S.DestroyUnit(C.actor,false,false);log('DEATH','actor='..C.actor,'native_wreck_requested=true');return
    end
    if not live(C.target,C.route.target,1)then return finish('INCONCLUSIVE hostile_died_before_all_mobile_mount_hits')end
    if frame-C.stage>600 then return finish('INCONCLUSIVE mobile_mount_hits_timeout')end
   end
  elseif C.phase=='salvage'and frame-C.stage>=30 then
   local found={};local allNew=0
   for _,fid in ipairs(S.GetAllFeatures()or{})do
    local fd=F[S.GetFeatureDefID(fid)];local cp=fd and fd.customParams or{}
    if not C.beforeFeatures[fid]then allNew=allNew+1;if cp.parent_actor==C.route.spec.key then found[#found+1]=fid end end
   end
   if #found~=1 or allNew~=1 then return fail('native_wreck_count_'..#found..'_all_new_'..allNew)end
   local fid=found[1];local fd=F[S.GetFeatureDefID(fid)];local m,dm,e,de,left=S.GetFeatureResources(fid)
   if not fd.reclaimable or fd.blocking or m~=C.route.spec.metal or dm~=m or e~=0 or de~=0 or left~=1 then return fail('native_wreck_remaining_resources')end
   log('SALVAGE','feature='..fid,'metal='..m,'energy='..e,'remaining='..left,'native_death_only=true')
   return finish('PASS scoped_motion_turn_mobile_mount_hits_one_wreck')
  end
 end
 function C.Projectile(pid,owner,wid)
  if C.result or C.phase~='combat'or owner~=C.actor then return end
  local slot=C.route.weapons[wid];if not slot then return end
  if C.projectiles[pid]then return fail('duplicate_projectile')end
  local x,y,z=S.GetProjectilePosition(pid);if not finite(x)or not finite(y)or not finite(z)then return fail('projectile_position')end
  local wx,wy,wz=S.GetUnitWeaponVectors(C.actor,slot);local nearest=math.huge;local actual
  for _,name in ipairs(C.route.spec.muzzles[slot])do
   local mx,my,mz=S.GetUnitPiecePosDir(C.actor,C.pieces[name]);if not finite(mx)or not finite(my)or not finite(mz)then return fail('native_muzzle_position')end
   local distance=(x-mx)^2+(y-my)^2+(z-mz)^2
   if distance<nearest then nearest=distance;actual=name end
  end
  local speed=S.GetUnitWeaponState(C.actor,slot,'projectileSpeed')
  if not finite(speed)or speed<=0 or nearest>math.max(16,speed+4)^2 or not finite(wx)or not finite(wy)or not finite(wz)then return fail('projectile_not_local_muzzle')end
  local vx,_,vz=S.GetUnitVelocity(C.actor);local moving=finite(vx)and finite(vz)and vx*vx+vz*vz>(1/30)^2
  C.projectiles[pid]={slot=slot,moving=moving}
  if moving then C.firstMovingShot=C.firstMovingShot or S.GetGameFrame()end
  log('PROJECTILE','pid='..pid,'slot='..slot,'wid='..wid,'owner='..owner,'muzzle='..actual,'moving='..tostring(moving),'frame='..S.GetGameFrame())
 end
 function C.Damaged(id,damage,paralyzer,wid,pid,attacker)
  if C.result or C.phase~='combat'or id~=C.target or attacker~=C.actor or paralyzer or not finite(damage)or damage<=0 then return end
  local slot=C.route.weapons[wid];if not slot then return end
  local p=C.projectiles[pid];if not p or p.slot~=slot or p.hit then return fail('damage_without_unique_owned_projectile')end
  local hp=S.GetUnitHealth(id);if not finite(hp)or hp>=C.lastHP then return fail('damage_without_HP_loss')end
  p.hit=true;C.hits[slot]=(C.hits[slot]or 0)+1;if p.moving then C.movingShots[slot]=true end
  log('HIT','pid='..pid,'slot='..slot,'wid='..wid,'attacker='..attacker,'target='..id,'moving='..tostring(p.moving),'damage='..damage,'before='..C.lastHP,'after='..hp);C.lastHP=hp
 end
 function C.Close()
  if C.closed then return end;C.closed=true
  if C.watching then for wid in pairs(C.route.weapons)do Script.SetWatchProjectile(wid,false)end end
  for id,row in pairs(C.owned)do if live(id,row.def,row.team)and not C.initial[id]then S.DestroyUnit(id,false,true)end end
 end
 return C
end
return M

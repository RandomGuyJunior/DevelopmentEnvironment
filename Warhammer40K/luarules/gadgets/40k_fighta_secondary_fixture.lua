function gadget:GetInfo()return{name='40K Fighta secondary native mount diagnostic',desc='Default-off funded non-economy three-mount witness',author='Local project',layer=158,enabled=true}end
local options=Spring.GetModOptions()or{}
local function on(v)return v==true or v==1 or v=='1'end
if not on(options.prototype_fighta_secondary_fixture)then return false end
if not gadgetHandler:IsSyncedCode()then
 local closeAt
 local function done(_,result)Spring.Echo('40K_FIGHTA_SECONDARY owned_fixture_autoclose '..tostring(result));closeAt=Spring.GetGameFrame()+90 end
 function gadget:Initialize()gadgetHandler:AddSyncAction('fortyk_fighta_secondary_done',done)end
 function gadget:GameFrame(f)if closeAt and f>=closeAt then closeAt=nil;Spring.SendCommands('quitforce')end end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction('fortyk_fighta_secondary_done')end
 return
end
local S=Spring;local phase='initial';local started,actor,target,origin,witness,enemy;local team=0;local watched={};local created={};local replacementAttempted=false
local function emit(event,...)
 local a={...};for i=1,#a do a[i]=tostring(a[i])end
 S.Echo('40K_FIGHTA_SECONDARY '..event..' '..table.concat(a,' '))
end
local function live(id)return type(id)=='number'and id%1==0 and id>=0 and S.ValidUnitID(id)==true and S.GetUnitIsDead(id)==false end
local function cleanup()
 if witness then witness.Close()end
 if GG.Recoil40KStompaWeaponWitness==witness then GG.Recoil40KStompaWeaponWitness=nil end
 for w in pairs(watched)do Script.SetWatchProjectile(w,false)end;watched={}
 for id,row in pairs(created)do
  if not row.retired and live(id)then
   if S.GetUnitDefID(id)==row.def and S.GetUnitTeam(id)==row.team then S.DestroyUnit(id,false,true)
   else emit('CLEANUP_PRESERVED',id,'refused_foreign_team_or_replaced_definition=true')end
  end
 end
end
local function finish(result)
 if phase=='done'then return end;phase='done';cleanup()
 emit('COMPLETE',result,'funded_non_economy=true own_actor_and_hostile_target_unpaid=true paid_economy_accepted=false primary_acceptance_unchanged=true landing_renderer_pending=true')
 SendToUnsynced('fortyk_fighta_secondary_done',result)
end
local function clear(x,z,r,ignoreAir)
 if not(x>r+64 and z>r+64 and x<Game.mapSizeX-r-64 and z<Game.mapSizeZ-r-64)or #(S.GetFeaturesInRectangle(x-r,z-r,x+r,z+r)or{})~=0 then return false end
 for _,id in ipairs(S.GetUnitsInRectangle(x-r,z-r,x+r,z+r)or{})do
  if id~=ignoreAir then return false end
 end
 return true
end
-- Same unchanged native admission geometry as the initial funded target.
local function fundedTargetSite()
 local x,y,z=S.GetUnitPosition(actor);if type(x)~='number'or type(y)~='number'or type(z)~='number'then return nil,'INCONCLUSIVE native_aircraft_pose_missing'end
 local d=UnitDefs[S.GetUnitDefID(actor)];local range,minimum=math.huge,0
 for n=2,4 do local wd=WeaponDefs[d.weapons[n].weaponDef];range=math.min(range,wd.range*.98);minimum=math.max(minimum,tonumber((wd.customParams or{}).source_minrange)or 0)end
 local targetDef=UnitDefNames.imp_russ;local td=UnitDefs[targetDef.id];local radius=math.max(td.radius or 0,td.xsize*4,td.zsize*4)+32
 local ground=S.GetGroundHeight(x,z)
 local distance=math.sqrt(math.max(0,range^2-(y-ground)^2))*.9
 for n=0,31 do local a=n*math.pi/16;local tx,tz=x+distance*math.sin(a),z+distance*math.cos(a);local ty=S.GetGroundHeight(tx,tz)
  local r2=(tx-x)^2+(ty-y)^2+(tz-z)^2
  local verticalClear=y-ty>(d.radius or math.huge)+(td.radius or math.huge)+16
  if ty>=0 and verticalClear and r2>minimum^2 and r2<range^2 and clear(tx,tz,radius,actor)and S.TestMoveOrder(targetDef.id,tx,ty,tz,0,0,0,true,true,false)and S.IsPosInLos(tx,ty,tz,S.GetUnitAllyTeam(actor))then
   local id=S.CreateUnit('imp_russ',tx,ty,tz,0,enemy)
   if not live(id)then return nil,'FAIL funded_hostile_target_birth'end
   local previous=created[id];created[id]={def=targetDef.id,team=enemy}
   if previous then return nil,'INCONCLUSIVE funded_target_identity_reused'end
   if S.GetUnitDefID(id)~=targetDef.id or S.GetUnitTeam(id)~=enemy then return nil,'FAIL native_funded_target_definition_or_owner'end
   S.GiveOrderToUnit(id,CMD.FIRE_STATE,{0},0);S.GiveOrderToUnit(id,CMD.MOVE_STATE,{0},0)
   return id
  end
 end
 return nil,'INCONCLUSIVE no_clear_naturally_visible_common_secondary_target'
end
function gadget:GameFrame(f)
 if phase=='done'then return end
 if not started then
  if f==0 then return end
  if f~=1 then finish('FAIL fresh_native_frame1_required');return end
  started=f
 end
 if f-started>2400 then finish('INCONCLUSIVE funded_secondary_scene_timeout_'..phase);return end
 if phase=='combat'and witness and not replacementAttempted and created[target]and created[target].nativeDeathConfirmed then
  replacementAttempted=true
  local originalActor=created[actor]
  if not originalActor or originalActor.retired or not live(actor)or S.GetUnitTeam(actor)~=originalActor.team or S.GetUnitDefID(actor)~=originalActor.def or not witness.CanReplaceTarget()then emit('TARGET_REPLACEMENT_REFUSED','reason=original_aircraft_or_death_not_qualified');finish('INCONCLUSIVE target_death_without_intact_original_aircraft');return end
  local prior=target;created[prior].completedTargetDeath=true
  local nextTarget,reason=fundedTargetSite()
  if not nextTarget then emit('TARGET_REPLACEMENT_REFUSED','original_target='..prior,'reason='..reason:gsub('^[A-Z]+ ',''));finish(reason);return end
  local accepted,why=witness.ReplaceTarget(nextTarget,f)
  if not accepted then emit('TARGET_REPLACEMENT_REFUSED','reason='..why);finish('INCONCLUSIVE replacement_target_not_qualified');return end
  target=nextTarget;S.GiveOrderToUnit(actor,CMD.ATTACK,{target},0)
  emit('REPLACEMENT_ATTACK','normal_native=true','target='..target,'max_replacements=1','no_heading_health_weapon_override=true')
 end
 for id,row in pairs(created)do
  if not(row.retired and row.completedTargetDeath)then
   local reason=row.retired and'retired'or not live(id)and'not_live'or S.GetUnitDefID(id)~=row.def and'definition_mismatch'or S.GetUnitTeam(id)~=row.team and'owner_mismatch'
   if reason then emit('OWNED_LOSS','id='..id,'role='..(id==actor and'actor'or id==target and'target'or'prior_target'),'predicate='..reason,'native_death_confirmed='..tostring(row.nativeDeathConfirmed==true));finish('INCONCLUSIVE created_actor_lost_transferred_or_replaced');return end
  end
 end
 if phase=='initial'then
  for key,v in pairs(options)do if key:match('^prototype_.*fixture$')and key~='prototype_fighta_secondary_fixture'and on(v)then finish('FAIL another_fixture_active');return end end
  if GG.Recoil40KStompaWeaponWitness then finish('FAIL occupied_native_weapon_witness');return end
  for _,t in ipairs(S.GetTeamList())do if t~=S.GetGaiaTeamID()and not S.AreTeamsAllied(team,t)then enemy=t;break end end
  local ad=UnitDefNames.ork_fighta_bomba;local td=UnitDefNames.imp_russ
  if not enemy or not ad or not td then finish('INCONCLUSIVE exact_aircraft_target_and_hostile_team_required');return end
  local d=UnitDefs[ad.id]
  if not d.canFly or(d.customParams or{}).animsource~='ork_fighta_bomba'or #d.weapons~=4 then finish('FAIL actual_genuine_Fighta_definition');return end
  local units=S.GetTeamUnits(team)or{};if #units~=1 then finish('FAIL fresh_single_commander_team_required');return end
  local x,_,z=S.GetUnitPosition(units[1]);if not x then finish('FAIL native_commander_position');return end
  local radius=math.max(d.radius or 0,d.xsize*4,d.zsize*4)+32
  for n=0,15 do local angle=n*math.pi/8;local ax,az=x+640*math.sin(angle),z+640*math.cos(angle);local ay=S.GetGroundHeight(ax,az)
   if ay and ay>=0 and clear(ax,az,radius)then
    actor=S.CreateUnit('ork_fighta_bomba',ax,ay,az,0,team)
    if not live(actor)then finish('FAIL funded_exact_actor_birth');return end
    created[actor]={def=ad.id,team=team}
    origin={ax,ay,az};phase='flight'
    S.GiveOrderToUnit(actor,CMD.MOVE,{x,S.GetGroundHeight(x,z),z},0)
    emit('FUNDED_ACTOR',actor,'ordinary_MOVE=true resources_not_granted=true unpaid_birth=true')
    return
   end
  end
  finish('INCONCLUSIVE no_bounded_clear_aircraft_birth_site')
 elseif phase=='flight'then
  if not live(actor)or S.GetUnitTeam(actor)~=team then finish('FAIL funded_actor_lost');return end
  local x,y,z=S.GetUnitPosition(actor)
  if f-started>=90 and y-S.GetGroundHeight(x,z)>=40 and(x-origin[1])^2+(z-origin[3])^2>=128^2 then
   local id,reason=fundedTargetSite();if not id then finish(reason);return end
   target=id;phase='settle';emit('FUNDED_TARGET',target,'target_physics_health_weapons_unchanged=true');return
  end
 elseif phase=='settle'then
  if not live(actor)or not live(target)then finish('FAIL funded_scene_lost');return end
  local los=S.GetUnitLosState(target,S.GetUnitAllyTeam(actor),false)or{};local _,_,_,_,progress=S.GetUnitHealth(target)
  if los.los==true and progress==1 then
   witness=VFS.Include('40k_configs/fighta_secondary_mount_fixture.lua').New(S,UnitDefs,WeaponDefs,actor,team,target,f,emit)
   if witness.result then finish(witness.result);return end
   for _,q in pairs(witness.slots)do watched[q.weapon]=true;Script.SetWatchProjectile(q.weapon,true)end
   GG.Recoil40KStompaWeaponWitness=witness;phase='combat'
   S.GiveOrderToUnit(actor,CMD.ATTACK,{target},0);emit('ATTACK','normal_native=true no_mount_isolation=true no_orientation_override=true')
  end
 elseif phase=='combat'then local result=witness.Step(f);if result then finish(result)end end
end
function gadget:ProjectileCreated(pid,owner,weapon)if witness then witness.Projectile(pid,owner,weapon)end end
function gadget:UnitDamaged(id,def,owner,damage,para,weapon,pid,attacker)if witness then witness.Damaged(id,damage,para,weapon,pid,attacker)end end
function gadget:UnitDestroyed(id,def,owner,attacker)
 local row=created[id];if not row then return end
 local good,nativeDead=pcall(S.GetUnitIsDead,id);local observed;if good and type(nativeDead)=='boolean'then observed=nativeDead end
 if phase~='done'then
  emit('OWNED_DESTROYED','id='..id,'role='..(id==actor and'actor'or id==target and'target'or'prior_target'),'native_def='..tostring(def),'native_team='..tostring(owner),'native_dead='..tostring(observed),'attacker='..tostring(attacker))
  if phase=='combat'and id==target and witness then row.nativeDeathConfirmed=witness.TargetDestroyed(id,def,owner,observed,attacker,S.GetGameFrame())==true end
 end
 row.retired=true
end
function gadget:Shutdown()cleanup()end

-- Short diagnostic: free fixture actors are explicitly not paid/ordinary evidence.
function gadget:GetInfo()return {name='40K Night point-impact diagnostic',desc='Native source-only weapon/terrain comparison',author='Local project',layer=112,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return false end
local o=Spring.GetModOptions()or{}
if o.prototype_diagnostic~='roster'or not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(o.prototype_source_progression)or o.prototype_roster_filter~='nec_nightbringer'or tonumber(o.prototype_test_speed or 1)~=1 then return false end
local owned={};local actor,target,weapon,team,enemy;local start,phase,phaseStart;local shots,hits,ground=0,0,0;local projectiles={};local impacts={};local done=false
local function log(...)Spring.Echo('40K NIGHT POINT DIAGNOSTIC',Spring.GetGameFrame(),...)end
local function alive(id)return id and Spring.ValidUnitID(id)and not Spring.GetUnitIsDead(id)end
local function cleanup()
 for id,r in pairs(owned)do if alive(id)and Spring.GetUnitDefID(id)==r.def and Spring.GetUnitTeam(id)==r.team then Spring.DestroyUnit(id,false,true)end end
 owned={}
end
local function finish(reason)
 if done then return end;done=true;log('LIMITED_DIAGNOSTIC_END',reason,'shots',shots,'actual_hits',hits,'terrain_terminations',ground,'paid',false,'ordinary',false)
 Spring.SetGameRulesParam('40k_night_point_diagnostic_result',hits>0 and ground>0 and 1 or -1);cleanup()
end
local function make(name,x,z,t)
 local id=Spring.CreateUnit(name,x,Spring.GetGroundHeight(x,z),z,0,t)
 local def=UnitDefNames[name].id
 if not id or Spring.GetUnitDefID(id)~=def or Spring.GetUnitTeam(id)~=t then return nil end
 owned[id]={def=def,team=t};Spring.GiveOrderToUnit(id,CMD.FIRE_STATE,{0},{});Spring.GiveOrderToUnit(id,CMD.MOVE_STATE,{0},{})
 return id
end
local site;local firstHitCount;local publishedPhase
local phases={settle=1,unit=2,close_move=3,close_settle=4,close_unit=5,terrain_settle=6,terrain=7,terrain_capture=8}
function gadget:Initialize()
 local a=UnitDefNames.nec_nightbringer;local b=UnitDefNames.nec_lord
 if not a or not b then finish('source_definition_missing');return end
 for _,t in ipairs(Spring.GetTeamList())do if t~=Spring.GetGaiaTeamID()then if not team then team=t elseif not Spring.AreTeamsAllied(team,t)then enemy=t;break end end end
 if not enemy then finish('native_teams_missing');return end
 for id,w in pairs(WeaponDefs)do if w.name=='nec_nightbringer_scythe_ranged'then weapon=id;Script.SetWatchProjectile(id,true);Script.SetWatchExplosion(id,true)end end
 if not weapon then finish('ranged_weapon_missing');return end
 for z=600,Game.mapSizeZ-600,256 do for x=600,Game.mapSizeX-600,256 do
  local y=Spring.GetGroundHeight(x,z);local ty=Spring.GetGroundHeight(x+130,z);local gy=Spring.GetGroundHeight(x,z+160)
  if y>0 and math.abs(y-ty)<2 and math.abs(y-gy)<2 and #Spring.GetFeaturesInCylinder(x,z,300)==0 and #Spring.GetUnitsInCylinder(x,z,300)==0
   and Spring.TestMoveOrder(a.id,x,y,z)and Spring.TestMoveOrder(b.id,x+130,ty,z)then site={x=x,z=z};break end
 end;if site then break end end
 if not site then finish('dry_clear_native_scene_unavailable');return end
 actor=make('nec_nightbringer',site.x,site.z,team);target=make('nec_lord',site.x+130,site.z,enemy)
 if not actor or not target then finish('native_fixture_birth_refused');return end
 Spring.SetGameRulesParam('40k_night_point_actor',actor);Spring.SetGameRulesParam('40k_night_point_target',target);start=Spring.GetGameFrame();phase='settle';phaseStart=start
 log('FREE_DIAGNOSTIC_ONLY',actor,target,'native_policy',WeaponDefs[weapon].impactOnly,WeaponDefs[weapon].noSelfDamage,'range',WeaponDefs[weapon].range)
end
function gadget:ProjectileCreated(id,owner,w)
 if done or owner~=actor or w~=weapon then return end
 shots=shots+1;Spring.SetGameRulesParam('40k_night_point_last_projectile_frame',Spring.GetGameFrame());projectiles[id]={phase=phase};log('REAL_PROJECTILE',id,owner,w,phase)
end
function gadget:Explosion(w,x,y,z,owner,id)
 if done or owner~=actor or w~=weapon or not projectiles[id]then return false end
 impacts[id]={frame=Spring.GetGameFrame(),phase=projectiles[id].phase,x=x,y=y,z=z,ground=Spring.GetGroundHeight(x,z),damage=0}
 log('REAL_EXPLOSION',id,w,owner,x,y,z,impacts[id].ground,phase)
 return false
end
function gadget:ProjectileDestroyed(id)
 if done or not projectiles[id]then return end
 local r=impacts[id];if r then r.destroyed=true;r.destroyedFrame=Spring.GetGameFrame();Spring.SetGameRulesParam('40k_night_point_last_impact_frame',Spring.GetGameFrame())end;log('REAL_PROJECTILE_DESTROYED',id,r and r.phase or 'no_impact_receipt');projectiles[id]=nil
end
function gadget:UnitDamaged(id,d,t,damage,paralyzer,w,p,attacker)
 if done or w~=weapon or attacker~=actor or not(projectiles[p]or impacts[p])then return end
 local r=impacts[p];if r then r.damage=r.damage+1 end
 log('ACTUAL_DAMAGE',id,attacker,w,p,damage,paralyzer,'self',id==actor)
 if id==target and damage>0 and not paralyzer then hits=hits+1 end
end
function gadget:GameFrame(f)
 if done or not start then return end
 if not alive(actor)then finish('actor_lost');return end
 if publishedPhase~=phase then publishedPhase=phase;Spring.SetGameRulesParam('40k_night_point_phase',phases[phase]);Spring.SetGameRulesParam('40k_night_point_phase_frame',f)end
 for id,r in pairs(impacts)do
  if r.destroyedFrame and f>r.destroyedFrame then
   if r.phase=='terrain'and r.destroyed and r.damage==0 and math.abs(r.y-r.ground)<=.5 then ground=ground+1;log('TERRAIN_TERMINATION',id,r.x,r.y,r.z,r.ground,'actual_damage_callbacks',r.damage,'explosion_frame',r.frame,'destroy_frame',r.destroyedFrame)end
   impacts[id]=nil
  elseif f-r.frame>=120 then
   log('UNKNOWN_IMPACT_EXPIRY',id,'explosion_frame',r.frame,'age',f-r.frame,'matched_destroy',false,'actual_damage_callbacks',r.damage)
   impacts[id]=nil;projectiles[id]=nil
  end
 end
 if f-start>=1800 then finish('bounded_60s_timeout');return end
 if phase=='settle'and f-phaseStart>=30 then
  Spring.GiveOrderToUnit(actor,CMD.ATTACK,{target},{});phase='unit';phaseStart=f;log('ORDINARY_UNIT_ATTACK',actor,target)
 elseif phase=='unit'and hits>0 then
  firstHitCount=hits;Spring.GiveOrderToUnit(actor,CMD.MOVE,{site.x+95,Spring.GetGroundHeight(site.x+95,site.z),site.z},{});phase='close_move';phaseStart=f;log('ORDINARY_CLOSE_MOVE',actor,site.x+95,site.z,'native_collision_unchanged',true)
 elseif phase=='close_move'and f-phaseStart>=120 then
  Spring.GiveOrderToUnit(actor,CMD.STOP,{},{});phase='close_settle';phaseStart=f
 elseif phase=='close_settle'and f-phaseStart>=30 then
  local x,y,z=Spring.GetUnitPosition(actor);log('ACTUAL_CLOSE_STANCE',actor,x,y,z);Spring.GiveOrderToUnit(actor,CMD.ATTACK,{target},{});phase='close_unit';phaseStart=f
 elseif(phase=='unit'and f-phaseStart>=600)or(phase=='close_unit'and(hits>(firstHitCount or 0)or f-phaseStart>=600))then
  log('UNIT_PHASE_END',hits>0 and 'actual_hit' or 'UNKNOWN_no_hit');Spring.GiveOrderToUnit(actor,CMD.STOP,{},{});
  if alive(target)then Spring.DestroyUnit(target,false,true);owned[target]=nil end
  phase='terrain_settle';phaseStart=f
 elseif phase=='terrain_settle'and f-phaseStart>=30 then
  local x,z=site.x,site.z+160;Spring.GiveOrderToUnit(actor,CMD.ATTACK,{x,Spring.GetGroundHeight(x,z),z},{});phase='terrain';phaseStart=f;log('ORDINARY_GROUND_ATTACK',actor,x,Spring.GetGroundHeight(x,z),z)
 elseif phase=='terrain'and ground>0 then phase='terrain_capture';phaseStart=f
 elseif phase=='terrain_capture'and f-phaseStart>=12 then finish('actual_target_and_terrain_receipts')end
end
function gadget:Shutdown()cleanup()end

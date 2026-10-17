function gadget:GetInfo()return{name='40K Stompa native weapon diagnostic',desc='Default-off unpaid pulse/belly/four-muzzle native function scene',author='Local project',layer=110,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return end
local M=VFS.Include('40k_configs/stompa_weapon_fixture.lua')
if not M.Enabled(Spring.GetModOptions())then return end
local pending
local owned,ledger,mounts,actor,target,stage,start,ground,stopped={},nil,{},nil,nil,0,0,false,false
local emit=function(s)Spring.Echo('40K_STOMPA_WEAPONS '..s)end
local function finish(why)
 if stopped then return end;stopped=true;if ledger then ledger.Close(why)end
 GG.Recoil40KStompaWeaponWitness=nil
 for _,id in ipairs(owned)do if Spring.ValidUnitID(id)and not Spring.GetUnitIsDead(id)then Spring.DestroyUnit(id,false,true)end end
 emit('COMPLETE reason='..why..' paid_acceptance=false fps_acceptance=false')
end
local function legal(def,x,z)
 return x>160 and z>160 and x<Game.mapSizeX-160 and z<Game.mapSizeZ-160 and Spring.TestMoveOrder(def,x,Spring.GetGroundHeight(x,z),z,0,0,0,true,true,false)
end
local ax,az,team,enemy
local function spawn(name,def,x,z,t)
 if not legal(def,x,z)then return nil end
 local id=Spring.CreateUnit(name,x,Spring.GetGroundHeight(x,z),z,0,t)
 if id then owned[#owned+1]=id;Spring.GiveOrderToUnit(id,CMD.FIRE_STATE,{0},0);Spring.GiveOrderToUnit(id,CMD.MOVE_STATE,{0},0)
  local state=Spring.GetUnitStates(id);if not state or state.firestate~=0 or state.movestate~=0 then return nil end
 end
 return id
end
local function nextPhase(f)
 if target and Spring.ValidUnitID(target)and not Spring.GetUnitIsDead(target)then Spring.DestroyUnit(target,false,true)end;target=nil
 if ground then ground=false;stage=stage+1 else ground=true end
 if stage>#M.Slots then finish('native_function_pass_visual_review_required');return end
 local slot=M.Slots[stage];local m=mounts[slot];local distance=math.floor(m.range*.60)
 local tx,tz=ax+(ground and -160 or 160),az+distance
 if not legal(UnitDefNames.ork_deff_dread.id,tx,tz)then finish('finite_target_site_refused');return end
 if not ground then target=spawn('ork_deff_dread',UnitDefNames.ork_deff_dread.id,tx,tz,enemy);if not target then finish('target_birth_refused');return end end
 if not ledger.Begin(slot,target,enemy,f,ground)then finish(ledger.failed or 'phase_refused');return end
 start=f;Spring.SetUnitRulesParam(actor,'40k_validation_mount',slot)
 Spring.GiveOrderToUnit(actor,CMD.STOP,{},0);Spring.GiveOrderToUnit(actor,CMD.FIRE_STATE,{2},0)
 local state=Spring.GetUnitStates(actor);if not state or state.firestate~=2 or state.movestate~=0 then finish('ordinary_firing_stance_readback_refused');return end
 Spring.GiveOrderToUnit(actor,CMD.ATTACK,ground and{tx,Spring.GetGroundHeight(tx,tz),tz}or{target},0)
 emit('PHASE slot='..slot..' terrain='..tostring(ground)..' range='..m.range..' reload='..m.reload..' target_horizontal_distance='..math.sqrt(distance*distance+160*160)..' target='..tostring(target))
end
function gadget:Initialize()
 if Spring.GetGameFrame()>0 then finish('late_init_or_save_requires_fresh_fixture');return end
 local d=UnitDefNames.ork_dakka_stompa;local t=UnitDefNames.ork_deff_dread
 if not d or not t then finish('actual_definitions_missing');return end
 local u=UnitDefs[d.id];local cp=u.customParams or{}
 if cp.source_stompa_design~='stompa_design_20261008'or cp.source_stompa_arm_status~='dakka_four_guns_v1'or cp.diagnostic~='roster'then finish('exact_full_design_metadata_missing');return end
 local teams=Spring.GetTeamList();for _,a in ipairs(teams)do if a~=Spring.GetGaiaTeamID()then for _,b in ipairs(teams)do if b~=Spring.GetGaiaTeamID()and not Spring.AreTeamsAllied(a,b)then team,enemy=a,b;break end end;if team then break end end end
 if not team then finish('enemy_teams_missing');return end
 local pieces
 for x=math.floor(Game.mapSizeX*.25),math.floor(Game.mapSizeX*.75),256 do for z=math.floor(Game.mapSizeZ*.25),math.floor(Game.mapSizeZ*.60),256 do if legal(d.id,x,z)and legal(t.id,x,z+660)then ax,az=x,z;break end end;if ax then break end end
 if not ax then finish('finite_full_footprint_site_refused');return end
 actor=spawn('ork_dakka_stompa',d.id,ax,az,team);if not actor then finish('actor_birth_refused');return end
 pieces=Spring.GetUnitPieceMap(actor)
 for _,slot in ipairs(M.Slots)do local entry=u.weapons[slot];local w=entry and WeaponDefs[entry.weaponDef];local p=w and w.customParams or{};local piece=pieces[p.source_muzzle]
  if not w or not piece or(w.type~='Cannon'and w.type~='BeamLaser')then finish('native_mount_or_piece_missing');return end
  mounts[slot]={weapon=entry.weaponDef,piece=piece,range=w.range,reload=w.reload,beam=w.type=='BeamLaser',beamtime=w.beamtime or .085}
  Script.SetWatchProjectile(entry.weaponDef,true);Script.SetWatchExplosion(entry.weaponDef,true)
 end
 ledger=M.New(Spring,actor,team,mounts,emit);GG.Recoil40KStompaWeaponWitness=ledger
 stage=0;ground=true;nextPhase(Spring.GetGameFrame())
end
function gadget:GameFrame(f)
 if stopped or not ledger then return end
 if Spring.GetUnitTeam(actor)~=team or Spring.GetUnitIsDead(actor)then finish('actor_death_or_capture');return end
 if target and not Spring.GetUnitIsDead(target)and Spring.GetUnitTeam(target)~=enemy then finish('target_capture');return end
 if target and Spring.GetUnitIsDead(target)and not ledger.Ready()then finish('target_death_before_evidence');return end
 if ledger.failed then finish(ledger.failed);return end
 if pending then if f>=pending then pending=nil;nextPhase(f)end;return end
 if ledger.Ready()and(ground or f-start>=150)then
  Spring.SetUnitRulesParam(actor,'40k_validation_mount',0);Spring.GiveOrderToUnit(actor,CMD.STOP,{},0);Spring.GiveOrderToUnit(actor,CMD.FIRE_STATE,{0},0)
  pending=f+math.max(3,math.ceil((mounts[M.Slots[stage]].beamtime or 0)*30)+2)
 elseif f-start>1800 then finish('native_evidence_timeout_slot_'..M.Slots[stage])end
end
function gadget:ProjectileCreated(pid,owner,wd)if ledger then ledger.Projectile(pid,owner,wd)end end
function gadget:ProjectileDestroyed(pid)if ledger then ledger.Deleted(pid)end end
function gadget:UnitDamaged(id,def,t,damage,para,wd,pid,attacker)if ledger then ledger.Damaged(id,damage,para,wd,attacker,pid)end end
function gadget:Explosion(wd,x,y,z,owner,pid)if ledger then ledger.Explosion(wd,x,y,z,owner,pid)end;return false end
function gadget:Shutdown()finish('shutdown_or_save_restart_requires_fresh_fixture')end

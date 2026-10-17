function gadget:GetInfo()
 return {name="40K native combat benchmark",desc="Opt-in constant-population source animation, effects and physical projectile stress",author="Local project",layer=105,enabled=true}
end
if not gadgetHandler:IsSyncedCode() then return end
local options=Spring.GetModOptions()
if options.prototype_diagnostic~="combatbenchmark" then return end
local stages={100,250,500}
local benchmarkUnits={imp_guardsman=true,ork_boy=true,imp_kasrkin=true}
local requestedUnit=options.prototype_benchmark_unit
local unitName=benchmarkUnits[requestedUnit] and requestedUnit or "imp_guardsman"
local verboseDurability=tostring(options.prototype_benchmark_durability_debug)=="1"
local stage,startFrame,stopped=0,0,false
local owned,ownedSet,pairs={}, {}, {}
local projectileCount,hitCount,damageTotal=0,0,0
local shooters={}
local lastHealth,lastDamage={},{}
local cleaning=false
local renderSamples,latestFPS,latestSim=0,0,0
local function emit(s) Spring.Echo("40K_COMBAT_BENCH "..s) end
local function clean()
 cleaning=true
 for _,id in ipairs(owned) do
  if Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id) then Spring.DestroyUnit(id,false,true) end
 end
 owned,ownedSet,pairs={},{},{}
 cleaning=false
end
local function finish(reason)
 if stopped then return end
 stopped=true
 emit(string.format('{"event":"complete","stage":%d,"reason":"%s"}',stage,reason))
 Spring.SetGameRulesParam("40k_combat_benchmark_done",1)
 clean()
end
local function healthEvidence(phase,f)
 local minimum,maximum,lowest,changed=math.huge,0,0,0
 for _,id in ipairs(owned) do
  if Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id) then
   local health,maxHealth=Spring.GetUnitHealth(id)
   if health and maxHealth then
    if health<minimum then minimum=health;lowest=id end
    maximum=math.max(maximum,maxHealth)
    if maxHealth<1000000 then changed=changed+1 end
    local recorded=lastHealth[id] or {};lastHealth[id]=recorded
    recorded.health,recorded.max=health,maxHealth
   end
  end
 end
 local low=lastHealth[lowest] or {health=0,max=0}
 emit(string.format('{"event":"health","stage":%d,"frame":%d,"phase":"%s","lowest_unit":%d,"health_min":%.3f,"lowest_max_health":%.3f,"max_health_max":%.3f,"below_fixture_max":%d}',stage,f,phase,lowest,minimum<math.huge and minimum or 0,low.max,maximum,changed))
end
local function begin(f)
 clean();stage=stage+1;startFrame=f
 projectileCount,hitCount,damageTotal=0,0,0;shooters={};lastHealth={};lastDamage={}
 renderSamples,latestFPS,latestSim=0,0,0
 local wanted=stages[stage]
 if not wanted then finish("all_requested_stages_complete");return end
 -- Two genuine opposed armies, total population exactly wanted. Every pair
 -- has a clear short firing lane; rear ranks never fire through a front rank.
 for i=1,wanted/2 do
  local col=(i-1)%32;local row=math.floor((i-1)/32)
  local x,z=4070+col*16,850+row*48
  if x>=Game.mapSizeX-64 or z+30>=Game.mapSizeZ-64 or
   Spring.GetGroundHeight(x,z)<5 or Spring.GetGroundHeight(x,z+30)<5 or
   math.abs(Spring.GetGroundHeight(x,z)-Spring.GetGroundHeight(x,z+30))>8 then
   finish("dry_combat_plateau_changed");return
  end
  local a=Spring.CreateUnit(unitName,x,Spring.GetGroundHeight(x,z),z,0,0)
  local b=Spring.CreateUnit(unitName,x,Spring.GetGroundHeight(x,z+30),z+30,2,1)
  if not a or not b then
   if a then owned[#owned+1]=a end;if b then owned[#owned+1]=b end
   finish("spawn_failed");return
  end
  for _,id in ipairs({a,b}) do
   owned[#owned+1]=id;ownedSet[id]=true
   -- Diagnostic durability prevents deaths from changing compared army sizes.
   -- Damage, aim, accuracy, reload, collisions, effects and Shot remain native.
   Spring.SetUnitMaxHealth(id,1000000);Spring.SetUnitHealth(id,1000000)
   Spring.SetUnitRulesParam(id,"40k_combat_benchmark_owned",1,{public=true})
   Spring.GiveOrderToUnit(id,CMD.MOVE_STATE,{0},{})
   Spring.GiveOrderToUnit(id,CMD.FIRE_STATE,{0},{})
  end
  pairs[#pairs+1]={a,b}
 end
 local def=UnitDefNames[unitName]
 for _,w in ipairs(UnitDefs[def.id].weapons) do Script.SetWatchProjectile(w.weaponDef,true) end
 Spring.SetGameRulesParam("40k_combat_benchmark_stage",stage)
 Spring.SetGameRulesParam("40k_combat_benchmark_count",wanted)
 Spring.SetGameRulesParam("40k_combat_benchmark_started",f)
 emit(string.format('{"event":"stage_start","stage":%d,"count":%d,"unit":"%s","frame":%d,"target_health":1000000,"pair_distance":30}',stage,wanted,unitName,f))
 healthEvidence("spawn",f)
end
function gadget:ProjectileCreated(projectile,owner,weapon)
 if not stopped and ownedSet[owner] then
  projectileCount=projectileCount+1;shooters[owner]=true
 end
end
function gadget:UnitDamaged(id,def,team,damage,paralyzer,weapon,projectile,attacker)
 if not stopped and ownedSet[id] and ownedSet[attacker] and not paralyzer and damage>0 then
  hitCount=hitCount+1;damageTotal=damageTotal+damage
  if not verboseDurability then return end
  local health,maxHealth=Spring.GetUnitHealth(id)
  local recordedDamage=lastDamage[id] or {};lastDamage[id]=recordedDamage
  recordedDamage.attacker,recordedDamage.weapon,recordedDamage.frame,recordedDamage.damage=attacker,weapon or -1,Spring.GetGameFrame(),damage
  if health and maxHealth then
   local previous=lastHealth[id]
   if previous and previous.max~=maxHealth then
    emit(string.format('{"event":"durability_change","stage":%d,"frame":%d,"unit":%d,"health":%.3f,"max_health":%.3f,"previous_max_health":%.3f,"attacker":%d,"weapon":%d}',stage,Spring.GetGameFrame(),id,health,maxHealth,previous.max,attacker,weapon or -1))
   end
   local recorded=lastHealth[id] or {};lastHealth[id]=recorded
    recorded.health,recorded.max=health,maxHealth
  end
 end
end
function gadget:UnitDestroyed(id,def,team,attacker,attackerDef,attackerTeam)
 if not cleaning and not stopped and ownedSet[id] then
  local prior=lastHealth[id] or {health=-1,max=-1}
  local damage=lastDamage[id] or {attacker=-1,weapon=-1,frame=-1,damage=0}
  -- UnitDestroyed does not provide a weaponDef; preserve the real last damage.
  emit(string.format('{"event":"unit_destroyed","stage":%d,"frame":%d,"unit":%d,"def":%d,"team":%d,"attacker":%d,"attacker_def":%d,"attacker_team":%d,"last_health":%.3f,"last_max_health":%.3f,"last_damage_weapon":%d,"last_damage_attacker":%d,"last_damage_frame":%d,"last_damage":%.3f}',stage,Spring.GetGameFrame(),id,def,team,attacker or -1,attackerDef or -1,attackerTeam or -1,prior.health,prior.max,damage.weapon,damage.attacker,damage.frame,damage.damage))
 end
end
function gadget:RecvLuaMsg(msg)
 if stopped then return end
 local idx,fps,sim=msg:match("^40K_COMBAT_BENCH_RENDER (%d+) ([%d.]+) ([%d.]+)$")
 if idx and tonumber(idx)==stage then
  latestFPS,latestSim=tonumber(fps),tonumber(sim);renderSamples=renderSamples+1
 end
 if msg=="40K_COMBAT_BENCH_ABORT_WALL" then finish("wall_time_safety_abort") end
end
function gadget:GameFrame(f)
 if stopped then return end
 if stage==0 then if f>=90 then begin(f) end;return end
 local age=f-startFrame
 if age==60 then
  healthEvidence("before_attack",f)
  for _,pair in ipairs(pairs) do
   Spring.GiveOrderToUnit(pair[1],CMD.FIRE_STATE,{2},{})
   Spring.GiveOrderToUnit(pair[2],CMD.FIRE_STATE,{2},{})
   Spring.GiveOrderToUnit(pair[1],CMD.ATTACK,{pair[2]},{})
   Spring.GiveOrderToUnit(pair[2],CMD.ATTACK,{pair[1]},{})
  end
 end
 if age>=150 and age%30==0 then
  healthEvidence("combat",f)
  local alive,active=0,0
  for _,id in ipairs(owned) do
   if Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id) then alive=alive+1 end
   if shooters[id] then active=active+1 end
  end
  emit(string.format('{"event":"combat","stage":%d,"frame":%d,"alive":%d,"fired_units":%d,"projectiles":%d,"native_hits":%d,"native_damage":%.3f}',stage,f,alive,active,projectileCount,hitCount,damageTotal))
  if alive~=stages[stage] then finish("population_changed");return end
 end
 if age>=1350 then
  local active=0;for _,id in ipairs(owned) do if shooters[id] then active=active+1 end end
  emit(string.format('{"event":"stage_end","stage":%d,"count":%d,"fps_last":%.2f,"sim_last":%.3f,"render_samples":%d,"fired_units":%d,"projectiles":%d,"native_hits":%d}',stage,stages[stage],latestFPS,latestSim,renderSamples,active,projectileCount,hitCount))
  if renderSamples<10 then finish("render_sampler_missing")
  elseif active<stages[stage]*.9 or hitCount==0 then finish("insufficient_native_combat")
  elseif latestFPS<20 or latestSim<.8 then finish("performance_safety_gate")
  elseif stage==#stages then finish("all_requested_stages_complete")
  else begin(f) end
 end
end

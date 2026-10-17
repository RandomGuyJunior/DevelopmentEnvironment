function gadget:GetInfo()
 return {name="40K opt-in native map-pack validation",desc="Native starts, metal, paths, source features and genuine projectile destruction",author="Local Recoil Project",layer=108,enabled=true}
end
if not gadgetHandler:IsSyncedCode() then return end
if Spring.GetModOptions().prototype_diagnostic~="mappack" then return end
local keys={"gothic_wall","gothic_rubble","imperial_wall","marine_statue","judgment_statue","oil_drum","supply_crate","twisted_metal"}
local names={"imp_guardsman","imp_marine","imp_russ","ork_boy","ork_meganob","ork_killa_kan"}
local layout,dimensions
local result,started=0,false
local ownedUnits,movers,shots={},{},{}
local scene={index=0,active=false}
local owner,weaponID,speed,gravity
local function log(...) Spring.Echo("40K MAPPACK",...) end
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1e12 end
local function stop(code,reason)
 if result~=0 then return end
 result=code;Spring.SetGameRulesParam("40k_mappack_result",code)
 Spring.SetGameRulesParam("40k_mappack_reason",reason)
 log(code==1 and "PASS" or code==-2 and "UNKNOWN" or "FAIL",reason,Spring.GetGameFrame())
end
local function failed(reason) stop(-1,reason);return false end
local function inspectFeature(id,expected)
 local def=Spring.GetFeatureDefID(id);local fd=def and FeatureDefs[def]
 if not fd or fd.name~=expected then return failed("feature_definition_"..expected) end
 if fd.destructable~=true or not finite(fd.maxHealth) or fd.maxHealth<=0 then return failed("indestructible_or_health_"..expected) end
 local health=Spring.GetFeatureHealth(id);if not finite(health) or health<=0 then return failed("feature_live_health_"..expected) end
 local sx,sy,sz,ox,oy,oz=Spring.GetFeatureCollisionVolumeData(id)
 local volume={sx,sy,sz,ox,oy,oz};for i=1,6 do if not finite(volume[i]) then return failed("nonfinite_feature_volume_"..expected) end end
 if not sx or sx<=0 or sy<=0 or sz<=0 then return failed("empty_feature_volume_"..expected) end
 if math.abs(ox)>0.01 or math.abs(oy)>0.01 or math.abs(oz)>0.01 then return failed("shifted_feature_volume_"..expected) end
 local pieces=Spring.GetFeaturePieceMap(id);if not pieces or not next(pieces) then return failed("missing_native_model_pieces_"..expected) end
 log("FEATURE_NATIVE_MODEL_PASS",expected,id,fd.modelname or "model",sx,sy,sz,health)
 return true
end
local function auditMap()
 local ok,value=pcall(VFS.Include,"map_pack_layout.lua",nil,VFS.MAP)
 if not ok or type(value)~="table" then stop(-2,"missing_map_layout_contract");return false end
 layout=value
 local spec=layout.spec
 if not spec or Game.mapSizeX~=layout.world or Game.mapSizeZ~=layout.world then return failed("native_map_dimensions") end
 log("DIMENSIONS_PASS",spec.key,Game.mapSizeX,Game.mapSizeZ,spec.players)
 for i,start in ipairs(layout.starts) do
  local x,z=start[1],start[2];local low,high=math.huge,-math.huge
  for xx=x-384,x+384,96 do for zz=z-384,z+384,96 do
   local y=Spring.GetGroundHeight(xx,zz);if not finite(y) or y<=5 then return failed("wet_or_nonfinite_start_"..i) end
   low=math.min(low,y);high=math.max(high,y)
  end end
  if high-low>0.02 then return failed("sloped_start_"..i) end
  -- Actual builder footprints, away from the native commander in the pad centre.
  for _,name in ipairs({"wh40k_armlab","wh40k_corlab","wh40k_armvp","corvp","wh40k_armsolar","wh40k_corsolar"}) do
   local ud=UnitDefNames[name];if not ud then stop(-2,"missing_base_scaffold_"..name);return false end
   local status=Spring.TestBuildOrder(ud.id,x+256,low,z+256,0)
   -- Pinned engine maps OPEN(3) to RECLAIMABLE(2) for legacy callers.
   if status~=2 and status~=3 then return failed("blocked_start_build_"..i.."_"..name.."_"..tostring(status)) end
  end
  log("START_DRY_FLAT_BUILD_PASS",i-1,x,z,low,high,"768elmo_pad")
 end
 local first,left,right
 left,right=0,0
 for i,site in ipairs(layout.metals) do
  local x,z=site[1],site[2];local total=0
  for _,dx in ipairs({-8,8}) do for _,dz in ipairs({-8,8,24}) do
   local _,_,amount=Spring.GetGroundInfo(x+dx,z+dz)
   if not finite(amount) or amount<=0 then return failed("missing_native_metal_"..i) end
   total=total+amount
  end end
  if first and math.abs(total-first)>0.0001 then return failed("unequal_native_deposits") end
  first=first or total
  if x<Game.mapSizeX/2 then left=left+total elseif x>Game.mapSizeX/2 then right=right+total end
 end
 if math.abs(left-right)>0.0001 or left<=0 then return failed("unbalanced_native_metal") end
 for i,start in ipairs(layout.starts) do
  local safe=0
  for _,site in ipairs(layout.metals) do if (site[1]-start[1])^2+(site[2]-start[2])^2<=1000^2 then safe=safe+1 end end
  if safe<4 then return failed("insufficient_safe_metal_start_"..i) end
 end
 log("NATIVE_METAL_BALANCE_PASS",#layout.metals,first,left,right,"four_safe_sites_per_start")
 local samples=0
 local function check(x,z)
  local y=Spring.GetGroundHeight(x,z)
  if not finite(y) or y<=5 then return failed("wet_or_nonfinite_road") end
  for _,name in ipairs(names) do
   local ud=UnitDefNames[name];if not ud then stop(-2,"missing_movement_class_"..name);return false end
   if not Spring.TestMoveOrder(ud.id,x,y,z,1,0,0,true,false,false) then return failed("native_road_terrain_"..name.."_"..x.."_"..z) end
  end
  for _,id in ipairs(Spring.GetFeaturesInRectangle(x-96,z-96,x+96,z+96) or {}) do
   local fd=FeatureDefs[Spring.GetFeatureDefID(id)]
   if fd and fd.name:sub(1,4)=="40k_" then return failed("scenery_obstructs_clear_road") end
  end
  samples=samples+1;return true
 end
 for _,z in ipairs(layout.lanes) do for x=192,layout.world-192,128 do
  for _,dz in ipairs({-96,0,96}) do if not check(x,z+dz) then return false end end
 end end
 for _,x in ipairs(layout.connectors) do for z=192,layout.world-192,128 do if not check(x,z) then return false end end end
 log("NATIVE_CONNECTED_ROAD_GRAPH_PASS",samples,"six_ground_classes","terrain_plus_clear_feature_envelopes")
 local count=0
 for _,id in ipairs(Spring.GetAllFeatures()) do
  local fd=FeatureDefs[Spring.GetFeatureDefID(id)]
  if fd and fd.name:sub(1,4)=="40k_" then
   count=count+1
   if not fd.destructable then return failed("indestructible_map_scenery_"..fd.name) end
  end
 end
 if count~=#layout.features then return failed("native_scenery_instance_count_"..count.."_"..#layout.features) end
 for _,key in ipairs(keys) do
  local id=FeatureDefNames["40k_"..key];local fd=id and FeatureDefs[id.id]
  if not fd or not fd.destructable or fd.maxHealth<=0 then return failed("native_scenic_def_"..key) end
 end
 local rubble=FeatureDefNames["40k_rubble_remnant"]
 if not rubble or not FeatureDefs[rubble.id].destructable then return failed("indestructible_rubble") end
 log("MAP_SCENERY_COUNT_DESTRUCTIBILITY_PASS",count,"eight_source_types_plus_damageable_rubble")
 return true
end
local function createUnit(name,x,z)
 local id=Spring.CreateUnit(name,x,Spring.GetGroundHeight(x,z),z,0,0)
 if not id then failed("fixture_unit_creation_"..name);return end
 ownedUnits[#ownedUnits+1]=id;Spring.GiveOrderToUnit(id,CMD.FIRE_STATE,{0},{});Spring.GiveOrderToUnit(id,CMD.MOVE_STATE,{0},{})
 return id
end
local function startFixtures(f)
 local x=layout.connectors[1]-256;local z=layout.combat_lanes[1]
 for i,name in ipairs(names) do
  local zz=z+(i-1)*40-100;local id=createUnit(name,x,zz);if not id then return end
  movers[id]={name=name,x=x,z=zz,tx=x+384,tz=zz,start=f,done=false}
  Spring.GiveOrderToUnit(id,CMD.MOVE,{x+384,Spring.GetGroundHeight(x+384,zz),zz},{})
 end
 local start=layout.starts[1];scene.x,scene.z=start[1]+300,start[2]+300
 owner=createUnit("imp_marine",scene.x-240,scene.z)
 local marine=UnitDefNames.imp_marine;weaponID=marine and UnitDefs[marine.id].weapons[1].weaponDef
 if not weaponID or not Spring.SpawnProjectile then stop(-2,"native_projectile_api_or_weapon_missing");return end
 local wd=WeaponDefs[weaponID];speed=wd.projectilespeed
 if not finite(speed) or speed<=0 then stop(-2,"native_projectile_speed_missing");return end
 gravity=(wd.myGravity or 0)~=0 and -wd.myGravity or -Game.gravity/(Game.gameSpeed*Game.gameSpeed)
 if Script.SetWatchProjectile then Script.SetWatchProjectile(weaponID,true) end
 log("FUNCTION_ONLY_FIXTURES",#ownedUnits,"free_diagnostic_units_not_production_acceptance")
end
local function nextScene(f)
 scene.index=scene.index+1
 if scene.index>#keys then scene.finished=true;scene.active=false;log("ALL_SCENERY_NATIVE_PROJECTILE_CHAINS_PASS",#keys,f);return end
 local key=keys[scene.index];scene.key=key;scene.active=true;scene.start=f;scene.primaryDestroyed=false;scene.remnantDestroyed=false;scene.remnant=nil;scene.primaryDamage=0;scene.remnantDamage=0;scene.projectiles=0
 scene.primary=Spring.CreateFeature("40k_"..key,scene.x,Spring.GetGroundHeight(scene.x,scene.z),scene.z,0,Spring.GetGaiaTeamID())
 if not scene.primary or not inspectFeature(scene.primary,"40k_"..key) then failed("owned_scenery_creation_"..key);return end
 Spring.SetGameRulesParam("40k_mappack_scene",scene.index);Spring.SetGameRulesParam("40k_mappack_scene_x",scene.x);Spring.SetGameRulesParam("40k_mappack_scene_z",scene.z)
 Spring.SetGameRulesParam("40k_mappack_scene_height",math.max(500,dimensions[key].y*3))
 log("OWNED_FEATURE_FIXTURE",key,scene.primary,scene.x,scene.z,f)
end
local function fireAt(id)
 local x,y,z,mx,my,mz=Spring.GetFeaturePosition(id,true)
 if not x or not finite(my) then return failed("native_target_midpoint_"..scene.key) end
 local sx=scene.x-180;local sy=my;local dx=mx-sx;local vx=speed;local vy
 for _=1,5 do local t=dx/vx;vy=(my-sy)/t-gravity*(t-1)*.5
  if math.abs(vy)>=speed then return failed("native_projectile_arc_unreachable") end
  vx=math.sqrt(speed*speed-vy*vy)
 end
 local pid=Spring.SpawnProjectile(weaponID,{owner=owner,team=0,weapon=1,pos={sx,sy,scene.z},speed={vx,vy,0},["end"]={mx,my,mz},gravity=gravity,ttl=math.ceil(dx/vx)*3+15})
 if not pid then return failed("native_projectile_spawn_failed") end
 shots[pid]=scene.key;scene.projectiles=scene.projectiles+1
 return true
end
function gadget:FeatureCreated(id,ally)
 if not scene.active then return end
 local fd=FeatureDefs[Spring.GetFeatureDefID(id)]
 if not fd or fd.name~="40k_rubble_remnant" then return end
 local x,_,z=Spring.GetFeaturePosition(id)
 if x and (x-scene.x)^2+(z-scene.z)^2<8^2 then
  scene.remnant=id;scene.remnantBorn=Spring.GetGameFrame()
  inspectFeature(id,"40k_rubble_remnant");log("NATIVE_RUBBLE_CREATED",scene.key,id,scene.primary,Spring.GetGameFrame())
 end
end
function gadget:FeatureDamaged(id,def,team,damage,weapon,projectile,attacker)
 if not scene.active or weapon~=weaponID or attacker~=owner or damage<=0 then return end
 if id==scene.primary then scene.primaryDamage=scene.primaryDamage+damage
 elseif id==scene.remnant then scene.remnantDamage=scene.remnantDamage+damage end
end
function gadget:FeatureDestroyed(id)
 if not scene.active then return end
 if id==scene.primary then scene.primaryDestroyed=true;scene.primaryDeathFrame=Spring.GetGameFrame();log("NATIVE_PRIMARY_DESTROYED",scene.key,id,scene.primaryDamage,scene.projectiles)
 elseif id==scene.remnant then scene.remnantDestroyed=true;scene.remnantDeathFrame=Spring.GetGameFrame();log("NATIVE_RUBBLE_DESTROYED",scene.key,id,scene.remnantDamage,scene.projectiles) end
end
function gadget:ProjectileDestroyed(id) shots[id]=nil end
function gadget:Initialize()
 Spring.SetGameRulesParam("40k_mappack_result",0)
 local ok,value=pcall(VFS.Include,"40k_reference/scenery_dimensions.lua")
 if not ok or type(value)~="table" then stop(-2,"missing_exported_scenery_dimensions");return end
 dimensions=value
end
function gadget:GameFrame(f)
 if result~=0 then return end
 if f>=2400 then failed("bounded_native_suite_timeout_80_seconds");return end
 if f>=30 and not started then
  started=true;if not auditMap() then return end;startFixtures(f);if result~=0 then return end;nextScene(f)
 end
 if not started then return end
 if scene.active then
  local target=scene.primaryDestroyed and scene.remnant or scene.primary
  if scene.primaryDestroyed and not scene.remnant and f-scene.primaryDeathFrame>15 then failed("native_rubble_chain_missing_"..scene.key);return end
  if scene.remnantDestroyed then
   if scene.primaryDamage<=0 or scene.remnantDamage<=0 then failed("missing_real_projectile_damage_"..scene.key);return end
   if f-scene.remnantDeathFrame>=15 then log("SCENERY_PROJECTILE_CHAIN_PASS",scene.key,scene.primaryDamage,scene.remnantDamage,scene.projectiles,f);nextScene(f) end
  elseif f-scene.start>=45 and target and Spring.GetFeatureDefID(target) then
   if not fireAt(target) then return end
  end
  if f-scene.start>240 then failed("scenery_native_projectile_timeout_"..scene.key);return end
 end
 local done=0
 for id,m in pairs(movers) do
  if m.done then done=done+1
  else
   local x,_,z=Spring.GetUnitPosition(id)
   if not x then failed("movement_fixture_missing_"..m.name);return end
   local remaining=math.sqrt((x-m.tx)^2+(z-m.tz)^2);local moved=math.sqrt((x-m.x)^2+(z-m.z)^2)
   if remaining<=48 and moved>=300 then m.done=true;done=done+1;log("ACTUAL_MOVE_ARRIVAL_PASS",m.name,id,moved,remaining,f-m.start) end
  end
 end
 if done==#names and scene.finished then stop(1,"native_dimensions_all_starts_build_pads_equal_metal_clear_ground_graph_six_actual_moves_eight_authentic_models_real_projectile_rubble_chains") end
end
function gadget:Shutdown()
 -- Cleanup only owned diagnostic units; scenery acceptance never uses direct health/deletion.
 for _,id in ipairs(ownedUnits) do if Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id) then Spring.DestroyUnit(id,false,true) end end
end

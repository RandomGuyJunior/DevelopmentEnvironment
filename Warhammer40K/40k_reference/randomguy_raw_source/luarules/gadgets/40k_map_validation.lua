function gadget:GetInfo()
 return {name="40K Ashen Bastion native validation",desc="Opt-in native production, extraction and six-unit ground movement",author="Local Recoil Project",layer=103,enabled=true}
end
if not gadgetHandler:IsSyncedCode() then return end
if tostring(Spring.GetModOptions().prototype_mapcheck or "0")~="1" then return end
local wantedMap="AshenBastion0.1"
local actualMap=(Game.mapName or ""):gsub("%s+","")
if actualMap~=wantedMap then
 Spring.Echo("40K MAPCHECK","FAIL","wrong_map",Game.mapName or "missing")
 return
end
local names={"imp_guardsman","imp_marine","imp_russ","ork_boy","ork_meganob","ork_killa_kan"}
local wanted={};for _,name in ipairs(names) do wanted[name]=true end
local births,products,mexes,factories,probes={}, {}, {}, {}, {}
local state="waiting"
local moveFrame
local function log(...) Spring.Echo("40K MAPCHECK",...) end
local function restore()
 for id,p in pairs(probes) do
  if Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id) then Spring.GiveOrderToUnit(id,CMD.FIRE_STATE,{p.firestate},{}) end
 end
end
local function fail(reason)
 if state=="failed" or state=="passed" then return end
 state="failed";Spring.SetGameRulesParam("40k_mapcheck_result",-1);log("FAIL",reason,Spring.GetGameFrame());restore()
end
local function checkTerrain()
 if Game.mapSizeX~=4096 or Game.mapSizeZ~=4096 then fail("dimensions");return false end
 local lowest=math.huge
 for x=0,4096,64 do for z=0,4096,64 do lowest=math.min(lowest,Spring.GetGroundHeight(x,z)) end end
 if lowest<=5 then fail("dry_terrain");return false end
 for _,x in ipairs({640,3456}) do
  local low,high=math.huge,-math.huge
  for xx=x-256,x+256,32 do for z=1792,2304,32 do
   local y=Spring.GetGroundHeight(xx,z);low=math.min(low,y);high=math.max(high,y)
  end end
  if high-low>0.02 then fail("flat_base_"..x);return false end
  log("BASE_FLAT_PASS",x,2048,low,high,"512_elmo_square")
 end
 log("TERRAIN_PASS",4096,4096,"minimum_sampled_height",lowest)
 return true
end
function gadget:Initialize()
 Spring.SetGameRulesParam("40k_mapcheck_result",0)
 if checkTerrain() then log("WAIT_NATIVE_PRODUCTION","both commander-built labs/vps/mexes and all six real products") end
end
function gadget:UnitCreated(id,defID,team,builder)
 local builderDef=builder and Spring.GetUnitDefID(builder)
 births[id]={builder=builder,builderName=builderDef and UnitDefs[builderDef].name,team=team,name=UnitDefs[defID].name}
end
function gadget:UnitFinished(id,defID,team)
 if state~="waiting" then return end
 local birth=births[id];if not birth then return end
 local name=UnitDefs[defID].name
 if team~=0 and team~=1 then return end
 local commander=birth.builderName=="armcom" or birth.builderName=="corcom"
 if commander then
  if name=="armlab" or name=="armvp" or name=="corlab" or name=="corvp" then
   factories[team]=factories[team] or {};factories[team][name:sub(4)]=id
   log("COMMANDER_FACTORY_FINISHED",team,name,id,birth.builder,Spring.GetGameFrame())
  elseif name=="armmex" or name=="cormex" then
   mexes[id]={team=team,builder=birth.builder,passed=false}
   log("COMMANDER_MEX_FINISHED",team,name,id,birth.builder)
  end
 end
 if wanted[name] then
  local factory=birth.builderName
  if factory~="armlab" and factory~="armvp" and factory~="corlab" and factory~="corvp" then
   fail("non_factory_product_"..name);return
  end
  local parent=births[birth.builder]
  if not parent or parent.team~=team or (parent.builderName~="armcom" and parent.builderName~="corcom") then
   fail("factory_not_commander_built_"..name);return
  end
  local list=products[name] or {};products[name]=list;list[#list+1]=id
  log("NATIVE_PRODUCT_FINISHED",team,name,id,"factory",birth.builder,factory,Spring.GetGameFrame())
 end
end
local function extraction()
 local teams={}
 for id,m in pairs(mexes) do
  if m.passed then teams[m.team]=true
  elseif Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id) then
   local native=Spring.GetUnitMetalExtraction(id) or 0
   local make,use=Spring.GetUnitResources(id)
   if native>0 and (make or 0)>0 then
    m.passed=true;teams[m.team]=true
    log("NATIVE_EXTRACTION_PASS",m.team,id,"extraction",native,"metal_make",make,"metal_use",use or 0,"commander",m.builder)
   end
  end
 end
 return teams[0] and teams[1]
end
local function startMovement(f)
 -- The production fixture keeps control until its complete native roster PASS.
 if Spring.GetGameRulesParam("40k_production_result")~=1 then return end
 for team=0,1 do
  if not factories[team] or not factories[team].lab or not factories[team].vp then return end
 end
 local selected={}
 for _,name in ipairs(names) do
  for _,id in ipairs(products[name] or {}) do
   if Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id) then selected[name]=id;break end
  end
  if not selected[name] then return end
 end
 if not extraction() then return end
 state="moving";moveFrame=f
 for index,name in ipairs(names) do
  local id=selected[name];local x,_,z=Spring.GetUnitPosition(id)
  local team=Spring.GetUnitTeam(id)
  -- Stop short of the opposing group; each probe makes one native MOVE.
  local tx=x<2048 and 1840 or 2256
  local tz=1984+((index-1)%3)*64
  local unitState=Spring.GetUnitStates(id) or {}
  local distance=math.sqrt((tx-x)^2+(tz-z)^2)
  probes[id]={name=name,team=team,x=x,z=z,tx=tx,tz=tz,distance=distance,firestate=unitState.firestate or 2,done=false}
  Spring.GiveOrderToUnit(id,CMD.FIRE_STATE,{0},{})
  Spring.GiveOrderToUnit(id,CMD.MOVE,{tx,Spring.GetGroundHeight(tx,tz),tz},{})
  log("MOVE_ORDER",name,id,team,"source_factory",births[id].builder,"from",x,z,"to",tx,tz,"distance",distance,f)
 end
 log("MOVEMENT_START","six native factory products",f)
end
function gadget:UnitDestroyed(id)
 if probes[id] and not probes[id].done then fail("movement_probe_destroyed_"..probes[id].name) end
 mexes[id]=nil
end
function gadget:GameFrame(f)
 if state=="failed" or state=="passed" or f%30~=0 then return end
 if f>900*Game.gameSpeed then fail("native_mapcheck_timeout_15_minutes");return end
 if state=="waiting" then
  if Spring.GetGameRulesParam("40k_production_result")==-1 then fail("production_fixture_failed");return end
  extraction();startMovement(f);return
 end
 local done=0
 for id,p in pairs(probes) do
  if p.done then done=done+1
  else
   local x,_,z=Spring.GetUnitPosition(id)
   if not x then fail("movement_unit_missing_"..p.name);return end
   local remaining=math.sqrt((p.tx-x)^2+(p.tz-z)^2)
   local travelled=math.sqrt((x-p.x)^2+(z-p.z)^2)
   if f%150==0 then log("MOVE_PROGRESS",p.name,id,"travelled",travelled,"remaining",remaining,f) end
   if remaining<=96 and travelled>=math.min(384,p.distance*0.6) then
    p.done=true;done=done+1
    log("MOVE_ARRIVAL_PASS",p.name,id,"source_factory",births[id].builder,"travelled",travelled,"remaining",remaining,"seconds",(f-moveFrame)/Game.gameSpeed)
   end
  end
 end
 if done==6 then
  state="passed";Spring.SetGameRulesParam("40k_mapcheck_result",1)
  log("PASS","dimensions_dry_flat_bases_both_commander_factory_roles_both_native_extraction_six_factory_products_six_centre_approach_arrivals",f)
  log("TERRAIN_PROJECTILE_CHECK","DEFERRED_independent_collision_probe_required_no_fake_projectiles_or_targets")
  restore()
 elseif f-moveFrame>300*Game.gameSpeed then fail("native_movement_timeout_5_minutes") end
end
function gadget:Shutdown() restore() end

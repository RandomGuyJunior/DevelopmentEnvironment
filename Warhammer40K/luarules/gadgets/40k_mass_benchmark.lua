function gadget:GetInfo()
 return {name="40K mass benchmark",desc="Opt-in native infantry movement benchmark",author="Local project",layer=101,enabled=true}
end
if not gadgetHandler:IsSyncedCode() then return end
local options=Spring.GetModOptions()
if tostring(Spring.GetModOptions().prototype_mixed_force)=='1' then return end

if options.prototype_diagnostic~="benchmark" then return end
local benchmarkUnits={imp_guardsman=true,ork_boy=true,imp_kasrkin=true}
local requestedUnit=options.prototype_benchmark_unit
local unitName=benchmarkUnits[requestedUnit] and requestedUnit or "imp_guardsman"
local stages={100,250,500}
if tostring(options.prototype_benchmark_1000)=="1" then stages[4]=1000 end
local owned,stage,startFrame={},0,0
local latestFPS,latestSim,renderSamples=0,0,0
local lastPositions={}
local stopped=false
local function emit(s) Spring.Echo("40K_BENCH "..s) end
local function clean()
 for _,id in ipairs(owned) do
  if Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id) then Spring.DestroyUnit(id,false,true) end
 end
 owned={};lastPositions={}
end
local function finish(reason)
 if stopped then return end
 stopped=true
 emit(string.format('{"event":"complete","stage":%d,"reason":"%s"}',stage,reason))
 Spring.SetGameRulesParam("40k_benchmark_done",1)
 clean()
end
local function orderMove(reverse)
 for i,id in ipairs(owned) do
  if Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id) then
   local col=(i-1)%32;local row=math.floor((i-1)/32)
   local x=(reverse and 4070 or 4230)+col*16
   local z=(reverse and 850 or 1010)+row*16
   Spring.GiveOrderToUnit(id,CMD.MOVE,{x,Spring.GetGroundHeight(x,z),z},{})
  end
 end
end
local function begin(f)
 clean();stage=stage+1;startFrame=f
 latestFPS,latestSim,renderSamples=0,0,0
 local wanted=stages[stage]
 if not wanted then finish("all_requested_stages_complete");return end
 for i=1,wanted do
  local col=(i-1)%32;local row=math.floor((i-1)/32)
  local x,z=4070+col*16,850+row*16
  if Spring.GetGroundHeight(x,z)<5 then
   finish("dry_plateau_changed");return
  end
  local id=Spring.CreateUnit(unitName,x,Spring.GetGroundHeight(x,z),z,0,0)
  if not id then finish("spawn_failed");return end
  owned[#owned+1]=id
  Spring.SetUnitRulesParam(id,"40k_benchmark_owned",1,{public=true})
  Spring.GiveOrderToUnit(id,CMD.FIRE_STATE,{0},{})
  Spring.GiveOrderToUnit(id,CMD.MOVE_STATE,{0},{})
 end
 Spring.SetGameRulesParam("40k_benchmark_stage",stage)
 Spring.SetGameRulesParam("40k_benchmark_count",wanted)
 Spring.SetGameRulesParam("40k_benchmark_started",f)
 emit(string.format('{"event":"stage_start","stage":%d,"count":%d,"unit":"%s","frame":%d}',stage,wanted,unitName,f))
 orderMove(false)
end
function gadget:RecvLuaMsg(msg)
 if stopped then return end
 local idx,fps,sim=msg:match("^40K_BENCH_RENDER (%d+) ([%d.]+) ([%d.]+)$")
 if idx and tonumber(idx)==stage then
  latestFPS,latestSim=tonumber(fps),tonumber(sim);renderSamples=renderSamples+1
 end
 if msg=="40K_BENCH_ABORT_WALL" then finish("wall_time_safety_abort") end
end
function gadget:GameFrame(f)
 if stopped then return end
 if stage==0 then if f>=90 then begin(f) end;return end
 local age=f-startFrame
 if age>0 and age%360==0 then orderMove(math.floor(age/360)%2==1) end
 if age>=150 and age%30==0 then
  local moving,alive,displacement=0,0,0
  for _,id in ipairs(owned) do
   if Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id) then
    alive=alive+1
    local x,y,z=Spring.GetUnitPosition(id)
    local vx,vy,vz=Spring.GetUnitVelocity(id)
    if vx*vx+vz*vz>0.0025 then moving=moving+1 end
    local old=lastPositions[id]
    if old then displacement=displacement+math.sqrt((x-old[1])^2+(z-old[2])^2) end
    lastPositions[id]={x,z}
   end
  end
  emit(string.format('{"event":"motion","stage":%d,"frame":%d,"alive":%d,"moving":%d,"displacement":%.3f}',stage,f,alive,moving,displacement))
 end
 if age>=1350 then
  emit(string.format('{"event":"stage_end","stage":%d,"count":%d,"fps_last":%.2f,"sim_last":%.3f,"render_samples":%d}',stage,stages[stage],latestFPS,latestSim,renderSamples))
  if renderSamples<10 then finish("render_sampler_missing")
  elseif latestFPS<20 or latestSim<0.8 then finish("performance_safety_gate")
  elseif stage==#stages then finish("all_requested_stages_complete")
  else begin(f) end
 end
end

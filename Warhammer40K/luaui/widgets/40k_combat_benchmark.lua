function widget:GetInfo()
 return {name="40K combat benchmark render sampler",desc="Opt-in native frame intervals and simulation clocks",author="Local project",layer=1004,enabled=true}
end
if Spring.GetModOptions().prototype_diagnostic~="combatbenchmark" then return end
local stage,stageTimer,lastTimer,lastFrame,lastDraw=0,nil,nil,nil,nil
local intervals,recentFPS={},{}
local captures={}
function widget:Initialize() Spring.SendCommands("forcestart") end
local function percentile(sorted,p)
 return sorted[math.max(1,math.ceil(#sorted*p))] or 0
end
function widget:Update()
 if Spring.GetGameRulesParam("40k_combat_benchmark_done")==1 then Spring.SendCommands("quitforce");return end
 local current=Spring.GetGameRulesParam("40k_combat_benchmark_stage") or 0
 if current==0 then return end
 local f=Spring.GetGameFrame();local now=Spring.GetTimer()
 if current~=stage then
  stage=current;stageTimer=now;lastTimer=now;lastDraw=now;lastFrame=f
  intervals,recentFPS={},{}
  local x,z=4415,1050
  Spring.SetCameraState({name="ta",mode=1,px=x,py=Spring.GetGroundHeight(x,z),pz=z,height=1050,angle=.9,flipped=-1},0)
  return
 end
 if lastDraw then intervals[#intervals+1]=Spring.DiffTimers(now,lastDraw)*1000 end
 lastDraw=now
 local wall=Spring.DiffTimers(now,stageTimer)
 if wall>120 then Spring.SendLuaRulesMsg("40K_COMBAT_BENCH_ABORT_WALL");return end
 local elapsed=Spring.DiffTimers(now,lastTimer)
 if elapsed<1 then return end
 local fps=Spring.GetFPS();local sim=(f-lastFrame)/(30*elapsed)
 lastTimer,lastFrame=now,f
 local age=f-(Spring.GetGameRulesParam("40k_combat_benchmark_started") or f)
 if age<150 then intervals={};return end
 if not captures[stage] and age>=300 then Spring.SendCommands("screenshot png");captures[stage]=true end
 table.sort(intervals)
 local at120,at144=0,0
 for _,ms in ipairs(intervals) do if ms<=1000/120 then at120=at120+1 end;if ms<=1000/144 then at144=at144+1 end end
 local n=#intervals
 Spring.Echo(string.format('40K_COMBAT_BENCH {"event":"render","stage":%d,"frame":%d,"fps":%.2f,"sim_ratio":%.4f,"wall_seconds":%.3f,"interval_samples":%d,"frame_ms_p50":%.3f,"frame_ms_p95":%.3f,"frame_ms_p99":%.3f,"fraction_120_budget":%.4f,"fraction_144_budget":%.4f}',stage,f,fps,sim,wall,n,percentile(intervals,.5),percentile(intervals,.95),percentile(intervals,.99),n>0 and at120/n or 0,n>0 and at144/n or 0))
 intervals={}
 recentFPS[#recentFPS+1]=fps;if #recentFPS>5 then table.remove(recentFPS,1) end
 local mean=0;for _,v in ipairs(recentFPS) do mean=mean+v end;mean=mean/#recentFPS
 Spring.SendLuaRulesMsg(string.format("40K_COMBAT_BENCH_RENDER %d %.2f %.4f",stage,mean,sim))
end

function widget:GetInfo()
 return {name="40K benchmark render sampler",desc="Opt-in render and simulation clock measurements",author="Local project",layer=1001,enabled=true}
end
if tostring(Spring.GetModOptions().prototype_mixed_force)=='1' then return end
if Spring.GetModOptions().prototype_diagnostic~="benchmark" then return end
local stage=0
local stageTimer,lastTimer,lastFrame
local fpsTotal,fpsMinimum,samples=0,math.huge,0
local recentFPS={}
local captured={}
local function clock() return Spring.GetTimer() end
function widget:Update()
 if Spring.GetGameRulesParam("40k_benchmark_done")==1 then Spring.SendCommands("quitforce");return end
 local current=Spring.GetGameRulesParam("40k_benchmark_stage") or 0
 if current==0 then return end
 local frame=Spring.GetGameFrame()
 local now=clock()
 if current~=stage then
  stage=current;stageTimer=now;lastTimer=now;lastFrame=frame
  fpsTotal,fpsMinimum,samples=0,math.huge,0
  recentFPS={}
  local x,z=4415,1110
  Spring.SetCameraState({name="ta",mode=1,px=x,py=Spring.GetGroundHeight(x,z),pz=z,height=1050,angle=.9,flipped=-1},0)
  return
 end
 if not captured[stage] and frame-(Spring.GetGameRulesParam("40k_benchmark_started") or frame)>300 then
  Spring.SendCommands("screenshot png");captured[stage]=true
 end
 local wall=Spring.DiffTimers(now,stageTimer)
 if wall>120 then Spring.SendLuaRulesMsg("40K_BENCH_ABORT_WALL");return end
 local elapsed=Spring.DiffTimers(now,lastTimer)
 if elapsed<1 then return end
 local fps=Spring.GetFPS()
 local sim=(frame-lastFrame)/(30*elapsed)
 lastTimer,lastFrame=now,frame
 if frame-(Spring.GetGameRulesParam("40k_benchmark_started") or frame)<150 then return end
 fpsTotal=fpsTotal+fps;fpsMinimum=math.min(fpsMinimum,fps);samples=samples+1
 Spring.Echo(string.format('40K_BENCH {"event":"render","stage":%d,"frame":%d,"fps":%.2f,"fps_running_mean":%.2f,"fps_running_min":%.2f,"sim_ratio":%.3f,"wall_seconds":%.3f}',stage,frame,fps,fpsTotal/samples,fpsMinimum,sim,wall))
 -- Recent samples catch degradation late in a stage without treating one draw hiccup as a trend.
 recentFPS[#recentFPS+1]=fps
 if #recentFPS>5 then table.remove(recentFPS,1) end
 local recentMean=0
 for _,v in ipairs(recentFPS) do recentMean=recentMean+v end
 recentMean=recentMean/#recentFPS
 Spring.SendLuaRulesMsg(string.format("40K_BENCH_RENDER %d %.2f %.3f",stage,recentMean,sim))
end

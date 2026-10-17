function widget:GetInfo()
 return {name='40K movement frame-budget sampler',desc='Opt-in measured frame pacing, no normal gameplay overhead',author='Local project',layer=1005,enabled=true}
end
if Spring.GetModOptions().prototype_diagnostic~='benchmark' then return end
local stage,lastDraw,windowTimer=0,nil,nil
local intervals={}
local function percentile(p)
 return intervals[math.max(1,math.ceil(#intervals*p))] or 0
end
function widget:Update()
 local current=Spring.GetGameRulesParam('40k_benchmark_stage') or 0
 if current==0 then lastDraw=nil;windowTimer=nil;intervals={};return end
 local now=Spring.GetTimer()
 if current~=stage then stage=current;lastDraw=now;windowTimer=now;intervals={};return end
 local started=Spring.GetGameRulesParam('40k_benchmark_started')
 local frame=Spring.GetGameFrame()
 if not started or frame-started<150 then lastDraw=now;windowTimer=now;intervals={};return end
 local ms=Spring.DiffTimers(now,lastDraw)*1000;lastDraw=now
 if ms>0 and ms<math.huge then intervals[#intervals+1]=ms end
 if Spring.DiffTimers(now,windowTimer)<1 then return end
 windowTimer=now
 local at120,at144=0,0
 for _,value in ipairs(intervals) do
  if value<=1000/120 then at120=at120+1 end
  if value<=1000/144 then at144=at144+1 end
 end
 table.sort(intervals)
 Spring.Echo(string.format('40K_FRAME_BUDGET {"event":"render","stage":%d,"frame":%d,"interval_samples":%d,"intervals_120_budget":%d,"intervals_144_budget":%d,"frame_ms_p50":%.4f,"frame_ms_p95":%.4f,"frame_ms_p99":%.4f}',stage,frame,#intervals,at120,at144,percentile(.5),percentile(.95),percentile(.99)))
 intervals={}
end

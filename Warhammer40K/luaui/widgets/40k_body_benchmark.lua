function widget:GetInfo()return{name='40K matched actual-body pacing observer',desc='Default-off bounded read-only diagnostic; no universal FPS acceptance',author='Local project',layer=1008,enabled=true}end
local o=Spring.GetModOptions()or{}
if o.prototype_body_benchmark~=true and o.prototype_body_benchmark~=1 and o.prototype_body_benchmark~='1'then return end
local recorder,codec
function widget:Initialize()
 local ok,result=pcall(function()
  assert(o.prototype_diagnostic=='normal','ordinary_diagnostic_required')
  local M=VFS.Include('40k_configs/body_benchmark.lua');codec=M
  return M.New(Spring,UnitDefs,{source=o.prototype_body_benchmark_source,engineFull=Engine.versionFull,mapChecksum=Game.mapChecksum,gameChecksum=Game.modChecksum,startFrame=tonumber(o.prototype_body_benchmark_start_frame)},
   M.Counts(o.prototype_body_benchmark_counts),tonumber(o.prototype_body_benchmark_intervals),function(row)local text=M.JSON(row);assert(#text<=15360,'native_log_byte_cap');Spring.Echo('40K_BODY_BENCH '..text)end)
 end)
 if not ok then
  local text=codec and codec.JSON{event='refused',reason=tostring(result):sub(1,1000),acceptance=false}or'{"event":"refused","reason":"observer_module_unavailable","acceptance":false}'
  Spring.Echo('40K_BODY_BENCH '..text);widgetHandler:RemoveWidget(self);return
 end
 recorder=result
end
function widget:Update()if recorder then recorder.Update()end end
function widget:Shutdown()if recorder then recorder.Shutdown()end end

function widget:GetInfo() return {name='40K native transport evidence',desc='Read-only native cargo visibility and positions; bounded opt-in completion',author='Local project',layer=1005,enabled=true} end
local opts=Spring.GetModOptions()
if opts.prototype_diagnostic~='roster' or tostring(opts.prototype_transport_review)~='1' then return end
local camera,seen,speedBad,quit=nil,{},false,false
local stages={loaded_hold=true,unloaded_settle=true,post_move=true}
local function log(...) Spring.Echo('40K TRANSPORT VIEW',...) end
function widget:Initialize() camera=Spring.GetCameraState();Spring.SendCommands('forcestart') end
function widget:Shutdown() if camera then Spring.SetCameraState(camera,0) end end
function widget:Update()
 local f=Spring.GetGameFrame();local user,speed,paused=Spring.GetGameSpeed()
 if paused then return end
 if not speed or math.abs(speed-1)>.05 then
  if not speedBad then log('UNKNOWN','actual_native_speed_not_1x',user or -1,speed or -1,f);speedBad=true end
 end
 local truck=Spring.GetGameRulesParam('40k_transport_review_truck')
 local stage=Spring.GetGameRulesParam('40k_transport_review_stage')
 local start=Spring.GetGameRulesParam('40k_transport_review_stage_start') or f
 local result=Spring.GetGameRulesParam('40k_transport_review_result')
 local key=tostring(stage)..':'..start
 if result then key='result';stage='result' end
 if truck and (stages[stage] or result) and f-start>=12 and not seen[key] then
  seen[key]=true
  local x,y,z=Spring.GetUnitPosition(truck)
  if x then
   Spring.SetCameraState({name='free',mode=4,px=x+155,py=y+175,pz=z+220,rx=-.60,ry=-2.53,rz=0,vx=0,vy=0,vz=0,avx=0,avy=0,avz=0},0)
   Spring.SelectUnitArray({truck})
   for i=1,7 do local id=Spring.GetGameRulesParam('40k_transport_review_cargo_'..i)
    if id then
     local visible=Spring.IsUnitVisible and tostring(Spring.IsUnitVisible(id)) or 'unavailable'
     local noDraw=Spring.GetUnitNoDraw and tostring(Spring.GetUnitNoDraw(id)) or 'unavailable'
     log('CARGO_VISIBILITY',stage,id,Spring.GetUnitTransporter(id) or -1,visible,noDraw,Spring.GetUnitPosition(id))
    end
   end
   Spring.SendCommands('screenshot png');log('CAPTURE',stage,f,start,result or 0,'actual_speed',speed or -1)
  else log('UNKNOWN','camera_native_position_missing',stage,f) end
 end
 local ended=Spring.GetGameRulesParam('40k_transport_review_complete_frame')
 if ended and f>=ended+90 and not quit then
  quit=true;log('COMPLETE',result or -1,f,speedBad and 'speed_unknown' or '1x');Spring.SendCommands('quitforce')
 end
end

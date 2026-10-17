function widget:GetInfo()return {name='40K terrain native view',desc='Opted camera and native screenshots only',author='Local project',layer=1005,enabled=true}end
if Spring.GetModOptions().prototype_diagnostic~='terrainreview' then return end
local seen,capture={},nil
function widget:Initialize()Spring.SendCommands('forcestart')end
function widget:Update()
 local f=Spring.GetGameFrame();local id=Spring.GetGameRulesParam('40k_terrain_actor');local phase=Spring.GetGameRulesParam('40k_terrain_phase');local start=Spring.GetGameRulesParam('40k_terrain_phase_frame')
 local key=tostring(id)..':'..tostring(start)
 if id and start and not seen[key] then
  local x,y,z=Spring.GetUnitPosition(id)
  if x then Spring.SetCameraState({mode=4,px=x+120,py=y+85,pz=z+130,rx=-.45,ry=-2.4,rz=0,vx=0,vy=0,vz=0,avx=0,avy=0,avz=0},0);Spring.SelectUnitArray({id});capture={key=key,frame=f,id=id,phase=phase};seen[key]=true end
 end
 if capture and f-capture.frame>=12 then Spring.SendCommands('screenshot png');Spring.Echo('40K TERRAIN CAPTURE',capture.id,capture.phase,f);capture=nil end
end

function widget:GetInfo()
 return {name="40K opt-in map-pack evidence",desc="Independent native camera, captures, readiness and bounded exit",author="Local Recoil Project",layer=1005,enabled=true}
end
if Spring.GetModOptions().prototype_diagnostic~="mappack" then return end
local boot=Spring.GetTimer();local force=false;local captured={};local pending;local finish
local function capture(tag,x,z,height,f)
 Spring.SetCameraState({name="ta",mode=1,px=x,py=Spring.GetGroundHeight(x,z),pz=z,height=height,angle=.8,flipped=-1},0)
 pending={frame=f+12,tag=tag};Spring.Echo("40K MAPPACK CAMERA",tag,x,z,height,f)
end
function widget:Update()
 local f=Spring.GetGameFrame()
 if f==0 and not force and Spring.DiffTimers(Spring.GetTimer(),boot)>5 then
  force=true;Spring.SendCommands("forcestart");Spring.Echo("40K MAPPACK AUTOSTART","opt-in diagnostic only")
 end
 if pending and f>=pending.frame then Spring.SendCommands("screenshot png");Spring.Echo("40K MAPPACK CAPTURE",pending.tag,f);pending=nil end
 if f>=1 and not captured.overview then
  captured.overview=true;capture("overview",Game.mapSizeX/2,Game.mapSizeZ/2,math.max(Game.mapSizeX,Game.mapSizeZ)*.8,f)
 end
 local scene=Spring.GetGameRulesParam("40k_mappack_scene")
 if scene and scene>0 and not captured[scene] then
  captured[scene]=true;capture("source_prop_"..scene,Spring.GetGameRulesParam("40k_mappack_scene_x"),Spring.GetGameRulesParam("40k_mappack_scene_z"),Spring.GetGameRulesParam("40k_mappack_scene_height") or 500,f)
 end
 local result=Spring.GetGameRulesParam("40k_mappack_result") or 0
 if result~=0 and not finish then finish=f+90;Spring.Echo("40K MAPPACK RESULT",result,Spring.GetGameRulesParam("40k_mappack_reason") or "unknown") end
 if finish and f>=finish then Spring.SendCommands("quitforce") end
end

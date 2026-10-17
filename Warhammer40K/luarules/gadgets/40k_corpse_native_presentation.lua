function gadget:GetInfo()return{name='40K default-off corpse presentation',desc='Three genuine zero-currency features; native screenshot requests only',author='Local project',layer=125,enabled=true}end
local o=Spring.GetModOptions()or{}
local M=VFS.Include('40k_configs/corpse_presentation_actor_selector.lua')
if not M.Enabled(o)then return false end
assert(VFS.Include('40k_configs/four_faction_playtest.lua').Enabled(o),'Actual development progression route required')
if not gadgetHandler:IsSyncedCode()then
 local original,pending,changed,capture,done;local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end;local function restore()if original then Spring.SetCameraState(original,0);original=nil end end
 local function camera(_,actor,fid,x,y,z,r,h)
  local spectating,full=Spring.GetSpectatingState();if not spectating or not full then Spring.Echo('40K CORPSE PRESENTATION CAMERA_REFUSED','owned_fullview_spectator_required');return end
  if not original then original=Spring.GetCameraState()end
  local distance=math.max(70,r*3,h*4)
  pending={actor=actor,fid=fid,x=x,y=y,z=z,distance=distance};changed=Spring.GetGameFrame();capture=false
  Spring.SetCameraState({name='free',mode=4,px=x+distance*.78,py=y+distance*.88,pz=z+distance,rx=-.612,ry=-2.48,rz=0,vx=0,vy=0,vz=0,avx=0,avy=0,avz=0},0)
 end
 function gadget:Initialize()gadgetHandler:AddSyncAction('40k_corpse_presentation_camera',camera);gadgetHandler:AddSyncAction('40k_corpse_presentation_done',function()done=true;restore()end)end
 function gadget:DrawScreen()
  if done or not pending or capture or Spring.GetGameFrame()-changed<15 then return end
  local spectator,full=Spring.GetSpectatingState();if not spectator or not full then restore();pending=nil;return end
  local c=Spring.GetCameraState();if c.name~='free'or not finite(c.px)or not finite(c.py)or not finite(c.pz)or not finite(c.rx)or not finite(c.ry)or math.abs(c.px-(pending.x+pending.distance*.78))>.1 or math.abs(c.py-(pending.y+pending.distance*.88))>.1 or math.abs(c.pz-(pending.z+pending.distance))>.1 or math.abs(c.rx+.612)>.01 or math.abs(c.ry+2.48)>.01 then return end
  local x,y,z=Spring.GetFeaturePosition(pending.fid)
  if not x then restore();pending=nil;return end
  local sx,sy=Spring.WorldToScreenCoords(x,y,z);local w,h=Spring.GetViewGeometry()
  if not finite(sx)or not finite(sy)or not finite(w)or not finite(h)or w<=0 or h<=0 or sx<0 or sy<0 or sx>=w or sy>=h then return end
  local kind,id=Spring.TraceScreenRay(sx,sy,false,false,false,false);if kind~='feature'or id~=pending.fid then Spring.Echo('40K CORPSE PRESENTATION TRACE_REFUSED',pending.actor,kind,tostring(id));return end
  capture=true;Spring.SendCommands('screenshot png')
  Spring.Echo('40K CORPSE PRESENTATION PNG_REQUEST',pending.actor,pending.fid,Spring.GetGameFrame(),'settle',Spring.GetGameFrame()-changed,'world',x,y,z,'camera',c.name,c.px,c.py,c.pz,c.rx,c.ry,'fullview',full,'renderAccepted=false','image_write_unconfirmed')
 end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction('40k_corpse_presentation_camera');gadgetHandler:RemoveSyncAction('40k_corpse_presentation_done');restore()end
 return
end
local fixture,start,failed
local function stop(reason)if failed then return end;failed=true;Spring.Echo('40K CORPSE PRESENTATION END',reason,'nativeAccepted=false','renderAccepted=false','paid=false','death=false');SendToUnsynced('40k_corpse_presentation_done');Spring.SetGameRulesParam('40k_corpse_presentation_finished',1)end
function gadget:Initialize()
 local ok,error=pcall(function()local rows=M.Admit(o,FeatureDefs);fixture=M.New(Spring,FeatureDefs,rows,Game.mapSizeX,Game.mapSizeZ);fixture.Begin();fixture.Check(true);start=Spring.GetGameFrame()end)
 if not ok then stop('REFUSED '..tostring(error));if fixture then fixture.Cleanup()end end
end
function gadget:GameFrame(f)
 if failed or not start then return end
 local ok,error=pcall(fixture.Check);if not ok then stop('REFUSED '..tostring(error));fixture.Cleanup();return end
 local elapsed=f-start
 if elapsed==30 or elapsed==120 or (elapsed==210 and #fixture.owned==3) then fixture.Check(true);local row=fixture.owned[(elapsed-30)/90+1];local x,y,z=Spring.GetFeaturePosition(row.fid);SendToUnsynced('40k_corpse_presentation_camera',row.actor,row.fid,x,y,z,Spring.GetFeatureRadius(row.fid),Spring.GetFeatureHeight(row.fid))end
 if elapsed>=300 then stop('BOUNDED_FEATURE_READBACK_COMPLETE')end
end
function gadget:FeatureDestroyed(fid)if fixture then fixture.FeatureDestroyed(fid)end end
function gadget:Shutdown()if fixture then fixture.Cleanup()end end

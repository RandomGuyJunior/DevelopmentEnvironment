function widget:GetInfo()return {name='40K walker visual opportunities',desc='Fixed explicit source view; no physical input',author='Local project',layer=1005,enabled=true}end
if Spring.GetModOptions().prototype_diagnostic~='walkreview' then return end
local seen={};local pending
function widget:Initialize()Spring.SendCommands('forcestart')end
function widget:Update()
 local f=Spring.GetGameFrame()
 for n=1,4 do local planned=210+(n-1)*66
  if f>=planned and not seen[n] then seen[n]=true;local id=Spring.GetGameRulesParam('40k_walk_review_actor_'..n)
   local x,y,z;if id then x,y,z=Spring.GetUnitPosition(id)end
   if x then
    Spring.SetCameraState({mode=4,px=x+80,py=y+50,pz=z+100,rx=math.atan2(-42,math.sqrt(16400)),ry=math.atan2(-80,-100),rz=0,fov=45,vx=0,vy=0,vz=0,avx=0,avy=0,avz=0,gndLock=false,gravity=0,autoTilt=0},0)
    Spring.SelectUnitArray({id});pending={id=id,frame=f,remaining=3,next=f+12,index=n}
   end
  end
 end
 if pending and f>=pending.next then Spring.SendCommands('screenshot png');Spring.Echo('40K WALK VIEW','CAPTURE',pending.index,pending.id,f,pending.remaining)
  pending.remaining=pending.remaining-1;pending.next=f+12;if pending.remaining==0 then pending=nil end
 end
end

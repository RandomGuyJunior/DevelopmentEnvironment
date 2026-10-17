function widget:GetInfo() return {name="40K opt-in match evidence",desc="Native factory and centre combat captures",author="Local project",layer=1002,enabled=true} end
local mode=Spring.GetModOptions().prototype_diagnostic
if mode~="demo" and mode~="production" then return end
if tostring(Spring.GetModOptions().prototype_eta_review)=='1' then return false end
local captured={}
local pendingCapture
function widget:Update()
 local f=Spring.GetGameFrame()
 if pendingCapture and f>=pendingCapture.frame then
  Spring.SendCommands("screenshot png");Spring.Echo("40K MATCH CAPTURE",mode,f,pendingCapture.x,pendingCapture.z)
  pendingCapture=nil
 end
 local interval=mode=="production" and 1800 or 3600
 local slot=math.floor(f/interval)
 if slot<1 or captured[slot] then return end
 captured[slot]=true
 local x,z=2462,2323
 if mode=="production" and slot<=2 then
  for _,id in ipairs(Spring.GetTeamUnits(0)) do
   local name=UnitDefs[Spring.GetUnitDefID(id)].name
   if (slot==1 and (name=="wh40k_armlab" or name=="wh40k_corlab")) or (slot==2 and (name=="wh40k_armvp" or name=="corvp")) then
    local ux,uy,uz=Spring.GetUnitPosition(id);x,z=ux,uz;Spring.SelectUnitArray({id});break
   end
  end
 end
 Spring.SetCameraState({name="ta",mode=1,px=x,py=Spring.GetGroundHeight(x,z),pz=z,height=750,angle=.9,flipped=-1},0)
 pendingCapture={frame=f+9,x=x,z=z}
end

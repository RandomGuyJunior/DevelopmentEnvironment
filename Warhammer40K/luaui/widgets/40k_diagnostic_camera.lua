function widget:GetInfo() return {name="40K diagnostic evidence",desc="Opt-in native render captures",author="Local project",layer=999,enabled=true} end
local mode=Spring.GetModOptions().prototype_diagnostic
if mode~="six" then return end
-- The explicit runtime review owns its camera and requested lifecycle.
if tostring(Spring.GetModOptions().prototype_runtime_library_review)=="1"then return end
local captures={}
function widget:Update()
 local f=Spring.GetGameFrame()
 local phase=f<300 and "idle" or f<900 and "walk" or "fire"
 -- Each unit gets a close view in all three native animation states.
 local offset=phase=="idle" and 110 or phase=="walk" and 340 or 1020
 local spacing=phase=="fire" and 180 or 20
 local slot=math.floor((f-offset)/spacing)+1
 if slot>=1 and slot<=6 then
  local key=phase..slot
  for _,id in ipairs(Spring.GetAllUnits()) do
   if Spring.GetUnitRulesParam(id,"40k_diagnostic_slot")==slot then
    local x,y,z=Spring.GetUnitPosition(id)
    local applied=Spring.SetCameraState({name="free",mode=4,px=x+(slot==3 and 70 or 35),py=y+(slot==3 and 75 or 40),pz=z+(slot==3 and 90 or 45),rx=-.612,ry=-2.48,rz=0,vx=0,vy=0,vz=0,avx=0,avy=0,avz=0},0)
    if not captures[key] and f>=offset+(slot-1)*spacing+5 and (phase~="fire" or f-(Spring.GetUnitRulesParam(id,"40k_last_shot") or -1000)>=1 and f-(Spring.GetUnitRulesParam(id,"40k_last_shot") or -1000)<=2) then
     Spring.SendCommands("screenshot png");captures[key]=true
     local state=Spring.GetCameraState();Spring.Echo("40K CAMERA",state.name,state.px,state.py,state.pz,state.height,state.rx,state.ry)
     Spring.Echo("40K CAPTURE",phase,slot,applied,UnitDefs[Spring.GetUnitDefID(id)].name)
    end
    break
   end
  end
 end
 if f>=2200 and f<2440 then
  for _,id in ipairs(Spring.GetAllUnits()) do
   if Spring.GetUnitRulesParam(id,"40k_diagnostic_slot")==3 then
    local x,y,z=Spring.GetUnitPosition(id)
    Spring.SetCameraState({name="free",mode=4,px=x+70,py=y+75,pz=z+90,rx=-.612,ry=-2.48,rz=0},0)
    local key="attachment"..tostring(Spring.GetUnitRulesParam(id,"40k_attachment_pose"))
    if f%60>=15 and not captures[key] then Spring.SendCommands("screenshot png");captures[key]=true;Spring.Echo("40K CAPTURE",key) end
   end
  end
 end
 if f>2500 then Spring.SendCommands("quitforce") end
end

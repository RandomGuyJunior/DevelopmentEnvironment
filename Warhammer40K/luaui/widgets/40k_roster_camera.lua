function widget:GetInfo() return {name='40K opt-in roster close evidence',desc='Native idle walk fire melee and attachment captures',author='Local project',layer=1004,enabled=true} end
if Spring.GetModOptions().prototype_diagnostic~='roster' then return end
-- Dedicated real cargo fixture owns completion only under this explicit opt-in.
if tostring(Spring.GetModOptions().prototype_transport_review)=='1' then return end
local captures={};local active
-- Explicit native visual review only; ordinary roster captures are unchanged.
local gaitReview=tostring(Spring.GetModOptions().prototype_gait_review)=='1'
local gaitTimes={24,36,48,60,72,84}
local gaitSeen={};local gaitOrigins={}
local function gaitEvidence(id,ud,f,start,x,y,z)
 local age=f-start
 local identity=ud.name..':'..id..':'..start
 local origin=gaitOrigins[identity]
 if not origin then origin={x,z};gaitOrigins[identity]=origin end
 local vx,vy,vz=Spring.GetUnitVelocity(id)
 vx,vy,vz=vx or 0,vy or 0,vz or 0
 local speed=math.sqrt(vx*vx+vz*vz)
 local distance=math.sqrt((x-origin[1])^2+(z-origin[2])^2)
 for _,planned in ipairs(gaitTimes) do
  local key=identity..':'..planned
  if age>=planned and not gaitSeen[key] then
   gaitSeen[key]=true
   -- A late Update cannot fabricate six distinct frames from one pose.
   if age>planned+3 then
    Spring.Echo('40K GAIT MISSED',ud.name,id,planned,age)
   elseif speed<=.001 or distance<=.01 then
    Spring.Echo('40K GAIT NO MOTION',ud.name,id,planned,age,speed,distance)
   else
    Spring.SelectUnitArray({id});Spring.SendCommands('screenshot png')
    Spring.Echo('40K GAIT FRAME',ud.name,id,f,start,planned,x,y,z,vx,vy,vz,distance)
    if Spring.GetUnitPieceMatrix and Spring.GetUnitPieceMap then
     local pieces=Spring.GetUnitPieceMap(id) or {}
     local names={}
     for name in pairs(pieces) do
      local lower=name:lower()
      if lower:find('pelvis',1,true) or lower:find('thigh',1,true) or lower:find('calf',1,true) or lower:find('foot',1,true) or lower:find('hip',1,true) then names[#names+1]=name end
     end
     table.sort(names)
     local count=0
     for _,name in ipairs(names) do
      local m={Spring.GetUnitPieceMatrix(id,pieces[name])}
      if #m==16 then
       count=count+1;Spring.Echo('40K GAIT MATRIX',ud.name,id,f,name,unpack(m))
      end
     end
     Spring.Echo('40K GAIT READBACK',ud.name,id,f,count)
    else Spring.Echo('40K GAIT READBACK UNAVAILABLE',ud.name,id,f) end
   end
  end
 end
end
local completed=false
local bounded=(tonumber(Spring.GetModOptions().prototype_test_end_frame) or 0)>0
function widget:Initialize() Spring.SendCommands("forcestart") end
function widget:Update()
 local f=Spring.GetGameFrame()
 local done=Spring.GetGameRulesParam('40k_roster_validation_complete')
 if bounded and done and f>done+30 and not completed then
  completed=true;Spring.Echo('40K ROSTER native suite ended',f);Spring.SendCommands('quitforce')
 end
 if not active or not Spring.ValidUnitID(active) or Spring.GetUnitIsDead(active) then
  active=nil
  for _,id in ipairs(Spring.GetAllUnits()) do if Spring.GetUnitRulesParam(id,'40k_roster_validation') then active=id;break end end
 end
 if not active then return end
 local phase=Spring.GetUnitRulesParam(active,'40k_roster_phase');local start=Spring.GetUnitRulesParam(active,'40k_roster_phase_start') or f
 local mount=Spring.GetUnitRulesParam(active,'40k_roster_mount') or 0
 local def=Spring.GetUnitDefID(active);local ud=def and UnitDefs[def];if not ud then return end
 local x,y,z=Spring.GetUnitPosition(active);if not x then return end
 local radius=math.max(14,Spring.GetUnitRadius(active) or 20);local height=Spring.GetUnitHeight(active) or 20
 local d=math.max(35,radius*2.6,height*1.8)
 Spring.SetCameraState({name='free',mode=4,px=x+d*.78,py=y+d*.88,pz=z+d,rx=-.612,ry=-2.48,rz=0,vx=0,vy=0,vz=0,avx=0,avy=0,avz=0},0)
 -- The opt-in sequence owns walk screenshots: a second capture in this same
 -- Update can stall rendering and lose the next genuine pose.
 if gaitReview and phase=='walk' then
  gaitEvidence(active,ud,f,start,x,y,z)
  return
 end
 local key=ud.name..':'..tostring(phase)..':'..mount
 local shot=Spring.GetUnitRulesParam(active,'40k_last_shot_'..mount) or -1000
 -- Let native post-spawn material/foundation presentation settle before idle QA.
 local captureAge=phase=='idle' and 60 or 24
 local ready=(phase=='fire' or phase=='melee') and f-shot>=1 and f-shot<=3 or phase~='fire' and phase~='melee' and f-start>=captureAge
 if (phase=='fire' or phase=='melee') and f-start>=120 and shot<start then ready=true;key=key..':no_shot' end
 if ready and not captures[key] then
  Spring.SelectUnitArray({active});Spring.SendCommands('screenshot png');captures[key]=true
  Spring.Echo('40K ROSTER CAPTURE',ud.name,phase,mount,f,'camera_distance',d,'native_radius',radius,'native_height',height)
 end
end

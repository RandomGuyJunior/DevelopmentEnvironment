-- Exactly selected diagnostic actors only; screenshots are visual receipts, not acceptance.
function widget:GetInfo()return {name='40K Night point diagnostic camera',desc='Native diagnostic PNGs and settled actor/camera readback',author='Local project',layer=1005,enabled=true}end
local o=Spring.GetModOptions()or{}
if o.prototype_diagnostic~='roster'or not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(o.prototype_source_progression)or o.prototype_roster_filter~='nec_nightbringer'or tonumber(o.prototype_test_speed or 1)~=1 then return end
local original;local phase,changed;local captures={}
local function emit(...)Spring.Echo('40K NIGHT POINT PNG',Spring.GetGameFrame(),...)end
function widget:Initialize()original=Spring.GetCameraState()end
function widget:Update()
 local f=Spring.GetGameFrame();local actor=Spring.GetGameRulesParam('40k_night_point_actor');local p=Spring.GetGameRulesParam('40k_night_point_phase')
 if not actor or not p or not Spring.ValidUnitID(actor)or Spring.GetUnitIsDead(actor)then return end
 local def=Spring.GetUnitDefID(actor);if not def or UnitDefs[def].name~='nec_nightbringer'then return end
 local x,y,z=Spring.GetUnitPosition(actor);if not x then return end
 if p==8 and phase==7 then phase=8 end -- Preserve the already settled ground camera through impact hold.
 if p~=phase then
  phase=p;changed=f
  local radius,height=Spring.GetUnitRadius(actor),Spring.GetUnitHeight(actor)
  local dimensions=Spring.GetUnitDefDimensions(def) -- Only the actual born actor's model.
  emit('ACTUAL_MODEL',actor,def,radius,height,dimensions and dimensions.radius,dimensions and dimensions.height)
  local distance=math.max(300,(radius or 20)*4,(height or 20)*3)
  Spring.SetCameraState({name='free',mode=4,px=x+distance*.78,py=y+distance*.88,pz=z+distance,rx=-.612,ry=-2.48,rz=0,vx=0,vy=0,vz=0,avx=0,avy=0,avz=0},0)
  Spring.SelectUnitArray({actor})
 end
 if f-changed<9 then return end
 local group=(p==2 or p==5)and 'target_fire'or(p==7 or p==8)and 'ground_fire'or nil
 if not group then return end
 local shot=Spring.GetGameRulesParam('40k_night_point_last_projectile_frame')or -1000
 local impact=Spring.GetGameRulesParam('40k_night_point_last_impact_frame')or -1000
 local key=group..':'..(f-shot>=0 and f-shot<=3 and 'projectile'or f-impact>=0 and f-impact<=3 and 'impact'or 'settled')
 if captures[key]then return end
 if key:find('settled',1,true)and f-changed<30 then return end
 captures[key]=true;Spring.SendCommands('screenshot png')
 local c=Spring.GetCameraState();emit('NATIVE_SCREENSHOT_REQUEST',key,actor,'settle_frames',f-changed,'world',x,y,z,'camera',c.name,c.mode,c.px,c.py,c.pz,c.rx,c.ry,'native_projectile_frame',shot,'native_impact_frame',impact)
end
function widget:Shutdown()if original then Spring.SetCameraState(original,0)end end

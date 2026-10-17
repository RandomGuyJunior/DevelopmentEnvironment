function widget:GetInfo()
 return{name='40K owned squad visual evidence',desc='Camera captures only in explicit automated paid diagnostic',author='Local project',layer=110,enabled=true}
end
local S=Spring
local options=S.GetModOptions()or{}
local enabled=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled
if not enabled(options.prototype_squad_paid_fixture)then return false end
-- The separate rendered-gait witness owns this diagnostic camera/capture lane.
-- Other paid runs retain the unchanged full-squad and fallen-body evidence.
if enabled(options.prototype_gait_movement_fixture)and enabled(options.prototype_animation_interpolation)and enabled(options.prototype_fractional_walk_sampling)then return false end
local taken={};local pending
local function focus(tag,x,y,z,height)
 S.SetCameraState({name='ta',mode=1,px=x,py=y,pz=z,height=height,angle=.9,flipped=-1},0)
 pending={tag=tag,frame=S.GetGameFrame()+12};taken[tag]=true
end
function widget:GameFrame(frame)
 if pending then
  if frame>=pending.frame then S.SendCommands('screenshot png');S.Echo('40K_SQUAD_VISUAL '..pending.tag..' frame='..frame..' diagnostic_camera_only=true');pending=nil end
  return
 end
 if not taken.full_squad then
  for _,id in ipairs(S.GetAllUnits()or{})do
   local n=S.GetUnitRulesParam(id,'40k_squad_living');local capacity=S.GetUnitRulesParam(id,'40k_squad_capacity')
   if n and n==capacity and capacity>1 then
    local x,y,z=S.GetUnitPosition(id);if x then focus('full_squad',x,y,z,250);return end
   end
  end
 elseif not taken.fallen_body then
  for _,id in ipairs(S.GetAllFeatures()or{})do
   local d=FeatureDefs[S.GetFeatureDefID(id)];local cp=d and d.customParams or{}
   if tonumber(cp.prototype40k_tactical_remains)==1 then
    local x,y,z=S.GetFeaturePosition(id);if x then focus('fallen_body',x,y,z,145);return end
   end
  end
 end
end

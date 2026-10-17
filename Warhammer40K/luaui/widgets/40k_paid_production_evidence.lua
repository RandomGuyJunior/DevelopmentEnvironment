function widget:GetInfo()
 return {name='40K opt-in paid production evidence',desc='Native paid faction suite start and bounded result capture',author='Local project',layer=1004,enabled=true}
end
local mode=Spring.GetModOptions().prototype_diagnostic
if mode~='expandedproduction' and mode~='vital' then return end
local observed,closeFrame=nil,nil
function widget:Initialize() Spring.SendCommands('forcestart') end
function widget:Update()
 local frame=Spring.GetGameFrame()
 local names={'40k_vital_production_result','40k_necron_production_result','40k_strategic_result'}
 for _,name in ipairs(names) do
  local result=Spring.GetGameRulesParam(name)
  if result and result~=0 and not observed then
   observed=name;closeFrame=frame+90
   Spring.Echo('40K PAID PRODUCTION RESULT',name,result,frame)
   Spring.SendCommands('screenshot png')
  end
 end
 if closeFrame and frame>=closeFrame then Spring.SendCommands('quitforce') end
end

-- Opt-in read-only evidence, never orders, resource setters or script calls.
function gadget:GetInfo()
 return {name='40K converter observer',desc='Observe paid source conversion',author='Local project',layer=100,enabled=true}
end
if not gadgetHandler:IsSyncedCode() or Spring.GetModOptions().prototype_diagnostic~='expandedproduction' then return false end
local eligible={}
for id,d in pairs(UnitDefs) do
 local cp=d.customParams or {}
 if (cp.prototype40k==true or cp.prototype40k==1 or cp.prototype40k=='1') and cp.prototype40k_vital=='converter' then
  local cap,eff=tonumber(cp.energyconv_capacity),tonumber(cp.energyconv_efficiency)
  if cap and cap>0 and eff and eff>0 then eligible[id]={capacity=cap,efficiency=eff,name=d.name} end
 end
end
local tracked={};local count=0;local limit=32
local function track(id,def,frame)
 if not tracked[id] and eligible[def] and count<limit then
  count=count+1;tracked[id]={def=def,finished=frame,consecutive=0}
 end
end
function gadget:Initialize()
 local frame=Spring.GetGameFrame()
 for _,id in ipairs(Spring.GetAllUnits()) do
  local _,_,_,_,progress=Spring.GetUnitHealth(id)
  if progress and progress>=1 then track(id,Spring.GetUnitDefID(id),frame) end
 end
end
function gadget:UnitFinished(id,def) track(id,def,Spring.GetGameFrame()) end
function gadget:UnitDestroyed(id) tracked[id]=nil end
function gadget:GameFrame(frame)
 if frame%30~=0 then return end
 for id,state in pairs(tracked) do
  if not (state.off and state.passed) then
   local d=eligible[state.def];local team=Spring.GetUnitTeam(id)
   local _,_,_,_,progress=Spring.GetUnitHealth(id)
   if team and progress and progress>=1 then
    local make,metalUse,energyMake,use=Spring.GetUnitResources(id)
    local current,storage=Spring.GetTeamResources(team,'energy')
    local capacity=Spring.GetTeamRulesParam(team,'mmCapacity')
    local usage=Spring.GetTeamRulesParam(team,'mmUse')
    local efficiency=Spring.GetTeamRulesParam(team,'mmAvgEffi')
    local level=Spring.GetTeamRulesParam(team,'mmLevel')
    local status=Spring.GetUnitRulesParam(id,'prototype40k_conversion_active')
    local active=Spring.GetUnitIsActive(id)
    local stunned=Spring.GetUnitIsStunned(id)
    local observed=make and use and make>0 and use>0 and use<=d.capacity+1e-6
      and math.abs(make/use-d.efficiency)<=math.max(1e-6,d.efficiency*.02)
      and status==1 and active==true and not stunned and capacity and capacity>0 and usage and usage>0
      and efficiency and efficiency>0 and level and level>=0 and level<=1
      and frame-state.finished>=30
    state.consecutive=observed and state.consecutive+1 or 0
    local result
    if make and use and math.abs(make)<1e-6 and math.abs(use)<1e-6 and not state.off then
     state.off=true;result='OBSERVED_OFF_SAMPLE'
    elseif state.consecutive>=2 and not state.passed then
     state.passed=true;result='OBSERVED_ACTIVE_PASS'
     Spring.SetGameRulesParam('40k_converter_observed_active_'..team,1)
    end
    if result then
     Spring.Echo('40K CONVERTER '..result..' frame='..frame..' id='..id..' def='..tostring(d.name)..' team='..team
      ..' progress='..progress..' active='..tostring(active)..' stunned='..tostring(stunned)..' status='..tostring(status)
      ..' metalMake='..tostring(make)..' metalUse='..tostring(metalUse)..' energyMake='..tostring(energyMake)..' energyUse='..tostring(use)
      ..' capacity='..d.capacity..' efficiency='..d.efficiency..' eCurrent='..tostring(current)..' eStorage='..tostring(storage)
      ..' mmCapacity='..tostring(capacity)..' mmUse='..tostring(usage)..' mmAvgEffi='..tostring(efficiency)..' mmLevel='..tostring(level))
    end
   else state.consecutive=0 end
  end
 end
end

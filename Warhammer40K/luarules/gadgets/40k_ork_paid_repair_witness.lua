function gadget:GetInfo()return{name='40K Ork paid repair read-only witness',desc='Default-off admission/fallback counters before squad handling',author='Local project',layer=39,enabled=true}end
local options=Spring.GetModOptions()or{}
local development=VFS.Include('40k_configs/development_playtest.lua')
if not development.OptionEnabled(options.prototype_ork_squad_paid_research_fixture)or not development.Enabled(options)or not development.OptionEnabled(options.prototype_source_progression)then return false end
if not gadgetHandler:IsSyncedCode()then return false end
local S=Spring;local witness={}
function gadget:Initialize()GG.Recoil40KOrkRepairWitness=witness end
function gadget:Shutdown()if GG.Recoil40KOrkRepairWitness==witness then GG.Recoil40KOrkRepairWitness=nil end end
local function relevant(def,cmd,params)
 local R=GG.Recoil40KSquads
 if not R or not UnitDefs[def].isBuilder or not params or #params~=1 then return false end
 return(cmd==CMD.REPAIR and R.Get(params[1]))or(cmd==34591 and R.squads[params[1]])
end
function gadget:AllowCommand(id,def,owner,cmd,params,opts)
 if relevant(def,cmd,params)then
  local row=witness[id]or{fallback=0};witness[id]=row
  S.Echo('40K_ORK_SQUAD_PAID_RESEARCH REPAIR_COMMAND_OBSERVED frame='..S.GetGameFrame()..' builder='..id..' id='..cmd..' param='..params[1]..' coded='..tostring(opts and opts.coded)..' observer_does_not_decide_admission=true')
 end
 return true
end
function gadget:CommandFallback(id,def,owner,cmd,params)
 if relevant(def,cmd,params)and cmd==34591 then
  local row=witness[id]or{fallback=0};witness[id]=row;row.fallback=row.fallback+1
 end
 return false
end

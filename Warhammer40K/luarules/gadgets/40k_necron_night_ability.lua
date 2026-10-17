function gadget:GetInfo()return{name='40K source Night ability',desc='Paid Invulnerability and explicit native regeneration adaptation',author='Local project',layer=65,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return end
local o=Spring.GetModOptions()or{}
if not(VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(o.prototype_source_progression))then return end
local M=VFS.Include('40k_configs/necron_night_ability.lua');local A,night;local lastResearch
local function ready()
 local R=GG.Recoil40KResearch;local relic=UnitDefNames['40k_relic_objective']
 local d=night and UnitDefs[night.id]
 -- Pinned native idleAutoHeal defaults10; refuse double regeneration.
 if not d or d.autoHeal~=0 or d.idleAutoHeal~=0 then return false end
 return R and type(R.HasResearch)=='function' and night and relic
  and VFS.FileExists('objects3d/nec_nightbringer.glb') and VFS.FileExists('scripts/generated/nec_nightbringer_anim.lua')
  and GG.Recoil40KRelicCapture and type(GG.Recoil40KRelicCapture.Owned)=='function' and true or false
end
local function desc(id)
 if Spring.GetUnitDefID(id)~=night.id then return end
 local allowed=A.CanActivate(id,Spring.GetGameFrame());local d={id=M.Command,type=CMDTYPE.ICON,name='Invulnerability',action='40knightinvulnerable',tooltip='Paid Nightbringer upgrade: 15 seconds immune to health damage; 90-second recharge',disabled=not allowed}
 local idx=Spring.FindUnitCmdDesc(id,M.Command);if idx then Spring.EditUnitCmdDesc(id,idx,d)else Spring.InsertUnitCmdDesc(id,d)end
end
function gadget:Initialize()
 gadgetHandler:RegisterCMDID(M.Command)
 night=UnitDefNames.nec_nightbringer;if not night then gadgetHandler:RemoveGadget(self);return end
 A=M.New(Spring,{nightDef=night.id,lordDef=UnitDefNames.nec_lord and UnitDefNames.nec_lord.id,fps=Game.gameSpeed or 30,Ready=ready,
 HasResearch=function(team,key)return GG.Recoil40KResearch and GG.Recoil40KResearch.HasResearch(team,key)==true end,
 Regenerated=function(...)local journal=GG.Recoil40KNightRegenObserver;if type(journal)=='function'then journal(...)end end,
 PaidCompletionValid=function(team,key,producer)
  -- Root common paid controller supplies the transaction-head witness; never
  -- equate a descriptor, team resources or a file with payment completion.
  local P=GG.Recoil40KNightPaidCompletion;return type(P)=='function'and P(team,key,producer)==true
 end})
 GG.Recoil40KNightAbility=A
 for _,id in ipairs(Spring.GetAllUnits()or{})do A.Restore(id);if Spring.GetUnitDefID(id)==night.id then desc(id)end end
end
function gadget:GameFrame(f)
 if ready()and lastResearch~=GG.Recoil40KResearch then
  lastResearch=GG.Recoil40KResearch
  -- Registration only when root has installed the actual paid record/whole-effect callbacks.
  if lastResearch.NightRefreshHandlers then lastResearch.NightRefreshHandlers()end
 end
 A.Frame(f);if f%30==0 then for _,id in ipairs(Spring.GetAllUnits()or{})do if Spring.GetUnitDefID(id)==night.id then desc(id)end end end
end
function gadget:UnitFinished(id,def)if def==night.id then desc(id)end end
function gadget:AllowCommand(id,def,team,cmd,params)
 if cmd~=M.Command then return true end
 if def~=night.id or params and #params>0 then return false end
 A.Activate(id,Spring.GetGameFrame());desc(id);return false
end
function gadget:UnitPreDamaged(id,def,team,damage,paralyzer,weapon,projectile,attacker)
 if def==night.id and not paralyzer and damage>=0 and A.IsActive(id,Spring.GetGameFrame())then
  if damage>0 and o.prototype_source_acceptance=='necrons'and type(GG.Recoil40KNightDamageRefusal)=='function'then
   local hp,max=Spring.GetUnitHealth(id);local xp=Spring.GetUnitExperience(id)
   GG.Recoil40KNightDamageRefusal(id,Spring.GetGameFrame(),damage,weapon,projectile,attacker,hp,max,xp)
  end
  return 0,0
 end
end
function gadget:UnitDestroyed(id)A.UnitDestroyed(id)end
function gadget:UnitTaken(id)A.UnitTransferred(id)end
function gadget:UnitGiven(id)A.UnitTransferred(id)end
function gadget:Shutdown()if GG.Recoil40KNightAbility==A then GG.Recoil40KNightAbility=nil end end

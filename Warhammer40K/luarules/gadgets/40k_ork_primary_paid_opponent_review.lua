function gadget:GetInfo()return {name='40K scoped paid primary opponent',desc='Ordinary paid source target; no aggressive AI/grants',author='Local project',layer=110,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return false end
local options=Spring.GetModOptions()or{}
local module=VFS.Include('40k_configs/ork_primary_paid_opponent_review.lua')
if not module.Enabled(options)then return false end
local P
function gadget:Initialize()
 if not GG.Recoil40KResearch then GG.Recoil40KPrimaryPaidOpponentFailure='actual_paid_controller_missing';return end
 P=module.New(Spring,UnitDefs,UnitDefNames,CMD,GG.Recoil40KResearch,options,function(...)Spring.Echo('40K PAID PRIMARY OPPONENT',...)end,VFS.Include('scripts/generated/ork_source_consumer_bundle_evidence.lua'))
 GG.Recoil40KPrimaryPaidOpponent=P
end
function gadget:UnitCreated(id,def,team,builder)if P then P.Birth(id,def,team,builder,Spring.GetGameFrame())end end
function gadget:UnitFinished(id,def,team)if P then P.Finished(id,def,team)end end
function gadget:GameFrame(frame)
 if not P then return end
 local okay,why=P.Frame(frame);if not okay then GG.Recoil40KPrimaryPaidOpponentFailure=why or P.Failure()end
end

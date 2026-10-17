function gadget:GetInfo()return{name='40K owned aircraft bombard review',desc='Exact paid source bombard native projectile adaptation',author='Local Recoil Project',layer=1,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return end
local options=Spring.GetModOptions()
if tostring(options.prototype_ork_aircraft_review)~='1'or not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(options.prototype_source_progression)or options.prototype_source_acceptance~='orks'then return false end
if not VFS.FileExists('scripts/generated/ork_aircraft_source_facts.lua')or not WeaponDefNames.ork_nuke_bomba_bombard then return false end
local M=VFS.Include('40k_configs/ork_nukklear_bombard_native.lua')
local Codec=VFS.Include('40k_configs/primary_variant_native.lua')
local F=VFS.Include('scripts/generated/ork_aircraft_source_facts.lua')
local R=M.New(Spring,UnitDefs,WeaponDefNames,F,Codec,function()return GG.Recoil40KResearch end,Game)
local function register(id,def)
 local d=UnitDefs[def];if not d or d.name~='ork_nuke_bomba'then return end
 Spring.InsertUnitCmdDesc(id,{id=M.Command,type=CMDTYPE.ICON_MAP,name='Nukklear Bombard',action='nukklearbombard',tooltip='1750 metal / 8750 energy; 600 second recharge; genuine native projectile'})
end
function gadget:Initialize()
 local okay,why=R.Start(true);if not okay then Spring.Echo('40K NUKKLEAR BOMBARD REFUSED',why);gadgetHandler:RemoveGadget(self);return end
 gadgetHandler:RegisterCMDID(M.Command);GG.Recoil40KNukklearBombard=R
 for _,id in ipairs(Spring.GetAllUnits())do register(id,Spring.GetUnitDefID(id))end
end
function gadget:Shutdown()if GG.Recoil40KNukklearBombard==R then GG.Recoil40KNukklearBombard=nil end end
function gadget:UnitCreated(id,def)register(id,def)end
function gadget:UnitDestroyed(id)R.Removed(id)end
function gadget:UnitTaken(id)R.Transferred(id)end
function gadget:UnitGiven(id)R.Transferred(id)end
function gadget:GameFrame(frame)R.Frame(frame)end
function gadget:UnitDamaged(id,def,team,damage,paralyzer,weapon,projectile)if not paralyzer then R.Damaged(id,damage,weapon,projectile,Spring.GetGameFrame())end end
function gadget:AllowCommand(id,def,team,cmd,params)
 if cmd==M.Command then local okay,why=R.Request(id,team,params,Spring.GetGameFrame());Spring.Echo('40K NUKKLEAR BOMBARD REQUEST',Spring.GetGameFrame(),id,okay,why or 'paid_pending');return false end
 if cmd==CMD.STOP then R.Cancel(id);return true end
 if R.Busy(id,Spring.GetGameFrame())then return false end
 return true
end

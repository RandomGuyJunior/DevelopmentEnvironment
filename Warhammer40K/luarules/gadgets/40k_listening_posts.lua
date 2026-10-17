function gadget:GetInfo()
 return{name='40K local listening-post fortification',desc='Paid native post upgrades with genuine completed stages',author='Local project',layer=51,enabled=true}
end
if not gadgetHandler:IsSyncedCode()then return false end
local wanted=false
for _,d in pairs(UnitDefs)do if tostring((d.customParams or{}).listening_post_version)=='1'then wanted=true;break end end
if not wanted then return false end
local attached=false
local function attach()
 local c=GG.Recoil40KResearch
 if not c then return false end
 assert(c.nativeHealthEffects and c.RefreshHealth,'Listening posts require the common native health owner')
 local config=VFS.Include('40k_configs/listening_post_profiles.lua')
 VFS.Include('40k_configs/listening_post_native.lua').Attach(c,Spring,UnitDefs,config,VFS.Include('40k_configs/listening_post_bindings.lua'),CMD,CMDTYPE,Game.gameSpeed)
 gadgetHandler:RegisterCMDID(config.Commands.upgrade);gadgetHandler:RegisterCMDID(config.Commands.cancel)
 attached=true;return true
end
function gadget:Initialize()attach()end
-- Initialization order may differ across pinned gadget loaders. Attach once
-- after the research owner exists; no per-frame post scanning afterwards.
function gadget:GameFrame()if not attached then attach()end end

-- Review metadata only: no health/speed/damage/economy changes.
local M={}
local ranged={cannon=true,lasercannon=true,beamlaser=true,lightningcannon=true,missilelauncher=true,torpedolauncher=true,emgcannon=true,flame=true,aircraftbomb=true,starburstlauncher=true,dgun=true,rifle=true}
function M.Apply(defs,o)
 local mode=VFS.Include('40k_configs/wraith_phase_review_gate.lua').Mode(o);if not mode then return false end
 local w=defs.nec_wraith;if not w or not w.customparams or w.customparams.animsource~='nec_wraith'then return false end
 w.customparams.source_entity='attrib/ebps/races/necrons/troops/necron_wraith.lua';w.customparams.necron_wraith_review=1
 -- Paired phase-only path never classifies global damage or carries passive defense.
 if mode=='squad'then return true end
 for _,d in pairs(defs)do for _,weapon in pairs(d.weapondefs or{})do
  local kind=tostring(weapon.weapontype or''):lower()
  if kind=='melee'or ranged[kind]then
   weapon.customparams=weapon.customparams or{};weapon.customparams.source_damage_kind=kind=='melee'and 'melee'or 'ranged'
  end
 end end
 return true
end
return M

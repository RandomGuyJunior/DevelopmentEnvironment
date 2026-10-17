local options=Spring and Spring.GetModOptions and Spring.GetModOptions()or{}
if not VFS.Include('40k_configs/four_faction_playtest.lua').Enabled(options)
 or not VFS.FileExists('40k_configs/ork_ard_boy_facts.lua')then return {} end
local owner=VFS.Include('40k_configs/tactical_marine_remains.lua')
return VFS.Include('40k_configs/ork_ard_boy_roster.lua').FeatureDefinitions(owner,VFS.Include('40k_configs/ork_ard_boy_facts.lua'),VFS)

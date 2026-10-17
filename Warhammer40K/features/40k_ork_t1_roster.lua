if not VFS.Include('40k_configs/four_faction_playtest.lua').Enabled(Spring.GetModOptions()or{})
 or not VFS.FileExists('40k_configs/ork_t1_roster_facts.lua')then return {} end
return VFS.Include('40k_configs/ork_t1_roster.lua').FeatureDefinitions(
 VFS.Include('40k_configs/tactical_marine_remains.lua'),VFS.Include('40k_configs/ork_t1_roster_facts.lua'),VFS)

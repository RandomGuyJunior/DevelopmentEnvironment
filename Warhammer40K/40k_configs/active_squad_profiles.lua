-- Runtime view only: the authored squad_profiles.lua stays pure and unchanged.
local base=VFS.Include('40k_configs/squad_profiles.lua')
local candidate=VFS.Include('40k_configs/guard_squad_flamer_integration.lua')
local options=Spring and Spring.GetModOptions and Spring.GetModOptions()or{}
local active=base
if candidate.Enabled(options)then active=candidate.Profiles(base,options,VFS.Include('40k_configs/four_faction_playtest.lua').Enabled(options),
 VFS.Include('40k_configs/guard_squad_flamer_role.lua'))end
active=VFS.Include('40k_configs/guard_elite_squad_profiles.lua').Profiles(active,options,VFS.Include('40k_configs/four_faction_playtest.lua').Enabled(options))
active=VFS.Include('40k_configs/faction_elite_squad_profiles.lua').Profiles(active,options,VFS.Include('40k_configs/four_faction_playtest.lua').Enabled(options))
active=VFS.Include('40k_configs/ork_ranged_elite_squad_profiles.lua').Profiles(active,options,VFS.Include('40k_configs/four_faction_playtest.lua').Enabled(options))
local sourceEnabled=VFS.Include('40k_configs/four_faction_playtest.lua').Enabled(options)
active=VFS.Include('40k_configs/ork_heavy_squad_profiles.lua').Profiles(active,options,sourceEnabled)
active=VFS.Include('40k_configs/marine_terminator_squad_profiles.lua').Profiles(active,options,sourceEnabled)
active=VFS.Include('40k_configs/necron_melee_squad_profiles.lua').Profiles(active,options,sourceEnabled)
active=VFS.Include('40k_configs/ork_burna_squad_profiles.lua').Profiles(active,options,sourceEnabled)
active=VFS.Include('40k_configs/ork_slugga_squad_profiles.lua').Profiles(active,options,sourceEnabled)
if VFS.FileExists('40k_configs/ork_t1_roster_facts.lua')then
 active=VFS.Include('40k_configs/ork_t1_roster.lua').Profiles(active,VFS.Include('40k_configs/ork_t1_roster_facts.lua'),VFS,sourceEnabled)
end
for _,actor in ipairs({'ork_ard_boy','ork_flash_gitz','ork_kommando'})do
 local path='40k_configs/'..actor..'_facts.lua'
 if VFS.FileExists(path)then
  active=VFS.Include('40k_configs/'..actor..'_roster.lua').Profiles(active,VFS.Include(path),VFS,sourceEnabled)
 end
end
local jumpAdapter
if VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(options.prototype_marine_assault_squad)
 and VFS.FileExists('40k_configs/squad_jump_contract.lua')then
 jumpAdapter=VFS.Include('40k_configs/squad_jump_contract.lua')
end
return VFS.Include('40k_configs/marine_assault_squad_profiles.lua').Profiles(active,options,sourceEnabled,jumpAdapter)

-- Preserve native resource assembly and add genuine local Necron aliases.
local resources=VFS.Include('40k_reference/resources.lua')
VFS.Include('40k_configs/necron_weapon_fx.lua').TextureAliases(resources,VFS)
return resources

-- Preserve the mounted Hosting baseline; add the authored 40K units.
VFS.Include('40k_reference/randomguy_hosting_unitdefs_post.lua')
return VFS.Include('40k_configs/randomguy_additive_units.lua').Apply(UnitDefs,VFS,getfenv(1))

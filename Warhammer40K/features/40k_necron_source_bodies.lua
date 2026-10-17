-- Genuine copied-source terminal death poses; invisible/donor fallbacks forbidden.
local options=Spring and Spring.GetModOptions and Spring.GetModOptions() or {}
if not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(options.prototype_source_progression)
 or not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(options.prototype_spyder_harvest_review)
 or options.prototype_diagnostic~='expandedproduction' then return {} end
local salvage=VFS.Include('40k_configs/corpse_reclaim_account.lua').Enabled(options)
local defs={}
for key,actor in pairs({nec_warrior='basic_warrior',nec_flayed='flayed_one',nec_immortal='immortal',nec_wraith='wraith',nec_destroyer='destroyer'})do
 -- Stock featuredefs_post prefixes objects3d/ itself; object is relative.
 local name=key..'_body';local object=name..'.glb'
 if VFS.FileExists('objects3d/'..object)and VFS.FileExists('unittextures/'..name..'_tex1.png')and VFS.FileExists('unittextures/'..name..'_tex2.png')then
  defs[name]={name=name,description='Source Necron corpse',object=object,blocking=false,reclaimable=salvage,autoreclaimable=salvage,resurrectable=0,indestructible=true,flammable=false,health=1,metal=0,energy=0,footprintx=1,footprintz=1,customparams={source_body='attrib/ebps/environment/gameplay/necron_'..actor..'_body.lua',source_owned_death_pose=1,corpse_reclaim_review=salvage and 1 or nil}}
 end
end
return defs

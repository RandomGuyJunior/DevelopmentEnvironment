-- Preserve pinned native pathing; rejected candidates allocate no extra layers.
local defs=VFS.Include('40k_reference/movedefs.lua')
assert(type(defs)=='table','Native MoveDefs unavailable')
local options=Spring and Spring.GetModOptions and Spring.GetModOptions() or {}
VFS.Include('40k_configs/candidate_movement_gates.lua').Apply(defs,options)
VFS.Include('40k_configs/ork_transport_envelope_movement.lua').ApplyMoveDefs(defs,options,function(key)
 return VFS.FileExists('objects3d/'..key..'.glb') and VFS.FileExists('scripts/generated/'..key..'_anim.lua')
end)
VFS.Include('40k_configs/ork_dakka_reference_diagnostic.lua').ApplyMoveDefs(defs,options,VFS)
return defs

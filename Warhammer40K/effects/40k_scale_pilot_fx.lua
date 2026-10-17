-- Explosion LuaParser has no GetModOptions. Register unused private clones
-- here; the default-off unit-definition pilot alone selects these names.
local Pilot=VFS.Include('40k_configs/scale_pilot.lua')
return VFS.Include('40k_configs/scale_pilot_ceg_closure.lua').New(VFS,Pilot).Definitions()

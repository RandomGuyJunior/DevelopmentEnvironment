-- Unused default-off dimensional clone; original Imperial/native weapon physics unchanged.
local P=VFS.Include('40k_configs/scale_pilot.lua')
local source=VFS.Include('effects/40k_imperial_source_fx.lua')
return {[P.EffectName('40k_dow_power_fist_impact')]=P.EffectClone(assert(source['40k_dow_power_fist_impact']))}

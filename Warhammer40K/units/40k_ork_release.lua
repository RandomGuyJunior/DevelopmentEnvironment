-- Genuine late Ork candidates are individually gated; conversion never means acceptance.
local opts=Spring and Spring.GetModOptions and Spring.GetModOptions() or {}
local review=opts.prototype_diagnostic=='roster' or opts.prototype_diagnostic=='expandedproduction'
local stompaFixture=VFS.Include('40k_configs/stompa_weapon_fixture.lua').Enabled(opts)
local selected=VFS.Include('40k_configs/mixed_v2_adapter.lua').Selected(opts)
local defs={}
VFS.Include('40k_configs/ork_release_candidates.lua').Apply(defs,function(key)
 if stompaFixture then return key=='ork_dakka_stompa'end
 if key=='ork_dakka_stompa'and VFS.Include('40k_configs/human_inspection_scene.lua').Enabled(opts)then return true end
 if selected then return selected[key]==true end
 return review or VFS.Include('40k_configs/development_playtest.lua').Allowed(key,opts) or VFS.FileExists('40k_configs/validated/'..key..'.lua')
end)
return defs

-- Exact source variants, independently gated; conversion never grants acceptance.
local opts=Spring and Spring.GetModOptions and Spring.GetModOptions() or {}
local review=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(opts.prototype_source_progression)
 and (opts.prototype_diagnostic=='roster' or opts.prototype_diagnostic=='expandedproduction')
local movement
-- Root owns real movement-layer integration and its native limits/egress tests.
if VFS.FileExists('40k_configs/primary_variant_movement.lua')then
 local adapter=VFS.Include('40k_configs/primary_variant_movement.lua')
 movement=adapter and adapter.Ready
end
local function ready(key)
 for _,p in ipairs({'objects3d/'..key..'.glb','scripts/generated/'..key..'_anim.lua',
 'unitpics/40k_'..key..'.png','unittextures/'..key..'_tex1.png','unittextures/'..key..'_tex2.png','scripts/40k_roster.lua'})do
  if not VFS.FileExists(p)then return false end
 end
 return review or VFS.Include('40k_configs/development_playtest.lua').Allowed(key,opts) or VFS.FileExists('40k_configs/validated/'..key..'.lua')
end
return VFS.Include('40k_configs/primary_variant_definitions.lua').Apply({},ready,movement)

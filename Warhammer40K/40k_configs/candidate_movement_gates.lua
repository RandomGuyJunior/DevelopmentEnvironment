-- Allocate pathfinding layers only for enabled, genuine late candidates.
-- Keep this predicate in parity with the two release UnitDef entrypoints.
local M={}
local actors={
 imp_baneblade='40k_superheavy5', imp_warhound='40k_titan8',
 ork_dakka_stompa='40k_ork_heavy8', ork_kustim_stompa='40k_ork_heavy8',
 ork_gargant='40k_ork_gargant12', ork_squiggoth='40k_ork_creature6',
}
function M.Selected(options)
 options=options or {}
 local review=options.prototype_diagnostic=='roster' or options.prototype_diagnostic=='expandedproduction'
 local selected={}
 for key,class in pairs(actors)do
  if (review or(key=='ork_dakka_stompa'and VFS.Include('40k_configs/human_inspection_scene.lua').Enabled(options))or (key=='ork_dakka_stompa' and VFS.Include('40k_configs/stompa_weapon_fixture.lua').Enabled(options)) or VFS.Include('40k_configs/development_playtest.lua').Allowed(key,options) or VFS.FileExists('40k_configs/validated/'..key..'.lua'))
   and VFS.FileExists('objects3d/'..key..'.glb')
   and VFS.FileExists('scripts/generated/'..key..'_anim.lua')
   and VFS.FileExists('scripts/40k_roster.lua')then selected[class]=true end
 end
 return selected
end
function M.Apply(defs,options)
 if VFS.FileExists('40k_configs/primary_variant_movement.lua')then
  VFS.Include('40k_configs/primary_variant_movement.lua').Apply(defs,options)
 end
 local selected=M.Selected(options)
 if not next(selected)then return defs end
 -- Existing helpers retain exact native-derived fields and authored namespaces.
 -- Work on a shallow temporary list so unselected classes never reach the engine.
 local proposed={};for i,d in ipairs(defs)do proposed[i]=d end
 VFS.Include('40k_configs/imperium_large_movement.lua').Apply(proposed)
 VFS.Include('40k_configs/ork_release_movement.lua').Apply(proposed)
 for i=#defs+1,#proposed do
  local d=proposed[i]
  if selected[d.name:lower()]then defs[#defs+1]=d end
 end
 return defs
end
return M

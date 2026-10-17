-- O4 integration proposal. Call only after the stock-script torso interface is
-- installed, and only for measured v2 facts. The original Deff Dread is untouched.
local M = {}
function M.Apply(defs, facts, torsoInterfaceReady)
 local key='ork_dread_ranged_fourarm'
 local f=assert(facts[key], 'Measured O4 export required')
 assert(torsoInterfaceReady == true, 'Stock aiming/clearance interface not integrated')
 assert(f.recipe=='project_dread_direct_torso_v2' and f.direct_socket_topology_checked
  and f.all_original_arm_geometry_excluded_by_mesh and f.geometry_checked, 'Fresh direct-torso topology required')
 local d=assert(defs[key], 'Build the existing separate ranged product first')
 assert(d.customparams.source_ranged_model_sha256==f.model_sha256, 'Model/facts pair differs')
 d.name='All-Gun Deff Dread'
 d.description='Two upper Kustom Mega-Blastas, lower twin Big Shoota and Rokkit Launcha'
 local c=d.customparams
 c.source_variant_recipe=f.recipe
 c.source_torso_aimpiece=f.torso_yaw_piece
 c.source_torso_bodypiece=f.torso_piece
 c.source_torso_aim_mode='shared_heading_local_residual'
 c.i18n_en_humanname=d.name;c.i18n_en_tooltip=d.description
 -- Broad aiming belongs to the shared torso. These are conservative candidate
 -- local cones, not evidence of measured safe clearance. Root's stock-script
 -- implementation must also consume them when optional clearance mode is off.
 for n,arm in ipairs(f.arms) do
  local w=d.weapondefs['mount'..n]
  assert(w.customparams.source_aimpiece==arm.pivot, 'Mount identity differs')
  w.customparams.source_torso_aimpiece=f.torso_yaw_piece
  w.customparams.source_local_yaw_min=-3;w.customparams.source_local_yaw_max=3
  w.customparams.source_local_pitch_min=-3;w.customparams.source_local_pitch_max=3
  -- Existing unit-relative old four-arm cones are invalid after the torso turns.
  -- Real local checks remain in stock AimWeapon/BlockShot; native collision stays.
  d.weapons[n].maindir=nil;d.weapons[n].maxangledif=nil
 end
 -- The existing builder computes collision from fresh f.bounds. Use the same
 -- measured candidate box for explicit selection; do not query UnitDef.model.
 -- Native weighted GLTF also derives relMidPos from its actual model bounds.
 -- Volume offsets are relative to that midpoint, not the unit origin.
 d.collisionvolumeoffsets='0 0 0'
 d.selectionvolumetype=d.collisionvolumetype
 d.selectionvolumescales=d.collisionvolumescales
 d.selectionvolumeoffsets=d.collisionvolumeoffsets
 return d
end
return M

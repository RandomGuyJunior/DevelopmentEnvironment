-- Apply only to the three actual paired models with an inserted neutral hip.
-- Baseline Kan and both baseline/direct Dread definitions are untouched.
local M={Keys={ork_kan_twin_shoota=true,ork_kan_twin_kmb=true,ork_kan_twin_rokkit=true}}
function M.Apply(d,key,f)
 assert(M.Keys[key]and f.recipe=='project_kan_paired_torso_v2'and f.torso_hierarchy_checked
  and f.geometry_checked and f.no_melee_geometry,'Measured paired-Kan torso recipe required')
 assert(f.torso_yaw_piece=='project_kan_hip_yaw'and f.torso_piece=='bip01 spine','Unexpected Kan hip interface')
 local c=assert(d.customparams)
 assert(c.animsource==key and c.source_ranged_model_sha256==f.model_sha256 and #d.weapons==2 and #f.arms==2,'Actual paired model/facts mismatch')
 c.source_variant_recipe=f.recipe;c.source_torso_aimpiece=f.torso_yaw_piece
 c.source_torso_bodypiece=f.torso_piece;c.source_torso_aim_mode='shared_heading_local_residual'
 for n,a in ipairs(f.arms)do
  local w=assert(d.weapondefs['mount'..n]);local p=assert(w.customparams)
  assert(a.id==(n==1 and'left'or'right')and a.parent==f.torso_piece and #a.muzzles==1
   and p.source_aimpiece==a.pivot and p.source_pitchpiece==a.pivot and p.source_muzzle==a.muzzles[1], 'Paired gun identity differs')
  p.source_torso_aimpiece=f.torso_yaw_piece
  -- Start conservatively; only actual clearance can justify wider local cones.
  p.source_local_yaw_min=-3;p.source_local_yaw_max=3
  p.source_local_pitch_min=-3;p.source_local_pitch_max=3
  d.weapons[n].maindir=nil;d.weapons[n].maxangledif=nil
 end
 return d
end
return M

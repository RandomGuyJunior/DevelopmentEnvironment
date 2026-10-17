-- Read-only integration contract: retained Lifta visual is not source lifting proof.
-- This module exposes no native mutation/callin and does not open any readiness gate.
local M={}
M.Source={actor='ork_dakka_stompa',entity='attrib/ebps/races/orks/troops/ork_gargantuan_squiggoth.lua',
 weapon='attrib/weapon/ork_zzzap_gun_gargant_left.lua',hardpoint=1,nativeMount=4,
 muzzle='lifta_droppa_beam_start',aim='lifta_droppa_aim_horizontal',pitch='lifta_droppa_aim_vertical',
 clip='fire_lifta_droppa',wheVariable='weapon_range_firing_left',reloadSeconds=5,
 accuracy=1,rangeSource=60,sourceAir=true,sourceGround=true,
 weaponSHA='886a7d2b285f5d615e6a2e5685dd61ea1192824a5c43cf821536a92afcaa84d4',
 wheSHA='48e9ef503b4bacdf7313cdc7880ef8135fede80369a421091c7ae4ebffde920c'}
M.Missing={'source_displaced_target_rule','source_eligible_target_classes_and_mass',
 'source_lift_height_and_duration','source_release_trajectory_and_collision_policy',
 'source_drop_damage_and_accounting','native_capture_death_save_and_move_controller_ownership'}
function M.InspectDefinition(name,def,animation)
 if name~=M.Source.actor then return nil,'source_actor_mismatch' end
 if type(def)~='table' or def.objectname~='ork_dakka_stompa.glb' or def.script~='40k_roster.lua' or
  not def.customparams or def.customparams.animsource~=M.Source.actor then return nil,'source_model_identity_mismatch' end
 local w=def.weapondefs and def.weapondefs.mount4
 local slot=def.weapons and def.weapons[4]
 local cp=w and w.customparams
 if not cp or not slot or slot.def~='mount4' or cp.source_muzzle~=M.Source.muzzle or
  cp.source_fireclip~=M.Source.clip or cp.source_aimpiece~=M.Source.aim or cp.source_pitchpiece~=M.Source.pitch then
  return nil,'retained_mount_identity_mismatch'
 end
 if type(animation)~='table' or type(animation.bones)~='table' or not animation.clips or not animation.clips[M.Source.clip] then return nil,'genuine_animation_missing' end
 local bones={};for _,b in ipairs(animation.bones)do bones[b]=true end
 if not (bones[M.Source.muzzle] and bones[M.Source.aim] and bones[M.Source.pitch])then return nil,'retained_marker_missing' end
 local clip=animation.clips[M.Source.clip]
 if clip.source~=M.Source.clip or clip.source_fps~=30 then return nil,'source_clip_identity_mismatch' end
 return {actor=name,nativeMount=4,sourceHardpoint=1,sourceCadenceSeconds=5,actualCadenceSeconds=w.reloadtime,
  sourceClipSeconds=clip.duration,actualDamage=w.damage and w.damage.default,
  actualTargetCategory=slot.onlytargetcategory,sourceSupportsAir=true,
  sourceLiftingSupported=false,nativeAccepted=false},'lifting_semantics_unrecovered'
end
function M.LiftingSupported()return false,'source_lifting_semantics_unrecovered' end
return M

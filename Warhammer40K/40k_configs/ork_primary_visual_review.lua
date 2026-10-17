-- Explicit isolated asset/weapon review, never production or whole faction acceptance.
local M={}
function M.Apply(defs,o)
 if tostring(o.prototype_ork_primary_visual_review)~='1'then return {enabled=false}end
 assert(o.prototype_diagnostic=='roster'and not VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(o.prototype_source_progression),'Isolated roster visual review only')
 local contract=VFS.Include('scripts/generated/ork_primary_role_contract.lua')
 local builder=VFS.Include('40k_configs/ork_primary_native_review_definitions.lua')
 local keys={'ork_pile_o_guns','ork_boomy_platform','ork_bigger_generator','ork_giant_waagh_banner_sp_dxp3','ork_stormboy'}
 local candidates={}
 for _,key in ipairs(keys)do
  assert(VFS.FileExists('objects3d/'..key..'.glb')and VFS.FileExists('scripts/generated/'..key..'_anim.lua'),'Genuine visual bundle missing: '..key)
  local facts=assert(contract.actors[key]);local d=assert(builder.Build(key,facts,contract.calibration[key],defs));local cp=d.customparams
  cp.faction='Orks';cp.prototype40k=1;cp.animsource=key;cp.source_entity=facts.entity;cp.source_role=facts.role
  cp.rosterrole=facts.role=='jump_infantry'and 'infantry'or facts.role=='energy'and 'generator'or facts.role
  cp.diagnostic='roster';cp.integration_status='isolated_asset_weapon_review_no_paid_or_cohort_acceptance'
  if key=='ork_bigger_generator'then d.energymake=assert(defs.ork_generator.energymake)*facts.power_per_second/facts.reference_source_generator_power end
  candidates[key]=d
 end
 for key,d in pairs(candidates)do defs[key]=d end
 return {enabled=true,actors=#keys,paid_acceptance=false}
end
return M

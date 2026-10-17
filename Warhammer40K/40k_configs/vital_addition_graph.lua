-- Additional production/vital hooks; does not edit shared upstream/roster files.
-- Include after vital_roles.Apply so its graph filtering cannot remove additions.
local M={}
local function add(defs,parent,child)
 local p,c=defs[parent],defs[child]
 if not p or not c or not (p.customparams or {}).prototype40k or not (c.customparams or {}).prototype40k then return end
 p.buildoptions=p.buildoptions or {}
 for _,old in ipairs(p.buildoptions)do if old==child then return end end
 p.buildoptions[#p.buildoptions+1]=child
end
function M.Apply(defs)
 for _,factory in ipairs({'wh40k_armvp','wh40k_armavp','imp_tank_factory'})do add(defs,factory,'imp_hydra')end
 for _,builder in ipairs({'imp_field_commander','wh40k_armck','wh40k_armcv','wh40k_armack','wh40k_armacv','imp_enginseer'})do
  add(defs,builder,'imp_missile_defence');add(defs,builder,'imp_comms_array')
 end
 for _,factory in ipairs({'corvp','coravp','ork_mek_shop'})do
  add(defs,factory,'ork_flak_wartrak');add(defs,factory,'ork_rokkit_interceptor')
 end
 for _,factory in ipairs({'wh40k_corlab','wh40k_coralab','ork_boyz_hut','ork_settlement'})do add(defs,factory,'ork_big_mek_defence')end
 for _,builder in ipairs({'nec_lord','nec_scarab','nec_spyder'})do
  add(defs,builder,'nec_sentry_pylon');add(defs,builder,'nec_particle_interceptor');add(defs,builder,'nec_shield_spike')
 end
 -- Preserve actual source actors for senior constructors and advanced factory
 -- paths. HQ/research infrastructure is paid; this is a native tier adaptation.
 for _,hq in ipairs({'imp_hq','wh40k_armalab'})do add(defs,hq,'wh40k_armack');add(defs,hq,'wh40k_armacv')end
 for _,hq in ipairs({'ork_settlement','wh40k_coralab'})do add(defs,hq,'wh40k_corack');add(defs,hq,'wh40k_coracv')end
 for _,builder in ipairs({'wh40k_armack','wh40k_armacv'})do add(defs,builder,'wh40k_armalab');add(defs,builder,'wh40k_armavp')end
 for _,builder in ipairs({'wh40k_corack','wh40k_coracv'})do add(defs,builder,'wh40k_coralab');add(defs,builder,'coravp')end
 return defs
end
return M

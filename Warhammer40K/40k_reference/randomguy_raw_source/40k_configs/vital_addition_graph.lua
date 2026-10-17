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
 for _,factory in ipairs({'armvp','armavp','imp_tank_factory'})do add(defs,factory,'imp_hydra')end
 for _,builder in ipairs({'armcom','armck','armcv','armack','armacv','imp_enginseer'})do
  add(defs,builder,'imp_missile_defence');add(defs,builder,'imp_comms_array')
 end
 for _,factory in ipairs({'corvp','coravp','ork_mek_shop'})do
  add(defs,factory,'ork_flak_wartrak');add(defs,factory,'ork_rokkit_interceptor')
 end
 for _,factory in ipairs({'corlab','coralab','ork_boyz_hut','ork_settlement'})do add(defs,factory,'ork_big_mek_defence')end
 for _,builder in ipairs({'nec_lord','nec_scarab','nec_spyder'})do
  add(defs,builder,'nec_sentry_pylon');add(defs,builder,'nec_particle_interceptor');add(defs,builder,'nec_shield_spike')
 end
 -- Preserve actual source actors for senior constructors and advanced factory
 -- paths. HQ/research infrastructure is paid; this is a native tier adaptation.
 for _,hq in ipairs({'imp_hq','armalab'})do add(defs,hq,'armack');add(defs,hq,'armacv')end
 for _,hq in ipairs({'ork_settlement','coralab'})do add(defs,hq,'corack');add(defs,hq,'coracv')end
 for _,builder in ipairs({'armack','armacv'})do add(defs,builder,'armalab');add(defs,builder,'armavp')end
 for _,builder in ipairs({'corack','coracv'})do add(defs,builder,'coralab');add(defs,builder,'coravp')end
 return defs
end
return M

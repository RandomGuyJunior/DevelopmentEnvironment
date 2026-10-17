-- Default-off matched model/material pilot, fixed Guard metal tiers only.
local M={}
function M.Apply(defs,options,V,fixed)
 if not V.Include('40k_configs/development_playtest.lua').OptionEnabled((options or{}).prototype_guard_metal_lamp_isolation_pilot)then return{enabled=false,changed={}}end
 assert(fixed,'Guard lamp isolation requires fixed extractor tiers')
 local keys={'imp_mex','imp_mex_t2','imp_mex_t3'}
 for _,path in ipairs({'objects3d/imp_post_stages_lamp_isolated.glb','objects3d/imp_post_stages_lamp_isolated.glb.lua','unittextures/imp_post_stages_lamp_isolated_tex1.png','unittextures/imp_post_stages_lamp_isolated_tex2.png','scripts/generated/imp_post_stages_anim.lua','scripts/generated/imp_post_stages_post.lua'})do assert(V.FileExists(path),'Guard lamp isolation closure missing: '..path)end
 local meta=V.Include('objects3d/imp_post_stages_lamp_isolated.glb.lua')
 assert(meta.tex1=='imp_post_stages_lamp_isolated_tex1.png'and meta.tex2=='imp_post_stages_lamp_isolated_tex2.png'and meta.fliptextures==false and meta.invertteamcolor==false,'Matched original-orientation lamp materials required')
 for tier,key in ipairs(keys)do
  local d=assert(defs[key],'Missing fixed Guard metal tier '..key);local cp=d.customparams or{}
  assert(d.objectname=='imp_post_stages.glb'and d.script=='40k_listening_post.lua'and cp.animsource=='imp_post_stages'and cp.listening_post_stage==tier-1 and cp.extractor_tier==tier and(d.extractsmetal or 0)>0 and not(d.energymake and d.energymake>0),'Guard metal tier/model drift '..key)
 end
 for _,key in ipairs(keys)do defs[key].objectname='imp_post_stages_lamp_isolated.glb'end
 return{enabled=true,changed=keys,nativeAccepted=false,renderAccepted=false}
end
return M

-- Scoped V07 material reuse. Unwired proposal; native/readability pending.
local M={Option='prototype_guard_energy_blue_pilot',DefaultEnabled=false,Actor='imp_generator',Model='imp_generator_energyblue.glb'}
function M.Apply(defs,options,V)
 if not V.Include('40k_configs/development_playtest.lua').OptionEnabled((options or{})[M.Option])then return{enabled=false,changed={}}end
 for _,path in ipairs({'objects3d/'..M.Model,'objects3d/'..M.Model..'.lua','unittextures/imp_generator_energyblue_tex1.png',
  'unittextures/imp_generator_energyblue_tex2.png','scripts/generated/imp_generator_anim.lua'})do assert(V.FileExists(path),'Missing Guard blue energy closure '..path)end
 local meta=V.Include('objects3d/'..M.Model..'.lua')
 assert(meta.tex1=='imp_generator_energyblue_tex1.png'and meta.tex2=='imp_generator_energyblue_tex2.png'and meta.fliptextures==false and meta.invertteamcolor==false,'Matched original energy material orientation required')
 local d=assert(defs[M.Actor],'Missing current Guard generator');local cp=d.customparams or{}
 assert(d.objectname=='imp_generator.glb'and d.script=='40k_roster.lua'and cp.animsource=='imp_generator','Unexpected generator model/script/animation')
 assert((d.energymake or 0)>0 and not(d.extractsmetal and d.extractsmetal>0),'Blue detail requires actual energy output without metal extraction')
 d.objectname=M.Model
 return{enabled=true,changed={M.Actor},nativeAccepted=false,renderAccepted=false}
end
return M

-- Apply immediately after measured ork_v13_airfields.Apply, before sole O1.
-- AIR3 has one queue and genuinely decorative source tower/generator art.
local M={Version=1}
function M.Apply(defs,facts)
 local g=facts and facts.fortyk_ork_super_air_factory
 if not g then return {definitions={},nativeAccepted=false}end
 assert(g.recipe=='ORK-AIR-3'and g.exact_bomba_tower and g.gunship_bounds and g.export_verified,'Actual AIR3 asset inputs required')
 local d=assert(defs.fortyk_ork_super_air_factory,'Measured AIR3 must be registered first')
 assert(d.objectname==g.objectname and d.builder and d.script=='40k_ork_static_factory.lua','Actual AIR3 native factory required')
 local s=assert(g.provisional_stats,'Explicit provisional AIR3 economics required')
 for _,k in ipairs({'metalcost','energycost','buildtime','health'})do assert(type(s[k])=='number'and s[k]==s[k]and s[k]>0 and s[k]<math.huge,'Invalid AIR3 stats')end
 -- No other source changes can fail after this validation. Native factory
 -- labor/yard/release ownership is preserved and no extra generator is alive.
 for _,k in ipairs({'metalcost','energycost','buildtime','health'})do d[k]=s[k]end
 d.name='Ork Gunship Airfield';d.description='T3 aircraft production; one Gunship queue; attached generator is decorative'
 d.weapons={};d.weapondefs={};d.canattack=false;d.buildoptions={};d.energymake=0
 local c=d.customparams;c.i18n_en_humanname=d.name;c.i18n_en_tooltip=d.description
 c.prototype40k_ork_v13_air3=1;c.prototype40k_native_air_accepted=g.native_clearance_accepted and 1 or 0
 return {definitions={'fortyk_ork_super_air_factory'},nativeAccepted=false,policy='ork_v13_exact_air3_single_queue_v1'}
end
return M

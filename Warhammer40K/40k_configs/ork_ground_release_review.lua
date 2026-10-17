-- Explicit engine-candidate gate; no ordinary-play enable and no geometry/goal mutation.
local M={};M.Key='prototype40k_ground_release_review'
function M.Apply(defs,options)
 if not options or tostring(options.prototype_transport_ground_release_review)~='1'then return defs end
 assert(options.prototype_diagnostic=='roster'and tostring(options.prototype_transport_envelope_review)=='1','Ground release needs reviewed native envelope roster')
 for _,name in ipairs({'ork_trukk','ork_slugga'})do
  local d=assert(defs[name],'Missing actual reviewed '..name)
  local cp=assert(d.customparams,'Missing source identity')
  assert(cp.animsource==name and cp.faction=='Orks'and tostring(cp.prototype40k)=='1','Wrong genuine source actor')
  assert(d.objectname==name..'.glb'and d.script=='40k_roster.lua','Wrong actual model/script')
  local expected=name=='ork_trukk'and '40k_ork_trukk_envelope10'or '40k_ork_slugga_envelope4'
  assert(d.movementclass==expected,'Envelope candidate must already be applied')
  assert(cp[M.Key]==nil or tostring(cp[M.Key])=='1','Conflicting release policy')
  cp[M.Key]=1
 end
 return defs
end
return M

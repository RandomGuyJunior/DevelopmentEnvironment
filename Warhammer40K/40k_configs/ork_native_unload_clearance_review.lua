-- Authored diagnostic marker only; root must call AFTER reviewed envelope/ground-release transforms.
local M={};M.Key='prototype40k_native_unload_clearance_review'
function M.Apply(defs,options)
 local mode=options and options.prototype_native_unload_clearance_review
 if mode==nil or tostring(mode)=='0'then return defs end
 assert(mode=='witness'or mode=='apply','Explicit witness/apply mode required')
 assert(options.prototype_diagnostic=='roster'and tostring(options.prototype_transport_ground_release_review)=='1'
  and tostring(options.prototype_transport_envelope_review)=='1'and tostring(options.prototype_transport_review)=='1'
  and tostring(options.prototype_transport_clearance_witness)=='1','Reviewed ground-release envelope roster required')
 -- Validate both before assigning either marker.
 for _,name in ipairs({'ork_trukk','ork_slugga'})do
  local d=assert(defs[name],'Missing actual source actor')
  local cp=assert(d.customparams,'Missing actual identity')
  assert(cp.animsource==name and cp.faction=='Orks'and tostring(cp.prototype40k)=='1','Wrong source identity')
  assert(tostring(cp.prototype40k_ground_release_review)=='1','Ground-release transform must already be applied')
  assert(d.objectname==name..'.glb'and d.script=='40k_roster.lua','Wrong genuine renderer/script')
  assert(d.movementclass==(name=='ork_trukk'and '40k_ork_trukk_envelope10'or '40k_ork_slugga_envelope4'),'Wrong physical envelope')
  assert(cp[M.Key]==nil or cp[M.Key]==mode,'Conflicting native unload mode')
 end
 for _,name in ipairs({'ork_trukk','ork_slugga'})do defs[name].customparams[M.Key]=mode end
 return defs
end
return M

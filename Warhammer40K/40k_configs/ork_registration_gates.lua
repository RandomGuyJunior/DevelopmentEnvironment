-- Conversion proves file availability, never ordinary release readiness.
local M={}
function M.Allowed(key,options,mixedSelected)
 options=options or {}
 local mode=options.prototype_diagnostic
 if VFS.Include('40k_configs/human_inspection_scene.lua').Enabled(options)and(key=='ork_morkanaut'or key=='ork_warbike_crewed'or key=='ork_trukk')then return true end
 if VFS.Include('40k_configs/stompa_weapon_fixture.lua').Enabled(options)then return key=='ork_dakka_stompa' or key=='ork_deff_dread'end
 -- Explicit mixed tests are an exact roster, even if other actors are accepted.
 local mixedV2=VFS.Include('40k_configs/mixed_v2_adapter.lua').Selected(options)
 if mixedV2 then return mixedV2[key]==true end
 if mixedSelected then return mixedSelected[key]==true end
 if mode=='benchmark' and tostring(options.prototype_mixed_force or '0')=='1'then
  local selected=VFS.Include('40k_configs/mixed_benchmark_exposure.lua').Selected(options)
  return selected and selected[key]==true or false
 end
 if(key=='ork_warbike_crewed'or key=='ork_morkanaut')and VFS.Include('40k_configs/ork_goh_native_fixture.lua').Registration(key,options)then return true end
 return VFS.Include('40k_configs/development_playtest.lua').Allowed(key,options) or mode=='roster' or mode=='expandedproduction' or mode=='vital' or mode=='ui'
  or VFS.FileExists('40k_configs/validated/'..key..'.lua')
end
return M

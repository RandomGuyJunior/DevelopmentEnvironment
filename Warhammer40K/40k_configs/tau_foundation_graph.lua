local M={}
M.Menus={
 tau_hq={'tau_builder'},
 tau_builder={'tau_hq','tau_barracks','tau_kroot_nest','tau_research','tau_vehicle_factory','tau_mex','tau_generator'},
 tau_barracks={'tau_fire_warrior'},tau_kroot_nest={'tau_kroot'},tau_vehicle_factory={'tau_piranha'},
}
M.Requires={
 tau_builder={owned_completed={'tau_hq'}},tau_fire_warrior={owned_completed={'tau_hq','tau_barracks'}},
 tau_kroot={owned_completed={'tau_kroot_nest'}},tau_piranha={owned_completed={'tau_vehicle_factory'}},
 tau_vehicle_factory={owned_completed={'tau_research'}},tau_generator={owned_completed={'tau_hq'}},
}
-- Display-only source HQ requirements are not real progression. The actual
-- source vehicle requirement10 is Path to Enlightenment (no paid tier invented).
M.Blockers={'Tau commander/start seed not implemented','Source economy decay/strategic capture mapping pending',
 'Paid native requirement enforcement must consume Requires','Primary faction release acceptance prerequisite'}
function M.Apply(defs,ready,secondaryEnabled)
 local report={blocked={},menus={}}
 if secondaryEnabled~=true or type(ready)~='function'then return report end
 for parent,children in pairs(M.Menus)do
  if defs[parent]and ready(parent)==true then
   local menu={}
   for _,child in ipairs(children)do
    if defs[child]and ready(child)==true then menu[#menu+1]=child else report.blocked[#report.blocked+1]=child end
   end
   defs[parent].buildoptions=menu;report.menus[parent]=menu
  end
 end
 return report
end
return M

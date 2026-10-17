-- Own native MoveDef records; root merges before candidates are enabled.
local M={Definitions={
 {name="40K_ORK_HEAVY8",footprintx=8,footprintz=8,maxslope=24,maxwaterdepth=5,crushstrength=1500},
 {name="40K_ORK_GARGANT12",footprintx=12,footprintz=12,maxslope=20,maxwaterdepth=5,crushstrength=2500},
 {name="40K_ORK_CREATURE6",footprintx=6,footprintz=6,maxslope=24,maxwaterdepth=5,crushstrength=1200},
}}
function M.Apply(defs)
 local names={};for _,d in ipairs(defs)do names[d.name:lower()]=true end
 for _,d in ipairs(M.Definitions)do if not names[d.name:lower()] then
  local copy={};for k,v in pairs(d)do copy[k]=v end;defs[#defs+1]=copy;names[d.name:lower()]=true
 end end
 return defs
end
return M

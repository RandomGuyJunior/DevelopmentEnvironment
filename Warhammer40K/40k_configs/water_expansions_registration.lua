-- Complete readiness for two explicitly scoped native water adaptation packets.
local M={}
local rules={naval={'naval_combat_expansion_theme_facts.lua',16},utility={'water_utility_expansion_theme_facts.lua',36}}
function M.Apply(kind,defs,saved,domains,V,expansion)
 local rule=assert(rules[kind],'Unknown water expansion');local path='scripts/generated/'..rule[1]
 assert(V.FileExists(path),'Complete '..kind..' expansion facts required')
 local theme=V.Include(path)
 local function ready(key,t,donor)
  local faction=key:match('^fortyk_([^_]+)_')
  if not faction or type(donor.script)~='string'or type(donor.buildpic)~='string'then return false end
  local paths={'objects3d/'..t.objectname,'scripts/'..donor.script,'unitpics/'..donor.buildpic,
   'unittextures/40k_domain_'..faction..'_cor_color.png','unittextures/cor_other.dds',
   'unittextures/cor_color.dds'} -- Native projectile materials stay unchanged.
  local normal=(donor.customparams or{}).normaltex
  if type(normal)~='string'then return false end;paths[#paths+1]=normal
  if kind=='utility'then -- The unchanged coratl torpedo uses native ARM materials.
   paths[#paths+1]='unittextures/Arm_color.dds';paths[#paths+1]='unittextures/Arm_other.dds'
  end
  for _,w in pairs(donor.weapondefs or{})do if w.model then paths[#paths+1]='objects3d/'..w.model end end
  for _,p in ipairs(paths)do if not V.FileExists(p)then return false end end
  return true
 end
 local report=expansion.Apply(defs,saved,domains,theme,ready)
 assert(#report.definitions==rule[2],'Whole '..kind..' expansion required')
 return report
end
return M

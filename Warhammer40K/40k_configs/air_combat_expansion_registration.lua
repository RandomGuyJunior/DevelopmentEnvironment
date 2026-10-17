-- Readiness for the exact sixteen authored native adaptations. No fallback assets.
local M={}
function M.Apply(defs,saved,domains,V,expansion)
 local path='scripts/generated/air_combat_expansion_theme_facts.lua'
 assert(V.FileExists(path),'Complete air combat expansion facts required')
 local theme=V.Include(path)
 local function ready(key,t,donor)
  local faction=key:match('^fortyk_([^_]+)_')
  if not faction or type(donor.script)~='string'or type(donor.buildpic)~='string'then return false end
  local paths={'objects3d/'..t.objectname,'scripts/'..donor.script,'unitpics/'..donor.buildpic,
   'unittextures/40k_domain_'..faction..'_cor_color.png','unittextures/cor_other.dds',
   'unittextures/cor_color.dds'} -- Pinned native bomb/missile projectile material.
  local normal=(donor.customparams or{}).normaltex
  if type(normal)~='string'then return false end
  paths[#paths+1]=normal
  for _,w in pairs(donor.weapondefs or{})do if w.model then paths[#paths+1]='objects3d/'..w.model end end
  for _,p in ipairs(paths)do if not V.FileExists(p)then return false end end
  return true
 end
 local report=expansion.Apply(defs,saved,domains,theme,ready)
 assert(#report.definitions==16,'Whole sixteen-aircraft package required')
 return report
end
return M

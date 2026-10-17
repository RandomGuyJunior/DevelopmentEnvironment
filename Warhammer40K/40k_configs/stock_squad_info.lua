local M={}
local profiles=VFS.Include('40k_configs/active_squad_profiles.lua')
function M.Description(base,id,d,S)
 if not id then return base end
 local n=S.GetUnitRulesParam(id,'40k_squad_living')
 if not n then return base end
 local max=S.GetUnitRulesParam(id,'40k_squad_capacity')or n
 local h=S.GetUnitRulesParam(id,'40k_squad_health')or 0
 local hp=S.GetUnitRulesParam(id,'40k_squad_maxhealth')or h
 local special=(S.GetUnitRulesParam(id,'40k_squad_special')or 0)==1
 local key=profiles.byID[S.GetUnitRulesParam(id,'40k_squad_profile')];local p=key and profiles.profiles[key]
 local role=p and p.shortRole or'Infantry squad'
 -- Existing stock info only. Researched equipment is a player entitlement,
 -- not evidence that a missing specialist is currently alive.
 if p and p.product and p.product:match('^ork_')then
  local research=''
  if p.research then research=special and '\nRokkit research complete; missing specialists need paid repair.'or'\nWaaagh Banner: permanent rokkit specialist research.'end
  return string.format('Mob %d/%d  HP %d/%d\n%s; paid builder casualty repair%s',n,max,h,hp,role,research)
 end
 if p and p.research and special then role=role..' + '..((p.researchRow or{}).name or'Specialist')..' slot'end
 return string.format('Squad %d/%d  HP %d/%d\n%s; builder casualty repair',n,max,h,hp,role)
end
return M

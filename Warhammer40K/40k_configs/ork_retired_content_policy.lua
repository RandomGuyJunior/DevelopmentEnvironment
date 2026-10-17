-- Explicit user design supersedes historical source-candidate acceptance.
local M={Revision='stompa_design_20261008',Removed='ork_kustim_stompa'}
function M.ActorAllowed(key)return key~='ork_kustim_stompa'and key~='ork_kustim_hammer_candidate'end
function M.MechanicAllowed(key)return key~='lifta_target_lifting'and key~='kustim_hammer'end
function M.FilterList(list)local out={};for _,v in ipairs(list or{})do if M.ActorAllowed(v)then out[#out+1]=v end end;return out end
function M.FilterDefinitions(defs)
 defs.ork_kustim_stompa=nil;defs.ork_kustim_hammer_candidate=nil
 for _,d in pairs(defs)do if d.buildoptions then d.buildoptions=M.FilterList(d.buildoptions)end end
 return defs
end
function M.FilterGraph(g)
 for _,field in ipairs({'Build','BuildOptions'})do for key,list in pairs(g[field]or{})do if not M.ActorAllowed(key)then g[field][key]=nil else g[field][key]=M.FilterList(list)end end end
 for _,field in ipairs({'Requires','Definitions','Units'})do if g[field]then g[field].ork_kustim_stompa=nil;g[field].ork_kustim_hammer_candidate=nil end end
 return g
end
-- Package/regeneration adapters use exact actor and dedicated runtime filenames;
-- shared melee, research, movement and transport are intentionally unaffected.
function M.PackageAllowed(path)
 local file=path:gsub('\\','/'):match('([^/]+)$')or path
 if file:find('ork_kustim_stompa',1,true)or file:find('ork_kustim_hammer',1,true)then return false end
 if file=='40k_lifta_vertical_hold.lua'or file=='40k_lifta_native_review.lua'then return false end
 return true
end
return M

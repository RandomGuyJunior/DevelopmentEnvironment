-- Only explicit mixed benchmarking may expose these exact genuine test actors.
local M={}
function M.Selected(options)
 options=options or {}
 if options.prototype_diagnostic~='benchmark' or tostring(options.prototype_mixed_force or '0')~='1' then return nil end
 local config=VFS.Include('40k_configs/mixed_benchmark.lua');local selected={}
 for _,team in ipairs(config.teams)do
  for _,name in ipairs(team.units)do selected[name]=true end
  for _,field in ipairs({'hq','factory','builder','generator','mex','product'})do selected[team[field]]=true end
  if tostring(options.prototype_mixed_large or '0')=='1'then selected[team.large]=true end
 end
 return selected
end
return M

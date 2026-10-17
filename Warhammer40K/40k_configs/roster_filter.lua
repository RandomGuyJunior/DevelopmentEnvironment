-- Explicit diagnostic selection only; single-filter substring behavior is retained.
local M={}
function M.Match(filter,name)
 if type(filter)~='string' or type(name)~='string' then return false end
 if not filter:find(',',1,true) then return filter=='' or name:find(filter,1,true)~=nil end
 if filter:sub(1,1)==',' or filter:sub(-1)==',' or filter:find(',,',1,true) then return false end
 local selected={}
 for key in filter:gmatch('[^,]+') do
  if not key:match('^[a-z0-9_]+$') or selected[key] then return false end
  selected[key]=true
 end
 return selected[name]==true
end
return M

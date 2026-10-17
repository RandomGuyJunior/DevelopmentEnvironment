-- UI-only candidate: mirror native live build descriptor disables on stock grid cells.
local M={}
function M.Disabled(descriptors)
 local out={}
 for _,d in ipairs(descriptors or{})do
  if type(d)=='table'and type(d.id)=='number'and d.id<0 and d.disabled==true then out[-d.id]=true end
 end
 return out
end
return M

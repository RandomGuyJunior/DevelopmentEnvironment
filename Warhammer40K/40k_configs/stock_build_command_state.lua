-- Stock HUD adapter data only: no commands, resource writes or custom rendering.
local M={}
function M.IsSource(def)return def and tostring((def.customParams or{}).prototype40k)=='1'end
function M.Read(descs)
 local disabled,tips={},{}
 for _,d in ipairs(descs or{})do if type(d.id)=='number'and d.id<0 then
  disabled[-d.id]=d.disabled==true
  if type(d.tooltip)=='string'and d.tooltip~=''then tips[-d.id]=d.tooltip end
 end end
 return disabled,tips
end
function M.IsCommand(cmd)
 return cmd and type(cmd.action)=='string'and cmd.action:sub(1,3)=='40k'
end
function M.Name(cmd)return M.IsCommand(cmd)and cmd.name or nil end
function M.Tooltip(cmd)return M.IsCommand(cmd)and cmd.tooltip or nil end
return M

-- Append dedicated native ground MoveDefs. GroundMoveType uses the MoveDef
-- footprint, so oversized actors must not share the ordinary 3-cell tank class.
local M={}
local function clone(v)
 if type(v)~='table'then return v end
 local t={};for k,x in pairs(v)do t[k]=clone(x)end;return t
end
function M.Apply(defs)
 local donor
 for _,d in ipairs(defs)do if type(d.name)=='string'and d.name:lower()=='tank3'then donor=d;break end end
 assert(donor,'Imperial large movement needs real native TANK3 MoveDef')
 for _,s in ipairs({{'40k_superheavy5',5},{'40k_titan8',8}})do
  local found=false
  for _,d in ipairs(defs)do if type(d.name)=='string'and d.name:lower()==s[1]then found=true;assert(d.footprintx==s[2]and d.footprintz==s[2],'Conflicting Imperial MoveDef');break end end
  if not found then local d=clone(donor);d.name=s[1];d.footprintx=s[2];d.footprintz=s[2];defs[#defs+1]=d end
 end
 return defs
end
return M

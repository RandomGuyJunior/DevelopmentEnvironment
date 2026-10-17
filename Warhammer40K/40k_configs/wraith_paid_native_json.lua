-- Bounded JSON for native readbacks; absent values stay absent.
local M={}
function M.Encode(v)
 if v==nil then return 'null'end
 if type(v)=='boolean'then return v and'true'or'false'end
 if type(v)=='number'then return v==v and math.abs(v)<math.huge and string.format('%.17g',v)or'null'end
 if type(v)=='string'then return '"'..v:gsub('[%z\1-\31\\"]',function(c)return string.format('\\u%04x',c:byte())end)..'"'end
 if type(v)=='table'then local t={};for k,x in pairs(v)do t[#t+1]=M.Encode(tostring(k))..':'..M.Encode(x)end;table.sort(t);return '{'..table.concat(t,',')..'}'end
 return 'null'
end
return M

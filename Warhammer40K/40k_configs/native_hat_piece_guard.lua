-- Integrated Hats only: native holiday metadata can survive replacement of a
-- BAR commander by a 40K GLB which has no holiday hat pieces. Keep its ordinary
-- script initialization alive without changing definitions or native hat rolls.
local M={}
local function marked(v)return v==true or v==1 or v=='1'or v=='true'end
local function customGLB(d)
 if not d then return false end
 local c=d.customParams or{}
 return marked(c.prototype40k)and(d.modeltype=='glb'or d.modeltype=='gltf')
end
-- Call after all raw source-model replacements, before native definitions are
-- finalized. A native holiday hat count describes the replaced BAR model, not
-- the imported 40K GLB; retaining it also makes strict identity date-dependent.
function M.ApplyRaw(defs)
 local changed={}
 for name,d in pairs(defs)do
  local c=d.customparams
  local model=type(d.objectname)=='string'and d.objectname:lower()or''
  if c and marked(c.prototype40k)and(model:match('%.glb$')or model:match('%.gltf$'))and c.holidayhatcount~=nil then
   c.holidayhatcount=nil;changed[#changed+1]=name
  end
 end
 table.sort(changed);return changed
end
function M.Proxy(native,defs)
 local proxy={}
 for _,method in ipairs({'SetUnitPieceMatrix','SetUnitPieceVisible'})do
  local forward=native[method]
  proxy[method]=function(id,piece,...)
   if piece==nil and customGLB(defs[native.GetUnitDefID(id)])then return false end
   return forward(id,piece,...)
  end
 end
 return setmetatable(proxy,{__index=native})
end
return M

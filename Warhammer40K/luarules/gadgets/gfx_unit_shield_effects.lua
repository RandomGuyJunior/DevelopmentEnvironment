-- Preserve native shield rendering/LOS/lifecycle; gate only commander visuals.
local path='40k_reference/commander_shield_native_effects.lua'
local source=assert(VFS.LoadFile(path,VFS.GAME),'Missing pinned native shield effects')
assert(VFS.CalculateHash(source,1)=='3c4a0d1f47f1ad9bf997c855bb2dc5ad2ec1f00c9906c21827fbdc0cdaf5cccc27679dc08cdbf364a164e840cac5184955a81077249c2ddf2632b7c23b212e3c','Pinned native shield effects changed')
local chunk=assert(loadstring(source,'@'..path))
if not gadgetHandler:IsSyncedCode()then
 local nativeSpring=Spring
 local scopedSpring=setmetatable({GetUnitIsActive=function(id)
  local active=nativeSpring.GetUnitIsActive(id)
  if not active then return active end
  local def=nativeSpring.GetUnitDefID(id)
  local cp=def and UnitDefs[def]and UnitDefs[def].customParams
  if not cp or cp.prototype40k_commander_shield~='native_corgate_half_standard_cost_v2'then return active end
  local wanted=nativeSpring.GetUnitRulesParam(id,'40k_commander_shield_wanted')
  local toggled=nativeSpring.GetUnitRulesParam(id,'40k_commander_shield_active')
  if(wanted~=nil and wanted~=1)or(toggled~=nil and toggled~=1)then return false end
  local enabled,power=nativeSpring.GetUnitShieldState(id)
  -- Native LoS/rule access remains authoritative for enemies; do not expose
  -- unavailable allied-only data or suppress unrelated native shield types.
  if enabled==nil or power==nil then return wanted==nil and active or false end
  return(enabled==true or enabled==1)and type(power)=='number'and power>0
 end},{__index=nativeSpring})
 setfenv(chunk,setmetatable({Spring=scopedSpring},{__index=getfenv(1)}))
end
return chunk()

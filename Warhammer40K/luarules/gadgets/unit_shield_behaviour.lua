-- Preserve exact pinned BAR shield behavior; only commander toggle/availability gates.
local path='40k_reference/commander_shield_native_behaviour.lua'
local source=assert(VFS.LoadFile(path,VFS.GAME),'Missing pinned native shield behavior')
assert(VFS.CalculateHash(source,1)=='005176fe430abb132455b67dd6460c8d57e9f0cf2ca598f79482297000b37959a33ebb957a701280c65487fe7213082e709ae2f4cd338a388592e7e0805b78de','Pinned native shield behavior changed')
local patched=VFS.Include('40k_configs/shield_activation_bridge.lua').Patch(source)
local chunk=assert(loadstring(patched,'@'..path))
-- Native shield code needs shield activation, not the commander's economic
-- activation. Scope this view to this gadget; all other units see native state.
local nativeSpring=Spring
local scopedSpring=setmetatable({GetUnitIsActive=function(id)
 local policy=GG and GG.Recoil40KCommanderShieldActive
 local enabled=policy and policy(id)
 if enabled~=nil then return enabled and nativeSpring.GetUnitIsActive(id)end
 return nativeSpring.GetUnitIsActive(id)
end},{__index=nativeSpring})
setfenv(chunk,setmetatable({Spring=scopedSpring},{__index=getfenv(1)}))
return chunk()

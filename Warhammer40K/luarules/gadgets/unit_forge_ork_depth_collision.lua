-- Explicit collision proxies for derived Depth Volume units only.
function gadget:GetInfo()
 return {name='Forge animated Depth Volume collision',desc='Original full-model piece hitboxes independent of shader geometry',author='Local project',layer=-10000,enabled=true}
end
if not gadgetHandler:IsSyncedCode()then return end
local cfg=VFS.Include('luarules/configs/forge_ork_depth_collision.lua')
local defs={}
for name,entry in pairs(cfg.units)do
 local def=UnitDefNames[name]
 if def then defs[def.id]=entry end
end
local function apply(id,defID)
 local entry=defs[defID];if not entry then return end
 local pieces=Spring.GetUnitPieceMap(id)
 if not pieces then return end
 -- Validate first: never apply a partial collision setup to an incompatible rig.
 for _,proxy in ipairs(entry.proxies)do
  if not pieces[proxy.piece]then
   Spring.Echo('FORGE_COLLISION missing expected piece',id,proxy.piece)
   return false
  end
 end
 -- The full original volume set owns collision. Reduced seam geometry must not
 -- create a second, accidental set, and empty muzzle/helper pieces never hit.
 for _,piece in pairs(pieces)do
  Spring.SetUnitPieceCollisionVolumeData(id,piece,false,1,1,1,0,0,0,2,1)
 end
 for _,proxy in ipairs(entry.proxies)do
  local p=pieces[proxy.piece];local s,o=proxy.scales,proxy.offsets
  -- Script-visible empty transform anchors still need to participate in hits.
  Spring.SetUnitPieceVisible(id,p,true)
  Spring.SetUnitPieceCollisionVolumeData(id,p,true,s[1],s[2],s[3],o[1],o[2],o[3],proxy.volumeType,proxy.primaryAxis)
 end
 Spring.SetUnitRulesParam(id,'forge_depth_collision_revision',1,{private=true})
 return true
end
function gadget:UnitCreated(id,defID)apply(id,defID)end
function gadget:UnitFinished(id,defID)apply(id,defID)end
function gadget:Initialize()
 for _,id in ipairs(Spring.GetAllUnits())do apply(id,Spring.GetUnitDefID(id))end
end

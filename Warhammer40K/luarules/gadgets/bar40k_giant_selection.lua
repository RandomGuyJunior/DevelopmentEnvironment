function gadget:GetInfo()return{name='Giant fitted model selection',desc='Selection-only native piece volumes; projectile hulls unchanged',layer=0,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return end
local profiles=VFS.Include('luarules/configs/bar40k_giant_selection.lua')
local function setup(u,d)
 local key=UnitDefs[d].customParams.bar40k_selection_profile
 local profile=key and profiles[key]
 if not profile then return end
 local map=Spring.GetUnitPieceMap(u)
 if not map then return end
 -- These units use their unchanged whole-unit projectile hull, never pieces.
 for _,p in pairs(map)do Spring.SetUnitPieceCollisionVolumeData(u,p,false,1,1,1,0,0,0,2,1)end
 for _,box in ipairs(profile.boxes)do
  local p=map[box.name]
  if p then
   Spring.SetUnitPieceVisible(u,p,true)
   Spring.SetUnitPieceCollisionVolumeData(u,p,true,box.scales[1],box.scales[2],box.scales[3],0,0,0,2,1)
  end
 end
end
function gadget:Initialize()for _,u in ipairs(Spring.GetAllUnits())do setup(u,Spring.GetUnitDefID(u))end end
function gadget:UnitCreated(u,d)setup(u,d)end

-- Native static factory contract. Geometry/markers are one composed entity.
local pad, nano = piece('build_pad', 'nano')
function script.Create()
  Spring.SetUnitNanoPieces(unitID, {nano})
end
function script.QueryBuildInfo() return pad end
function script.QueryNanoPiece() return nano end
function script.Activate()
  SetUnitValue(COB.INBUILDSTANCE, 1)
  return 1
end
function script.Deactivate()
  SetUnitValue(COB.INBUILDSTANCE, 0)
  return 0
end
function script.StartBuilding()
  SetUnitValue(COB.INBUILDSTANCE, 1)
end
function script.StopBuilding()
  -- Native factory closes its own yard after product egress.
end
function script.Killed()
  -- Pinned CUnit uses return-1 as wreck-chain depth:1 selects original corpse.
  return 1
end

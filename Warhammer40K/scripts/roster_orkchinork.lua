-- Banked static Chinork, rigid rotor pivots. Native aircraft owns movement.
local body, front, rear, nano = piece("chinork_body", "chinork_rotor_front", "chinork_rotor_rear", "chinork_nano")
local y_axis = 2
function script.Create()
 Spring.SetUnitNanoPieces(unitID, {nano})
 SetUnitValue(COB.INBUILDSTANCE, 0)
 Spin(front, y_axis, math.rad(1080), math.rad(540))
 Spin(rear, y_axis, -math.rad(1080), math.rad(540))
end
function script.StartBuilding()
 SetUnitValue(COB.INBUILDSTANCE, 1)
end
function script.StopBuilding()
 SetUnitValue(COB.INBUILDSTANCE, 0)
end
function script.QueryNanoPiece() return nano end
function script.QueryBuildInfo() return body end
function script.Activate() return 1 end
function script.Deactivate() return 0 end
function script.Killed()
 StopSpin(front, y_axis)
 StopSpin(rear, y_axis)
 Explode(front, SFX.FALL + SFX.SMOKE + SFX.FIRE)
 Explode(rear, SFX.FALL + SFX.SMOKE + SFX.FIRE)
 Explode(body, SFX.FALL + SFX.SMOKE + SFX.FIRE)
 return 0
end

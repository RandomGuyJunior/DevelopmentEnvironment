-- Scoped utility chassis: native build/minelayer mechanics, no movement controller.
local nano,mine=piece('nano','mine')
local mineLayer=UnitDefs[unitDefID].customParams.bar40k_utility_mine_layer
function script.Create()Spring.SetUnitNanoPieces(unitID,{nano})end
function script.QueryNanoPiece()return nano end
function script.QueryBuildInfo()return mineLayer and mine or nano end
function script.StartBuilding(heading,pitch)SetUnitValue(COB.INBUILDSTANCE,1)end
function script.StopBuilding()SetUnitValue(COB.INBUILDSTANCE,0)end
function script.Activate()return 1 end
function script.Deactivate()return 0 end
function script.AimFromWeapon(n)return nano end
function script.QueryWeapon(n)return nano end
function script.AimWeapon(n,heading,pitch)return true end
function script.FireWeapon(n)end
function script.Shot(n)end
function script.Killed(recent,max)return recent/max>.5 and 2 or 1 end

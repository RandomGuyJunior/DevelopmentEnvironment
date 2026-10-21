local ROLE_BOMB=false
-- Native aircraft movement/ballistics; no polling or competing flight controller.
local body,muzzle,bomb,cargo=piece('body','muzzle','bomb','cargo')
function script.Create() end
function script.StartMoving() end
function script.StopMoving() end
function script.Activate() return 1 end
function script.Deactivate() return 0 end
function script.QueryWeapon(n) return ROLE_BOMB and bomb or muzzle end
function script.AimFromWeapon(n) return body end
function script.AimWeapon(n,heading,pitch) return ROLE_BOMB or (math.abs(heading)<math.rad(75) and math.abs(pitch)<math.rad(85)) end
function script.BlockShot(n,targetID) return false end
function script.FireWeapon(n) end
function script.Shot(n) end
function script.BeginTransport(passenger) SetUnitValue(COB.BUSY,0) end
function script.EndTransport() SetUnitValue(COB.BUSY,0) end
function script.QueryTransport(passenger) return cargo end
function script.TransportPickup(passenger) Spring.UnitScript.AttachUnit(cargo,passenger);SetUnitValue(COB.BUSY,0) end
function script.TransportDrop(passenger,x,y,z) Spring.UnitScript.DropUnit(passenger);SetUnitValue(COB.BUSY,0) end
function script.Killed(recentDamage,maxHealth) return 0 end

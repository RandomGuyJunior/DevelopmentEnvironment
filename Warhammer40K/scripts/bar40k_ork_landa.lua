local ROLE_BOMB=false
-- Native aircraft movement/ballistics; no polling or competing flight controller.
local body,muzzle,bomb,cargo=piece('body','muzzle','bomb','cargo')
-- Lua piece numbers are one-based. Zero becomes the engine's -1 hidden-cargo
-- sentinel, so passengers occupy the Landa internally rather than hanging below.
-- Native detach/death release clears this state; no separate NoDraw owner.
local INTERNAL_CARGO=0
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
function script.QueryTransport(passenger) return INTERNAL_CARGO end
function script.TransportPickup(passenger) Spring.UnitScript.AttachUnit(INTERNAL_CARGO,passenger);SetUnitValue(COB.BUSY,0) end
function script.TransportDrop(passenger,x,y,z) Spring.UnitScript.DropUnit(passenger);SetUnitValue(COB.BUSY,0) end
function script.Killed(recentDamage,maxHealth) return 0 end

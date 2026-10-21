local data=include("bar40k/animation_data.lua")("bar40k/bar40k_ork_battlewagon_kannon_animation.lua")
-- The heavy mount has a 90-degree forward traverse; turn the chassis outside it.
data.aimGroups[1].centerYaw=0
data.aimGroups[1].maxYaw=45
data.aimGroups[1].minPitch=-10
data.aimGroups[1].maxPitch=60
data.physicalBarrelGateDegrees=3
data.aimActuatorMinTurnDegrees=180
data.aimActuatorMinMoveSpeed=120
include("bar40k/walker_arsenal_actor.lua")(data)

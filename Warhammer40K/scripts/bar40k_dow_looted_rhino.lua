local data=include("bar40k/animation_data.lua")("bar40k/bar40k_dow_looted_rhino_animation.lua")
data.boundedTurretTraverse=true -- 60 deg/s yaw, 45 deg/s elevation; physical aim gate retained
include("bar40k/dow_native_pose_actor.lua")(data)

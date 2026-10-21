local data=include("bar40k/animation_data.lua")("bar40k/bar40k_sanctus_commander_animation.lua")
data.fixedInfantryPose=true
include("bar40k/sanctus_roster_actor.lua")(data)

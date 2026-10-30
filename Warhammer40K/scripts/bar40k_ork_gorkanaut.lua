local data=include("bar40k/animation_data.lua")("bar40k/bar40k_ork_gladius_gorkanaut_animation.lua")
include("bar40k/gladius_gork_arsenal_actor.lua")(data)

local facing=include("bar40k/gork_main_facing.lua")()
local originalCreate=script.Create
function script.Create()originalCreate();StartThread(facing.Run)end

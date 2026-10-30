local data=include("bar40k/animation_data.lua")("bar40k/orkgargant_animation.lua")
include("bar40k/giant_body_actor.lua")(data)

local facing=include("bar40k/gargant_belly_facing.lua")()
local inheritedCreate=script.Create
function script.Create()inheritedCreate();StartThread(facing.Run)end

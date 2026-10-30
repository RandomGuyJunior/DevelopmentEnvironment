local data=include("bar40k/animation_data.lua")("bar40k/orkgreatgargant_animation.lua")
include("bar40k/giant_body_actor.lua")(data)

-- This fixed horizontal mount pitches normally; native movement turns the hull.
local bellyFacing=include("bar40k/great_belly_facing.lua")()
local inheritedCreate=script.Create
function script.Create()
 inheritedCreate()
 StartThread(bellyFacing.Run)
end

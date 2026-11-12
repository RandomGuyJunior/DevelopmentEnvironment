include('imperial_guard/roster_actor.lua')('imperial_guard/impshadowsword_animation.lua')
local facing=include('bar40k/native_ground_facing.lua')(1,1)
local create=script.Create
function script.Create() create();StartThread(facing.Run) end

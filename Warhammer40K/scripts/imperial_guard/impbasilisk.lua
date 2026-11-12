include('imperial_guard/roster_actor.lua')('imperial_guard/impbasilisk_animation.lua')
local facing=include('bar40k/native_ground_facing.lua')(1.25,1,true)
local create=script.Create
function script.Create() create();StartThread(facing.Run) end

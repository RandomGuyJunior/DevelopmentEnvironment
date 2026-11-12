local data=include("bar40k/animation_data.lua")("bar40k/orkkannonwagon_animation.lua")
include("bar40k/walker_arsenal_actor.lua")(data)
-- Only native Shot confirms a shell and starts the authored recoil pulse.
function script.FireWeapon()end
include("bar40k/tts_ballistic_aim.lua")(data,6)

local nativeFacing=include('bar40k/native_ground_facing.lua')(42,1)
local createBeforeFacing=script.Create
function script.Create()createBeforeFacing();StartThread(nativeFacing.Run)end

local data=include("bar40k/animation_data.lua")("bar40k/orkkillbursta_animation.lua")
include("bar40k/roster_experimental_flat.lua")(data)
-- A projectile, not a FireWeapon attempt, owns the existing gun recoil.
function script.FireWeapon()end
-- Consume native Cannon wantedDir once; preserve its own high/low solution.
include("bar40k/tts_ballistic_aim.lua")(data,5)

local nativeFacing=include('bar40k/native_ground_facing.lua')(22,1)
local createBeforeFacing=script.Create
function script.Create()createBeforeFacing();StartThread(nativeFacing.Run)end

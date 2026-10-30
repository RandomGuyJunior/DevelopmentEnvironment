local data=include("bar40k/animation_data.lua")("bar40k/bar40k_gladius_warbike_animation.lua")
include("bar40k/walker_arsenal_actor.lua")(data)
local nextMuzzle=1
local oldShot=script.Shot
function script.QueryWeapon(n)return piece(data.weapons[n].muzzles[nextMuzzle])end
function script.Shot(n)oldShot(n);nextMuzzle=nextMuzzle%#data.weapons[n].muzzles+1 end
local facing=include("bar40k/gladius_warbike_facing.lua")()
local oldCreate=script.Create
function script.Create()oldCreate();StartThread(facing.Run)end

local data=include("bar40k/animation_data.lua")("bar40k/bar40k_gladius_warbuggy_animation.lua")
include("bar40k/walker_arsenal_actor.lua")(data)
local nextMuzzle=1
local oldShot=script.Shot
function script.QueryWeapon(n)return piece(data.weapons[n].muzzles[nextMuzzle])end
function script.Shot(n)oldShot(n);nextMuzzle=nextMuzzle%#data.weapons[n].muzzles+1 end

local shared=include("bar40k/animation_data.lua")("bar40k/bar40k_knight_crusader_animation.lua")
local data=setmetatable({clips={}}, {__index=shared})
for k,v in pairs(shared.clips)do data.clips[k]=v end
include("bar40k/knight_repaired_actor.lua")(data)
local nextMuzzle={};local oldQuery,oldShot=script.QueryWeapon,script.Shot
function script.QueryWeapon(n)local list=data.weapons[n].muzzles;return piece(list[nextMuzzle[n]or 1])end
function script.Shot(n)oldShot(n);nextMuzzle[n]=(nextMuzzle[n]or 1)%#data.weapons[n].muzzles+1 end
local oldAim,oldBlock=script.AimWeapon,script.BlockShot
function script.AimWeapon(n,h,p)return oldAim(n==4 and 1 or n,h,p)end
function script.BlockShot(n)if n==4 then return oldBlock(1)end;return oldBlock(n)end

local nativeFacing=include("bar40k/knight_primary_facing.lua")()
local originalCreate=script.Create
function script.Create()originalCreate();StartThread(nativeFacing.Run)end

include("bar40k/knight_ion_shield_bind.lua")()

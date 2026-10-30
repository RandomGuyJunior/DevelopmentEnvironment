-- Share immutable source clips and geometry; only comparison config is private.
local source=include("bar40k/animation_data.lua")("bar40k/orkgreatgargant_animation.lua")
local data={};for k,v in pairs(source)do data[k]=v end
data.weaponMounts={};for k,v in pairs(source.weaponMounts)do data.weaponMounts[k]=v end
local gun={};for k,v in pairs(source.weaponMounts[2])do gun[k]=v end
gun.continuousFireFrames=8;gun.cadenceFrames=4.5;data.weaponMounts[2]=gun
include("bar40k/giant_body_actor.lua")(data)
local bellyFacing=include("bar40k/great_belly_facing.lua")()
local inheritedCreate=script.Create
function script.Create()inheritedCreate();StartThread(bellyFacing.Run)end

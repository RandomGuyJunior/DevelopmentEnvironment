local source=include("bar40k/animation_data.lua")("bar40k/orkgreatgargant_animation.lua")
local data={};for k,v in pairs(source)do data[k]=v end
data.weaponMounts={};for k,v in pairs(source.weaponMounts)do data.weaponMounts[k]=v end
local gun={};for k,v in pairs(source.weaponMounts[2])do gun[k]=v end
gun.alternateSalvo=false;gun.continuousFireFrames=nil;gun.cadenceFrames=nil
data.weaponMounts[2]=gun
local sfx={}
for n,side in pairs({[4]='left',[5]='right'})do
 local mount={};for k,v in pairs(source.weaponMounts[n])do mount[k]=v end
 mount.muzzles={'rapid_shoulder_'..side..'_muzzle_a','rapid_shoulder_'..side..'_muzzle_b'}
 mount.fireClip=nil;mount.alternateSalvo=nil
 sfx[n]=mount.sfx;mount.sfx=nil
 data.weaponMounts[n]=mount
end
data.shoulderClearance=include("bar40k/giant_hull_clearance.lua").twin
include("bar40k/giant_body_actor.lua")(data)
include("bar40k/great_salvo.lua")(data)
include("bar40k/great_twin_recoil.lua")(data,sfx)
local bellyFacing=include("bar40k/great_belly_facing.lua")()
local inheritedCreate=script.Create
function script.Create()inheritedCreate();StartThread(bellyFacing.Run)end
include("bar40k/great_death_sequence.lua")()

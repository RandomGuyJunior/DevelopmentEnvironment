local bank=include('bar40k/animation_data.lua')('bar40k/ouchy_shokk_anim.lua')
local data={};for k,v in pairs(bank)do data[k]=v end
local aim={};for k,v in pairs(bank.aim)do aim[k]=v end
-- Exact native donor servo profile, without mutating cached artwork.
aim.yawSpeed=500;aim.pitchSpeed=250
-- Actual muzzle elevation: Grot payload nose is30degrees above the gun.
aim.minPitch=-54.479;aim.maxPitch=60;aim.spinJoint=4;aim.spinPivotBind={-0.5435724626485444,63.935190717528485,44.16768672559229};aim.spinDegreesPerSecond=45;aim.spinHoldSeconds=.15;data.aim=aim
include('bar40k/ouchy_tower_actor.lua')(data)

local bank=include('bar40k/animation_data.lua')('bar40k/ouchy_grot_anim.lua')
local data={};for k,v in pairs(bank)do data[k]=v end
local aim={};for k,v in pairs(bank.aim)do aim[k]=v end
-- Exact native donor servo profile, without mutating cached artwork.
aim.yawSpeed=300.071429;aim.pitchSpeed=200.043956
-- Actual muzzle elevation: Grot payload nose is30degrees above the gun.
aim.minPitch=-24.479;aim.maxPitch=89.9;data.aim=aim
include('bar40k/ouchy_tower_actor.lua')(data)

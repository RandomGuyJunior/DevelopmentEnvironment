local bank=include('bar40k/animation_data.lua')('bar40k/ouchy_zzap_anim.lua')
local data={};for k,v in pairs(bank)do data[k]=v end
local aim={};for k,v in pairs(bank.aim)do aim[k]=v end
-- Exact native donor servo profile, without mutating cached artwork.
aim.yawSpeed=50;aim.pitchSpeed=50
-- Actual muzzle elevation: Grot payload nose is30degrees above the gun.
aim.minPitch=-54.479;aim.maxPitch=60;data.aim=aim
include('bar40k/ouchy_tower_actor.lua')(data)

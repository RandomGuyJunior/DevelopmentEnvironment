-- Authored normal-play adaptation of the genuine cannon and four-port rocket pod.
-- Each native weapon owns its reload, projectiles, spread, collision and damage.
local M={}
function M.Apply(d)
 local gun=assert(d.weapondefs.mount1)
 local rockets=assert(d.weapondefs.mount2)
 assert(gun.weapontype=='Cannon' and rockets.weapontype=='MissileLauncher')
 assert(rockets.customparams.source_muzzle_pair=='marker_dreadnought_missile_nub_1,marker_dreadnought_missile_nub_2,marker_dreadnought_missile_nub_3,marker_dreadnought_missile_nub_4')
 gun.name='Hellfire assault cannon'
 gun.customparams.source_aimfrom_muzzle=1
 gun.customparams.source_muzzlefx='40k_dow_assaultcannon_muzzle'
 gun.explosiongenerator='custom:40k_dow_assaultcannon_impact'
 rockets.name='Hellfire rocket salvo'
 rockets.burst=4;rockets.burstrate=.16
 -- Preserve the old 365 raw damage per two-second cycle across four missiles.
 rockets.damage.default=(rockets.customparams.source_damage_min+rockets.customparams.source_damage_max)/2/rockets.burst
 rockets.areaofeffect=48;rockets.edgeeffectiveness=.35
 rockets.accuracy=180;rockets.sprayangle=900
 rockets.tracks=false;rockets.turnrate=0
 rockets.weaponvelocity=300;rockets.startvelocity=120;rockets.weaponacceleration=180;rockets.flighttime=3
 rockets.model='cormissile.s3o'
 rockets.cegtag='40k_dow_rokkit_trail'
 rockets.explosiongenerator='custom:40k_dow_rokkit_impact'
 rockets.customparams.source_muzzlefx='40k_dow_rokkit_muzzle'
 rockets.customparams.source_aimfrom_muzzle=1
 rockets.customparams.hellfire_salvo_adaptation='four native unguided missiles; original cycle damage split equally; physical spread and blast; original pod emitters'
 d.customparams.hellfire_weapon_repair='native_pod_salvo_v1'
 return d
end
return M

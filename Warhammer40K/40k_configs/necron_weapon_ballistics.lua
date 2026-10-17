-- Independent, explicitly reviewed native geometry/cadence patch. No acceptance markers.
local M={}
M.Profiles={
 nec_lord={{reload=1,accuracy=.8,beam=true,source='necron_lord_staff_of_light_ranged'}},
 nec_warrior={{reload=1,accuracy=.7,beam=true,source='necron_warrior_gauss_flayer_ranged'}},
 nec_immortal={{reload=1,accuracy=.8,beam=true,source='necron_gauss_blaster_immortal'},{reload=1,accuracy=.8,beam=true,source='necron_gauss_blaster_immortal'}},
 nec_destroyer={{reload=.5,accuracy=.7,beam=true,source='necron_gauss_flayer_destroyer'},{reload=.5,accuracy=.7,beam=true,source='necron_gauss_flayer_destroyer'}},
 nec_heavy_destroyer={{reload=3,accuracy=.8,beam=true,source='necron_gauss_cannon_heavy_destroyer'}},
 nec_spyder={{reload=1,accuracy=.8,beam=true,source='necron_tomb_spyder_particle_projector'}},
 nec_turret={},
 nec_monolith_mobile={{reload=3,accuracy=1,beam=true,source='necron_particle_whip_monolith'}},
 -- Source ranged event is not sufficient to prove a beam: retain native projectile.
 nec_nightbringer={{reload=1,accuracy=.8,beam=false,source='necron_nightbringer_scythe_ranged'}},
}
for i=1,8 do M.Profiles.nec_turret[i]={reload=3,accuracy=.9,beam=true,source='necron_warrior_gauss_flayer_turret'}end
for i,side in ipairs({'left_front','right_front','left_rear','right_rear'})do M.Profiles.nec_monolith_mobile[i+1]={reload=1,accuracy=.8,beam=true,source='necron_heavy_gauss_cannon_'..side..'_monolith'}end
local function allowed(ready,key)return type(ready)=='function' and ready(key)==true or type(ready)=='table' and ready[key]==true end
local function positive(n)return type(n)=='number' and n==n and n>0 and n<math.huge end
-- review[key]={approved=true,clips={fire=actualExportedDuration,...}}
-- Full clip-cycle floor is deliberately conservative; no animation keys/events rewritten.
function M.Apply(defs,ready,review)
 local changed={};local keys={};for key in pairs(M.Profiles)do keys[#keys+1]=key end;table.sort(keys)
 for _,key in ipairs(keys)do
  local d=defs[key];local r=type(review)=='table' and review[key]
  if d and allowed(ready,key) and type(r)=='table' and r.approved==true then
   local patches={};local valid=true
   for i,p in ipairs(M.Profiles[key])do
    local mount=d.weapons and d.weapons[i];local w=mount and d.weapondefs and d.weapondefs[mount.def]
    local cp=w and w.customparams;local clip=cp and cp.source_fireclip;local cycle=0
    if clip and clip~='' then cycle=r.clips and r.clips[clip] end
    if not w or not cp or not cp.source_muzzle or not positive(w.reloadtime) or not (cycle==0 or positive(cycle))
      or (w.weapontype~='BeamLaser' and w.weapontype~='LaserCannon')
      or (p.accuracy<1 and not ((tonumber(w.accuracy)or 0)>0 or (tonumber(w.sprayangle)or 0)>0)) then valid=false;break end
    patches[#patches+1]={w=w,p=p,reload=math.max(w.reloadtime,p.reload,cycle),cycle=cycle}
   end
   if valid then
    for _,patch in ipairs(patches)do
     local w,p=patch.w,patch.p
     if p.beam and w.weapontype~='BeamLaser' then
      -- Beam default distance attenuation would silently reduce former projectile damage.
      w.weapontype='BeamLaser';w.beamburst=false;w.sweepfire=false;w.minintensity=1
     end
     w.reloadtime=patch.reload
     w.collidefriendly=true;w.collideenemy=true;w.collideground=true;w.collidefeature=true;w.collideneutral=true;w.collidenontarget=true
     w.avoidfriendly=true;w.avoidfeature=true;w.avoidground=true;w.waterweapon=false
     -- Native angular spread remains untouched: source probability is not an angular cone.
     local cp=w.customparams;cp.source_ballistics_profile=p.source;cp.source_ballistics_reload=p.reload;cp.source_ballistics_accuracy=p.accuracy
     cp.source_ballistics_clipcycle=patch.cycle;cp.source_ballistics_native_pending=1
    end
    changed[#changed+1]=key
   end
  end
 end
 return changed
end
return M

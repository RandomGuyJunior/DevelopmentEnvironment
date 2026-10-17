-- Genuine two-hardpoint Tactical Bike. Review-only until independent acceptance.
local M={Key='imp_tactical_bike',Source='attrib/ebps/races/space_marines/troops/space_marine_tactical_bike.lua'}
local function finite(n)return type(n)=='number'and n==n and n>0 and n<math.huge end
function M.Ready(f)
 if type(f)~='table'or f.version~=1 or f.source_entity~=M.Source or f.source_squad~='attrib/sbps/races/space_marines/space_marine_squad_tactical_bike.lua'or not finite(f.pose_error)or f.pose_error>=1e-4 then return false end
 for _,name in ipairs({'bone_bike_rear','bone_bike_front_end','marker_bolter_barrel01','marker_bolter_barrel02','marker_chain_sword_edge'})do if not(f.bones and f.bones[name])then return false end end
 for _,name in ipairs({'idle','walk','fire','melee'})do if not(f.clips and f.clips[name]and finite(f.clips[name].duration))then return false end end
 return f.health==670 and f.initial_cost.metal==170 and f.initial_cost.energy==30 and f.initial_cost.time==30 and f.weapons and #f.weapons==2
end
function M.Build(f,policy)
 if not M.Ready(f)or type(policy)~='table'or not finite(policy.rangeScale)or not finite(policy.speedScale)then return end
 local gun,claw=f.weapons[1],f.weapons[2]
 assert(gun.source_profile=='attrib/weapon/chaos_bolter_bike.lua'and gun.source_reload==.5 and claw.source_profile=='attrib/weapon/space_marine_chainsword_assault.lua'and claw.source_reload==1,'Genuine default source hardpoints required')
 local dims={};for i=1,3 do dims[i]=f.bounds.max[i]-f.bounds.min[i];assert(finite(dims[i]))end
 local function weapon(name,kind,reload,damage)
  return {name=name,weapontype=kind,reloadtime=reload,damage={default=damage},turret=true,tolerance=4000,
   collidefriendly=true,collideenemy=true,collideground=true,collidefeature=true,collideneutral=true,collidenontarget=true,
   avoidfriendly=true,avoidfeature=true,avoidground=true,areaofeffect=1,cratermult=0,impulsefactor=0}
 end
 local bolter=weapon('Paired bike bolters','Cannon',gun.source_reload,(gun.source_damage_min+gun.source_damage_max)/2)
 bolter.range=gun.source_range*policy.rangeScale;bolter.burst=1;bolter.weaponvelocity=450;bolter.size=.35;bolter.stages=2
 bolter.accuracy=70;bolter.sprayangle=70;bolter.rgbcolor='1 .8 .3';bolter.rgbcolor2='1 .1 .05'
 bolter.explosiongenerator='custom:40k_dow_bolter_impact'
 bolter.customparams={source_profile=gun.source_profile,source_profile_sha256=gun.source_sha256,source_hardpoint=1,
  source_muzzle='marker_bolter_barrel01',source_muzzle_pair='marker_bolter_barrel01,marker_bolter_barrel02',source_muzzle_pair_mode='simultaneous',source_fireclip='fire',
  source_wholebodyaim=1,source_wholebodyfire=1,source_weapon_bones='bone_bike_front_end',source_weapon_bones_only=1,
  source_muzzlefx='40k_dow_bolter_muzzle',source_fx_family='bolter',source_accuracy=gun.source_accuracy,source_damage_min=gun.source_damage_min,source_damage_max=gun.source_damage_max,
  source_range=gun.source_range,source_effects_pending=1,source_cue_inferred=1,source_native_collision_pending=1,
  source_damage_adaptation='Deterministic midpoint; source armour table/native cadence/spread requires acceptance'}
 local melee=weapon('Bike rider chainsword','Melee',claw.source_reload,(claw.source_damage_min+claw.source_damage_max)/2)
 -- No source range/contact timestamp exists in the copied weapon profile.
 -- Empty fireclip makes existing roster melee guard refuse; trajectory inference
 -- cannot silently turn a proposed maximum-reach frame into an accepted hit.
 melee.range=policy.meleeDiagnosticRange or 24;assert(finite(melee.range),'Explicit prototype melee reach required')
 melee.explosiongenerator='custom:40k_dow_chainsword_impact'
 melee.customparams={source_profile=claw.source_profile,source_profile_sha256=claw.source_sha256,source_hardpoint=2,
  source_muzzle='marker_chain_sword_edge',source_fireclip='',source_expected_fireclip='melee',source_no_muzzle=1,
  source_wholebodyaim=1,source_contact_pending=1,source_range_pending=1,source_effects_pending=1,source_fx_family='chainsword',
  source_damage_min=claw.source_damage_min,source_damage_max=claw.source_damage_max}
 return {name='Tactical Bike',description='Space Marine bike with paired bolters and rider chainsword',objectname=f.asset_key..'.glb',script='40k_roster.lua',buildpic='40k_'..f.asset_key..'.png',
  metalcost=170,energycost=30,buildtime=30*30,health=670,speed=f.source_speed*policy.speedScale,maxacc=.08,maxdec=.2,turnrate=1000,turninplace=true,
  canmove=true,canattack=true,canreclaim=false,canrepair=false,builder=false,footprintx=2,footprintz=4,movementclass=policy.movementClass or'TANK3',maxslope=15,maxwaterdepth=0,
  category='ALL MOBILE NOTSUB SURFACE',sightdistance=400,collisionvolumetype='Box',collisionvolumescales=table.concat(dims,' '),collisionvolumeoffsets='0 0 0',upright=true,
  weapondefs={bike_bolter=bolter,bike_chainsword=melee},weapons={{def='bike_bolter',onlytargetcategory='SURFACE'},{def='bike_chainsword',onlytargetcategory='SURFACE'}},
  customparams={faction='Imperium',prototype40k=1,prototype40k_expansion=1,animsource=f.asset_key,rosterrole='bike',unitgroup='weapon',
   source_entity=M.Source,source_squad=f.source_squad,source_model_sha256=f.source_model_sha256,source_generated_glb_sha256=f.generated_model_sha256,
   prototype40k_tech_requires=M.Key,source_cohort_pending=1,source_melee_contact_pending=1,source_source_cadence_pending=1,source_collision_pending=1,
   integration_status='genuine_source_candidate_native_unaccepted',source_initial_members=1,source_maximum_members=3,
   source_native_range_adaptation=policy.rangeScale,source_native_speed_adaptation=policy.speedScale}}
end
function M.Definitions(f,options,policy)
 options=options or{}
 local review=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(options.prototype_source_progression)and(options.prototype_diagnostic=='roster'or options.prototype_diagnostic=='expandedproduction')
 -- Whole mechanics are unaccepted; files alone never expose ordinary content.
 if not review then return{}end
 if not f or not VFS.FileExists('objects3d/'..f.asset_key..'.glb')or not VFS.FileExists('scripts/generated/'..f.asset_key..'_anim.lua')or not VFS.FileExists('unitpics/40k_'..f.asset_key..'.png')or not VFS.FileExists('scripts/40k_roster.lua')then return{}end
 local d=M.Build(f,policy);return d and{[M.Key]=d}or{}
end
return M

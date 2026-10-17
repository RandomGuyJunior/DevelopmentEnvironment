-- Exact GOH-01 actor; root integrates its single ORK-VEH-3 production assignment.
local options=Spring and Spring.GetModOptions and Spring.GetModOptions()or{}
if not VFS.Include('40k_configs/ork_registration_gates.lua').Allowed('ork_morkanaut',options)then return{}end
local path='40k_configs/ork_morkanaut_facts.lua'
if not VFS.FileExists(path)then return{}end
local facts=VFS.Include(path)
for _,file in ipairs({'objects3d/ork_morkanaut.glb','objects3d/ork_morkanaut.glb.lua','objects3d/ork_morkanaut_wreck.glb','objects3d/ork_morkanaut_wreck.glb.lua','unittextures/ork_morkanaut_tex1.png','unittextures/ork_morkanaut_tex2.png','scripts/generated/ork_morkanaut_anim.lua','scripts/40k_morkanaut.lua'})do
 if not VFS.FileExists(file)then return{}end
end
assert(facts.sourceLabel=='evz_morkanaut'and facts.recipe=='GOH-01/ORK-VEH-3'and facts.export_verified,'Exact Morkanaut geometry facts required')
local function projectile(name,range,reload,damage,aoe)
 return{name=name,weapontype='Cannon',range=range,reloadtime=reload,weaponvelocity=420,turret=true,tolerance=900,
  rgbcolor='.15 .45 1',rgbcolor2='.7 .9 1',size=1.2,stages=3,explosiongenerator='custom:40k_ork_kmb_impact',areaofeffect=aoe,
  collidefriendly=true,collideenemy=true,collideground=true,collidefeature=true,collideneutral=true,collidenontarget=true,
  avoidfriendly=true,avoidfeature=true,cratermult=0,impulsefactor=0,damage={default=damage}}
end
local wd={main=projectile('Main-arm Kustom Mega-blasta',620,4.5,420,48),belly=projectile('Torso Kustom Mega-blasta',410,2.2,95,16),
 rokkits={name='Shoulder Rokkit Launchas',weapontype='MissileLauncher',range=520,reloadtime=5,weaponvelocity=300,startvelocity=120,weaponacceleration=120,
  turret=true,tolerance=1000,tracks=false,areaofeffect=40,burst=2,burstrate=.2,model='cormissile.s3o',smoketrail=true,
  explosiongenerator='custom:40k_ork_ranged_rokkit_impact',cegtag='40k_ork_ranged_rokkit_trail',cratermult=0,impulsefactor=0,
  collidefriendly=true,collideenemy=true,collideground=true,collidefeature=true,collideneutral=true,collidenontarget=true,avoidfriendly=true,avoidfeature=true,damage={default=140}},
 klaw={name='Morkanaut Power Klaw',weapontype='Melee',range=72,reloadtime=3.2,turret=true,tolerance=3000,areaofeffect=1,cratermult=0,impulsefactor=0,
  collidefriendly=true,collideenemy=true,collideground=true,collidefeature=true,collideneutral=true,collidenontarget=true,avoidfriendly=true,avoidfeature=true,damage={default=310}}}
-- Native target-directed aiming reaches the genuine arm's limited yaw/pitch.
-- The existing forward mount cone still bounds the articulation; no move orders.
wd.main.turret=true
wd.main.size=2.4
wd.main.explosiongenerator='custom:40k_morkanaut_kmb_impact'
-- Native plasma interception owns power, regeneration and incoming projectile
-- removal. The pelvis-centered sphere encloses the complete current body.
-- Reversible balance: 3000 power, 60/sec regen costing 120 energy/sec while
-- regenerating, 1500 starting power; smart/exterior prevents own-fire capture.
wd.kff={name='Morkanaut Kustom Force Field',weapontype='Shield',damage={default=0},
 shield={radius=96,power=3000,startingpower=1500,powerregen=60,powerregenenergy=120,
  armortype='shields',intercepttype=1,repulser=false,smart=true,exterior=true,
  visible=true,visiblerepulse=true,visiblehitframes=8,alpha=.18,
  goodcolor={.15,.45,1,.18},badcolor={.075,.225,.5,.12}},
 customparams={source_actor='evz_morkanaut',source_muzzle=facts.mounts.pelvis,
  source_field_device='mork027_kustom_force_field',source_passive=1,requires_native_shield=1}}
for key,muzzle in pairs({main=facts.mounts.main,belly=facts.mounts.belly,rokkits=facts.mounts.rockets,klaw=facts.mounts.klaw})do
 local family=key=='rokkits'and'rokkit'or key=='klaw'and'power_claw'or'kmb'
 wd[key].customparams={source_muzzle=muzzle,source_actor='evz_morkanaut',source_fx_family=family}
end
wd.rokkits.customparams.source_muzzle=facts.mounts.rocketPorts[1]
wd.rokkits.customparams.source_muzzle_pair=table.concat(facts.mounts.rocketPorts,',')
return{ork_morkanaut={name='Morkanaut',description='T3 heavy walker: main-arm and torso Mega-blastas, rokkits, power klaw and plasma KFF',
 objectname='ork_morkanaut.glb',script='40k_morkanaut.lua',buildpic='40k_ork_morkanaut.png',
 metalcost=3000,energycost=18000,buildtime=24000,health=12000,speed=18,maxacc=.05,maxdec=.14,turnrate=550,turninplace=true,
 explodeas='largeExplosionGeneric',selfdestructas='largeExplosionGenericSelfd',
 canmove=true,canattack=true,category='ALL MOBILE NOTSUB SURFACE',footprintx=math.max(6,facts.footprintx),footprintz=math.max(6,facts.footprintz),movementclass='HTBOT6',
 maxslope=24,maxwaterdepth=5,sightdistance=560,upright=true,collisionvolumetype='Box',collisionvolumescales=facts.collisionvolumescales,
 collisionvolumeoffsets=facts.collisionvolumeoffsets,selectionvolumetype='Box',selectionvolumescales=facts.selectionvolumescales,
 customparams={faction='Orks',prototype40k=1,prototype40k_source_progression=1,techlevel=3,animsource='ork_morkanaut',rosterrole='walker',unitgroup='weapon',
  source_entity='evz_morkanaut',source_asset='GOH-01',ork_producer_recipe='ORK-VEH-3',model_author='private source',
  source_independent_weapon_assemblies=1,source_native_kff='native_plasma_shield_v1',source_main_arm_aim='target_direction_safe18x22_v2',source_morkanaut_conversion='canonical_weighted_v1',integration_status='native_acceptance_pending'},
 sfxtypes={explosiongenerators={'custom:40k_ork_kmb_muzzle','custom:40k_dow_rokkit_muzzle','custom:40k_morkanaut_kmb_muzzle'}},weapondefs=wd,
 weapons={{def='main',onlytargetcategory='SURFACE',maindir='0 0 1',maxangledif=36},{def='belly',onlytargetcategory='SURFACE',maindir='0 0 1',maxangledif=16},
  {def='rokkits',onlytargetcategory='SURFACE',maindir='0 0 1',maxangledif=24},{def='klaw',onlytargetcategory='SURFACE'},{def='kff',onlytargetcategory='NOTSUB'}},
 corpse='wreck',featuredefs={wreck={description='Morkanaut wreck',object='ork_morkanaut_wreck.glb',blocking=false,reclaimable=true,autoreclaimable=true,
  resurrectable=0,indestructible=true,flammable=false,health=1,metal=750,energy=0,footprintx=facts.footprintx,footprintz=facts.footprintz,
  featuredead='',customparams={source_vehicle='evz_morkanaut',parent_actor='ork_morkanaut',prototype40k_remains_domain='vehicle',one_salvage_owner=1,persistent_salvage=1}}}}}

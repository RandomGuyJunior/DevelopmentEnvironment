-- Authored Necron faction. Converted private assets and native validation are required.
local defs={}
local options=Spring and Spring.GetModOptions and Spring.GetModOptions() or {}
local mode=options.prototype_diagnostic
local fixture=mode=='roster' or mode=='expandedproduction' or mode=='ui' or mode=='vital'
fixture=fixture=='1' or fixture==1 or fixture==true
-- Exact mixed-v2 actor set only, with source progression explicitly opted in.
local mixedSelected=VFS.Include('40k_configs/mixed_v2_adapter.lua').Selected(options)
local function add(key,name,role,metal,energy,time,hp,speed,size)
 if mixedSelected and not mixedSelected[key] then return end
 if not VFS.FileExists('objects3d/'..key..'.glb') or not VFS.FileExists('scripts/generated/'..key..'_anim.lua') or not VFS.FileExists('scripts/40k_roster.lua')
 or (not fixture and not VFS.Include('40k_configs/development_playtest.lua').Allowed(key,options) and not (mixedSelected and mixedSelected[key]) and not VFS.FileExists('40k_configs/validated/'..key..'.lua')) then return end
 local d={name=name,description='Necrons '..role,objectname=key..'.glb',script='40k_roster.lua',buildpic='40k_'..key..'.png',
 metalcost=metal,energycost=energy,buildtime=time,health=hp,speed=speed,footprintx=size,footprintz=size,
 maxacc=.08,maxdec=.2,turnrate=700,maxslope=30,maxwaterdepth=5,sightdistance=450,upright=true,
 canmove=speed>0,canattack=false,category=speed>0 and 'ALL MOBILE NOTSUB SURFACE' or 'ALL NOTSUB SURFACE',
 collisionvolumetype=speed>0 and 'CylY' or 'Box',collisionvolumeoffsets='0 0 0',
 customparams={faction='Necrons',prototype40k=1,prototype40k_expansion=1,animsource=key,rosterrole=role,production_role=role,
 unitgroup=role,balance_status='provisional_native_validation_required'},
 sfxtypes={explosiongenerators={'custom:40k_dow_gauss_muzzle','custom:40k_dow_gauss_heavy_muzzle','custom:40k_dow_particle_muzzle'}}}
 if speed>0 then d.movementclass=size>=3 and 'TANK3' or 'SBOT2';d.turninplace=true
 else d.yardmap=string.rep('o',size*size) end
 defs[key]=d;return d
end
local function gun(d,label,kind,range,reload,damage,muzzle,clip,family,pivot,pitch,burst,spacing)
 if not d then return end
 d.canattack=true;d.weapondefs=d.weapondefs or {};d.weapons=d.weapons or {};local n=#d.weapons+1;local key='mount'..n
 local w={name=label,weapontype=kind,range=range,reloadtime=reload,damage={default=damage},turret=true,
 accuracy=100,sprayangle=130,tolerance=3000,areaofeffect=1,cratermult=0,impulsefactor=0,
 collidefriendly=true,collideenemy=true,collideground=true,collidefeature=true,collideneutral=true,collidenontarget=true,
 avoidfriendly=true,avoidfeature=true,burst=burst or 1,burstrate=spacing or .3,
 rgbcolor='.12 1 .18',rgbcolor2='.8 1 .8',thickness=.5,corethickness=.2,beamtime=.055,beamttl=2,
 weaponvelocity=900,size=.35,stages=2,duration=.025,explosiongenerator='custom:40k_dow_'..family..'_impact',
 customparams={source_muzzle=muzzle,source_fireclip=clip or '',source_fx_family=family,
 source_muzzlefx=family=='gauss' and 1024 or family=='gauss_heavy' and 1025 or 1026}}
 if pivot then w.customparams.source_aimpiece=pivot end
 if pitch then w.customparams.source_pitchpiece=pitch end
 if d.customparams.rosterrole=='tank' or d.customparams.rosterrole=='defence' then
  if not pivot then w.customparams.source_wholebodyaim=1 end
 end
 if kind=='Melee' then
  w.explosiongenerator='custom:40k_dow_necron_blade_impact';w.customparams.source_muzzlefx=nil;w.customparams.source_fireclip='melee'
  w.customparams.source_fx_family='necron_blade';w.accuracy=0;w.sprayangle=0
 end
 d.weapondefs[key]=w;d.weapons[n]={def=key,onlytargetcategory=kind=='Melee' and 'SURFACE' or 'NOTSUB'}
end
local lord=add('nec_lord','Necron Lord','infantry',1000,5000,9000,5000,18,1)
gun(lord,'Staff of Light','LaserCannon',290,1.8,38,'marker_gun_muzzle_ctr','fire','particle')
gun(lord,'Staff blade','Melee',25,3.0,90,'marker_gun_muzzle_start','melee','necron_blade')
local scarab=add('nec_scarab','Builder Scarab','builder',55,220,500,240,23,1)
local warrior=add('nec_warrior','Necron Warrior','infantry',35,190,420,420,16,1)
gun(warrior,'Gauss Flayer','BeamLaser',285,1.1,16,'marker_gun_muzzle_ctr_out','fire','gauss')
local immortal=add('nec_immortal','Necron Immortal','infantry',85,440,850,750,16,1)
gun(immortal,'Gauss Blaster','BeamLaser',340,1.5,18,' marker_gauss_muzzle01_ext','fire','gauss')
gun(immortal,'Gauss Blaster right tube','BeamLaser',340,1.5,18,' marker_gauss_muzzle02_ext','fire','gauss')
local flayed=add('nec_flayed','Flayed One','infantry',55,280,600,600,19,1)
gun(flayed,'Flayer blades','Melee',23,2.7,65,'mrkr_blade_r_01','melee','necron_blade')
local destroyer=add('nec_destroyer','Necron Destroyer','tank',260,1300,2400,1450,34,2)
gun(destroyer,'Gauss Cannon','BeamLaser',385,1.6,30,'marker_gunmuzzle_01','fire','gauss_heavy','bip01','bip01 spine1')
gun(destroyer,'Gauss Cannon right tube','BeamLaser',385,1.6,30,'marker_gunmuzzle_02','fire','gauss_heavy','bip01','bip01 spine1')
local heavy=add('nec_heavy_destroyer','Heavy Destroyer','tank',420,2100,3200,1700,31,2)
gun(heavy,'Heavy Gauss Cannon','BeamLaser',480,4.5,155,'marker_gun_muzzle_ctr01','fire','gauss_heavy','bip01','bone_gun_vertical')
local wraith=add('nec_wraith','Wraith','infantry',130,650,1400,900,26,1)
gun(wraith,'Phase claws','Melee',25,2.4,75,'mrkr_needle_right_01','melee','necron_blade')
local spyder=add('nec_spyder','Tomb Spyder','walker',390,1900,3300,2400,21,2)
gun(spyder,'Particle Projector','LaserCannon',310,2.8,80,'marker_gun_muzzle_ctr','fire','particle','ts_bone_llower_arm','ts_bone_lupper_arm')
gun(spyder,'Tomb Spyder claw','Melee',35,3.1,140,'mrkr_claw_right_cntr','melee','necron_blade')
local monolith=add('nec_monolith_mobile','Restored Monolith','tank',1800,9000,13500,10000,16,6)
gun(monolith,'Particle Whip','LaserCannon',630,6,420,'mrkr_crystal_ctr','fire','particle')
if monolith then monolith.weapondefs.mount1.areaofeffect=48;monolith.weapondefs.mount1.thickness=1.3;monolith.weapondefs.mount1.accuracy=160 end
for _,v in ipairs({{'front_left','fl'},{'front_right','fr'},{'rear_left','rl'},{'rear_right','rr'}}) do
 gun(monolith,'Gauss Flux Arc '..v[1],'BeamLaser',350,1.7,20,'marker_gun_'..v[2]..'_muzzle_01',v[1]..'_fire','gauss','bone_move_gun_'..v[1],'bone_vert_gun_'..v[1],3,.3)
end
local hq=add('nec_hq','Dormant Monolith','HQ',600,3000,5000,6000,0,7)
local core=add('nec_core','Summoning Core','barracks',250,1250,2000,2600,0,5)
local greater=add('nec_greater_core','Greater Summoning Core','tank_factory',550,2700,4000,3800,0,7)
local generator=add('nec_generator','Necron Plasma Generator','generator',150,0,1400,1100,0,3)
local mex=add('nec_mex','Necron Listening Post Extractor','mex',60,300,600,900,0,3)
local thermo=add('nec_thermo','Thermo Plasma Generator','thermo',500,3500,4500,2600,0,5)
local archive=add('nec_archive','Forbidden Archive','support',280,1400,2400,2500,0,5)
local storage=add('nec_energy_core','Necron Energy Core','storage',350,1700,3000,2300,0,4)
local turret=add('nec_turret','Gauss Turret','defence',200,1000,1600,1600,0,3)
-- This source is static with eight actual radial emitters, no invented gunfire animation.
-- Coordinator must verify emitter geometry and each mount before removing validation gate.
for _,side in ipairs({'n','ne','e','se','s','sw','w','nw'}) do
 local emitter=(side=='e' or side=='w') and 'bone_bigblock_'..side or 'bone_stubby_'..side
 gun(turret,'Gauss emitter '..side,'BeamLaser',380,3,9,emitter,'','gauss',emitter)
end
local structures={'nec_hq','nec_core','nec_greater_core','nec_generator','nec_mex','nec_thermo','nec_archive','nec_energy_core','nec_turret'}
local function constructor(d,power)
 if not d then return end
 d.builder=true;d.workertime=power;d.builddistance=110;d.canrepair=true;d.canreclaim=true;d.canassist=true;d.canrestore=true
 d.buildoptions=structures;d.customparams.unitgroup='builder'
end
constructor(lord,150);constructor(scarab,55)
if lord then
 lord.customparams.iscommander=true;lord.customparams.commander=1;lord.customparams.production_role='commander'
 lord.energymake=25;lord.metalmake=1;lord.energystorage=1000;lord.metalstorage=500
end
local function factory(d,options,power)
 if not d then return end
 d.builder=true;d.canmove=true;d.speed=0;d.workertime=power;d.builddistance=220;d.canassist=true;d.canreclaim=false;d.buildoptions=options
 d.yardmap=string.rep('e',d.footprintx*d.footprintz);d.customparams.unitgroup='builder';d.customparams.factory=1
end
factory(hq,{'nec_scarab','nec_lord'},110)
factory(core,{'nec_warrior','nec_immortal','nec_flayed','nec_wraith'},90)
factory(greater,{'nec_destroyer','nec_heavy_destroyer','nec_spyder','nec_monolith_mobile'},130)
if hq then hq.energystorage=500;hq.metalstorage=300;hq.energymake=10 end
if generator then generator.energymake=25;generator.customparams.unitgroup='energy' end
if mex then mex.extractsmetal=.001;mex.activatewhenbuilt=true;mex.onoffable=true;mex.customparams.metal_extractor=1;mex.customparams.unitgroup='metal' end
-- Native Recoil derives needGeo from a geothermal yard cell, not a raw needgeo field.
if thermo then thermo.energymake=250;thermo.yardmap='ooooo ooooo oogoo ooooo ooooo';thermo.customparams.unitgroup='energy' end
if archive then archive.radardistance=1700;archive.sonardistance=900;archive.energyuse=15;archive.onoffable=true;archive.activatewhenbuilt=true;archive.description='Long-range sensor and surveillance archive';archive.customparams.unitgroup='util' end
if storage then storage.energystorage=5000;storage.metalstorage=1500;storage.customparams.unitgroup='util' end
return defs

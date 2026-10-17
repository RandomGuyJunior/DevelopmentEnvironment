-- Critical native functions using real DoW/UA actors and mounted source weapons.
-- Each logical role has its own native acceptance marker; all remain diagnostic
-- until actual AA/stockpile/interception/shield and production tests pass.
local defs={}
local opts=Spring and Spring.GetModOptions and Spring.GetModOptions() or {}
local mode=opts.prototype_diagnostic
local diagnostic=mode=='roster' or mode=='vital' or mode=='expandedproduction'
local function add(key,source,name,faction,role,speed,size,metal,energy,hp)
 if not VFS.FileExists('objects3d/'..source..'.glb') or not VFS.FileExists('scripts/generated/'..source..'_anim.lua') or not VFS.FileExists('scripts/40k_roster.lua')
  or (not diagnostic and not VFS.Include('40k_configs/development_playtest.lua').Allowed(key,opts) and not VFS.FileExists('40k_configs/validated/'..key..'.lua')) then return end
 local d={name=name,description=faction..' '..role,objectname=source..'.glb',script='40k_roster.lua',buildpic='40k_'..source..'.png',metalcost=metal,energycost=energy,buildtime=metal*12,
 health=hp,speed=speed,maxacc=.08,maxdec=.2,turnrate=800,turninplace=true,canmove=speed>0,canattack=true,footprintx=size,footprintz=size,maxslope=30,maxwaterdepth=5,sightdistance=500,upright=not (speed>0 and size>=3),
 category=speed>0 and 'ALL MOBILE NOTSUB SURFACE' or 'ALL NOTSUB SURFACE',collisionvolumetype=speed>0 and 'CylY' or 'Box',collisionvolumeoffsets='0 0 0',
 customparams={faction=faction,prototype40k=1,prototype40k_expansion=1,prototype40k_vital=role,animsource=source,rosterrole=speed>0 and (size>=3 and 'tank' or 'infantry') or 'defence',production_role=role,unitgroup='weapon',balance_status='critical_native_role_pending',diagnostic=diagnostic and 'roster' or nil},
 weapondefs={},weapons={},sfxtypes={explosiongenerators={'custom:40k_dow_autocannon_muzzle','custom:40k_dow_heavy_bolter_muzzle','custom:40k_dow_rokkit_muzzle','custom:40k_dow_particle_muzzle','custom:40k_dow_slugga_muzzle'}}}
 if speed>0 then d.movementclass=size>=3 and 'TANK3' or 'SBOT2'
 else d.yardmap=string.rep('o',size*size) end
 defs[key]=d;return d
end
local function mount(d,label,kind,range,reload,damage,muzzle,fire,pivot,pitch,family,fx,burst,spacing)
 if not d then return end
 local n=#d.weapons+1;local key='mount'..n
 local w={name=label,weapontype=kind,turret=true,range=range,reloadtime=reload,damage={default=damage},weaponvelocity=kind=='BeamLaser' and 1200 or 650,
 accuracy=100,sprayangle=150,areaofeffect=(kind=='MissileLauncher' or kind=='StarburstLauncher') and 12 or 1,cratermult=0,impulsefactor=0,tolerance=4000,
 collidefriendly=true,collideenemy=true,collideground=true,collidefeature=true,collideneutral=true,collidenontarget=true,avoidfriendly=true,avoidfeature=true,
 size=.35,stages=2,thickness=.5,beamtime=.06,beamttl=2,burst=burst or 1,burstrate=spacing or .3,explosiongenerator='custom:40k_dow_'..family..'_impact',
 rgbcolor=family=='particle' and '.18 1 .32' or '1 .65 .2',customparams={source_muzzle=muzzle,source_fireclip=fire,source_aimpiece=pivot,source_pitchpiece=pitch,source_fx_family=family,source_muzzlefx=fx}}
 d.weapondefs[key]=w;d.weapons[n]={def=key,onlytargetcategory='SURFACE'};return w
end
local function interceptor(w,pair)
 if not w then return end
 w.burst=2;w.burstrate=.25;w.interceptor=1;w.coverage=1600;w.range=2400;w.stockpile=true;w.stockpiletime=60;w.metalpershot=120;w.energypershot=5000;w.customparams.stockpilelimit=12
 w.tracks=true;w.turnrate=12000;w.weaponacceleration=180;w.weaponvelocity=1800;w.flighttime=12;w.weapontimer=2
 w.cegtag='40k_dow_rokkit_trail';w.customparams.source_muzzle_pair=pair;w.customparams.requires_native_interception=1
end
local function field(d,label,marker,color,power,radius)
 if not d then return end
 local n=#d.weapons+1;local key='mount'..n
 d.weapondefs[key]={name=label,weapontype='Shield',damage={default=0},shield={alpha=.15,armortype='shields',exterior=true,energyupkeep=0,intercepttype=1,power=power,powerregen=80,powerregenenergy=120,radius=radius,repulser=false,smart=true,startingpower=power,badcolor={1,.12,.1,.15},goodcolor=color,visiblerepulse=true},
 customparams={source_muzzle=marker,source_passive=1,source_field_fx=label,requires_native_shield=1}}
 d.weapons[n]={def=key,onlytargetcategory='NOTSUB'}
 d.customparams.source_passive_mounts=tostring(n)
end
local hydra=add('imp_hydra','imp_hydra','Hydra Anti-Air Tank','Imperium','anti_air',30,3,420,2100,2500)
if hydra then
 hydra.customparams.root_bone='body'
 for _,side in ipairs({'left','right'})do for _,level in ipairs({'top','bottom'})do
  local w=mount(hydra,'Hydra '..side..' '..level..' autocannon','Cannon',600,1.8,14,'marker_autocannon_'..side..'_barrel_'..level,side=='left' and 'fire' or 'right_fire','aim_horizontal_bone','aim_vertical_bone','autocannon',1024,3,.25)
  hydra.weapons[#hydra.weapons].onlytargetcategory='VTOL'
 end end
 mount(hydra,'Hydra hull heavy bolter','Cannon',300,1.4,3,'marker_hull_bolter','hull_fire','basilisk_hull_bolter','basilisk_hull_bolter','heavy_bolter',1025,3,.25)
 hydra.weapons[5].maindir='0 0 1';hydra.weapons[5].maxangledif=70
end
local missile=add('imp_missile_defence','imp_missile_defence','Imperial Missile Interceptor','Imperium','strategic_defence',0,3,1500,18000,3000)
if missile then
 missile.customparams.root_bone='emplacement_base'
 interceptor(mount(missile,'Source emplacement interceptor missiles','StarburstLauncher',2400,3,1500,'marker_missle_barrel_r','fire','emplacement_turret','aim_vert_missle','rokkit',1026),'marker_missle_barrel_r,marker_missle_barrel_r01')
 missile.weapons[1].onlytargetcategory='NOTSUB'
end
local rokkit=add('ork_rokkit_interceptor','ork_rokkit_interceptor','Ork Interceptor Rokkit Battery','Orks','strategic_defence',24,3,1300,14000,2400)
if rokkit then
 rokkit.customparams.root_bone='body'
 interceptor(mount(rokkit,'Source twin interceptor rokkits','StarburstLauncher',2400,3.5,1500,'marker_twin_linked_rokkit_barrel01','fire','aim_horz_main','aim_vert_main','rokkit',1026),'marker_twin_linked_rokkit_barrel01,marker_twin_linked_rokkit_barrel02')
 rokkit.weapons[1].onlytargetcategory='NOTSUB'
end
local flak=add('ork_flak_wartrak','ork_wartrak','Ork Twin Shoota Anti-Air Wartrak','Orks','anti_air',32,3,300,1500,1900)
if flak then
 flak.customparams.root_bone='body'
 local w=mount(flak,'Twin big shoota AA','Cannon',520,1.8,11,'marker_twin_linked_big_shootas_barrel01','fire','aim_horz_main','aim_vert_main','heavy_bolter',1025,4,.3)
 w.customparams.source_muzzle_pair='marker_twin_linked_big_shootas_barrel01,marker_twin_linked_big_shootas_barrel02';flak.weapons[1].onlytargetcategory='VTOL'
end
local mek=add('ork_big_mek_defence','ork_big_mek_defence','Big Mek with Kustom Force Field','Orks','field_defence',18,1,380,2200,1500)
if mek then
 mek.customparams.root_bone='bip01 pelvis';mek.customparams.rosterrole='builder';mek.customparams.buildclip='build'
 mek.builder=true;mek.workertime=100;mek.builddistance=140;mek.canrepair=true;mek.canreclaim=true;mek.canassist=true;mek.buildoptions={}
 mount(mek,'Mek slugga','Cannon',260,1.5,8,'marker_big_mek_slugga_barrel','fire','unit_aim',nil,'slugga',1028,3,.3)
 mount(mek,'Mek choppa','Melee',27,2.8,55,'marker_big_mek_axe_blade','melee','unit_aim',nil,'choppa',nil)
 field(mek,'DoW kustom force field','marker_big_mek_trans_mid',{.3,.7,1,.15},3600,280)
end
local pylon=add('nec_sentry_pylon','nec_sentry_pylon','Necron Anti-Air Sentry Pylon','Necrons','anti_air',0,3,650,3800,2400)
if pylon then
 pylon.customparams.root_bone='cylinder00';mount(pylon,'Particle Accelerator AA','BeamLaser',700,3,150,'barrel_muzzle_middle','fire','aim_horizontal','aim_vertical','particle',1027)
 pylon.weapons[1].onlytargetcategory='VTOL'
end
local particle=add('nec_particle_interceptor','nec_sentry_pylon','Necron Particle Interceptor Pylon','Necrons','strategic_defence',0,3,1800,22000,3000)
if particle then
 particle.customparams.root_bone='cylinder00'
 local w=mount(particle,'Particle Accelerator Point Defense','BeamLaser',2400,4,1500,'barrel_muzzle_middle','fire','aim_horizontal','aim_vertical','particle',1027)
 w.burst=2;w.burstrate=.25;w.interceptor=1;w.coverage=1600;w.energypershot=600;w.customparams.requires_native_beam_interception=1;particle.weapons[1].onlytargetcategory='NOTSUB'
end
local spike=add('nec_shield_spike','nec_shield_spike','Necron Shield Spike','Necrons','field_defence',0,3,600,3500,2400)
if spike then spike.customparams.root_bone='bone_master';field(spike,'UA Necron shield spike','marker_pillar',{.14,1,.25,.15},7000,450)end
local comms=add('imp_comms_array','imp_comms_array','Imperial Communications Array','Imperium','advanced_recon',0,5,480,2500,2400)
if comms then comms.customparams.root_bone='bunker';comms.canattack=false;comms.radardistance=1600;comms.radardistancejam=600;comms.energystorage=500;comms.metalstorage=200;comms.energyupkeep=15;comms.weapondefs=nil;comms.weapons=nil end
return defs

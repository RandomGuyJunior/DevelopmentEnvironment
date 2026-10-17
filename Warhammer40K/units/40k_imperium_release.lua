-- Genuine UA late-Imperial candidates. Normal release needs coordinator-owned
-- native acceptance; file generation alone cannot expose these units.
local defs={}
local opts=Spring and Spring.GetModOptions and Spring.GetModOptions() or {}
local diagnostic=opts.prototype_diagnostic=='roster' or opts.prototype_diagnostic=='expandedproduction'
local selected=VFS.Include('40k_configs/mixed_v2_adapter.lua').Selected(opts)
local function mount(name,kind,range,reload,damage,marker,fire,aim,pitch)
 return {name=name,weapontype=kind,range=range,reloadtime=reload,damage={default=damage},turret=true,
  weaponvelocity=kind=='LaserCannon' and 1100 or 500,accuracy=140,sprayangle=160,tolerance=3000,
  areaofeffect=kind=='Melee' and 1 or 8,cratermult=0,impulsefactor=0,thickness=.5,size=.5,
  collidefriendly=true,collideenemy=true,collideground=true,collidefeature=true,collideneutral=true,collidenontarget=true,
  avoidfriendly=true,avoidfeature=true,rgbcolor='1 .65 .2',
  explosiongenerator='custom:40k_heavy_bolter_impact',
  customparams={source_muzzle=marker,source_fireclip=fire,source_aimpiece=aim or 'unit_aim',source_pitchpiece=pitch,source_muzzlefx=1027}}
end
local function add(key,name,role,metal,energy,time,hp,speed,size,weapons)
 if selected and not selected[key]then return end
 if not (diagnostic or VFS.Include('40k_configs/development_playtest.lua').Allowed(key,opts) or VFS.FileExists('40k_configs/validated/'..key..'.lua'))
  or not VFS.FileExists('objects3d/'..key..'.glb') or not VFS.FileExists('scripts/40k_roster.lua')
  or not VFS.FileExists('scripts/generated/'..key..'_anim.lua')then return end
 local d={name=name,description='Imperium '..role,objectname=key..'.glb',script='40k_roster.lua',buildpic='40k_'..key..'.png',
  metalcost=metal,energycost=energy,buildtime=time,health=hp,speed=speed,footprintx=size,footprintz=size,
  maxacc=.06,maxdec=.15,turnrate=650,maxslope=30,maxwaterdepth=5,sightdistance=450,
  upright=role~='tank',canmove=speed>0,canattack=weapons~=nil,turninplace=true,
  category=speed>0 and 'ALL MOBILE NOTSUB SURFACE' or 'ALL NOTSUB SURFACE',
  customparams={prototype40k=1,prototype40k_expansion=1,faction='Imperium',animsource=key,production_role=role,rosterrole=role,
   model_author='private genuine source',balance_status='provisional_source_role',integration_status='native_acceptance_required'},
  sfxtypes={explosiongenerators={'custom:40k_lasgun_muzzle','custom:40k_bolter_muzzle','custom:40k_shoota_muzzle','custom:40k_heavy_bolter_muzzle','custom:40k_battlecannon_muzzle'}}}
 if speed>0 then d.movementclass=size>=3 and 'TANK3' or 'SBOT2' end
 if weapons then
  d.weapondefs={};d.weapons={}
  for n,w in ipairs(weapons)do d.weapondefs['mount'..n]=w;d.weapons[n]={def='mount'..n,onlytargetcategory='SURFACE'}end
 else d.yardmap=string.rep('o',size*size) end
 defs[key]=d;return d
end
local pistol=mount('Bolt pistol','Cannon',210,.8,12,'marker_marine_boltpistol_barrel','fire')
local sword=mount('Chainsword','Melee',28,1.9,70,'bip01 r hand','melee')
local assault=add('imp_assault_marine','Assault Marine','infantry',140,700,1100,600,21,1,{pistol,sword})
if assault then
 assault.customparams.source_jump_required=1;assault.customparams.role_acceptance_requires='paid production, chainsword contact, native jump movement and landing'
 local cp=assault.customparams
 cp.jump_launch_clip='jump_launch';cp.jump_air_clip='jump_air';cp.jump_land_clip='jump_land'
 cp.jump_launch_frames=13;cp.jump_air_clip_frames=31;cp.jump_land_frames=11;cp.jump_flight_frames=90
 cp.jump_range=480;cp.jump_charge_capacity=135;cp.jump_charge_cost=45;cp.jump_charge_regen=1
end
local storm=mount('Storm bolter','Cannon',330,1.2,14,'marker_terminator_storm_bolter_barrel','fire')
storm.burst=3;storm.burstrate=.22
storm.customparams.source_muzzle_pair='marker_terminator_storm_bolter_barrel,marker_terminator_storm_bolter_barrel_l'
local fist=mount('Terminator power fist','Melee',30,2.8,135,'bip01 l hand','melee')
add('imp_terminator','Terminator','infantry',240,1300,1900,1450,17,1,{storm,fist})
local main=mount('Baneblade cannon','Cannon',620,7,400,'marker_battlecannon_main','fire','aim_horiz_main','aim_vert_main')
main.areaofeffect=52;main.explosiongenerator='custom:40k_battlecannon_impact';main.customparams.source_muzzlefx=1028
local dem=mount('Demolisher cannon','Cannon',360,8,330,'marker_demolisher','demolisher','unit_aim','aim_vert_demolisher')
dem.areaofeffect=70;dem.explosiongenerator='custom:40k_battlecannon_impact';dem.customparams.source_muzzlefx=1028
local lasr=mount('Right lascannon','LaserCannon',460,2.6,110,'marker_lascannon_r','las_right','aim_las_horiz_right','aim_las_vert_right')
local lasl=mount('Left lascannon','LaserCannon',460,2.6,110,'marker_lascannon_l','las_left','aim_las_horiz_left','aim_las_vert_left')
local coax=mount('Coaxial autocannon','Cannon',500,2.0,40,'marker_battlecannon_secondary','autocannon','unit_aim')
coax.burst=2;coax.burstrate=.35;coax.customparams.source_weapon_bones='bb_battlecannon_secondary';coax.customparams.source_weapon_bones_only=1
local function hb(label,marker,clip,aim)
 local w=mount(label,'Cannon',320,1.5,7,marker,clip,aim);w.burst=3;w.burstrate=.25
 w.customparams.source_muzzle_pair=marker..','..marker..'01';return w
end
local baneblade=add('imp_baneblade','Baneblade','tank',3500,18000,22000,18000,25,5,{
 main,dem,lasr,lasl,hb('Front twin heavy bolter','marker_heavybolter_front','hb_front','aim_hb_horiz_front'),
 hb('Right twin heavy bolter','marker_heavybolter_r','hb_right','aim_hb_horiz_right'),
 hb('Left twin heavy bolter','marker_heavybolter_l','hb_left','aim_hb_horiz_left'),coax})
if baneblade then baneblade.movementclass='40K_SUPERHEAVY5';baneblade.weapons[8].slaveto=1 end
local plasma=mount('Warhound plasma blastgun','Cannon',850,6,850,'marker_lplasma_barrel1','fire','left_weapon_horiz_aim','left_weapon_vert_aim')
plasma.areaofeffect=90;plasma.customparams.source_muzzle_pair='marker_lplasma_barrel1,marker_lplasma_barrel2';plasma.customparams.source_muzzlefx=1028
plasma.explosiongenerator='custom:40k_battlecannon_impact'
local vulcan=mount('Warhound Vulcan mega bolter','Cannon',600,1.6,55,'marker_rbolter_barrel1','vulcan','right_weapon_horiz_aim','right_weapon_vert_aim')
vulcan.burst=6;vulcan.burstrate=.20;vulcan.customparams.source_muzzle_pair='marker_rbolter_barrel1,marker_rbolter_barrel2'
local titan=add('imp_warhound','Warhound Scout Titan','walker',9000,48000,60000,45000,20,8,{plasma,vulcan})
if titan then titan.movementclass='40K_TITAN8';titan.maxslope=20;titan.customparams.source_voidshield_required=1 end
for _,s in ipairs({
 {'imp_superheavy_factory','Mars Pattern Command','superheavy_factory',2200,11000,15000,10000,12,{'imp_baneblade'}},
 {'imp_titan_factory','Titan Assembly Facility','titan_factory',5000,28000,35000,22000,16,{'imp_warhound'}},
})do
 local d=add(s[1],s[2],s[3],s[4],s[5],s[6],s[7],0,s[8])
 if d then
  d.builder=true;d.canmove=true;d.workertime=160;d.builddistance=400;d.buildoptions=s[9]
  d.yardmap=string.rep('e',s[8]*s[8]);d.customparams.source_buildclip='production'
  d.customparams.prototype40k_factory=s[3];d.customparams.role_acceptance_requires='paid construction, largest product production and legal exit, rally, placement and collision'
 end
end
return defs

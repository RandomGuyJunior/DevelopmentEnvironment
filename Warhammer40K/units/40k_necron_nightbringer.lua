-- Genuine source model candidate; only manifestation, never ordinary production.
local key='nec_nightbringer';local o=Spring and Spring.GetModOptions and Spring.GetModOptions() or {}
local diagnostic=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(o.prototype_source_progression) and (o.prototype_diagnostic=='roster' or o.prototype_diagnostic=='expandedproduction')
for _,path in ipairs({'objects3d/'..key..'.glb','scripts/generated/'..key..'_anim.lua','scripts/40k_roster.lua'})do if not VFS.FileExists(path)then return {} end end
if not diagnostic and not VFS.FileExists('40k_configs/validated/'..key..'.lua')then return {} end
local function weapon(name,kind,range,damage,marker,clip,leech)
 return {name=name,weapontype=kind,range=range,reloadtime=1,damage={default=damage},turret=true,
 accuracy=kind=='Melee' and 0 or 100,sprayangle=kind=='Melee' and 0 or 130,tolerance=3000,areaofeffect=1,cratermult=0,impulsefactor=0,
 collidefriendly=true,collideenemy=true,collideground=true,collidefeature=true,collideneutral=true,collidenontarget=true,
 avoidfriendly=true,avoidfeature=true,rgbcolor='.12 1 .18',thickness=.5,corethickness=.2,beamtime=.055,beamttl=2,weaponvelocity=900,
 explosiongenerator=kind=='Melee' and 'custom:40k_dow_necron_blade_impact' or 'custom:40k_dow_particle_impact',
 customparams={source_muzzle=marker,source_fireclip=clip,source_fx_family=kind=='Melee' and 'necron_blade' or 'particle',
 source_muzzlefx=kind~='Melee' and 1026 or nil,source_life_leech_damage=leech,source_wholebodyaim=1}}
end
-- Genuine source point area/radius0: damage only the actual collided object.
-- Native geometry/target/terrain candidate review remains required.
local ranged=weapon('Nightbringer scythe ranged','LaserCannon',250,315,'mrkr_hand_weapon','fire',50)
ranged.impactonly=true
return {[key]={name='Essence of the Nightbringer',description='One-for-one Necron Lord manifestation',objectname=key..'.glb',script='40k_roster.lua',buildpic='40k_'..key..'.png',
 -- Effective paid Lord cost is transferred by the gadget, not refunded or charged twice.
 metalcost=1000,energycost=5000,buildtime=9000,health=15000,autoheal=0,idleautoheal=0,speed=18,maxacc=.08,maxdec=.2,turnrate=700,maxslope=30,maxwaterdepth=5,
 footprintx=3,footprintz=3,movementclass='BOT3',upright=true,turninplace=true,canmove=true,canattack=true,builder=false,maxthisunit=1,
 sightdistance=450,category='ALL MOBILE NOTSUB SURFACE',collisionvolumetype='CylY',collisionvolumeoffsets='0 0 0',
 metalmake=1,energymake=25,metalstorage=500,energystorage=1000,
 sfxtypes={explosiongenerators={'custom:40k_dow_gauss_muzzle','custom:40k_dow_gauss_heavy_muzzle','custom:40k_dow_particle_muzzle'}},
 weapondefs={scythe_ranged=ranged,
 scythe_melee=weapon('Nightbringer scythe melee','Melee',35,875,'marker_sythe_01','melee',35)},
 weapons={{def='scythe_ranged',onlytargetcategory='NOTSUB'},{def='scythe_melee',onlytargetcategory='SURFACE'}},
 customparams={faction='Necrons',prototype40k=1,prototype40k_expansion=1,animsource=key,root_bone='dummy02',rosterrole='infantry',production_role='commander',unitgroup='weapon',iscommander=true,commander=1,
 production_method='lord_transformation',possession_form=1,source_health=15000,
 source_cloth_idleclip='cape_idle',source_cloth_walkclip='cape_walk',source_cloth_meleeclip='cape_melee',
 source_cloth_bones='wnb_bone_hoodbone_w,wnb_bone_cape1w,wnb_bone_r_loop_w,wnb_bone_l_loop_w,wnb_bone_l_armfab1_w,wnb_bone_l_armfab3_w,wnb_bone_l_armfab4_w,wnb_bone_l_armfab2_w,wnb_bone_cape3_w,wnb_bone_cape2_w,wnb_bone_l_cape2_w,wnb_bone_r_cape2_w,wnb_bone_l_capefab1_w,wnb_bone_l_capefab2_w,wnb_bone_r_capefab1_w,wnb_bone_r_capefab2_w,wnb_bone_r_armfab1_w,wnb_bone_r_armfab3_w,wnb_bone_r_armfab4_w,wnb_bone_r_armfab2_w,wnb_bone_lowcloth_w,wnb_bone_hem1_w,wnb_bone_hem2_w,wnb_bone_tail_2_w,wnb_bone_r_tail_w,wnb_bone_l_tail_w,wnb_bone_skirt_1_w,wnb_bone_skirt_2_w,wnb_bone_skirt_overlap02_w,wnb_bone_skirt_overlap_w,wnb_bone_l_train2_w,wnb_bone_l_train3_w,wnb_bone_r_train2_w,wnb_bone_r_train3_w',

 source_entity='attrib/ebps/races/necrons/troops/necron_night_bringer.lua',source_ranged='attrib/weapon/necron_nightbringer_scythe_ranged.lua',source_melee='attrib/weapon/necron_nightbringer_scythe_melee.lua',
 source_damage_adaptation='Mean source damage315/875; native range250 adapts source25; native spread100/130 approximates sourceaccuracy0.8; native attack cadence source1second; root native balance/visual verification pending',
 balance_status='source_candidate_native_pending'}}}

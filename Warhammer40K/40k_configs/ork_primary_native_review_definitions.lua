-- Executable baseline native review definitions from exact ignored source facts.
-- Spatial/accuracy/mean-damage adaptations are documented, not original engine claims.
local M={Version=1}
local mounts={
 ork_pile_o_guns={muzzle='marker_pile_o_guns_shoota_barrel_l',yaw='gun01_aim_horz',pitch='gun01_aim_vert',clip='fire'},
 ork_boomy_platform={muzzle='marker_main_barrel',yaw='bone_main_aim_horz',pitch='bone_main_aim_vert',clip='fire'},
 ork_giant_waagh_banner_sp_dxp3={muzzle='native_source_hp01_emitter',yaw='unit_aim',clip='',offset=true},
 ork_stormboy={muzzle='marker_boyz_slugga_barrel',yaw='unit_aim',clip='fire'}}
local function weapon(row,mount,kind)
 local f=row.fields;local lo=assert(f['area_effect.weapon_damage.armour_damage.min_damage']);local hi=assert(f['area_effect.weapon_damage.armour_damage.max_damage'])
 local w={name=row.virtual,weapontype=kind or 'Cannon',range=(f.max_range or 4.5)*10,reloadtime=assert(f.reload_time),weaponvelocity=480,turret=true,tolerance=4000,areaofeffect=math.max(1,(f['area_effect.area_effect_information.radius']or 0)*10),cratermult=0,impulsefactor=0,collidefriendly=true,collideenemy=true,collideground=true,collidefeature=true,collidenontarget=true,avoidfriendly=true,avoidfeature=true,damage={default=(lo+hi)/2},accuracy=(1-(f.accuracy or 1))*600,targetmoveerror=.15,size=.25,stages=2,rgbcolor='1 .8 .3',explosiongenerator='custom:40k_shoota_impact',customparams={source_weapon=row.virtual,source_weapon_sha256=row.sha256,source_accuracy=f.accuracy,source_damage_min=lo,source_damage_max=hi,source_muzzle=mount.muzzle,source_fireclip=mount.clip,source_aimpiece=mount.yaw,source_pitchpiece=mount.pitch}}
 local family=kind=='Melee'and 'choppa'or row.virtual:find('slugga',1,true)and 'slugga'or 'shoota'
 w.explosiongenerator='custom:40k_dow_'..family..'_impact';w.customparams.source_fx_family=family
 if kind~='Melee'then w.customparams.source_muzzlefx='40k_dow_'..family..'_muzzle'end
 if mount.yaw=='unit_aim'then w.customparams.source_wholebodyaim=1 end
 if kind=='Melee'then w.weaponvelocity=1;w.accuracy=0;w.range=45 end
 return w
end
function M.Build(key,facts,calibration,defs)
 local mobile=key=='ork_stormboy';local footprint=mobile and {1,1}or calibration.minimum_geometry_footprint_16unit_cells
 local labor=mobile and defs.ork_boyz_hut and defs.ork_boyz_hut.workertime or defs.ork_grot and defs.ork_grot.workertime
 assert(type(labor)=='number'and labor>0,'Actual native producer workertime required')
 local d={name=key,description='Exact source baseline role; guarded native review',buildoptions={},weapondefs={},weapons={},objectname=key..'.glb',script='40k_roster.lua',buildpic='40k_'..key..'.png',metalcost=facts.cost.metal,energycost=facts.cost.power*5,buildtime=facts.seconds*labor,health=facts.health,speed=mobile and (defs.ork_slugga and defs.ork_slugga.speed or 18)or 0,maxacc=.08,maxdec=.2,turnrate=mobile and 900 or 400,turninplace=true,canmove=mobile,canattack=false,category=mobile and 'ALL MOBILE NOTSUB SURFACE'or 'ALL NOTSUB SURFACE',footprintx=footprint[1],footprintz=footprint[2],maxslope=mobile and 36 or 24,maxwaterdepth=5,sightdistance=430,customparams={source_build_seconds=facts.seconds,source_labor_reference=mobile and 'ork_boyz_hut'or 'ork_grot',source_completed_pose_profile=key}}
 assert(type(facts.source_whm_sha256)=='string'and #facts.source_whm_sha256==64 and type(facts.native_glb_sha256)=='string'and #facts.native_glb_sha256==64,'Distinct source WHM/native GLB identities required')
 d.customparams.source_model_sha256=facts.source_whm_sha256;d.customparams.source_native_glb_sha256=facts.native_glb_sha256
 for key,value in pairs(facts.source_qualifiers or{})do d.customparams[key]=value end
 if mobile and facts.cohort then d.customparams.source_squad=facts.cohort.source_squad;d.customparams.source_squad_sha256=facts.cohort.source_sha256 end
 if mobile then d.movementclass=defs.ork_slugga and defs.ork_slugga.movementclass or 'SBOT2';d.upright=true
 else d.yardmap=string.rep('o',footprint[1]*footprint[2]);d.upright=true end
 if key~='ork_bigger_generator'then
  local field='combat_ext.hardpoints.hardpoint_01.weapon_table.weapon_01.weapon';local w=weapon(assert(facts.armament_contract[field]),assert(mounts[key]))
  if key=='ork_boomy_platform'then w.explosiongenerator='custom:40k_dow_artillery_impact';w.customparams.source_muzzlefx='40k_dow_artillery_muzzle';w.customparams.source_fx_family='artillery';w.hightrajectory=1;w.weaponvelocity=290;w.size=1;w.customparams.source_minrange=facts.armament_contract[field].fields.min_range*10;w.avoidfeature=false end
  if key=='ork_giant_waagh_banner_sp_dxp3'then w.customparams.source_hardpoint_offset_required=1;d.customparams.source_fixed_defence_adaptation='source_hardpoint_offset_on_original_tower_root' end
  d.canattack=true;d.weapondefs={mount1=w};d.weapons={{def='mount1',onlytargetcategory='SURFACE'}}
  if mobile then
   local melee=facts.armament_contract['combat_ext.hardpoints.hardpoint_02.weapon_table.weapon_01.weapon'];d.weapondefs.mount2=weapon(melee,{muzzle='marker_boyz_choppa_knife_blade',yaw='unit_aim',clip='melee'},'Melee');d.weapons[2]={def='mount2',onlytargetcategory='SURFACE'}
  end
 end
 if key=='ork_giant_waagh_banner_sp_dxp3'then d.builder=true;d.canmove=true;d.workertime=150;d.builddistance=180;d.yardmap=string.rep('e',footprint[1]*footprint[2]);d.buildoptions={} end
 return d
end
return M

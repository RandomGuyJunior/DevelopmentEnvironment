-- Two genuine source air products. Spatial/mean/aim-group adaptations require native review.
local M={Version=1}
local mounts={
 {muzzle='fb_fx_nose_gun_l',pair='fb_fx_nose_gun_l,fb_fx_nose_gun_r,fb_fx_wing_gun_l,fb_fx_wing_gun_r',yaw='fb_nose_gun_l_horiz',pitch='fb_nose_gun_l_vert',clip='main_fire',group_yaw='fb_nose_gun_r_horiz,fb_wing_gun_l_horiz,fb_wing_gun_r_horiz',group_pitch='fb_nose_gun_r_vert,fb_wing_gun_l_vert,fb_wing_gun_r_vert'},
 {muzzle='fb_fx_bubble_gun_mid',yaw='fb_bubble_gun_horiz',pitch='fb_bubble_gun_vert',clip='bubble_fire'},
 {muzzle='fb_fx_bomb_bay',yaw='unit_aim',clip='bomb_fire'},
 {muzzle='fb_fx_rear_gun_l',pair='fb_fx_rear_gun_l,fb_fx_rear_gun_r',yaw='fb_rear_gun_horiz',pitch='fb_rear_gun_vert',clip='rear_fire'}}
local function hash(v)return type(v)=='string'and #v==64 and not v:find('[^0-9a-f]')end
-- Static copied-source readiness only; neither production prerequisites nor native acceptance.
function M.DefinitionReady(key,f)
 if key~='ork_fighta_bomba'and key~='ork_nuke_bomba'then return false,'actor'end
 if type(f)~='table'or f.source_entity~='attrib/ebps/races/orks/troops/'..key..'.lua'or not hash(f.source_model_sha256)or not hash(f.native_glb_sha256)then return false,'source_identity'end
 if type(f.weapons)~='table'or #f.weapons~=4 or type(f.production)~='table'or f.producer_workertime~=150 then return false,'whole_mounts_or_producer'end
 for n,row in ipairs(f.weapons)do
  local w=row.fields
  if not hash(row.sha256)or type(row.source)~='string'or type(w)~='table'or type(w.reload_time)~='number'or w.reload_time<=0 or type(w.minimum)~='number'or type(w.maximum)~='number'or w.maximum<w.minimum or not mounts[n]then return false,'source_mount_'..n end
 end
 if key=='ork_nuke_bomba'then
  local a=f.bombard
  if type(a)~='table'or not hash(a.sha256)or not hash(a.projectile_sha256)or a.fire_metal~=1750 or a.fire_energy~=8750 or a.recharge~=600 or a.range~=800 or not a.minimum or not a.maximum or f.production.seconds~=240 or f.production.addition~=60 then return false,'whole_paid_bombard_or_producer'end
 elseif f.production.seconds~=70 or f.production.addition~=0 then return false,'producer'end
 return true
end
function M.Build(key,f,work)
 local ready,reason=M.DefinitionReady(key,f);assert(ready,reason)
 assert(key=='ork_fighta_bomba'or key=='ork_nuke_bomba','Exact two actors only')
 assert(type(work)=='number'and work>0 and work==f.producer_workertime,'Verified actual producer work required')
 local d={name=key,description='Genuine source aircraft; qualified native review',objectname=key..'.glb',script='40k_roster.lua',buildpic='40k_'..key..'.png',metalcost=f.cost.metal,energycost=f.cost.power*5,buildtime=f.production.seconds*work,health=f.health,speed=f.speed*10,maxacc=(f.speed*10/30)/(f.acceleration*30),maxdec=(f.speed*10/30)/(f.deceleration*30),turnrate=f.rotation*65536/360/30,canfly=true,canmove=true,canattack=true,hoverattack=true,airhoverfactor=0,cruisealt=f.altitude*10,collide=true,blocking=false,footprintx=math.ceil(f.bounds.size[1]/16),footprintz=math.ceil(f.bounds.size[3]/16),category='ALL MOBILE VTOL AIR NOTSUB',sightdistance=f.sight*10,weapondefs={},weapons={},buildoptions={},customparams={prototype40k=1,prototype40k_source_progression=1,faction='Orks',rosterrole='aircraft',animsource=key,root_bone='fb_root',normaltex=key..'_tex2.png',prototype40k_ork_aircraft_review=1,source_entity=f.source_entity,source_squad=f.source_squad,source_model_sha256=f.source_model_sha256,source_native_glb_sha256=f.native_glb_sha256,source_build_seconds=f.production.seconds,source_ebp_build_seconds=f.cost.seconds,source_producer_time_addition=f.production.addition,source_producer_time_sha256=f.production.source_sha256,source_native_birth_cost_signature=f.birth_signature,source_labor_reference='ork_giant_waagh_banner_sp_dxp3',source_air_native_adaptation='source_speed_altitude_times10_hovercraft_group_aim_uniform_mean_v1',source_scale_x=1.5,source_scale_y=1,source_scale_z=1.5}}
 -- Its tex2 is the native glow/specularity mask, not a tangent-space normal map.
 if key=='ork_fighta_bomba'then d.customparams.normaltex=nil end
 for n,row in ipairs(f.weapons)do local m=mounts[n];local w=row.fields;local bomb=n==3
  local wd={name=row.source,weapontype=bomb and'MissileLauncher'or'Cannon',range=w.max_range*10,reloadtime=w.reload_time,weaponvelocity=bomb and row.projectile_speed*10 or 480,startvelocity=bomb and .1 or nil,weaponacceleration=bomb and 80 or nil,tracks=bomb or nil,turnrate=bomb and 16000 or nil,turret=true,tolerance=4000,areaofeffect=math.max(1,w.radius*10),damage={default=(w.minimum+w.maximum)/2},accuracy=(1-w.accuracy)*600,targetmoveerror=.15,cratermult=0,impulsefactor=0,collidefriendly=true,collideenemy=true,collideground=true,collidefeature=true,collidenontarget=true,avoidfriendly=true,avoidfeature=true,size=bomb and 1 or .25,rgbcolor=bomb and'1 .3 .05'or'1 .8 .3',explosiongenerator=bomb and'custom:40k_dow_artillery_impact'or'custom:40k_dow_shoota_impact',customparams={source_weapon=row.source,source_weapon_sha256=row.sha256,source_hardpoint=n,source_muzzle=m.muzzle,source_muzzle_pair=m.pair,source_aimpiece=m.yaw,source_pitchpiece=m.pitch,source_fireclip=m.clip,source_wholebodyaim=n==3 and 1 or nil,source_minrange=w.min_range*10,source_damage_min=w.minimum,source_damage_max=w.maximum,source_accuracy=w.accuracy,source_weapon_bones=n==1 and f.main_weapon_bones or nil,source_weapon_bones_only=n==1 and 1 or nil,source_group_yaw=m.group_yaw,source_group_pitch=m.group_pitch,source_group_aim_required=n==1 and 1 or nil,source_fx_family=bomb and'artillery'or'shoota',source_muzzlefx=not bomb and'40k_dow_shoota_muzzle'or nil,source_fired_projectile=w.projectile}}
  d.weapondefs['mount'..n]=wd;d.weapons[n]={def='mount'..n,onlytargetcategory=bomb and'SURFACE'or'ALL'}
 end
 if key=='ork_nuke_bomba'then local a=f.bombard
  d.weapondefs.bombard={name=a.source,weapontype='MissileLauncher',range=a.range,reloadtime=a.recharge,weaponvelocity=a.projectile_speed,startvelocity=.1,weaponacceleration=80,tracks=true,turnrate=16000,turret=true,areaofeffect=a.radius,damage={default=(a.minimum+a.maximum)/2},cratermult=0,impulsefactor=0,collidefriendly=true,collideenemy=true,collideground=true,collidefeature=true,collidenontarget=true,avoidfriendly=false,avoidfeature=false,size=2,rgbcolor='1 .2 .02',explosiongenerator='custom:40k_dow_artillery_impact',customparams={source_ability=a.source,source_ability_sha256=a.sha256,source_fired_projectile=a.projectile,source_projectile_sha256=a.projectile_sha256,source_impact=a.impact,source_damage_min=a.minimum,source_damage_max=a.maximum,source_manual_paid_only=1}}
 end
 return d
end
return M

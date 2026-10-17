-- Authored expansion groundwork. Assets/scripts must be real and individually
-- validated before these definitions are exposed. No BAR substitute models.
local defs={}
local options=Spring and Spring.GetModOptions and Spring.GetModOptions() or {}
local mode=options.prototype_diagnostic
local testing=mode=='roster' or mode=='expandedproduction' or mode=='ui' or mode=='vital' or ((mode=='benchmark' or mode=='combatbenchmark') and options.prototype_benchmark_unit=='imp_kasrkin')
local mixedSelected=mode=='benchmark' and tostring(options.prototype_mixed_force or '0')=='1'
 and VFS.Include('40k_configs/mixed_benchmark_exposure.lua').Selected(options) or nil
local mixedV2=VFS.Include('40k_configs/mixed_v2_adapter.lua').Selected(options)
if mixedV2 then mixedSelected=mixedV2;testing=false end
local function copy(value) if type(value)~="table" then return value end;local out={};for k,v in pairs(value)do out[k]=copy(v)end;return out end
local fx={"custom:40k_lasgun_muzzle","custom:40k_bolter_muzzle","custom:40k_shoota_muzzle","custom:40k_heavy_bolter_muzzle","custom:40k_battlecannon_muzzle"}
local function weapon(name,kind,range,reload,damage,burst,spacing)
 return {name=name,weapontype=kind,range=range,reloadtime=reload,damage={default=damage},
  weaponvelocity=kind=="LaserCannon" and 900 or 550,burst=burst or 1,burstrate=spacing or .25,
  accuracy=120,sprayangle=160,turret=true,tolerance=3000,areaofeffect=1,cratermult=0,impulsefactor=0,
  collidefriendly=true,collideenemy=true,collideground=true,collidefeature=true,collideneutral=true,collidenontarget=true,
  avoidfriendly=true,avoidfeature=true,size=.35,stages=2,thickness=.4,duration=.02,
  rgbcolor=kind=="LaserCannon" and "1 .02 .01" or "1 .75 .25",
  explosiongenerator=kind=="LaserCannon" and "custom:40k_lasgun_impact" or "custom:40k_heavy_bolter_impact"}
end
local function add(key,name,role,metal,energy,time,health,speed,size,script,weapons)
 local model=key..".glb"
 -- Coordinator writes this project-owned marker only after native source/model,
 -- all-mounted-weapon and role checks. An export by itself is not acceptance.
 local walkReview=mode=="walkreview" and tostring(options.prototype_walk_sampling_review)=="1" and key=="imp_kasrkin"
 if (mixedV2 and not mixedV2[key]) or (not testing and not VFS.Include('40k_configs/development_playtest.lua').Allowed(key,options) and not walkReview and not (mixedSelected and mixedSelected[key]) and not VFS.FileExists("40k_configs/validated/"..key..".lua")) or not VFS.FileExists("objects3d/"..model)
  or not VFS.FileExists("scripts/"..script) or not VFS.FileExists("scripts/generated/"..key.."_anim.lua") then return end
 local d={name=name,description="Imperium "..role,objectname=model,script=script,buildpic="40k_"..key..".png",
  metalcost=metal,energycost=energy,buildtime=time,health=health,speed=speed,footprintx=size,footprintz=size,
  maxacc=.08,maxdec=.2,turnrate=900,maxslope=30,maxwaterdepth=5,sightdistance=400,upright=role~="tank" and role~="transport" and role~="artillery",
  canmove=speed>0,canattack=weapons~=nil,category=speed>0 and "ALL MOBILE NOTSUB SURFACE" or "ALL NOTSUB SURFACE",
  collisionvolumetype=speed>0 and "CylY" or "Box",collisionvolumeoffsets="0 0 0",
  customparams={faction="Imperium",prototype40k=1,prototype40k_expansion=1,production_role=role,
   animsource=key,model_author="private genuine source",balance_status="provisional_groundwork"},
  sfxtypes={explosiongenerators=fx}}
 if weapons then
  local first=weapons[1];d.customparams.fireperiod=first.burst and first.burst>1 and first.burstrate or first.reloadtime
  d.customparams.muzzlefx=first.weapontype=="LaserCannon" and 1024 or 1027
 end
 if speed>0 then d.movementclass=size>=3 and "TANK3" or "SBOT2";d.turninplace=true end
 if weapons then
  d.weapondefs={};d.weapons={}
  for n,w in ipairs(weapons)do d.weapondefs["mount"..n]=copy(w);d.weapons[n]={def="mount"..n,onlytargetcategory="SURFACE"}end
 end
 defs[key]=d;return d
end
local pistol=weapon("Laspistol","LaserCannon",180,1.1,8)
add("imp_commissar","Commissar","infantry",70,350,650,500,18,1,"40k_roster.lua",{pistol})
add("imp_kasrkin","Kasrkin","infantry",55,280,520,320,20,1,"40k_roster.lua",{weapon("Hellgun","LaserCannon",300,.8,12)})
add("imp_scout","Scout Marine","infantry",30,150,300,220,23,1,"40k_roster.lua",{weapon("Scout bolter","Cannon",280,.8,10)})
add("imp_devastator","Heavy Bolter Marine","infantry",85,420,800,480,18,1,"40k_roster.lua",{weapon("Heavy bolter","Cannon",360,1.3,8,3,.2)})
add("imp_ogryn","Ogryn","infantry",90,450,850,800,17,1,"40k_roster.lua",{weapon("Ripper gun","Cannon",200,1.3,14,3,.25),{name="Ogryn fists",weapontype="Melee",range=24,reloadtime=2.6,damage={default=65},turret=true}})
add("imp_heavy_weapon_team","Heavy Weapon Team","infantry",100,500,900,450,18,1,"40k_roster.lua",{weapon("Team lasgun","LaserCannon",260,.9,6)})
add("imp_heavy_weapon_team_deployed","Deployed Heavy Weapon Team","infantry",100,500,900,450,0,2,"40k_roster.lua",{weapon("Deployed heavy bolter","Cannon",450,1.4,10,3,.2)})
add("imp_sentinel","Sentinel","walker",220,1100,1800,1400,28,2,"40k_roster.lua",{weapon("Multi-laser","LaserCannon",350,1.2,15,3,.22)})
add("imp_dreadnought","Dreadnought","walker",450,2200,3400,2800,22,2,"40k_roster.lua",{weapon("Assault cannon","Cannon",330,1.2,16,4,.18),{name="Dreadnought power fist",weapontype="Melee",range=35,reloadtime=2.8,damage={default=160},turret=true}})
local earthshaker=weapon("Earthshaker","Cannon",1000,8,400);earthshaker.areaofeffect=64;earthshaker.weaponvelocity=350;earthshaker.hightrajectory=1;earthshaker.explosiongenerator="custom:40k_battlecannon_impact"
add("imp_basilisk","Basilisk","artillery",550,2700,4500,2200,35,3,"40k_roster.lua",{earthshaker,weapon("Hull heavy bolter","Cannon",300,1.2,2,3,.25)})
local flame={name="Inferno cannon",weapontype="Flame",range=220,reloadtime=1.5,burst=5,burstrate=.12,weaponvelocity=250,damage={default=14},turret=true,areaofeffect=16,collidefriendly=true,collideenemy=true,collideground=true,collidefeature=true,collideneutral=true,collidenontarget=true,avoidfriendly=true}
add("imp_hellhound","Hellhound","tank",380,1900,3000,2400,40,3,"40k_roster.lua",{flame,weapon("Hull heavy bolter","Cannon",300,1.2,2,3,.25)})
local autocannon=weapon("Predator autocannon","Cannon",430,3.5,130);autocannon.areaofeffect=16;autocannon.explosiongenerator="custom:40k_battlecannon_impact"
add("imp_predator","Predator","tank",500,2500,3800,3000,40,3,"40k_roster.lua",{autocannon,weapon("Left heavy bolter","Cannon",310,1.2,2,3,.25),weapon("Right heavy bolter","Cannon",310,1.2,2,3,.25)})
local hwtCrew=defs["imp_heavy_weapon_team_deployed"]
if hwtCrew then
 hwtCrew.customparams.source_secondarycrew_prefix="2_"
 hwtCrew.customparams.source_secondarycrew_idleclip="crew2_idle"
 hwtCrew.customparams.source_secondarycrew_fireclip="crew2_fire_idle"
end
local structures={
 {"imp_hq","Imperium Headquarters","HQ",600,3000,5000,5000,6,{"imp_enginseer"}},
 {"imp_barracks","Imperium Barracks","barracks",240,1200,1800,2400,5,{"imp_guardsman","imp_marine","imp_commissar","imp_kasrkin","imp_ogryn","imp_scout","imp_devastator","imp_heavy_weapon_team"}},
 {"imp_tank_factory","Imperium Tank Factory","tank_factory",500,2500,3600,3800,8,{"imp_russ","imp_basilisk","imp_hellhound","imp_predator"}},
 {"imp_walker_factory","Imperium Walker Factory","walker_factory",420,2100,3200,3200,6,{"imp_sentinel","imp_dreadnought"}},
 {"imp_generator","Plasma Generator","generator",150,0,1400,900,3},
 {"imp_mex","Listening Post Extractor","mex",60,300,600,850,3},
 {"imp_thermo","Thermo Plasma Generator","thermo",500,3500,4500,2400,5},
 {"imp_research","Tactica Command","research",280,1400,2400,2400,5},
}
for _,s in ipairs(structures)do
 local d=add(s[1],s[2],s[3],s[4],s[5],s[6],s[7],0,s[8],"40k_roster.lua")
 if d then
  -- Native static buildings/extractors require a nonempty yard map.
  d.yardmap=string.rep("o",s[8]*s[8])
  if s[9]then d.builder=true;d.workertime=s[3]=="HQ" and 120 or 100;d.builddistance=200;d.canmove=true;d.buildoptions=s[9];d.yardmap=string.rep("e",s[8]*s[8]) end
  -- Completed factories produce units; construction clips must not repeat here.
  if s[1]=="imp_walker_factory" then d.customparams.source_buildclip="production"
  elseif s[1]=="imp_barracks" or s[1]=="imp_tank_factory" then d.customparams.source_buildclip="idle" end
  if s[3]=="generator" then d.energymake=25;d.energystorage=100 end
  if s[3]=="mex" then d.extractsmetal=.001;d.activatewhenbuilt=true;d.onoffable=true;d.energyupkeep=3 end
  if s[3]=="thermo" then d.yardmap="ooooo ooooo oogoo ooooo ooooo";d.energymake=250;d.energystorage=500 end
  if s[3]=="research" then d.customparams.research_pending=1 end
 end
end
local builder=add("imp_enginseer","Techpriest Enginseer","builder",90,450,800,450,19,1,"40k_roster.lua",{pistol})
if builder then
 builder.builder=true;builder.workertime=100;builder.builddistance=160;builder.canrepair=true;builder.canreclaim=true;builder.canassist=true
 builder.buildoptions={"imp_hq","imp_barracks","imp_tank_factory","imp_walker_factory","imp_generator","imp_mex","imp_thermo","imp_research"}
 builder.customparams.buildclip="build_1"
end
local sourceMounts={["imp_barracks"]={},["imp_basilisk"]={{["source_muzzle"]="marker_main_barrel",["source_aimpiece"]="unit_aim",["source_fireclip"]="fire",["source_pitchpiece"]="bone_main_aim_vert"},{["source_muzzle"]="marker_hull_bolter",["source_aimpiece"]="bone_hull_aim_horiz",["source_fireclip"]="hull_fire",["source_pitchpiece"]="bone_hull_aim_vert"}},["imp_commissar"]={{["source_muzzle"]="marker_muzzle_laspistol",["source_aimpiece"]="unit_aim",["source_fireclip"]="fire"}},["imp_devastator"]={{["source_muzzle"]="marker_marine_ heavy_bolter_barrel",["source_aimpiece"]="unit_aim",["source_fireclip"]="fire"}},["imp_dreadnought"]={{["source_muzzle"]="marker_assault_cannon_barrel",["source_aimpiece"]="unit_aim",["source_fireclip"]="fire",["source_pitchpiece"]="right_arm_vert_aim"},{["source_muzzle"]="dreadnaught_melee_wrist_l",["source_aimpiece"]="unit_aim",["source_fireclip"]="melee"}},["imp_enginseer"]={{["source_muzzle"]="marker_muzzle_laspistol",["source_aimpiece"]="unit_aim",["source_fireclip"]="fire"}},["imp_generator"]={},["imp_heavy_weapon_team"]={{["source_muzzle"]="marker_lasgun_muzzle",["source_fireclip"]="fire",["source_aimpiece"]="unit_aim"}},["imp_heavy_weapon_team_deployed"]={{["source_muzzle"]="marker_muzzle_heavy_bolter",["source_aimpiece"]="bone_gun_horizontal",["source_fireclip"]="fire",["source_pitchpiece"]="bone_gun_vertical"}},["imp_hellhound"]={{["source_muzzle"]="marker_turret_barrel_l",["source_aimpiece"]="hellhound_bone_04_aim_hor",["source_fireclip"]="fire",["source_pitchpiece"]="hellhound_bone_05_aim_vert_bone_05"},{["source_muzzle"]="marker_bolter_barrel",["source_aimpiece"]="bone_hull_aim_horiz",["source_fireclip"]="hull_fire",["source_pitchpiece"]="bone_hull_aim_vert"}},["imp_hq"]={},["imp_kasrkin"]={{["source_muzzle"]="marker_lasgun_muzzle",["source_aimpiece"]="unit_aim",["source_fireclip"]="fire"}},["imp_mex"]={},["imp_ogryn"]={{["source_muzzle"]="marker_ripper_gun_muzzle",["source_aimpiece"]="unit_aim",["source_fireclip"]="fire"},{["source_muzzle"]="bip01 r hand",["source_aimpiece"]="unit_aim",["source_fireclip"]="melee"}},["imp_predator"]={{["source_muzzle"]="marker_autocannon",["source_aimpiece"]="aim_horizontal_main",["source_fireclip"]="fire",["source_pitchpiece"]="aim_vertical_main"},{["source_muzzle"]="marker_heavy_bolter_barrel_l",["source_aimpiece"]="aim_horizontal_left",["source_pitchpiece"]="aim_vertical_left"},{["source_muzzle"]="marker_heavy_bolter_barrel_r",["source_aimpiece"]="aim_horizontal_right",["source_pitchpiece"]="aim_vertical_right"}},["imp_research"]={},["imp_scout"]={{["source_muzzle"]="marker_marine_bolter_barrel",["source_aimpiece"]="unit_aim",["source_fireclip"]="fire"}},["imp_sentinel"]={{["source_muzzle"]="marker_multilaser_muzzle",["source_aimpiece"]="unit_aim",["source_fireclip"]="fire",["source_pitchpiece"]="aim_vertical_guns"}},["imp_tank_factory"]={},["imp_thermo"]={},["imp_walker_factory"]={}}
local sourceRoots={["imp_barracks"]="bunker",["imp_basilisk"]="body",["imp_generator"]="plasma_generator",["imp_heavy_weapon_team"]="bip01 pelvis",["imp_heavy_weapon_team_deployed"]="bone_gun_horizontal",["imp_hq"]="hq",["imp_mex"]="listening_post",["imp_research"]="tactica_base",["imp_scout"]="bip01",["imp_sentinel"]="bip01",["imp_tank_factory"]="bunker_base",["imp_thermo"]="thermo_base",["imp_walker_factory"]="piekeystone"}
for key,d in pairs(defs)do
 d.customparams.rosterrole=d.customparams.production_role
 if sourceRoots[key]then d.customparams.root_bone=sourceRoots[key]end
 for n,ref in ipairs(sourceMounts[key] or {})do d.weapondefs["mount"..n].customparams=ref end
end
return defs

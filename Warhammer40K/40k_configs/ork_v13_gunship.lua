-- User-approved Blender14 Gunship: four recessed twin-cannon Kans and two
-- forward quad-Shoota Kans. No bomb, extra gantry or decorative Grot crew.
local M={Version=5,Policy='gunship_approved_kan_turrets_no_bomb_v5'}
local names={'port_fore','port_aft','starboard_fore','starboard_aft','port_gantry','starboard_gantry'}
local function clone(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=clone(x)end;return r end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function positive(v)return finite(v)and v>0 end
local function nativeCone(yaw,pitch)
 -- Native maxAngleDif is the FULL cone width. It only prefilters targets;
 -- the script retains the tighter measured rectangular yaw/pitch envelope.
 -- Five extra degrees cover owner-origin versus turret-axis parallax.
 -- Beyond90degree yaw, the widest part of a rectangular sector is its
 -- level edge, not its raised corner. Keep this native prefilter enclosing
 -- the measured sector while the exact floor/ceiling remains script-owned.
 local c=math.cos(yaw)
 return math.min(360,2*math.deg(math.acos(math.min(c,c*math.cos(pitch))))+10)
end
function M.Apply(defs,facts)
 local g=facts and facts.ork_gunship;if not g then return{definitions={},nativeAccepted=false}end
 assert(not defs.ork_gunship,'Gunship already registered')
 assert(g.source_asset=='MOW-02'and g.source_label=='Orc_Ship2'and g.recipe=='ORK-AIR-3-GUNSHIP'and g.export_verified==true and g.objectname=='40k/ork_gunship.glb','Exact MOW hull closure required')
 assert(g.loadout_revision==4 and g.approved_blender_revision==14 and g.articulated_turrets_verified==true,'Fresh approved articulated Blender14 export required')
 assert(g.main_barrel_radial_scale==2 and g.forward_axis=='+Z','Approved radial2 nose and native forward axes required')
 assert(g.visible_weapon_count==13 and g.visible_cannon_count==9 and g.visible_shoota_barrel_count==8 and g.turret_count==7,'Exact visible gun/native owner correspondence required')
 assert(g.native_weapon_owner_count==7 and g.simultaneous_volley_revision==1,'Seven-owner real-barrel geometry contract required')
 assert(g.presentation_hover_revision==1 and g.presentation_hover_amplitude==1.5 and g.native_model_metadata_revision==1 and g.static_wreck,'Exact bounded hover/native envelope and static wreck facts required')
 assert(g.weapon_arc_revision==1,'Fresh measured paired-elevation envelope required')
 assert(g.bomb_removed==true and g.rejected_neck_cannons_removed==true and g.grot_crew_count==0,'Rejected model features must be absent')
 for _,k in ipairs({'root','nose_yaw','nose_pitch','nose_muzzle','nose_axis'})do assert(g.pieces and g.pieces[k],'Actual nose piece missing '..k)end
 for _,b in ipairs({g.bounds,g.bodyBounds})do assert(b and b.min and b.max,'Measured hull bounds required');for i=1,3 do assert(finite(b.min[i])and finite(b.max[i])and b.max[i]>b.min[i],'Strict measured hull bounds required')end end
 for _,k in ipairs({'footprintx','footprintz'})do assert(positive(g[k])and g[k]<=64 and g[k]==math.floor(g[k]),'Measured native footprint required')end
 assert(type(g.collisionvolumescales)=='string'and type(g.collisionvolumeoffsets)=='string','Measured collision fields required')
 assert(positive(g.nose_yaw_limit)and g.nose_yaw_limit<=math.rad(6.001)and positive(g.nose_pitch_down_limit)and g.nose_pitch_down_limit<=math.rad(20.001)and positive(g.nose_pitch_up_limit)and g.nose_pitch_up_limit<=math.rad(10.001),'Approved safe nose articulation required')
 if g.nose_recoil_distance then assert(positive(g.nose_recoil_distance)and g.nose_recoil_distance<=8 and g.pieces.nose_recoil,'Measured nose recoil required')end
 for _,name in ipairs(names)do
  local t=assert(g.turrets and g.turrets[name],'Measured turret absent '..name)
  local kind=name:find('gantry',1,true)and'shoota'or'cannon'
  assert(t.kind==kind and t.bind_axes_identity==true and t.barrel_neutral_forward=='+Z','Actual identity-bind turret kind required')
  assert(finite(t.yaw_center)and math.abs(t.yaw_center)<=math.pi and positive(t.yaw_limit)and t.yaw_limit<=math.pi,'Measured hull-safe yaw required')
  assert(finite(t.pitch_down_limit)and t.pitch_down_limit>=0 and(kind=='shoota'or t.pitch_down_limit>0)and t.pitch_down_limit<=math.rad(80.001)and positive(t.pitch_up_limit)and t.pitch_up_limit<=math.pi*.5,'Safe physical pitch required')
  if kind=='shoota'then assert(t.yaw_limit==math.pi and t.pitch_up_limit==math.pi*.5 and type(t.yaw_pitch_floor)=='table','Full azimuth/zenith with measured hull clearance required')end
  assert(type(t.yaw_pitch_floor)=='table'and type(t.yaw_pitch_ceiling)=='table','Measured safe floor AND ceiling required '..name)
  assert(positive(t.recoil_distance)and t.recoil_distance<=8,'Measured small barrel recoil required')
  for _,suffix in ipairs({'yaw','axis','left_pitch','right_pitch','left_recoil','right_recoil'})do assert(g.pieces[name..'_'..suffix],'Actual turret piece missing '..name..'_'..suffix)end
  for _,side in ipairs({'left','right'})do
   if kind=='shoota'then for i=1,2 do assert(g.pieces[name..'_'..side..'_muzzle_'..i],'Actual Shoota muzzle missing')end
   else assert(g.pieces[name..'_'..side..'_muzzle'],'Actual cannon muzzle missing')end
  end
 end
 local donor=assert(defs.corcrwh,'Actual Cortex Dragon donor missing');assert(donor.canfly and donor.canmove and donor.hoverattack,'Native Dragon flight required')
 local d=clone(donor);d.name='Ork Gunship';d.description='T3 Dragon-style gunship; heavy nose Kannon, four recessed twin-cannon turrets and two quad Big Shoota turrets'
 d.objectname=g.objectname;d.script='40k_ork_gunship.lua';d.buildpic='40k_ork_gunship.png'
 d.metalcost=4600;d.energycost=64000;d.buildtime=60000;d.health=15000
 -- Higher ordinary native hover and native attack-body pitch. Extreme
 -- overhead targets remain the purpose of the independent AA mounts.
 d.cruisealtitude=270
 -- Zero retains native no-land hovering but removes random horizontal wind.
 -- A small bounded ordinary root Move supplies smooth idle presentation.
 d.airhoverfactor=0;d.upright=false;d.nochasecategory=''
 d.canfly=true;d.canmove=true;d.canattack=true;d.canmanualfire=false;d.builder=false;d.buildoptions={};d.workertime=0
 d.hoverattack=true;d.collide=true;d.blocking=false;d.category='ALL MOBILE VTOL AIR NOTSUB'
 -- Ordinary self-acquisition covers the1470 ground guns and1100 AA guns;
 -- donor850 air sight would otherwise hide useful fighter-defence targets.
 d.sightdistance=1600;d.airsightdistance=1600
 d.footprintx=g.footprintx;d.footprintz=g.footprintz;d.collisionvolumetype='box';d.collisionvolumescales=g.collisionvolumescales;d.collisionvolumeoffsets=g.collisionvolumeoffsets;d.usepiececollisionvolumes=false
 local cp={prototype40k=1,faction='Orks',rosterrole='aircraft',techlevel=3,prototype40k_ork_v13_recipe=g.recipe,
  prototype40k_donor='ork_gunship',prototype40k_tech_requires='ork_gunship',prototype40k_native_donor='corcrwh',prototype40k_ork_aircraft_domain=1,prototype40k_source_asset='MOW-02',
  prototype40k_native_clearance_pending=1,prototype40k_source_clip_claim=0,prototype40k_native_air_accepted=g.nativeAccepted==true and 1 or 0,
  prototype40k_gunship_loadout_revision=4,prototype40k_gunship_loadout_policy=M.Policy,prototype40k_gunship_mount_count=7,prototype40k_gunship_visible_gun_count=13,prototype40k_gunship_turret_count=7,prototype40k_gunship_simultaneous_volley=1,
  prototype40k_gunship_broadsides_pending=0,prototype40k_hide_rejected_legacy_loadout=0,
  prototype40k_gunship_alternating_cannons=1,
  prototype40k_nose_yaw_center=0,prototype40k_nose_yaw_limit=g.nose_yaw_limit,prototype40k_nose_pitch_down_limit=g.nose_pitch_down_limit,prototype40k_nose_pitch_up_limit=g.nose_pitch_up_limit,
  prototype40k_nose_recoil_distance=g.nose_recoil_distance,prototype40k_gunship_cruise_altitude=270,
  prototype40k_gunship_mg_salvo_sound='sounds/40k/weapon_big_shoota_1.wav',
  prototype40k_gunship_runtime_revision=11,i18n_en_humanname=d.name,i18n_en_tooltip=d.description};d.customparams=cp
 if g.engine_exhaust_revision then
  assert(g.engine_exhaust_revision==1 and g.pieces.engine_exhaust_port and g.pieces.engine_exhaust_starboard,'Measured native engine markers required')
  cp.prototype40k_gunship_engine_exhaust_revision=1
 end
 d.weapondefs={nose_kannon={name='Gunship Siege Kannon',weapontype='Cannon',turret=true,range=1100,reloadtime=8,weaponvelocity=560,
  areaofeffect=128,edgeeffectiveness=.35,damage={default=1800,vtol=450},mygravity=.1,accuracy=80,targetmoveerror=.2,tolerance=2000,
  cratermult=0,impulsefactor=0,collidefriendly=true,collideenemy=true,collideground=true,collidefeature=true,collidenontarget=true,avoidfriendly=true,avoidfeature=true,
  size=6,rgbcolor='1 .65 .12',explosiongenerator='custom:40k_gunship_siege_impact',soundtrigger=true,
  customparams={source_fx_family='artillery',source_muzzle='nose_muzzle',source_aimpiece='nose_yaw',source_pitchpiece='nose_pitch',source_recoilpiece=g.nose_recoil_distance and'nose_recoil'or nil,source_muzzlefx='40k_gunship_siege_muzzle',source_group='nose',prototype40k_authored_loadout=1}}}
 d.weapons={{def='nose_kannon',onlytargetcategory='SURFACE VTOL',maindir='0 0 1',maxangledif=nativeCone(g.nose_yaw_limit,math.max(g.nose_pitch_down_limit,g.nose_pitch_up_limit))}}
 for _,name in ipairs(names)do
  local t=g.turrets[name];local shoota=t.kind=='shoota';local key=name..(shoota and'_quad_big_shoota'or'_twin_kannon')
  local muzzle=name..'_left'..(shoota and'_muzzle_1'or'_muzzle');local muzzles={}
  for _,side in ipairs({'left','right'})do for i=1,shoota and 2 or 1 do muzzles[#muzzles+1]=name..'_'..side..(shoota and('_muzzle_'..i)or'_muzzle')end end
   local w={name='Gunship '..name:gsub('_',' ')..(shoota and' fighter defence quad Big Shoota'or' twin Kannon'),weapontype=shoota and'LaserCannon'or'Cannon',turret=true,
    -- 1470 is exactly +40%. Old290 velocity capped real reach to1051 at
    -- gravity80 (647 at130).520/135 retains true1470 reach; recessed guns
    -- now use the native HIGH root to clear the hull in forward sectors.
    -- At level1470 this is~66.4degrees/~7s flight. Nose stays low-arc.
    -- Native gravity/leading/collision remain authoritative.
    range=shoota and 1100 or 1470,reloadtime=shoota and 2.4 or 1.75,weaponvelocity=shoota and 1000 or 520,
    projectiles=shoota and 4 or 1,burst=shoota and 15 or 1,burstrate=shoota and .1 or nil,canattackground=not shoota,mygravity=not shoota and .15 or nil,
    duration=shoota and .01 or nil,thickness=shoota and .7 or nil,corethickness=shoota and .3 or nil,hardstop=shoota and true or nil,
    -- Native angle units use sin(value*pi/0xafff):100/200 give~.400/.799
    -- degrees, <=1.199 combined at zeroXP. Steady native leading replaces
    -- randomized speed-leading jitter, while finite rounds still disperse
    -- and can miss maneuvering targets. No homing or enforced hit/miss quota.
    accuracy=shoota and 100 or nil,sprayangle=shoota and 200 or nil,predictboost=shoota and 1 or nil,
    firetolerance=shoota and 32768 or nil,
    hightrajectory=shoota and 0 or 1,tolerance=4000,areaofeffect=shoota and 8 or 60,edgeeffectiveness=.35,cratermult=0,impulsefactor=0,
    collidefriendly=true,collideenemy=true,collideground=true,collidefeature=true,collideneutral=true,collidenontarget=true,avoidfriendly=true,avoidfeature=true,
    damage={default=shoota and 15 or 160},size=not shoota and 1 or nil,stages=not shoota and 2 or nil,rgbcolor='1 .8 .3',
    explosiongenerator=shoota and'custom:40k_dow_big_shoota_impact'or'custom:genericshellexplosion-medium',soundtrigger=true,soundstart=shoota and''or nil,
    customparams={source_weapon=shoota and'attrib/weapon/ork_big_shoota_turret_listeningpost.lua'or'attrib/weapon/ork_lobba_boomy_platform.lua',
     source_fx_family=shoota and'gunship_mg_salvo'or'artillery',source_actual_salvo_sound=shoota and 1 or nil,source_muzzle=muzzle,source_muzzle_pair=table.concat(muzzles,','),
     source_aimpiece=name..'_yaw',source_pitchpiece=name..'_left_pitch',source_recoilpiece=name..'_left_recoil',source_muzzlefx=shoota and'40k_dow_big_shoota_muzzle'or'40k_dow_artillery_muzzle',
     source_group=name,source_native_volley=shoota and 4 or 1,source_alternating_barrels=not shoota and 1 or nil,prototype40k_authored_loadout=1}}
   -- Pinned CWeapon::UpdateSalvo calls Shot -> Query -> Fire for each
   -- native projectile in the SAME frame. MG owners synchronize all four
   -- barrels. Cannon owners alternate one real barrel every1.75s, so each
   -- barrel retains a nominal3.5s cycle without scripted damage/shots.
   -- AA fires15 native salvos/2.4s with four15-damage rounds each:375DPS
   -- versus prior366.7, a reversible2.3% adjustment. The original1.451s
   -- Big Shoota sample starts once at the first ACTUAL shot of its1.4s burst.
   -- A native tracking pause/interruption can leave a bounded sample tail;
   -- it never restarts the sample for each salvo or invents a sound timer.
   d.weapondefs[key]=w
   -- UnitDef mainDir is object space (+right), while rigid model X is -right.
   -- The old unflipped X made every broadside acquisition cone face inboard.
   d.weapons[#d.weapons+1]={def=key,onlytargetcategory=shoota and'VTOL'or'SURFACE VTOL',maindir=string.format('%.8f 0 %.8f',-math.sin(t.yaw_center),math.cos(t.yaw_center)),maxangledif=shoota and 360 or nativeCone(t.yaw_limit,math.max(t.pitch_down_limit,t.pitch_up_limit)),burstcontrolwhenoutofarc=shoota and 1 or nil}
  cp['prototype40k_'..name..'_yaw_center']=t.yaw_center;cp['prototype40k_'..name..'_yaw_limit']=t.yaw_limit
  cp['prototype40k_'..name..'_pitch_down_limit']=t.pitch_down_limit;cp['prototype40k_'..name..'_pitch_up_limit']=t.pitch_up_limit;cp['prototype40k_'..name..'_recoil_distance']=t.recoil_distance
  for _,kind in ipairs({'floor','ceiling'})do
   local rows=t['yaw_pitch_'..kind]
   if rows then
    cp['prototype40k_'..name..'_pitch_'..kind..'_count']=#rows
    for i,row in ipairs(rows)do cp['prototype40k_'..name..'_pitch_'..kind..'_yaw_'..i]=row.yaw;cp['prototype40k_'..name..'_pitch_'..kind..'_pitch_'..i]=row.pitch end
   end
  end
 end
 d.sfxtypes={explosiongenerators={'custom:40k_dow_big_shoota_muzzle','custom:40k_dow_artillery_muzzle','custom:40k_gunship_siege_muzzle'}}
 d.explodeas='largeExplosionGeneric';d.selfdestructas='largeExplosionGenericSelfd'
 local wreck=g.static_wreck
 assert(g.salvage_fraction==.25,'Existing one-wreck entitlement required');d.corpse='dead';d.featuredefs={dead={name='Ork Gunship wreck',description='Reclaimable Gunship hull',object=g.objectname,
  blocking=false,reclaimable=true,resurrectable=0,indestructible=true,flammable=false,featuredead='',damage=7500,health=7500,metal=1150,energy=16000,reclaimtime=15000,
  footprintx=g.footprintx,footprintz=g.footprintz,height=wreck.height,collisionvolumetype='box',collisionvolumescales=wreck.collisionvolumescales,collisionvolumeoffsets=wreck.collisionvolumeoffsets,
  customparams={prototype40k_gunship_salvage=1,parent_actor='ork_gunship',prototype40k_remains_domain='vehicle'}}}
 defs.ork_gunship=d;return{definitions={'ork_gunship'},nativeAccepted=false,policy=M.Policy,broadsidesPending=false,bombRetired=true}
end
return M

-- Genuine T1 additions; shared squad/remains/native damage owners only.
-- Provisional tuning: eight Gretchin bodies, 8M/40E/96 work per body; one
-- Bomb Squig creature, 35M/175E/420 work. No constructor, capacity research,
-- missing-member grant or source HQ/population semantics are imported.
local M={Version=1,ProfileID=20,GretchinActor='ork_gretchin_combat',BombActor='ork_bomb_squig'}
M.Actors={ork_gretchin_combat={feature='40k_gretchin_combat_corpse',name='Gretchin'},
 ork_bomb_squig={feature='40k_bomb_squig_corpse',name='Bomb Squig'}}
local function copy(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
local function positive(v)return type(v)=='number'and v==v and v>0 and v<math.huge end
function M.Closed(facts,V)
 if type(facts)~='table'or not(V and V.FileExists)then return false end
 for actor,row in pairs(M.Actors)do
  local f=facts[actor]
  if not f or f.actor~=actor or f.corpse~=row.feature or not positive(f.speed)
   or not positive(f.sourceStride)or not positive(f.contacts)or type(f.collisionvolumescales)~='string'
   or type(f.collisionvolumeoffsets)~='string'or not f.liveBounds or not f.corpseBounds
   or not f.sourceWHMSHA256 or f.nativeAccepted~=false then return false end
  for _,path in ipairs({'objects3d/'..actor..'.glb','objects3d/'..actor..'.glb.lua',
   'unittextures/'..actor..'_tex1.png','unittextures/'..actor..'_tex2.png',
   'scripts/generated/'..actor..'_anim.lua','unitpics/40k_'..actor..'.png',
   'objects3d/'..row.feature..'.glb','objects3d/'..row.feature..'.glb.lua',
   'unittextures/'..row.feature..'_tex1.png','unittextures/'..row.feature..'_tex2.png','scripts/40k_roster.lua'})do
   if V.FileExists(path)~=true then return false end
  end
 end
 return facts.ork_gretchin_combat.muzzle=='marker_grot_blaster_barrel'and facts.ork_bomb_squig.muzzle=='marker_center'
end
local function base(actor,f,cost,health,role)
 return {objectname=actor..'.glb',script='40k_roster.lua',buildpic='40k_'..actor..'.png',
  metalcost=cost[1],energycost=cost[2],buildtime=cost[3],mass=cost[1],health=health,speed=f.speed,
  maxacc=.12,maxdec=.3,turnrate=1100,turninplace=true,canmove=true,canattack=true,
  builder=false,buildoptions={},footprintx=1,footprintz=1,movementclass='SBOT2',maxslope=36,maxwaterdepth=5,
  sightdistance=360,category='ALL MOBILE NOTSUB SURFACE',collisionvolumetype='Box',
  collisionvolumescales=f.collisionvolumescales,collisionvolumeoffsets=f.collisionvolumeoffsets,
  selectionvolumetype='Box',selectionvolumescales=f.collisionvolumescales,selectionvolumeoffsets=f.collisionvolumeoffsets,
  usepiececollisionvolumes=false,usepieceselectionvolumes=false,weapons={},weapondefs={},
  customparams={faction='Orks',prototype40k=1,prototype40k_four_faction=1,prototype40k_source_progression=1,
   animsource=actor,root_bone='bip01',rosterrole=role,unitgroup='weapon',prototype40k_donor=actor,
   techlevel=1,prototype40k_tech_requires=actor=='ork_gretchin_combat'and'ork_gretchin_squad'or'ork_bomb_squig',
   locomotion_source_stride=f.sourceStride,locomotion_playback=f.playback,
   locomotion_contact_samples=f.contacts,locomotion_policy='natural_source_stride_v1',
   prototype40k_t1_roster=1,prototype40k_native_acceptance_pending=1,
   prototype40k_salvage_policy='sole_tactical_owner_25percent_body_metal_zero_energy'}}
end
function M.Definitions(facts,V)
 if not M.Closed(facts,V)then return {} end
 local g=base(M.GretchinActor,facts[M.GretchinActor],{8,40,96},80,'infantry')
 g.name='Gretchin';g.description='T1 Gretchin blaster infantry; full eight-body squad per paid order'
 g.customparams.source_voice_profile='grot'
 g.weapondefs.blaster={name='Gretchin Blaster',weapontype='Cannon',range=180,reloadtime=1.25,
  weaponvelocity=520,turret=true,tolerance=4000,areaofeffect=1,cratermult=0,impulsefactor=0,
  avoidfriendly=true,avoidfeature=true,collidefriendly=true,collideenemy=true,collideground=true,
  collidefeature=true,collideneutral=true,collidenontarget=true,damage={default=4},
  size=.2,stages=2,rgbcolor='1 .8 .3',explosiongenerator='custom:40k_shoota_impact',
  soundstart='40k_shoota',soundstartvolume=.7,
  customparams={source_muzzle='marker_grot_blaster_barrel',source_fireclip='fire',source_aimpiece='unit_aim',source_wholebodyaim=1,source_fx_family='shoota'}}
 g.weapons={{onlytargetcategory='SURFACE',def='blaster'}}
 local b=base(M.BombActor,facts[M.BombActor],{35,175,420},100,'creature')
 b.name='Bomb Squig';b.description='T1 single bomb-carrying creature; native close-range detonation; one paid body'
 -- Pinned native parser adds25 to this authored distance: effective65, inside
 -- the72 blast radius. Ordinary attack/LOS and native event admission survive.
 b.kamikaze=true;b.kamikazedistance=40;b.kamikazeuselos=true
 b.explodeas='40k_bomb_squig_blast';b.selfdestructas='40k_bomb_squig_blast';b.selfdestructcountdown=0
 b.cantbetransported=true;b.canmanualfire=false;b.customparams.prototype40k_creature_singleton=1
 b.customparams.prototype40k_squad_exception='Single creature; paid once; cannot restore a dead singleton'
 -- Source contains no firing clip. Native kamikaze supports stock attack
 -- orders without a fake zero-damage gun; death is the sole blast/damage path.
 -- Generic roster Killed returns0 and invokes the existing shared remains
 -- owner; neither definition has a native corpse or second salvage callback.
 return {ork_gretchin_squad=g,ork_bomb_squig=b}
end
function M.Profiles(baseProfiles,facts,V,sourceEnabled)
 if sourceEnabled~=true or not M.Closed(facts,V)then return baseProfiles end
 assert(not baseProfiles.byID[M.ProfileID]and not baseProfiles.profiles.ork_gretchin,'Gretchin stable squad ID collision')
 for _,key in ipairs(baseProfiles.order)do local p=baseProfiles.profiles[key]
  assert(p.product~='ork_gretchin_squad'and p.member~='ork_gretchin_member','Gretchin squad actor collision')
 end
 local out=copy(baseProfiles)
 out.profiles.ork_gretchin={id=M.ProfileID,product='ork_gretchin_squad',member='ork_gretchin_member',capacity=8,spacing=14,
  name='Gretchin Mob',shortRole='Light blaster mob',description='8 real Gretchin per paid order. Builders heal survivors and restore casualties for resources.'}
 out.byID[M.ProfileID]='ork_gretchin';out.order[#out.order+1]='ork_gretchin'
 return out
end
function M.RegisterRemains(owner,facts,V)
 if not M.Closed(facts,V)then return false end
 assert(owner and owner.Version==1 and owner.Fraction==.25 and owner.Actors and owner.Definition,'Existing sole remains owner required')
 for actor in pairs(M.Actors)do assert(not owner.Actors[actor],'Duplicate T1 corpse actor '..actor)end
 for actor,row in pairs(M.Actors)do owner.Actors[actor]=copy(row)end
 return true
end
function M.FeatureDefinitions(owner,facts,V)
 if not M.RegisterRemains(owner,facts,V)then return {} end
 local out={}
 for actor,row in pairs(M.Actors)do local d=owner.Definition(row.feature..'.glb',actor)
  local f=facts[actor];local low,high=f.corpseBounds.min,f.corpseBounds.max
  d.height=high[2]-low[2];d.collisionvolumetype='Box';d.collisionvolumescales=table.concat({high[1]-low[1],high[2]-low[2],high[3]-low[3]},' ')
  d.collisionvolumeoffsets='0 0 0';d.blocking=false
  d.customparams.prototype40k_t1_roster_remains=1
  out[row.feature]=d
 end
 return out
end
return M

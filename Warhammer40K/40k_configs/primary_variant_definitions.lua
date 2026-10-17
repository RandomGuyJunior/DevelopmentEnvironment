-- Candidate native definitions from exact inspected source profiles.
-- Caller supplies readiness and explicit dedicated movement capability.
local M={}
local facts=VFS.Include('40k_configs/primary_variant_candidates.lua')
local function weapon(p,n)
 local melee=p.native_kind=='Melee'
 local sourceAccuracy=assert(tonumber(p.accuracy),'Source accuracy required')
 local spread=melee and 0 or math.max(0,math.floor((1-sourceAccuracy)*600+.5))
 local cp={source_weapon_profile=p.source_weapon_profile,source_profile_sha256=p.source_sha256,
  source_muzzle=p.source_muzzle,source_muzzle_pair=p.source_muzzle_pair,
  source_fireclip=p.source_fireclip,source_aimpiece=p.source_aimpiece,source_pitchpiece=p.source_pitchpiece,
  source_fx_family=p.fx_family,source_accuracy=sourceAccuracy,
  source_damage_min=p.minimum_damage,source_damage_max=p.maximum_damage,
  source_cadence_seconds=p.reload,source_weapon_bones=p.source_weapon_bones,
  source_weapon_bones_only=p.source_weapon_bones_only}
 local w={name=p.source_weapon_profile,weapontype=p.native_kind,turret=true,
  range=melee and 35 or assert(p.range)*10,reloadtime=assert(p.reload),burst=1,
  damage={default=(assert(p.minimum_damage)+assert(p.maximum_damage))/2},
  accuracy=spread,sprayangle=spread,tolerance=3000,areaofeffect=math.max(1,(p.radius or 0)*10),
  cratermult=0,impulsefactor=0,collidefriendly=true,collideenemy=true,collideground=true,
  collidefeature=true,collideneutral=true,collidenontarget=true,avoidfriendly=true,avoidfeature=true,
  weaponvelocity=600,size=.35,customparams=cp}
 -- Only a source-supported category gets a matched existing family. New melta,
 -- zzzap, krak and power-fist identities deliberately await their own FX.
 local known={heavy_bolter=true,bolter=true,shoota=true,battlecannon=true}
 if known[p.fx_family]then w.explosiongenerator='custom:40k_'..p.fx_family..'_impact' end
 if p.native_kind=='BeamLaser'then
  w.beamburst=true;w.beamtime=.055;w.beamttl=2;w.thickness=.6;w.corethickness=.25
  w.rgbcolor=p.fx_family=='melta' and '1 .45 .1' or '.45 .85 1'
 elseif p.native_kind=='MissileLauncher'then
  w.tracks=true;w.turnrate=18000;w.startvelocity=90;w.weaponacceleration=200;w.flighttime=4
 elseif p.native_kind=='Flame'then
  w.weaponvelocity=350;w.duration=.12;w.flamegfxtime=.12;w.size=1
  w.rgbcolor='1 .55 .1';w.rgbcolor2='.35 .1 .02'
 end
 return w
end
function M.Build(key,movementReady)
 local r=facts[key];if not r then return nil end
 -- BOT3 is a genuine pinned native class; every larger candidate needs the
 -- coordinator-owned exact class adapter, not an unrelated pathfinder alias.
 if r.movementclass~='BOT3' and not (movementReady and movementReady(key,r.movementclass,r.footprint))then return nil end
 local d={name=r.name,description=r.faction..' '..r.role..' source candidate',
  objectname=key..'.glb',script='40k_roster.lua',buildpic='40k_'..key..'.png',
  -- Direct source req->metal, power->energy, seconds->30 work adaptation.
  -- Engine completion still depends on actual producer workertime/resources.
  metalcost=r.source_cost.requisition,energycost=r.source_cost.power,
  buildtime=r.source_cost.time*30,health=r.source_health,speed=r.source_speed,
  footprintx=r.footprint,footprintz=r.footprint,movementclass=r.movementclass,
  upright=r.role=='walker',turninplace=r.role=='walker',canmove=true,canattack=true,
  maxacc=.06,maxdec=.15,turnrate=r.role=='walker' and 500 or 250,maxslope=24,maxwaterdepth=5,
  sightdistance=500,category='ALL MOBILE NOTSUB SURFACE',
  collisionvolumetype='Box',collisionvolumescales=table.concat(r.bounds.size,' '),
  collisionvolumeoffsets=table.concat({(r.bounds.min[1]+r.bounds.max[1])/2,(r.bounds.min[2]+r.bounds.max[2])/2,(r.bounds.min[3]+r.bounds.max[3])/2},' '),
  weapondefs={},weapons={},
  customparams={faction=r.faction,prototype40k=1,prototype40k_expansion=1,animsource=key,
   root_bone=r.root_bone,rosterrole=r.role,production_role=r.role,unitgroup='weapon',
   source_entity=r.source_entity,source_squad=r.source_squad,source_model_sha256=r.source_model_sha256,
   source_producer=r.producer,source_squad_transport_slots=r.source_squad_slots,
   source_transport_adaptation_pending=r.source_squad_slots>0 and 1 or nil,
   source_abilities_pending=#r.source_abilities>0 and 1 or nil,
   integration_status='converted_source_candidate_native_unaccepted',
   source_balance_adaptation='source mean damage/cadence/health/speed; range x10; req/power direct; source accuracy mapped linearly to spread; source seconds x30 work',
   role_acceptance_requires='paid source tech/production, egress, all guns/abilities, source-like FX/cadence/collision/animations, transport where applicable'}}
 for n,p in ipairs(r.weapons)do
  d.weapondefs['mount'..n]=weapon(p,n);d.weapons[n]={def='mount'..n,onlytargetcategory='SURFACE'}
 end
 if key=='imp_dreadnought_hellfire'then VFS.Include('40k_configs/hellfire_weapons.lua').Apply(d)end
 return d
end
function M.Apply(defs,ready,movementReady)
 for key in pairs(facts)do
  if ready(key)then local d=M.Build(key,movementReady);if d then defs[key]=d end end
 end
 return defs
end
M.Facts=facts
return M

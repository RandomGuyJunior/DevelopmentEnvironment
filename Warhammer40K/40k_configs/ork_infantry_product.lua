-- Definition/profile adapter only. Existing paid squad, repair, native combat,
-- movement, equipment and remains runtimes remain the authoritative owners.
local Shared={}
local function copy(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
local function positive(v)return type(v)=='number'and v==v and v>0 and v<math.huge end
local function hash(s)return type(s)=='string'and #s==64 and s:match('^[0-9a-f]+$')end
function Shared.New(row)
 assert(type(row)=='table'and hash(row.sourceWHMSHA256)and row.actor and row.feature and row.id and row.capacity)
 local M={Version=1,Actor=row.actor,Feature=row.feature,ProfileID=row.id}
 function M.Closed(f,V)
  if type(f)~='table'or f.actor~=M.Actor or f.corpse~=M.Feature or f.schema~=1
   or not positive(f.speed)or not positive(f.sourceStride)or not positive(f.contacts)or not positive(f.playback)
   or math.abs(f.speed-f.sourceStride*f.playback)>1e-6*math.max(1,f.speed)
   or not hash(f.modelSHA256)or not hash(f.bankSHA256)or f.sourceWHMSHA256~=row.sourceWHMSHA256
   or f.muzzle~=row.muzzle or(row.meleeMuzzle and f.meleeMuzzle~=row.meleeMuzzle)
   or type(f.collisionvolumescales)~='string'or type(f.collisionvolumeoffsets)~='string'
   or type(f.liveBounds)~='table'or type(f.corpseBounds)~='table'or not(V and V.FileExists)then return false end
  for _,actor in ipairs({M.Actor,M.Feature})do
   for _,path in ipairs({'objects3d/'..actor..'.glb','objects3d/'..actor..'.glb.lua',
    'unittextures/'..actor..'_tex1.png','unittextures/'..actor..'_tex2.png'})do
    if V.FileExists(path)~=true then return false end
   end
  end
  for _,path in ipairs({'scripts/40k_roster.lua','scripts/generated/'..M.Actor..'_anim.lua','unitpics/40k_'..M.Actor..'.png'})do
   if V.FileExists(path)~=true then return false end
  end
  return true
 end
 function M.Definitions(f,V)
  if not M.Closed(f,V)then return {} end
  local d={name=row.name,description=row.description,objectname=M.Actor..'.glb',
   script='40k_roster.lua',buildpic='40k_'..M.Actor..'.png',metalcost=row.cost[1],energycost=row.cost[2],buildtime=row.cost[3],
   mass=row.cost[1],health=row.health,speed=f.speed,maxacc=.1,maxdec=.25,turnrate=1000,turninplace=true,
   canmove=true,canattack=true,builder=false,buildoptions={},movementclass='SBOT2',
   footprintx=1,footprintz=1,maxslope=36,maxwaterdepth=5,sightdistance=row.sight or 400,
   category='ALL MOBILE NOTSUB SURFACE',collisionvolumetype='Box',
   collisionvolumescales=f.collisionvolumescales,collisionvolumeoffsets=f.collisionvolumeoffsets,
   selectionvolumetype='Box',selectionvolumescales=f.collisionvolumescales,selectionvolumeoffsets=f.collisionvolumeoffsets,
   usepiececollisionvolumes=false,usepieceselectionvolumes=false,
   customparams={faction='Orks',prototype40k=1,prototype40k_four_faction=1,prototype40k_source_progression=1,
    animsource=M.Actor,root_bone=row.root,rosterrole='infantry',unitgroup='weapon',techlevel=row.tier,
    source_entity=row.entity,source_model_sha256=f.sourceWHMSHA256,source_native_glb_sha256=f.modelSHA256,
    source_voice_profile=row.voice or'ork',prototype40k_tech_requires=M.Actor,prototype40k_donor=M.Actor,
    prototype40k_infantry_completion=1,prototype40k_native_acceptance_pending=1,
    prototype40k_salvage_policy='sole_tactical_owner_25percent_body_metal_zero_energy',
    locomotion_source_stride=f.sourceStride,locomotion_playback=f.playback,
    locomotion_contact_samples=f.contacts,locomotion_policy='natural_source_stride_v1'},
   weapondefs=copy(row.weapondefs),weapons=copy(row.weapons)}
  for key,value in pairs(row.extra or{})do d[key]=copy(value)end
  return {[M.Actor]=d}
 end
 function M.Profiles(base,f,V,sourceEnabled)
  if sourceEnabled~=true or not M.Closed(f,V)then return base end
  assert(not base.byID[M.ProfileID]and not base.profiles[M.Actor],'New Ork infantry stable profile collision')
  for _,key in ipairs(base.order)do local p=base.profiles[key]
   assert(p.product~=M.Actor and p.member~=M.Actor..'_member','New Ork infantry body owner collision')
  end
  local out=copy(base)
  out.profiles[M.Actor]={id=M.ProfileID,product=M.Actor,member=M.Actor..'_member',capacity=row.capacity,spacing=row.spacing or 24,
   name=row.mobName,shortRole=row.shortRole,description=row.mobDescription}
  out.byID[M.ProfileID]=M.Actor;out.order[#out.order+1]=M.Actor
  return out
 end
 function M.RegisterRemains(owner,f,V)
  if not M.Closed(f,V)then return false end
  assert(owner and owner.Version==1 and owner.Fraction==.25 and owner.Actors and owner.Definition,'Existing sole remains owner required')
  assert(not owner.Actors[M.Actor],'Duplicate Ork infantry remains owner')
  owner.Actors[M.Actor]={feature=M.Feature,name=row.name}
  return true
 end
 function M.FeatureDefinitions(owner,f,V)
  if not M.RegisterRemains(owner,f,V)then return {} end
  local d=owner.Definition(M.Feature..'.glb',M.Actor)
  local a,b=f.corpseBounds.min,f.corpseBounds.max
  d.height=b[2]-a[2];d.collisionvolumetype='Box'
  d.collisionvolumescales=table.concat({b[1]-a[1],b[2]-a[2],b[3]-a[3]},' ')
  d.collisionvolumeoffsets='0 0 0';d.blocking=false
  return {[M.Feature]=d}
 end
 return M
end
return Shared

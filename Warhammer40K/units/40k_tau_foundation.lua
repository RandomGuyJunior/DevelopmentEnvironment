-- Tau secondary foundation; no normal-ready default and no acceptance markers.
local defs={}
local opts=Spring and Spring.GetModOptions and Spring.GetModOptions()or{}
if opts.prototype_diagnostic~='taufoundation'then return defs end
local catalog=VFS.Include('40k_configs/tau_foundation_catalog.lua')
for key,c in pairs(catalog)do
 if VFS.FileExists('objects3d/'..key..'.glb')and VFS.FileExists('scripts/40k_roster.lua')and VFS.FileExists('scripts/generated/'..key..'_anim.lua')then
  local mobile=c.speed>0;local builder=c.role=='builder';local factory=c.role=='hq'or c.role:find('factory')~=nil
  local d={name=key:gsub('_',' '),description='Tau source foundation',objectname=key..'.glb',script='40k_roster.lua',buildpic='40k_'..key..'.png',
   health=c.health,metalcost=c.metal,energycost=c.energy,buildtime=c.buildtime,speed=c.speed,footprintx=c.size,footprintz=c.size,
   maxacc=.05,maxdec=.12,turnrate=700,maxslope=30,maxwaterdepth=5,sightdistance=400,canmove=mobile or factory,canattack=#c.weapons>0,
   builder=builder or factory,workertime=(builder or factory)and 100 or nil,builddistance=(builder or factory)and 300 or nil,
   upright=c.role~='hover',movementclass=mobile and(c.role=='hover'and'HOVER3'or'SBOT2')or nil,
   category=mobile and'ALL MOBILE NOTSUB SURFACE'or'ALL NOTSUB SURFACE',
   customparams={prototype40k=1,faction='Tau',animsource=key,rosterrole=c.role,production_role=c.role,source_entity=c.source_entity,
    integration_status='secondary_disabled_native_acceptance_pending',source_buildclip='build',source_effects_pending=1},
   weapondefs={},weapons={}}
  if not mobile then d.yardmap=string.rep(factory and'e'or'o',c.size*c.size)end
  if c.role=='extractor'then d.extractsmetal=.001;d.customparams.source_economy_mapping_pending=1 end
  if c.role=='generator'then d.energymake=1;d.customparams.source_decay_required=1 end
  for n,w in ipairs(c.weapons)do
   local name='mount'..n;d.weapondefs[name]={name=w.customparams.source_weapon_identity,weapontype=w.kind,range=w.range,reloadtime=w.reload,damage={default=w.mean_damage},
    turret=true,weaponvelocity=900,accuracy=180,sprayangle=160,tolerance=3000,areaofeffect=w.kind=='Melee'and 1 or 8,cratermult=0,impulsefactor=0,
    collidefriendly=true,collideenemy=true,collideground=true,collidefeature=true,collidenontarget=true,
    rgbcolor='1 .45 .15',thickness=.3,size=.3,customparams=w.customparams}
   -- Morale facts are retained without falsely asserting measured native hits.
   w.customparams.source_accuracy=w.source_accuracy;w.customparams.source_morale_damage=w.source_morale_damage
   d.weapons[n]={def=name,onlytargetcategory='SURFACE'}
  end
  defs[key]=d
 end
end
return defs
